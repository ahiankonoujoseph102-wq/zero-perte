/// « À faire quand vous avez le temps » (0.36) : ce qui n'est plus demandé au
/// démarrage. Rien n'est obligatoire pour vendre.
library;

import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import '../vendeur_qr.dart';
import 'compter_stock.dart';
import 'ma_boutique.dart';
import 'produits.dart';
import 'synchronisation.dart';
import 'vendeurs.dart';

IconData iconeTache(TypeTache t) => switch (t) {
  TypeTache.compterStock => Icons.inventory_rounded,
  TypeTache.vendeur => Icons.person_add_alt_1_rounded,
  TypeTache.google => Icons.cloud_upload_rounded,
  TypeTache.prixAchat => Icons.price_change_rounded,
  TypeTache.telephone => Icons.phone_rounded,
};

Widget pageTache(EtatApplication etat, TypeTache t) => switch (t) {
  TypeTache.compterStock => PageCompterStock(etat: etat),
  TypeTache.vendeur =>
    etat.ajoutParQrPossible
        ? PageAjouterMonVendeur(etat: etat)
        : PageVendeurs(etat: etat),
  TypeTache.google => PageSynchronisation(etat: etat),
  TypeTache.prixAchat => PageProduits(etat: etat),
  TypeTache.telephone => PageMaBoutique(etat: etat),
};

class PageAFaire extends StatelessWidget {
  const PageAFaire({super.key, required this.etat});
  final EtatApplication etat;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: etat,
    builder: (context, _) {
      final taches = etat.tachesAFaire;
      return PageZp(
        titre: 'À faire',
        icone: Icons.checklist_rounded,
        corps: taches.isEmpty
            ? const EtatVide(
                icone: Icons.check_circle_rounded,
                titre: 'Tout est fait !',
                explication: 'Votre boutique est bien réglée.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Quand vous avez le temps. Rien n\'est obligatoire pour vendre.',
                    style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
                  ),
                  const SizedBox(height: 12),
                  for (final t in taches) ...[
                    Material(
                      color: CouleursZp.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: CouleursZp.ligne),
                      ),
                      child: ListTile(
                        key: Key('tache-${t.type.name}'),
                        minVerticalPadding: 14,
                        leading: Icon(iconeTache(t.type), size: 32),
                        title: Text(
                          t.titre,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          t.detail,
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => pageTache(etat, t.type),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      );
    },
  );
}

/// Ligne de l'accueil : « À faire quand vous avez le temps (3) ».
class CarteAFaire extends StatelessWidget {
  const CarteAFaire({super.key, required this.etat});
  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    final n = etat.tachesAFaire.length;
    if (n == 0) return const SizedBox.shrink();
    return Material(
      color: CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FormesZp.rayon),
        side: const BorderSide(color: CouleursZp.ligne, width: 1.5),
      ),
      child: InkWell(
        key: const Key('carte-a-faire'),
        borderRadius: BorderRadius.circular(FormesZp.rayon),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => PageAFaire(etat: etat))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.checklist_rounded, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'À faire quand vous avez le temps',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: CouleursZp.credit,
                  borderRadius: BorderRadius.circular(FormesZp.rayonPetit),
                ),
                child: Text(
                  '$n',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CouleursZp.texteSurCredit,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
