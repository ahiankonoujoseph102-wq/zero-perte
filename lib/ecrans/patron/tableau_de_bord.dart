import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/tableau.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import 'graphiques.dart';
import 'tableau.dart' show texteRaison;
import '../accueil_vendeur.dart' show etatCaisseAffiche;
import '../caisse/ma_caisse.dart';
import 'a_faire.dart';

/// Tableau de bord du patron (accueil sur tablette et PC) : les chiffres du
/// jour, la courbe des 7 derniers jours et les produits qui rapportent le plus
/// sur 30 jours.
class TableauDeBord extends StatefulWidget {
  const TableauDeBord({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<TableauDeBord> createState() => _TableauDeBordState();
}

class _TableauDeBordState extends State<TableauDeBord>
    with RechargeAMinuit<TableauDeBord> {
  @override
  DateTime maintenantPourMinuit() => widget.etat.maintenant();

  @override
  void nouveauJour() => _recharger();

  late Future<(TableauPatron, ResumeJour)> _tableau = _charger();

  Future<(TableauPatron, ResumeJour)> _charger() async =>
      (await widget.etat.tableau(Periode.jour), await widget.etat.resumeJour());

  void _recharger() {
    if (mounted) {
      setState(() {
        _tableau = _charger();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.etat.addListener(_recharger);
  }

  @override
  void dispose() {
    widget.etat.removeListener(_recharger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<(TableauPatron, ResumeJour)>(
          future: _tableau,
          builder: (context, s) {
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (t, jour) = s.data!;
            return LayoutBuilder(
              builder: (context, c) {
                final colonnes = c.maxWidth >= 1000 ? 4 : 2;
                final chiffres = [
                  _Chiffre(
                    cle: 'bord-ventes',
                    icone: Icons.shopping_basket_rounded,
                    titre: 'Vendu aujourd\'hui',
                    montant: t.ventes,
                    couleur: CouleursZp.argentEntreClair,
                    detail:
                        '${t.nombreVentes} ${t.nombreVentes > 1 ? 'ventes' : 'vente'}',
                  ),
                  _Chiffre(
                    cle: 'bord-benefice',
                    icone: Icons.trending_up_rounded,
                    titre: 'Bénéfice',
                    montant: t.benefice.benefice,
                    couleur: t.benefice.benefice >= 0
                        ? CouleursZp.argentEntreClair
                        : CouleursZp.argentSortClair,
                    detail: jour.beneficeInconnu
                        ? 'Ajoutez le prix d\'achat pour le voir'
                        : null,
                  ),
                  _Chiffre(
                    cle: 'bord-caisse',
                    icone:
                        etatCaisseAffiche(jour).icone ??
                        Icons.point_of_sale_rounded,
                    titre: 'Ma caisse (espèces)',
                    montant: 0,
                    texte: etatCaisseAffiche(jour).court.replaceAll('\n', ' '),
                    couleur: etatCaisseAffiche(jour).couleur,
                    detail: 'Dépenses : ${formatFrancs(t.depenses)}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PageMaCaisse(etat: widget.etat),
                      ),
                    ),
                  ),
                  _Chiffre(
                    cle: 'bord-credits',
                    icone: Icons.menu_book_rounded,
                    titre: 'Ce qu\'on me doit',
                    montant: t.credits,
                    couleur: CouleursZp.creditTexte,
                  ),
                ];
                final courbe = CarteZp(
                  titre: 'Ventes des 7 derniers jours',
                  icone: Icons.show_chart_rounded,
                  child: CourbeSeptJours(jours: t.septJours),
                );
                final top = CarteZp(
                  titre: 'Les plus vendus (30 jours)',
                  icone: Icons.emoji_events_rounded,
                  child: BarresClassement(
                    key: const Key('top-30-jours'),
                    lignes: t.meilleurs30Jours,
                    vide: 'Aucune vente ces 30 derniers jours.',
                  ),
                );
                final stock = CarteZp(
                  titre: 'Stock bas (${t.stockBas.length})',
                  icone: Icons.warning_amber_rounded,
                  child: t.stockBas.isEmpty
                      ? const Text(
                          'Rien à racheter pour l\'instant.',
                          style: TextStyle(
                            fontSize: 17,
                            color: CouleursZp.texteDoux,
                          ),
                        )
                      : Column(
                          children: [
                            for (final (p, _, raison) in t.stockBas.take(6))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    ImageProduit(produit: p, taille: 32),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        p.nom,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 17),
                                      ),
                                    ),
                                    Text(
                                      texteRaison(raison),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: raison == RaisonStockBas.epuise
                                            ? CouleursZp.argentSortClair
                                            : CouleursZp.creditTexte,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                );
                return ListView(
                  key: const Key('tableau-de-bord'),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Bonjour ${widget.etat.utilisateurActuel?.nom ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Voici votre boutique aujourd\'hui.',
                      style: TextStyle(
                        fontSize: 17,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                    if (jour.parVendeur.length > 1)
                      Text(
                        [
                          for (final e in jour.parVendeur.entries)
                            '${e.key} : ${formatFrancs(e.value)}',
                        ].join('   ·   '),
                        key: const Key('bord-vendeurs'),
                        style: const TextStyle(
                          fontSize: 17,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                    if (widget.etat.tachesAFaire.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      CarteAFaire(etat: widget.etat),
                    ],
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: colonnes,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      // Plus haut si le texte du téléphone est agrandi.
                      mainAxisExtent:
                          104 *
                              MediaQuery.textScalerOf(context).scale(16) /
                              16 +
                          24,
                      children: chiffres,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: courbe),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: top),
                      ],
                    ),
                    const SizedBox(height: 14),
                    stock,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.montant,
    required this.couleur,
    this.detail,
    this.texte,
    this.onTap,
  });

  final String cle;
  final IconData icone;
  final String titre;
  final int montant;
  final Color couleur;
  final String? detail;

  /// Texte à la place du montant (état de la caisse).
  final String? texte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: CouleursZp.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: FormesZp.arrondi,
      side: BorderSide(color: CouleursZp.ligne, width: 1.5),
    ),
    child: InkWell(
      borderRadius: FormesZp.arrondi,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(EspacesZp.l),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: couleur.withValues(alpha: 0.16),
              child: Icon(icone, color: couleur, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: CouleursZp.texteDoux,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      texte ?? formatFrancs(montant),
                      key: Key(cle),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: couleur,
                      ),
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      maxLines: 1,
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
      ),
    ),
  );
}
