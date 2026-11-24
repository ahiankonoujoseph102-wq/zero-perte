import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../theme/couleurs.dart';
import '../vendeur_qr.dart';
import 'ma_boutique.dart';
import 'compter_stock.dart';
import 'a_faire.dart';
import '../caisse/fermeture.dart';
import '../caisse/saisie_montant.dart';
import '../communs.dart';
import '../vente/devis.dart';
import '../vente/retour.dart';
import 'arrivages.dart';
import 'produits.dart';
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
    this.ouvrir, {
    this.groupe = GroupeGestion.boutique,
  });
  final String cle;
  final IconData icone;
  final String titre;
  final Color couleur;
  final GroupeGestion groupe;

  /// Nul = pas encore disponible.
  final Widget Function(EtatApplication etat)? ouvrir;
}

/// Rubriques de « Gestion » (0.37) : on trouve vite, toujours au même endroit.
enum GroupeGestion {
  stock('Stock et produits', Icons.inventory_2_rounded),
  argent('Argent', Icons.payments_rounded),
  personnes('Vendeurs et appareils', Icons.groups_rounded),
  boutique('Ma boutique', Icons.storefront_rounded);

  const GroupeGestion(this.titre, this.icone);
  final String titre;
  final IconData icone;
}

/// Tout ce qui n'est pas sur l'accueil (Vendre, Ma caisse, Ce qu'on me doit,
/// Mon bénéfice) se trouve ici, rangé par rubrique.
final List<EntreePatron> entreesPatron = [
  EntreePatron(
    'arrivages',
    Icons.local_shipping_rounded,
    'Arrivage',
    CouleursZp.ciel,
    (etat) => PageArrivages(etat: etat),
    groupe: GroupeGestion.stock,
  ),
  EntreePatron(
    'compter-stock',
    Icons.fact_check_rounded,
    'Compter mon stock',
    CouleursZp.argentEntre,
    (etat) => PageCompterStock(etat: etat),
    groupe: GroupeGestion.stock,
  ),
  EntreePatron(
    'produits',
    Icons.sell_rounded,
    'Produits et prix',
    CouleursZp.argentEntre,
    (etat) => PageProduits(etat: etat),
    groupe: GroupeGestion.stock,
  ),
  EntreePatron(
    'inventaire',
    Icons.inventory_rounded,
    'Inventaire complet',
    CouleursZp.mauve,
    (etat) => PageInventaires(etat: etat),
    groupe: GroupeGestion.stock,
  ),
  EntreePatron(
    'fermetures',
    Icons.point_of_sale_rounded,
    'Caisses fermées',
    CouleursZp.marque,
    (etat) => PageFermetures(etat: etat),
    groupe: GroupeGestion.argent,
  ),
  EntreePatron(
    'fournisseurs',
    Icons.handshake_rounded,
    'Ce que je dois',
    CouleursZp.creditTexte,
    (etat) => PageFournisseurs(etat: etat),
    groupe: GroupeGestion.argent,
  ),
  EntreePatron(
    'retrait',
    Icons.account_balance_wallet_rounded,
    'Argent pris',
    CouleursZp.argentSort,
    pageRetraitPatron,
    groupe: GroupeGestion.argent,
  ),
  EntreePatron(
    'retours',
    Icons.assignment_return_rounded,
    'Retours',
    CouleursZp.argentSort,
    (etat) => PageRetours(etat: etat),
    groupe: GroupeGestion.argent,
  ),
  EntreePatron(
    'devis',
    Icons.request_quote_rounded,
    'Devis',
    CouleursZp.ciel,
    (etat) => PageListeDevis(etat: etat),
    groupe: GroupeGestion.argent,
  ),
  EntreePatron(
    'ajouter-vendeur',
    Icons.qr_code_2_rounded,
    'Ajouter mon vendeur',
    CouleursZp.argentEntre,
    (etat) => PageAjouterMonVendeur(etat: etat),
    groupe: GroupeGestion.personnes,
  ),
  EntreePatron(
    'vendeurs',
    Icons.badge_rounded,
    'Vendeurs',
    CouleursZp.mauve,
    (etat) => PageVendeurs(etat: etat),
    groupe: GroupeGestion.personnes,
  ),
  EntreePatron(
    'appareils',
    Icons.devices_rounded,
    'Mes appareils',
    CouleursZp.marque,
    (etat) => PageMesAppareils(etat: etat),
    groupe: GroupeGestion.personnes,
  ),
  EntreePatron(
    'ma-boutique',
    Icons.storefront_rounded,
    'Ma boutique',
    CouleursZp.marque,
    (etat) => PageMaBoutique(etat: etat),
  ),
  EntreePatron(
    'a-faire',
    Icons.checklist_rounded,
    'À faire',
    CouleursZp.credit,
    (etat) => PageAFaire(etat: etat),
  ),
  EntreePatron(
    'synchro',
    Icons.cloud_sync_rounded,
    'Compte Google',
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

/// Espace du patron (protégé par son code secret) : « Gestion ».
class EspacePatron extends StatelessWidget {
  const EspacePatron({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Gestion',
      icone: Icons.tune_rounded,
      corps: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          EspacesZp.l,
          0,
          EspacesZp.l,
          EspacesZp.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in GroupeGestion.values) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: EspacesZp.l,
                  bottom: EspacesZp.s,
                ),
                child: Row(
                  key: Key('rubrique-${g.name}'),
                  children: [
                    Icon(g.icone, color: CouleursZp.texteDoux, size: 22),
                    const SizedBox(width: EspacesZp.s),
                    Expanded(
                      child: Text(
                        g.titre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Toutes les cases sont construites d'un coup (16 en tout).
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisExtent: 132,
                  crossAxisSpacing: EspacesZp.m,
                  mainAxisSpacing: EspacesZp.m,
                ),
                children: [
                  for (final e in entreesPatron)
                    if (e.groupe == g) _TuileGestion(etat: etat, entree: e),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TuileGestion extends StatelessWidget {
  const _TuileGestion({required this.etat, required this.entree});

  final EtatApplication etat;
  final EntreePatron entree;

  @override
  Widget build(BuildContext context) {
    final e = entree;
    final couleur = e.couleur == CouleursZp.marque
        ? Theme.of(context).colorScheme.primary
        : e.couleur;
    return Material(
      color: CouleursZp.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: FormesZp.arrondi,
        side: BorderSide(color: CouleursZp.ligne, width: 1.5),
      ),
      child: InkWell(
        key: Key('patron-${e.cle}'),
        borderRadius: FormesZp.arrondi,
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
          padding: const EdgeInsets.all(EspacesZp.m),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: couleur.withValues(alpha: 0.16),
                  child: Icon(e.icone, size: 32, color: couleur),
                ),
                const SizedBox(height: EspacesZp.s),
                Text(
                  e.titre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
