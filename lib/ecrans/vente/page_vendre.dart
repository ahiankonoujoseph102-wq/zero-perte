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
import 'devis.dart';
import 'nouveau_produit.dart';
import 'page_encaisser.dart';
import 'ventes_du_jour.dart';

/// Écran « Vendre » : grille des produits en haut, panier et total en bas.
class PageVendre extends StatefulWidget {
  const PageVendre({super.key, required this.etat, this.panier, this.devis});

  final EtatApplication etat;

  /// Panier déjà rempli (devis transformé en vente).
  final Panier? panier;

  /// Devis d'où vient ce panier : marqué « vendu » après l'encaissement.
  final OperationLue? devis;

  @override
  State<PageVendre> createState() => _PageVendreState();
}

class _PageVendreState extends State<PageVendre> {
  late final Panier _panier = widget.panier ?? Panier();
  late OperationLue? _devis = widget.devis;

  /// Devis (facture proforma) fait avec le panier : ni stock ni caisse.
  Future<void> _faireDevis() async {
    if (_panier.vide) {
      annoncer(context, 'Ajoutez d\'abord les produits du devis.');
      return;
    }
    try {
      final d = await etat.creerDevis(_panier);
      if (!mounted) return;
      setState(_panier.vider);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PageDevis(etat: etat, devis: d),
        ),
      );
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    }
  }

  /// Catégorie affichée (null = toutes).
  String? _categorie;

  /// Recherche d'un produit par son nom (grandes boutiques).
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

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

  /// Produit qui manque : créé ici (nom + prix), puis vendu tout de suite.
  Future<void> _nouveauProduit() async {
    final p = await demanderNouveauProduit(
      context,
      etat,
      nom: _recherche.text.trim(),
    );
    if (p == null || !mounted) return;
    setState(_recherche.clear);
    await _toucherProduit(p);
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
    final taille = MediaQuery.sizeOf(context);
    // Tablette et PC : grande fenêtre par-dessus la vente.
    final fini = estGrandEcran(context)
        ? await navigateurDeLApplication(context).push<bool>(
            DialogRoute<bool>(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(24),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: CouleursZp.ligne, width: 1.5),
                ),
                child: SizedBox(
                  width: (taille.width - 48).clamp(0, 1040),
                  height: (taille.height - 48).clamp(0, 720),
                  child: PageEncaisser(
                    etat: etat,
                    panier: _panier,
                    fenetre: true,
                  ),
                ),
              ),
            ),
          )
        : await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PageEncaisser(etat: etat, panier: _panier),
            ),
          );
    if (fini == true) {
      final d = _devis;
      if (d != null) {
        await etat.devisVendu(d);
        _devis = null;
      }
      if (mounted) setState(_panier.vider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final tous = etat.produits;
        String cat(Produit p) => p.catalogueId?.split('.').first ?? 'autres';
        final categories = <String>{for (final p in tous) cat(p)}.toList();
        final cherche = sansAccents(_recherche.text.trim());
        final produits = [
          for (final p in tous)
            if ((_categorie == null || cat(p) == _categorie) &&
                (cherche.isEmpty || correspond(p.nom, cherche)))
              p,
        ];
        // Au-delà de 12 produits, une case pour chercher par le nom.
        final champRecherche = tous.length > 12
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  key: const Key('recherche-produit'),
                  controller: _recherche,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Chercher un produit',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: _recherche.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_recherche.clear),
                          ),
                  ),
                ),
              )
            : null;
        String nomCategorie(String id) =>
            etat.catalogue.categories
                .where((c) => c.id == id)
                .firstOrNull
                ?.nom ??
            'Autres';
        final large = estGrandEcran(context);
        // Filtre seulement s'il y a plusieurs VRAIES catégories (les produits
        // créés pendant la vente sont dans « Autres » : ça ne compte pas).
        final filtre = categories.where((c) => c != 'autres').length > 1
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
        // On peut vendre sans avoir tout saisi : un produit qui manque se
        // crée ici.
        Widget boutonNouveau(String texte) => GrosBouton(
          key: const Key('bouton-nouveau-produit'),
          texte: texte,
          icone: Icons.add_rounded,
          couleur: CouleursZp.argentEntre,
          onPressed: _nouveauProduit,
        );
        final grille = tous.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Pas encore de produit. Ajoutez celui que vous '
                        'vendez maintenant : son nom et son prix suffisent.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 16),
                      boutonNouveau('Nouveau produit'),
                    ],
                  ),
                ),
              )
            : produits.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Aucun produit ne s\'appelle « ${_recherche.text.trim()} ».',
                        key: const Key('recherche-vide'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                      const SizedBox(height: 16),
                      boutonNouveau('Ajouter « ${_recherche.text.trim()} »'),
                    ],
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
                // Dernière case : « + Nouveau produit ».
                itemCount: produits.length + 1,
                itemBuilder: (context, i) => i == produits.length
                    ? _TuileNouveauProduit(onTap: _nouveauProduit)
                    : _TuileVente(
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
        // Icône + mot : on comprend sans deviner.
        final actions = [
          _ActionHaut(
            cle: 'bouton-devis',
            icone: Icons.request_quote_rounded,
            texte: 'Devis',
            aide: 'Faire un devis',
            onPressed: _faireDevis,
          ),
          _ActionHaut(
            cle: 'bouton-ventes-du-jour',
            icone: Icons.receipt_long_rounded,
            texte: 'Ventes',
            aide: 'Ventes du jour',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PageVentesDuJour(etat: etat)),
            ),
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
                      ?champRecherche,
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
              ?champRecherche,
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

class _ActionHaut extends StatelessWidget {
  const _ActionHaut({
    required this.cle,
    required this.icone,
    required this.texte,
    required this.aide,
    required this.onPressed,
  });

  final String cle;
  final IconData icone;
  final String texte;
  final String aide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: aide,
    child: InkWell(
      key: Key(cle),
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 26),
              Text(
                texte,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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

/// Case « + Nouveau produit » (vendre sans avoir tout saisi avant).
class _TuileNouveauProduit extends StatelessWidget {
  const _TuileNouveauProduit({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: CouleursZp.fond,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: CouleursZp.argentEntre, width: 2),
    ),
    child: InkWell(
      key: const Key('vendre-nouveau-produit'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(8),
        // Se réduit si la case est petite (texte agrandi, tablette…).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_rounded,
                size: 44,
                color: CouleursZp.argentEntre,
              ),
              SizedBox(height: 4),
              Text(
                'Nouveau produit',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
    Widget option(
      String cle,
      String texte,
      int prix,
      VoidCallback onTap, {
      String? titre,
      Color? couleur,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        key: Key(cle),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, titre == null ? 64 : 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          side: BorderSide(color: couleur ?? CouleursZp.ligne, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titre != null)
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: couleur ?? CouleursZp.texte,
                      ),
                    ),
                  Text(
                    texte,
                    style: TextStyle(
                      fontSize: titre == null ? 20 : 17,
                      fontWeight: titre == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: CouleursZp.texte,
                    ),
                  ),
                ],
              ),
            ),
            if (prix > 0)
              Text(
                formatFrancs(prix),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: CouleursZp.argentEntre,
                ),
              ),
          ],
        ),
      ),
    );
    // Vente en gros (0.36) : « Détail » et « Gros » bien séparés.
    final gros = [
      for (final c in conditionnements)
        if (!estPrixRevendeur(c)) c,
    ];
    final revendeurs = [
      for (final c in conditionnements)
        if (estPrixRevendeur(c)) c,
    ];
    final avecGros = gros.isNotEmpty || revendeurs.isNotEmpty;
    String contenu(Conditionnement c) =>
        '1 ${c.nom.replaceAll(suffixeRevendeur, '')} '
        '(${decrireUnites(c.facteurMilliemes, p.uniteBase)})';
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
                titre: avecGros ? 'Détail' : null,
              ),
            for (final c in gros)
              option(
                'choix-${c.nom}',
                contenu(c),
                c.prixVente,
                () => Navigator.of(context).pop(ligne(p, c, 1)),
                titre: 'Gros',
                couleur: CouleursZp.marque,
              ),
            for (final c in revendeurs)
              option(
                'choix-${c.nom}',
                contenu(c),
                c.prixVente,
                () => Navigator.of(context).pop(ligne(p, c, 1)),
                titre: 'Gros revendeur',
                couleur: CouleursZp.creditTexte,
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

/// Texte en minuscules sans accents (« Pâtes » se trouve en tapant « pate »).
String sansAccents(String t) {
  const avec = 'àâäáãçéèêëíìîïñóòôöõúùûüÿœæ';
  const sans = 'aaaaaceeeeiiiinooooouuuuyoa';
  final b = StringBuffer();
  for (final c in t.toLowerCase().split('')) {
    final i = avec.indexOf(c);
    b.write(i < 0 ? c : sans[i]);
  }
  return b.toString();
}

/// Vrai si un mot du nom commence par ce qui est tapé (« ri » trouve « Riz »,
/// pas « Sucrerie ») ; à partir de 4 lettres, n'importe où dans le nom.
bool correspond(String nom, String cherche) {
  final n = sansAccents(nom);
  if (cherche.length >= 4 && n.contains(cherche)) return true;
  return n
          .split(RegExp(r"[\s,'’()/-]+"))
          .any((mot) => mot.startsWith(cherche)) ||
      n.startsWith(cherche);
}
