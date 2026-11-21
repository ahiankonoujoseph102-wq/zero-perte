// Captures d'écran avec les VRAIES polices (pas lancées par GitHub Actions).
//
// Usage, sur un ordinateur de développement :
//   flutter test test_captures --update-goldens
// Les images sont écrites dans test_captures/captures/ (non enregistrées dans git).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/services/telephone.dart';
import 'package:zero_perte/app/etat_application.dart';

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

  const ecrans = <String, (Size, double)>{
    '5pouces_360x640': (Size(360, 640), 2.0),
    '6pouces5_412x915': (Size(412, 915), 2.625),
    '4pouces_320x568': (Size(320, 568), 2.0),
  };

  final scenes = <String, (EtapeAssistant, bool)>{
    'accueil': (EtapeAssistant.termine, true),
    'assistant_bienvenue': (EtapeAssistant.bienvenue, true),
    'assistant_verification_ok': (EtapeAssistant.verification, true),
    'assistant_verification_bloquee': (EtapeAssistant.verification, false),
  };

  for (final e in ecrans.entries) {
    for (final scene in scenes.entries) {
      testWidgets('capture ${scene.key} ${e.key}', (tester) async {
        final (taille, _) = e.value;
        final (etape, google) = scene.value;
        final env = await environnementDeTest(
          etape: etape,
          voixFrancaise: false,
          telephone: google
              ? telephoneCompatible
              : const InfosTelephoneSansGoogle(),
        );
        await afficherApp(tester, env.etat, taille: taille, densite: 2);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('captures/${scene.key}_${e.key}.png'),
        );
      });
    }
  }
}

class InfosTelephoneSansGoogle extends InfosTelephone {
  const InfosTelephoneSansGoogle()
    : super(
        androidSdk: 29,
        androidVersion: '10',
        fabricant: 'HUAWEI',
        modele: 'P40 lite',
        servicesGoogle: false,
        espaceLibreMo: 250,
      );
}
