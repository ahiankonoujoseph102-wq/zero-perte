import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/inventaire.dart';

import '../support/outils.dart';
import 'caisse_test.dart' show taperMontant;
import 'inventaire_test.dart' show boutiquePourInventaire;
import 'vendeurs_test.dart' show ouvrirEspacePatron;

void main() {
  group('produits du jour', () {
    final poids = {
      'riz': 600 * 30,
      'sucre': 800 * 5,
      'bonbon': 25 * 1,
      'huile': 1300 * 10,
    };

    test('même jour → même choix ; 3 produits différents', () {
      final j = DateTime(2026, 11, 22);
      final a = produitsDuJour(jour: j, poids: poids);
      expect(a, hasLength(3));
      expect(a.toSet(), hasLength(3));
      expect(produitsDuJour(jour: j, poids: poids), a);
    });

    test('les produits chers et rapides sortent beaucoup plus souvent', () {
      var riz = 0;
      var bonbon = 0;
      for (var d = 1; d <= 300; d++) {
        final choix = produitsDuJour(
          jour: DateTime(2026, 1, d),
          poids: poids,
          nombre: 1,
        );
        if (choix.single == 'riz') riz++;
        if (choix.single == 'bonbon') bonbon++;
      }
      expect(riz, greaterThan(100));
      expect(bonbon, lessThan(5));
    });
  });

  testWidgets(
    'le vendeur ferme la caisse → compte les produits du jour sans voir les écarts → le patron voit « Kossi − … »',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiquePourInventaire(etat);
          await etat.ouvrirCaisse(0);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.verifierPin(etat.vendeurs.first, '5913');
        },
      );
      await afficherApp(tester, env.etat);
      await toucherDansMaCaisse(tester, 'bouton-fermer-caisse');
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
      await attendre(tester, tours: 10);
      await toucher(tester, find.byKey(const Key('bouton-compter-du-jour')));
      await attendre(tester, tours: 8);
      // 2 produits en stock → 2 produits à compter ; chacun compté 0 (tout manque).
      expect(find.textContaining('Produit 1 sur 2'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 12);
      expect(find.byKey(const Key('comptage-merci')), findsOneWidget);
      expect(find.textContaining('manque'), findsNothing);

      final ecarts = (await tester.runAsync(
        () => env.etat.ecartsParPersonne(depuis: 0),
      ))!;
      // Riz 100 kg × 600 + sucre 10 × 800 = 68 000 F manquants.
      expect(ecarts.values.single, -68000);

      // Le patron consulte.
      await toucher(tester, find.byKey(const Key('bouton-fin-comptage')));
      env.etat.deconnecter();
      await tester.runAsync(
        () => env.etat.verifierPin(env.etat.patron!, '482713'),
      );
      await attendre(tester);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'inventaire');
      await attendre(tester, tours: 8);
      expect(
        tester.widget<Text>(find.byKey(const Key('ecart-Kossi'))).data,
        '− 68 000 F',
      );
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('page Inventaire (patron) sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiquePourInventaire,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'inventaire');
      await attendre(tester, tours: 6);
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('bouton-inventaire-du-jour')));
      await attendre(tester, tours: 8);
      await taperMontant(tester, '5');
      expect(tester.takeException(), isNull);
    });
  }
}
