import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/inventaire.dart';
import '../../domaine/quantites.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../caisse/fermeture.dart' show dateEtHeure;
import '../communs.dart';
import '../clavier_montant.dart';

/// Inventaire complet en comptage aveugle : un produit à la fois, on compte
/// sans voir ce que l'application attend. À la fin : écarts en francs.
class PageInventaire extends StatefulWidget {
  const PageInventaire({
    super.key,
    required this.etat,
    this.produits,
    this.titre = 'Inventaire',
  });

  final EtatApplication etat;

  /// Seulement ces produits (inventaire tournant du jour) ; nul = tous.
  final List<Produit>? produits;
  final String titre;

  @override
  State<PageInventaire> createState() => _PageInventaireState();
}

class _PageInventaireState extends State<PageInventaire> {
  late final List<Produit> _produits = [
    ...(widget.produits ?? widget.etat.produits),
  ]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
  int _i = 0;
  final Map<String, int> _comptes = {};
  List<Conditionnement> _conds = const [];
  Conditionnement? _unite;
  int _nombre = 0;
  bool _enCours = false;

  Produit get _p => _produits[_i];

  @override
  void initState() {
    super.initState();
    _chargerUnites();
  }

  Future<void> _chargerUnites() async {
    if (_produits.isEmpty) return;
    final c = [
      for (final x in await widget.etat.journal.conditionnements(_p.id))
        if (!estPrixRevendeur(x)) x,
    ];
    if (!mounted) return;
    setState(() {
      _conds = c;
      _unite = null;
      _nombre = 0;
    });
  }

  Future<void> _suivant() async {
    _comptes[_p.id] = _unite == null
        ? _nombre * milliemesParUnite
        : versMilliemes(_nombre, _unite!);
    if (_i < _produits.length - 1) {
      setState(() => _i++);
      await _chargerUnites();
      return;
    }
    setState(() => _enCours = true);
    try {
      final inv = await widget.etat.faireInventaire(_comptes);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          // Un vendeur ne voit pas les écarts (comme pour la caisse).
          builder: (_) => widget.etat.estPatron
              ? PageResultatInventaire(etat: widget.etat, inventaire: inv)
              : const PageComptageMerci(),
        ),
      );
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_produits.isEmpty) {
      return const PageZp(
        titre: 'Inventaire',
        icone: Icons.inventory_rounded,
        corps: Center(
          child: Text(
            'Aucun produit à compter.',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
    }
    final p = _p;
    final dernier = _i == _produits.length - 1;
    return PageZp(
      titre: widget.titre,
      icone: Icons.inventory_rounded,
      bas: GrosBouton(
        key: const Key('bouton-produit-suivant'),
        texte: dernier ? 'Terminer l\'inventaire' : 'Produit suivant',
        icone: dernier ? Icons.check_rounded : Icons.arrow_forward_rounded,
        onPressed: _enCours ? null : _suivant,
      ),
      corps: ListView(
        key: ValueKey('inventaire-$_i'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Produit ${_i + 1} sur ${_produits.length}',
            key: const Key('inventaire-etape'),
            style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ImageProduit(produit: p, taille: 56),
              const SizedBox(width: 12),
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
          const SizedBox(height: 8),
          const Text(
            'Comptez ce qu\'il y a vraiment dans la boutique et la réserve.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (_conds.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in [null, ..._conds])
                  ChoiceChip(
                    key: Key('inventaire-unite-${c?.nom ?? p.uniteBase}'),
                    label: Text(
                      c?.nom ?? p.uniteBase,
                      style: const TextStyle(fontSize: 18),
                    ),
                    selected: _unite?.id == c?.id,
                    onSelected: (_) => setState(() => _unite = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$_nombre ${pluriel(_unite?.nom ?? p.uniteBase, _nombre)}',
                key: const Key('inventaire-compte'),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: ClavierMontant(
              valeur: _nombre,
              maximum: 999999,
              onChange: (v) => setState(() => _nombre = v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Résultat d'un inventaire (patron) : chaque produit et l'écart total en francs.
class PageResultatInventaire extends StatelessWidget {
  const PageResultatInventaire({
    super.key,
    required this.etat,
    required this.inventaire,
  });

  final EtatApplication etat;
  final Inventaire inventaire;

  @override
  Widget build(BuildContext context) {
    final inv = inventaire;
    final total = inv.ecartFrancs;
    return PageZp(
      titre: 'Résultat',
      icone: Icons.fact_check_rounded,
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Inventaire du ${dateEtHeure(inv.heure)}',
            style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  (total < 0 ? CouleursZp.argentSort : CouleursZp.argentEntre)
                      .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              total == 0
                  ? 'Tout est juste.'
                  : total < 0
                  ? 'Marchandise manquante : ${formatFrancs(-total)}'
                  : 'Marchandise en trop : ${formatFrancs(total)}',
              key: const Key('inventaire-total'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: total < 0
                    ? CouleursZp.argentSort
                    : CouleursZp.argentEntre,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final l in inv.lignes) _ligne(l),
        ],
      ),
    );
  }

  Widget _ligne(LigneInventaire l) {
    final p = etat.produits.where((p) => p.id == l.produitId).firstOrNull;
    final unite = p?.uniteBase ?? '';
    final e = etatLigne(
      attendu: l.attendu,
      compte: l.compte,
      tolerance: avecTolerance(
        uniteBase: unite,
        auMontant: p?.auMontant ?? false,
      ),
    );
    final (texte, couleur) = switch (e) {
      EtatLigneInventaire.juste => ('Juste', CouleursZp.argentEntre),
      EtatLigneInventaire.tolere => (
        'Presque juste (mesure au ${unite.isEmpty ? 'détail' : unite})',
        CouleursZp.argentEntre,
      ),
      EtatLigneInventaire.manque => (
        'Il manque ${decrireUnites(-l.ecart, unite)} (${formatFrancs(-l.ecartFrancs)})',
        CouleursZp.argentSort,
      ),
      EtatLigneInventaire.surplus => (
        'En trop : ${decrireUnites(l.ecart, unite)} (${formatFrancs(l.ecartFrancs)})',
        CouleursZp.creditTexte,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CouleursZp.surface,
        borderRadius: BorderRadius.circular(FormesZp.rayon),
        border: Border.all(color: couleur, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p?.nom ?? 'Produit',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            'Attendu ${decrireUnites(l.attendu, unite)} · compté ${decrireUnites(l.compte, unite)}',
            style: const TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
          ),
          Text(
            texte,
            key: Key('inventaire-${p?.nom ?? l.produitId}'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fin du comptage pour un vendeur : aucun chiffre, le patron verra les écarts.
class PageComptageMerci extends StatelessWidget {
  const PageComptageMerci({super.key});

  @override
  Widget build(BuildContext context) => PageZp(
    titre: 'Comptage',
    icone: Icons.check_circle_rounded,
    bas: GrosBouton(
      key: const Key('bouton-fin-comptage'),
      texte: 'Terminé',
      icone: Icons.check_rounded,
      onPressed: () => Navigator.of(context).pop(),
    ),
    corps: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Comptage enregistré. Merci !\nLe patron verra le résultat.',
          key: Key('comptage-merci'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

/// Espace patron → « Inventaire » : écarts par personne (30 jours), inventaire
/// complet, ou les produits du jour.
class PageInventaires extends StatefulWidget {
  const PageInventaires({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageInventaires> createState() => _PageInventairesState();
}

class _PageInventairesState extends State<PageInventaires> {
  late Future<Map<String, int>> _ecarts = _charger();

  Future<Map<String, int>> _charger() {
    final m = widget.etat.maintenant();
    return widget.etat.ecartsParPersonne(
      depuis: DateTime(m.year, m.month, m.day - 29).millisecondsSinceEpoch,
    );
  }

  Future<void> _ouvrir(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() {
        _ecarts = _charger();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    return PageZp(
      titre: 'Inventaire',
      icone: Icons.inventory_rounded,
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GrosBouton(
            key: const Key('bouton-inventaire-complet'),
            texte: 'Tout compter',
            icone: Icons.inventory_rounded,
            onPressed: () => _ouvrir(PageInventaire(etat: etat)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('bouton-inventaire-du-jour'),
            onPressed: () async {
              final p = await etat.produitsAInventorierAujourdhui();
              if (!context.mounted) return;
              if (p.isEmpty) {
                annoncer(context, 'Aucun produit en stock à compter.');
                return;
              }
              await _ouvrir(
                PageInventaire(
                  etat: etat,
                  produits: p,
                  titre: 'Produits du jour',
                ),
              );
            },
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text(
              'Compter les produits du jour',
              style: TextStyle(fontSize: 18),
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 60)),
          ),
          const SizedBox(height: 18),
          const Text(
            'Écarts des 30 derniers jours',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          FutureBuilder<Map<String, int>>(
            future: _ecarts,
            builder: (context, s) {
              final e = s.data;
              if (e == null) return const SizedBox(height: 40);
              if (e.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Aucun inventaire pour l\'instant.',
                    style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
                  ),
                );
              }
              return Column(
                children: [
                  for (final MapEntry(key: qui, value: f) in e.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              etat.nomDe(qui),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Text(
                            f == 0
                                ? 'Juste'
                                : f < 0
                                ? '− ${formatFrancs(-f)}'
                                : '+ ${formatFrancs(f)}',
                            key: Key('ecart-${etat.nomDe(qui)}'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: f < 0
                                  ? CouleursZp.argentSort
                                  : CouleursZp.argentEntre,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
