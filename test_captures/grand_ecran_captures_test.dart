// Captures sur tablette 10 pouces (paysage et portrait) et PC 1366×768.
// Lancement manuel : flutter test test_captures --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/tableau.dart';

import '../test/ecrans/credit_test.dart' show boutiqueAvecKofi;
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;
import '../test/support/outils.dart';

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
  const ecrans = {
    'tablette_paysage': (Size(1280, 800), 1.5),
    'tablette_portrait': (Size(800, 1280), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };
  for (final e in ecrans.entries) {
    final (taille, densite) = e.value;
    testWidgets('grand ecran ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueAvecKofi);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/ge_accueil_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.sucre')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/ge_vente_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-5000')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/ge_encaisser_${e.key}.png'),
      );
      await tester.pageBack();
      await attendre(tester);
      await tester.pageBack();
      await attendre(tester);
      await ouvrirEspacePatron(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/ge_patron_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('patron-tableau')));
      await attendre(tester, tours: 10);
      await toucher(tester, find.byKey(Key('periode-${Periode.mois.name}')));
      await attendre(tester, tours: 10);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/ge_tableau_${e.key}.png'),
      );
    });
  }
}
