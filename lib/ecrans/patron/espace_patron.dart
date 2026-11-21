import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../theme/couleurs.dart';
import '../caisse/fermeture.dart';
import '../caisse/saisie_montant.dart';
import '../communs.dart';
import 'arrivages.dart';
import 'fournisseurs.dart';
import 'inventaire.dart';
import 'sauvegarde.dart';
import 'synchronisation.dart';
import 'tableau.dart';
import 'vendeurs.dart';

/// Une entrée du menu du patron.
class EntreePatron {
  const EntreePatron(
    this.cle,
    this.icone,
    this.titre,
    this.couleur,
    this.ouvrir,
  );
  final String cle;
  final IconData icone;
  final String titre;
  final Color couleur;

  /// Nul = pas encore disponible.
  final Widget Function(EtatApplication etat)? ouvrir;
}

/// Entrées du menu (les étapes suivantes en ajoutent).
final List<EntreePatron> entreesPatron = [
  EntreePatron(
    'tableau',
    Icons.insights_rounded,
    'Tableau',
    CouleursZp.argentEntre,
    (etat) => PageTableau(etat: etat),
  ),
  EntreePatron(
    'arrivages',
    Icons.local_shipping_rounded,
    'Arrivages',
    CouleursZp.marque,
    (etat) => PageArrivages(etat: etat),
  ),
  EntreePatron(
    'vendeurs',
    Icons.groups_rounded,
    'Vendeurs',
    CouleursZp.marque,
    (etat) => PageVendeurs(etat: etat),
  ),
  EntreePatron(
    'inventaire',
    Icons.inventory_rounded,
    'Inventaire',
    CouleursZp.marque,
    (etat) => PageInventaires(etat: etat),
  ),
  EntreePatron(
    'fermetures',
    Icons.fact_check_rounded,
    'Caisses fermées',
    CouleursZp.marque,
    (etat) => PageFermetures(etat: etat),
  ),
  EntreePatron(
    'fournisseurs',
    Icons.local_shipping_rounded,
    'Fournisseurs',
    CouleursZp.marque,
    (etat) => PageFournisseurs(etat: etat),
  ),
  EntreePatron(
    'retrait',
    Icons.account_balance_wallet_rounded,
    'Argent pris',
    CouleursZp.argentSort,
    pageRetraitPatron,
  ),
  EntreePatron(
    'synchro',
    Icons.cloud_sync_rounded,
    'Appareils et Drive',
    CouleursZp.marque,
    (etat) => PageSynchronisation(etat: etat),
  ),
  EntreePatron(
    'sauvegarde',
    Icons.backup_rounded,
    'Sauvegarde',
    CouleursZp.marque,
    (etat) => PageSauvegarde(etat: etat),
  ),
];

/// Espace du patron (protégé par son code secret).
class EspacePatron extends StatelessWidget {
  const EspacePatron({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    // Pas de sauvegarde en démonstration : ses données ne doivent pas en sortir.
    final entrees = [
      for (final e in entreesPatron)
        if (!(etat.estDemo && (e.cle == 'sauvegarde' || e.cle == 'synchro'))) e,
    ];
    return PageZp(
      titre: 'Espace patron',
      icone: Icons.key_rounded,
      corps: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 150,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: entrees.length,
        itemBuilder: (context, i) {
          final e = entrees[i];
          final couleur = e.couleur == CouleursZp.marque
              ? Theme.of(context).colorScheme.primary
              : e.couleur;
          return Material(
            color: CouleursZp.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: CouleursZp.ligne, width: 1.5),
            ),
            child: InkWell(
              key: Key('patron-${e.cle}'),
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                final ouvrir = e.ouvrir;
                if (ouvrir == null) {
                  annoncer(context, '« ${e.titre} » arrive bientôt.');
                  return;
                }
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => ouvrir(etat)));
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: couleur.withValues(alpha: 0.14),
                        child: Icon(e.icone, size: 36, color: couleur),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        e.titre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
