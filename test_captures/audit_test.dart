// Captures pour l'audit complet de l'application (boutique de démonstration).
// Lancement : flutter test test_captures/audit_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zero_perte/app/etat_application.dart';

import '../test/support/outils.dart';
import '../test/ecrans/visite_guidee_test.dart' show ouvrirDemo;

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
  const tailles = {
    'telephone': (Size(412, 915), 2.625),
    'pc': (Size(1366, 768), 1.0),
  };
  const pages = [
    'vendre',
    'ma-caisse',
    'credit',
    'chiffres',
    'arrivages',
    'inventaire',
    'devis',
    'retours',
    'fournisseurs',
    'vendeurs',
    'espace-patron',
  ];
  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('audit ${e.key}', (tester) async {
      await ouvrirDemo(tester, taille: taille, densite: densite);
      await tester.tap(find.byKey(const Key('visite-quitter')));
      await tester.pump(const Duration(seconds: 4));
      await attendre(tester, tours: 6);
      Future<void> capture(String n) => expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('captures/audit/${e.key}_$n.png'),
      );
      await capture('00_accueil');
      var i = 1;
      for (final p in pages) {
        final cles = [
          Key('bouton-$p'),
          Key('accueil-$p'),
          Key('menu-$p'),
          Key('tuile-$p'),
        ];
        Finder? f;
        for (final k in cles) {
          if (find.byKey(k).evaluate().isNotEmpty) {
            f = find.byKey(k).first;
            break;
          }
        }
        if (f == null) {
          // ignore: avoid_print
          print('introuvable : $p');
          continue;
        }
        await tester.ensureVisible(f);
        await tester.tap(f);
        await attendre(tester, tours: 8);
        await capture('${(i++).toString().padLeft(2, '0')}_$p');
        if (e.key == 'telephone') {
          for (final el in find.byType(Navigator).evaluate().toList()) {
            final st = (el as StatefulElement).state as NavigatorState;
            if (st.mounted) st.popUntil((r) => r.isFirst);
          }
          await attendre(tester, tours: 6);
        }
      }
    });
  }

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
