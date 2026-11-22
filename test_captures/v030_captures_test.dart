// Captures de la version 0.30 sur les 4 tailles : installation (Retour, logo,
// code d'activation) et démonstration guidée avec Afi.
// Lancement : flutter test test_captures/v030_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
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
    matchesGoldenFile('captures/v030/$nom.png'),
  );

  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('installation ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await capture('30_activation_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-coller-code')));
      await attendre(tester, tours: 4);
      await capture('31_rien_copie_${e.key}');
    });

    testWidgets('visite ${e.key}', (tester) async {
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
      Future<void> jusqua(int chapitre, int etape) async {
        for (var i = 0; i < 700; i++) {
          final v = visite(tester);
          if (v.chapitre == chapitre && v.etape == etape) break;
          await attendre(tester, tours: 1);
        }
        // Laisse la page se charger, puis le cadre et le geste se poser.
        await attendre(tester, tours: 3);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await jusqua(0, 3); // « Le gros bouton vert, Vendre… »
      await capture('32_visite_accueil_${e.key}');
      await jusqua(2, 0); // billet de 5 000 F
      await capture('33_visite_monnaie_${e.key}');
      await jusqua(4, 2); // fiche de Kofi
      await capture('34_visite_credit_${e.key}');
      await tester.tap(find.byKey(const Key('visite-quitter')));
      await tester.pump(const Duration(seconds: 4));
      await attendre(tester, tours: 4);
      await capture('35_demo_libre_${e.key}');
    });
  }
}
