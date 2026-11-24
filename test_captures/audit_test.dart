// Captures pour l'audit complet de l'application (boutique de démonstration).
// Lancement : flutter test test_captures/audit_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zero_perte/app/etat_application.dart';

import '../test/support/outils.dart';

Future<void> _polices() async {
  final m =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in m.cast<Map<String, dynamic>>()) {
    final l = FontLoader(f['family'] as String);
    for (final x in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
      l.addFont(rootBundle.load(x['asset'] as String));
    }
    await l.load();
  }
}

void main() {
  setUpAll(_polices);
  testWidgets('recherche dans Vendre (grande boutique)', (tester) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.termine,
      preparer: (etat) async {
        await etat.ajouterDuCatalogue(
          etat.catalogue.produitsDe(['alimentation', 'boissons']).take(30),
        );
      },
    );
    await afficherApp(
      tester,
      env.etat,
      taille: const Size(412, 915),
      densite: 2.625,
    );
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('captures/audit/recherche_0.png'),
    );
    await toucher(tester, find.byKey(const Key('bouton-vendre')));
    await attendre(tester, tours: 6);
    if (find
        .byKey(const Key('bouton-valider-montant-page'))
        .evaluate()
        .isNotEmpty) {
      await toucher(
        tester,
        find.byKey(const Key('bouton-valider-montant-page')),
      );
      await attendre(tester, tours: 6);
    }
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('captures/audit/recherche_1.png'),
    );
    await tester.enterText(find.byKey(const Key('recherche-produit')), 'ri');
    await attendre(tester, tours: 4);
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('captures/audit/recherche_2.png'),
    );
  });
}
