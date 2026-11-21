import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/quantites.dart';
import '../../domaine/tableau.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import 'graphiques.dart';

String texteRaison(RaisonStockBas r) => switch (r) {
  RaisonStockBas.epuise => 'Épuisé',
  RaisonStockBas.sousLeSeuil => 'Sous le seuil',
  RaisonStockBas.moinsDUneSemaine => 'Moins d\'une semaine de vente',
};

/// Tableau du patron : ventes, bénéfice estimé, dépenses, meilleurs produits,
/// stock bas ; pour aujourd'hui, cette semaine ou ce mois.
class PageTableau extends StatefulWidget {
  const PageTableau({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageTableau> createState() => _PageTableauState();
}

class _PageTableauState extends State<PageTableau> {
  Periode _periode = Periode.jour;
  late Future<TableauPatron> _tableau = widget.etat.tableau(_periode);

  void _choisir(Periode p) {
    setState(() {
      _periode = p;
      _tableau = widget.etat.tableau(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Tableau',
      pleineLargeur: true,
      icone: Icons.insights_rounded,
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in Periode.values)
                ChoiceChip(
                  key: Key('periode-${p.name}'),
                  label: Text(p.libelle, style: const TextStyle(fontSize: 17)),
                  selected: _periode == p,
                  onSelected: (_) => _choisir(p),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<TableauPatron>(
            future: _tableau,
            builder: (context, s) {
              if (!s.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _Contenu(etat: widget.etat, t: s.data!);
            },
          ),
        ],
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.etat, required this.t});

  final EtatApplication etat;
  final TableauPatron t;

  @override
  Widget build(BuildContext context) {
    final b = t.benefice;
    final tout = <Widget>[
      _Chiffre(
        cle: 'chiffre-ventes',
        icone: Icons.shopping_basket_rounded,
        titre: 'Ventes',
        montant: t.ventes,
        couleur: CouleursZp.argentEntre,
        detail: '${t.nombreVentes} ${t.nombreVentes > 1 ? 'ventes' : 'vente'}',
      ),
      _Chiffre(
        cle: 'chiffre-benefice',
        icone: Icons.trending_up_rounded,
        titre: 'Bénéfice estimé',
        montant: b.benefice,
        couleur: b.benefice >= 0
            ? CouleursZp.argentEntre
            : CouleursZp.argentSort,
        detail: b.lignesSansCout > 0
            ? 'Sans les produits dont le prix d\'achat n\'est pas connu '
                  '(enregistrez leurs arrivages).'
            : 'Prix de vente − prix d\'achat (dernier arrivage).',
      ),
      _Chiffre(
        cle: 'chiffre-depenses',
        icone: Icons.payments_rounded,
        titre: 'Dépenses',
        montant: t.depenses,
        couleur: CouleursZp.argentSort,
      ),
      _Chiffre(
        cle: 'chiffre-credits',
        icone: Icons.menu_book_rounded,
        titre: 'Les clients doivent (crédit)',
        montant: t.credits,
        couleur: CouleursZp.creditTexte,
      ),
    ];
    final suite = <Widget>[
      if (t.septJours.isNotEmpty) ...[
        const SizedBox(height: 8),
        const _Titre('Ventes des 7 derniers jours'),
        CarteZp(child: CourbeSeptJours(jours: t.septJours)),
      ],
      const SizedBox(height: 8),
      const _Titre('Les plus vendus'),
      if (t.meilleurs.isEmpty)
        const Text(
          'Aucune vente sur cette période.',
          style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
        )
      else
        for (final (i, (nom, montant)) in t.meilleurs.indexed)
          _Ligne(
            cle: 'meilleur-$i',
            gauche: '${i + 1}. $nom',
            droite: formatFrancs(montant),
          ),
      const SizedBox(height: 16),
      _Titre('Stock bas (${t.stockBas.length})'),
      if (t.stockBas.isEmpty)
        const Text(
          'Rien à racheter pour l\'instant.',
          style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
        )
      else
        for (final (p, stock, raison) in t.stockBas)
          Container(
            key: Key('stock-bas-${p.nom}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CouleursZp.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: raison == RaisonStockBas.epuise
                    ? CouleursZp.argentSort
                    : CouleursZp.credit,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                ImageProduit(produit: p, taille: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nom,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        raison == RaisonStockBas.epuise
                            ? texteRaison(raison)
                            : '${texteRaison(raison)} · reste ${decrireUnites(stock, p.uniteBase)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: raison == RaisonStockBas.epuise
                              ? CouleursZp.argentSort
                              : CouleursZp.texteDoux,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    ];
    // Grand écran : chiffres à gauche, graphique et listes à droite.
    if (estGrandEcran(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tout,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: suite,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...tout, ...suite],
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texte,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    ),
  );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.cle, required this.gauche, required this.droite});
  final String cle;
  final String gauche;
  final String droite;
  @override
  Widget build(BuildContext context) => Padding(
    key: Key(cle),
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Text(gauche, style: const TextStyle(fontSize: 18))),
        Text(
          droite,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.montant,
    required this.couleur,
    this.detail,
  });

  final String cle;
  final IconData icone;
  final String titre;
  final int montant;
  final Color couleur;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: CouleursZp.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: CouleursZp.ligne),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: couleur.withValues(alpha: 0.12),
          child: Icon(icone, color: couleur, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(fontSize: 17)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatFrancs(montant),
                  key: Key(cle),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: CouleursZp.texteDoux,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
