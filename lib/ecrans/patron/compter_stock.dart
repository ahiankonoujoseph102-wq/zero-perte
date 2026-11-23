/// « Compter mon stock » petit à petit (0.36) : pas besoin d'inventaire pour
/// démarrer. On compte d'abord les produits qui comptent le plus (les plus
/// vendus, puis les plus chers), quelques-uns à la fois, au fil des jours.
library;

import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../donnees/journal_local.dart' show Produit;
import '../../theme/couleurs.dart';
import '../communs.dart';
import 'inventaire.dart';

/// Nombre de produits proposés à la fois.
const int produitsParComptage = 5;

/// Les « premiers » produits à compter (les plus importants).
const int produitsPrioritaires = 20;

class PageCompterStock extends StatefulWidget {
  const PageCompterStock({super.key, required this.etat});
  final EtatApplication etat;

  @override
  State<PageCompterStock> createState() => _PageCompterStockState();
}

class _PageCompterStockState extends State<PageCompterStock> {
  late Future<List<Produit>> _aCompter = widget.etat.produitsACompter();

  Future<void> _compter(List<Produit> produits) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageInventaire(
          etat: widget.etat,
          produits: produits,
          titre: 'Compter mon stock',
        ),
      ),
    );
    if (mounted) {
      setState(() => _aCompter = widget.etat.produitsACompter());
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    return FutureBuilder<List<Produit>>(
      future: _aCompter,
      builder: (context, s) {
        final reste = s.data;
        final total = etat.produits.length;
        final faits = etat.nombreProduitsComptes;
        final prochains = reste?.take(produitsParComptage).toList() ?? const [];
        return PageZp(
          titre: 'Compter mon stock',
          icone: Icons.inventory_rounded,
          bas: prochains.isEmpty
              ? null
              : GrosBouton(
                  key: const Key('bouton-compter-prochains'),
                  texte: 'Compter ces ${prochains.length} produits',
                  icone: Icons.checklist_rounded,
                  onPressed: () => _compter(prochains),
                ),
          corps: reste == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      total == 0
                          ? 'Pas encore de produit.'
                          : '$faits produits comptés sur $total',
                      key: const Key('progression-comptage'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : faits / total,
                        minHeight: 14,
                        backgroundColor: CouleursZp.ligne,
                        color: CouleursZp.argentEntre,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reste.isEmpty
                          ? 'Tout est compté. Bravo ! Le stock et les alertes '
                                'sont justes maintenant.'
                          : 'Pas besoin de tout compter aujourd\'hui. Comptez '
                                '$produitsParComptage produits quand vous avez '
                                'le temps : on commence par ceux qui se vendent '
                                'le plus ou qui coûtent le plus cher.',
                      style: const TextStyle(
                        fontSize: 17,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                    if (reste.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'D\'abord (${reste.take(produitsPrioritaires).length})',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final p in reste.take(produitsPrioritaires))
                        _Ligne(produit: p),
                      if (reste.length > produitsPrioritaires) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Ensuite, au fil des jours : '
                          '${reste.length - produitsPrioritaires} autres produits.',
                          style: const TextStyle(
                            fontSize: 17,
                            color: CouleursZp.texteDoux,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.produit});
  final Produit produit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        ImageProduit(produit: produit, taille: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(produit.nom, style: const TextStyle(fontSize: 18)),
        ),
        const Text(
          'pas encore compté',
          style: TextStyle(fontSize: 14, color: CouleursZp.texteDoux),
        ),
      ],
    ),
  );
}
