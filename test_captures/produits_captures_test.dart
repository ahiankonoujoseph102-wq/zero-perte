// Captures « Produits et prix » sur les 4 tailles (liste et fiche).
// Lancement : flutter test test_captures/produits_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/outils.dart';
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;

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
    '4pouces': (Size(320, 568), 2.0),
    'telephone': (Size(412, 915), 2.625),
    'tablette_paysage': (Size(1280, 800), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };
  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('produits ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueInstallee(etat);
          await etat.creerProduit(
            nom: 'Savon Lux',
            uniteBase: 'pièce',
            prixVente: 450,
            prixAchat: 300,
            stockDepart: 24,
            conditionnements: [('carton de 24', 24, 10000)],
          );
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await capture(tester, 'gestion_${e.key}');
      await ouvrirPagePatron(tester, 'produits');
      await capture(tester, 'liste_${e.key}');
      final savon = env.etat.produits.firstWhere((p) => p.nom == 'Savon Lux');
      await toucher(tester, find.byKey(Key('produit-${savon.id}')));
      await attendre(tester, tours: 6);
      await capture(tester, 'fiche_${e.key}');
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> capture(WidgetTester tester, String nom) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('captures/produits/$nom.png'),
);
