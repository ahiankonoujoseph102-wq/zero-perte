// Captures du lot E (retour partiel, devis, rapports) et de la sécurité de
// l'écran d'entrée, sur les 4 tailles demandées.
// Lancement manuel : flutter test test_captures/lot_e_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../test/support/outils.dart';
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;
import 'allure_captures_test.dart' show boutiqueVivante, horlogeCaptures;

Future<void> _chargerPolices() async {
  final manifeste =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final famille in manifeste.cast<Map<String, dynamic>>()) {
    final chargeur = FontLoader(famille['family'] as String);
    for (final f in (famille['fonts'] as List).cast<Map<String, dynamic>>()) {
      chargeur.addFont(rootBundle.load(f['asset'] as String));
    }
    await chargeur.load();
  }
}

void main() {
  setUpAll(_chargerPolices);
  const tailles = {
    '4pouces': (Size(320, 568), 2.0),
    'telephone': (Size(412, 915), 2.625),
    'tablette_paysage': (Size(1280, 800), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };
  Future<void> capture(String nom) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('captures/lot_e/$nom.png'),
  );

  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('lot E ${e.key}', (tester) async {
      late String recu;
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueVivante(etat);
          String id(String c) =>
              etat.produits.firstWhere((p) => p.catalogueId == c).id;
          final v = await etat.journal.enregistrerVente(
            lignes: [
              LigneDemandee.quantite(
                produitId: id('alimentation.riz'),
                nombre: 3,
              ),
              LigneDemandee.quantite(
                produitId: id('alimentation.huile'),
                nombre: 2,
              ),
            ],
            mode: ModePaiement.especes,
            montantRecu: 5000,
            auteurId: etat.auteurActuel,
          );
          recu = v.recu;
          await etat.rechargerProduits();
        },
        horloge: horlogeCaptures,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);

      // Retour partiel : 1 kg de riz et 1 huile reviennent.
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
      await toucher(tester, find.byKey(Key('vente-$recu')));
      await attendre(tester, tours: 6);
      await capture('10_detail_vente_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-retour')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('retour-plus-0')));
      await toucher(tester, find.byKey(const Key('retour-plus-1')));
      await toucher(
        tester,
        find.byKey(const Key('motif-retour-Produit abîmé')),
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
      await attendre(tester);
      await capture('11_retour_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
      await attendre(tester, tours: 10);
      await capture('12_retour_termine_${e.key}');

      // Devis : 2 kg de riz + 1 huile.
      await revenirAccueil(tester);
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('plus-0')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.huile')));
      if (find.byKey(const Key('choix-base')).evaluate().isNotEmpty) {
        await toucher(tester, find.byKey(const Key('choix-base')));
      }
      await toucher(tester, find.byKey(const Key('bouton-devis')));
      await attendre(tester, tours: 10);
      await capture('13_devis_${e.key}');

      // Rapports (mois) et liste des retours.
      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'chiffres');
      await toucher(tester, find.byKey(const Key('onglet-rapport')));
      await toucher(tester, find.byKey(const Key('rapport-semaine')));
      await attendre(tester, tours: 12);
      await capture('14_rapport_semaine_${e.key}');

      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-retours')));
      await attendre(tester, tours: 6);
      await capture('15_retours_${e.key}');

      // Nouveau vendeur : le code est tiré au hasard et montré une fois.
      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-vendeurs')));
      await toucher(tester, find.byKey(const Key('bouton-ajouter-vendeur')));
      await tester.enterText(find.byKey(const Key('champ-nom-vendeur')), 'Afi');
      await toucher(tester, find.byKey(const Key('bouton-creer-code')));
      await attendre(tester, tours: 10);
      await capture('16_code_vendeur_${e.key}');

      // Écran d'entrée bloqué après 5 codes faux.
      await revenirAccueil(tester);
      env.etat.deconnecter();
      await attendre(tester, tours: 6);
      for (var i = 0; i < 5; i++) {
        await taperCode(tester, '2468');
      }
      await capture('17_entree_bloquee_${e.key}');
    });
  }
}
