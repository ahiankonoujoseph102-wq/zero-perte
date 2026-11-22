// Captures de la visite guidée avec Afi en médaillon sur les 4 tailles.
// Lancement : flutter test test_captures/afi_medaillon_visite_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/demo_guidee/voix_demo.dart';

import '../test/support/outils.dart';
import '../test/ecrans/visite_guidee_test.dart' show ouvrirDemo, visite;

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
    find.byType(MaterialApp).first,
    matchesGoldenFile('captures/afi_medaillon/$nom.png'),
  );

  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('visite médaillon ${e.key}', (tester) async {
      dureeParoleVisite = (_) => const Duration(seconds: 3);
      pauseEntrePhrasesVisite = const Duration(milliseconds: 10);
      addTearDown(() {
        dureeParoleVisite = dureeEstimee;
        pauseEntrePhrasesVisite = const Duration(milliseconds: 700);
      });
      await ouvrirDemo(
        tester,
        taille: taille,
        densite: densite,
        heure: DateTime(2026, 11, 21, 9),
      );
      expect(find.byKey(const Key('visite-avatar')), findsOneWidget);
      Future<void> jusqua(int chapitre, int etape) async {
        for (var i = 0; i < 700; i++) {
          final v = visite(tester);
          if (v.chapitre == chapitre && v.etape == etape) break;
          await attendre(tester, tours: 1);
        }
        await attendre(tester, tours: 3);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await jusqua(0, 3); // « Le gros bouton vert, Vendre… »
      await capture('40_accueil_${e.key}');
      await jusqua(2, 0); // billet de 5 000 F
      await capture('41_monnaie_${e.key}');
      await jusqua(4, 2); // fiche de Kofi
      await capture('42_credit_${e.key}');
      await tester.tap(find.byKey(const Key('visite-quitter')));
      await tester.pump(const Duration(seconds: 4));
      await attendre(tester, tours: 4);
    });
  }
}
