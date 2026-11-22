import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../theme/couleurs.dart';
import '../caisse/fermeture.dart';
import '../caisse/saisie_montant.dart';
import '../communs.dart';
import '../vente/devis.dart';
import '../vente/retour.dart';
import 'arrivages.dart';
import 'produits.dart';
import 'chiffres.dart';
import 'fournisseurs.dart';
import 'inventaire.dart';
import 'sauvegarde.dart';
import 'synchronisation.dart';
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
    'produits',
    Icons.sell_rounded,
    'Produits et prix',
    CouleursZp.argentEntre,
    (etat) => PageProduits(etat: etat),
  ),
  EntreePatron(
    'devis',
    Icons.request_quote_rounded,
    'Devis',
    CouleursZp.marque,
    (etat) => PageListeDevis(etat: etat),
  ),
  EntreePatron(
    'retours',
    Icons.assignment_return_rounded,
    'Retours',
    CouleursZp.argentSort,
    (etat) => PageRetours(etat: etat),
  ),
  EntreePatron(
    'chiffres',
    Icons.insights_rounded,
    'Chiffres',
    CouleursZp.argentEntre,
    (etat) => PageChiffres(etat: etat),
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
    Icons.handshake_rounded,
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
    // Tablette et PC : les pages déjà dans le menu de gauche ne sont pas
    // répétées ici (une seule façon d'y aller, moins de confusion).
    final menuAGauche = MediaQuery.sizeOf(context).width >= 840;
    const dansLeMenu = {
      'chiffres',
      'devis',
      'retours',
      'arrivages',
      'vendeurs',
      'inventaire',
      'fournisseurs',
    };
    final entrees = [
      for (final e in entreesPatron)
        if (!(etat.estDemo && (e.cle == 'sauvegarde' || e.cle == 'synchro')) &&
            !(menuAGauche && dansLeMenu.contains(e.cle)))
          e,
    ];
    return PageZp(
      titre: 'Gestion',
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
