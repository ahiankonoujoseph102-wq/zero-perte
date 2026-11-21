// Captures d'écran avec les VRAIES polices (pas lancées par GitHub Actions).
//
// Usage, sur un ordinateur de développement :
//   flutter test test_captures --update-goldens
// Les images sont écrites dans test_captures/captures/ (non enregistrées dans git).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zero_perte/main.dart';

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

  const ecrans = <String, (Size, double)>{
    '5pouces_360x640': (Size(360, 640), 2.0),
    '6pouces5_412x915': (Size(412, 915), 2.625),
    '4pouces_320x568': (Size(320, 568), 2.0),
  };

  for (final e in ecrans.entries) {
    testWidgets('capture ${e.key}', (tester) async {
      final (taille, densite) = e.value;
      tester.view.physicalSize = taille * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ZeroPerteApp(
          infosPaquet: Future.value(
            PackageInfo(
              appName: 'Zéro Perte',
              packageName: 'tg.zeroperte.app',
              version: '0.2.0',
              buildNumber: '12',
            ),
          ),
          maintenant: DateTime(2026, 11, 21),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/${e.key}.png'),
      );
    });
  }
}
