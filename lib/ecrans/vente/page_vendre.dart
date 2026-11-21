import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/panier.dart';
import '../../domaine/quantites.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../clavier_montant.dart';
import '../communs.dart';
import '../credit/clients.dart';
import 'page_encaisser.dart';
import 'ventes_du_jour.dart';

/// Écran « Vendre » : grille des produits en haut, panier et total en bas.
class PageVendre extends StatefulWidget {
  const PageVendre({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageVendre> createState() => _PageVendreState();
}

class _PageVendreState extends State<PageVendre> {
  final Panier _panier = Panier();

  /// Catégorie affichée (null = toutes).
  String? _categorie;

  Future<void> _choisirClient() async {
    if (_panier.clientId != null) {
      setState(() => _panier.choisirClient(null, null));
      return;
    }
    final c = await Navigator.of(context).push<Client>(
      MaterialPageRoute(
        builder: (_) =>
            PageClients(etat: etat, choisir: true, pourCredit: false),
      ),
    );
    if (c != null && mounted) {
      setState(() => _panier.choisirClient(c.id, c.nom));
    }
  }

  EtatApplication get etat => widget.etat;

  Future<void> _toucherProduit(Produit p) async {
    final conds = (await etat.journal.conditionnements(p.id))
        .where((c) => c.prixVente > 0)
        .toList();
    if (!mounted) return;
    if (!p.aUnPrix && conds.isEmpty) {
      annoncer(
        context,
        '${p.nom} n\'a pas de prix. Demandez au patron.',
        erreur: true,
      );
      return;
    }
    LignePanier? ligne;
    if (conds.isEmpty && !p.auMontant) {
      ligne = _ligne(p, null, 1);
    } else {
      ligne = await showModalBottomSheet<LignePanier>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) =>
            _ChoixUnite(produit: p, conditionnements: conds, ligne: _ligne),
      );
    }
    if (ligne == null) return;
    HapticFeedback.selectionClick();
    setState(() => _panier.ajouter(ligne!));
  }

  LignePanier _ligne(Produit p, Conditionnement? c, int nombre) => LignePanier(
    produitId: p.id,
    nomProduit: p.nom,
    uniteBase: p.uniteBase,
    emoji: p.emoji,
    conditionnement: c,
    nombre: nombre,
    prixUnitaire: c?.prixVente ?? p.prixUnitaire,
  );

  Future<void> _encaisser() async {
    final fini = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PageEncaisser(etat: etat, panier: _panier),
      ),
    );
    if (fini == true) setState(_panier.vider);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final tous = etat.produits;
        String cat(Produit p) => p.catalogueId?.split('.').first ?? 'autres';
        final categories = <String>{for (final p in tous) cat(p)}.toList();
        final produits = _categorie == null
            ? tous
            : tous.where((p) => cat(p) == _categorie).toList();
        String nomCategorie(String id) =>
            etat.catalogue.categories
                .where((c) => c.id == id)
                .firstOrNull
                ?.nom ??
            'Autres';
        final large = estGrandEcran(context);
        final filtre = categories.length > 1
            ? SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final c in <String?>[null, ...categories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('categorie-${c ?? 'tous'}'),
                          label: Text(
                            c == null ? 'Tous' : nomCategorie(c),
                            style: const TextStyle(fontSize: 17),
                          ),
                          selected: _categorie == c,
                          onSelected: (_) => setState(() => _categorie = c),
                        ),
                      ),
                  ],
                ),
              )
            : null;
        final grille = tous.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucun produit. Le patron doit d\'abord ajouter ses produits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: large ? 150 : 132,
                  mainAxisExtent: large ? 150 : 132,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: produits.length,
                itemBuilder: (context, i) => _TuileVente(
                  produit: produits[i],
                  onTap: () => _toucherProduit(produits[i]),
                ),
              );
        final client = Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _panier.clientId == null
                ? TextButton.icon(
                    key: const Key('bouton-client-panier'),
                    onPressed: _choisirClient,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'Client (facultatif)',
                      style: TextStyle(fontSize: 17),
                    ),
                  )
                : InputChip(
                    key: const Key('client-panier'),
                    avatar: const Icon(Icons.person_rounded),
                    label: Text(
                      _panier.clientNom ?? '',
                      style: const TextStyle(fontSize: 17),
                    ),
                    onDeleted: _choisirClient,
                    onPressed: _choisirClient,
                  ),
          ),
        );
        const invitation = Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Touchez les produits vendus.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
          ),
        );
        final totalEtBouton = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
                  ),
                  MontantGeant(
                    _panier.total,
                    key: const Key('total-panier'),
                    couleur: CouleursZp.argentEntre,
                    taille: 40,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GrosBouton(
                key: const Key('bouton-encaisser'),
                texte: 'Encaisser',
                icone: Icons.payments_rounded,
                couleur: CouleursZp.argentEntre,
                hauteur: 72,
                onPressed: _encaisser,
              ),
            ),
          ],
        );
        final actions = [
          IconButton(
            key: const Key('bouton-ventes-du-jour'),
            tooltip: 'Ventes du jour',
            iconSize: 30,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PageVentesDuJour(etat: etat)),
            ),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          const SizedBox(width: 8),
        ];
        if (large) {
          // Tablette / PC : produits à gauche, panier à droite.
          return PageZp(
            titre: 'Vendre',
            icone: Icons.shopping_basket_rounded,
            pleineLargeur: true,
            actions: actions,
            corps: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?filtre,
                      Expanded(child: grille),
                    ],
                  ),
                ),
                Container(
                  key: const Key('colonne-panier'),
                  width: 400,
                  decoration: const BoxDecoration(
                    color: CouleursZp.surface,
                    border: Border(
                      left: BorderSide(color: CouleursZp.ligne, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Panier',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!_panier.vide) client,
                      Expanded(
                        child: _panier.vide
                            ? const Center(child: invitation)
                            : _ListePanier(
                                panier: _panier,
                                pleineHauteur: true,
                                onChange: () => setState(() {}),
                              ),
                      ),
                      if (!_panier.vide)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: totalEtBouton,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return PageZp(
          titre: 'Vendre',
          icone: Icons.shopping_basket_rounded,
          actions: actions,
          corps: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filtre par catégorie, seulement si la boutique en a plusieurs.
              ?filtre,
              Expanded(child: grille),
              if (!_panier.vide) client,
              if (!_panier.vide)
                _ListePanier(panier: _panier, onChange: () => setState(() {})),
            ],
          ),
          bas: _panier.vide ? invitation : totalEtBouton,
        );
      },
    );
  }
}

class _TuileVente extends StatelessWidget {
  const _TuileVente({required this.produit, required this.onTap});

  final Produit produit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    return Material(
      color: CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CouleursZp.ligne, width: 1.5),
      ),
      child: InkWell(
        key: Key('vendre-${p.catalogueId ?? p.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ImageProduit(produit: p, taille: 44),
              const SizedBox(height: 4),
              Text(
                p.nom,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  p.aUnPrix
                      ? '${formatFrancs(p.prixUnitaire)} / ${p.uniteBase}'
                      : 'Voir les prix',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CouleursZp.texteDoux,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix de l'unité vendue : unité de base, conditionnement, ou « au montant ».
class _ChoixUnite extends StatelessWidget {
  const _ChoixUnite({
    required this.produit,
    required this.conditionnements,
    required this.ligne,
  });

  final Produit produit;
  final List<Conditionnement> conditionnements;
  final LignePanier Function(Produit, Conditionnement?, int) ligne;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    Widget option(String cle, String texte, int prix, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            key: Key(cle),
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 64),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    texte,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (prix > 0)
                  Text(
                    formatFrancs(prix),
                    style: const TextStyle(
                      fontSize: 20,
                      color: CouleursZp.argentEntre,
                    ),
                  ),
              ],
            ),
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ImageProduit(produit: p, taille: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.nom,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (p.aUnPrix)
              option(
                'choix-base',
                '1 ${p.uniteBase}',
                p.prixUnitaire,
                () => Navigator.of(context).pop(ligne(p, null, 1)),
              ),
            for (final c in conditionnements)
              option(
                'choix-${c.nom}',
                '1 ${c.nom}',
                c.prixVente,
                () => Navigator.of(context).pop(ligne(p, c, 1)),
              ),
            if (p.auMontant && p.aUnPrix)
              option(
                'choix-montant',
                'Pour un montant (ex. 100 F)',
                0,
                () async {
                  final montant = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _SaisieMontant(),
                  );
                  if (montant != null && montant > 0 && context.mounted) {
                    Navigator.of(context).pop(
                      LignePanier(
                        produitId: p.id,
                        nomProduit: p.nom,
                        uniteBase: p.uniteBase,
                        emoji: p.emoji,
                        montant: montant,
                        prixUnitaire: p.prixUnitaire,
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SaisieMontant extends StatefulWidget {
  const _SaisieMontant();
  @override
  State<_SaisieMontant> createState() => _SaisieMontantState();
}

class _SaisieMontantState extends State<_SaisieMontant> {
  int _montant = 0;

  @override
  Widget build(BuildContext context) {
    final hauteurClavier = (MediaQuery.sizeOf(context).height * 0.32).clamp(
      180.0,
      260.0,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pour combien ?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [50, 100, 200, 250, 500, 1000])
                  ActionChip(
                    key: Key('rapide-$m'),
                    label: Text(
                      formatFrancs(m),
                      style: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () => setState(() => _montant = m),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: MontantGeant(
                _montant,
                couleur: CouleursZp.argentEntre,
                taille: 44,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: hauteurClavier,
              child: ClavierMontant(
                valeur: _montant,
                onChange: (v) => setState(() => _montant = v),
              ),
            ),
            GrosBouton(
              key: const Key('bouton-valider-montant'),
              texte: 'Ajouter',
              icone: Icons.add_rounded,
              onPressed: _montant > 0
                  ? () => Navigator.of(context).pop(_montant)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListePanier extends StatelessWidget {
  const _ListePanier({
    required this.panier,
    required this.onChange,
    this.pleineHauteur = false,
  });

  final Panier panier;
  final VoidCallback onChange;

  /// Grand écran : le panier occupe toute la colonne de droite.
  final bool pleineHauteur;

  @override
  Widget build(BuildContext context) {
    final hauteurMax = pleineHauteur
        ? double.infinity
        : MediaQuery.sizeOf(context).height * 0.3;
    return Container(
      constraints: BoxConstraints(maxHeight: hauteurMax),
      decoration: const BoxDecoration(
        color: CouleursZp.surface,
        border: Border(top: BorderSide(color: CouleursZp.ligne, width: 2)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: panier.lignes.length,
        itemBuilder: (context, i) {
          final l = panier.lignes[i];
          return Padding(
            key: Key('ligne-panier-$i'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(l.emoji ?? '📦', style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.libelle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17),
                      ),
                      Text(
                        formatFrancs(l.prix),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: Key('moins-$i'),
                  iconSize: 26,
                  onPressed: () {
                    panier.changer(i, -1);
                    onChange();
                  },
                  icon: Icon(
                    l.auMontant || l.nombre == 1
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                  ),
                ),
                if (!l.auMontant)
                  IconButton.filledTonal(
                    key: Key('plus-$i'),
                    iconSize: 26,
                    onPressed: () {
                      panier.changer(i, 1);
                      onChange();
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
