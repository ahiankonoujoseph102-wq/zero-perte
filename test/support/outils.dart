// Outils communs aux tests d'écran : faux services et tailles d'écran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/donnees/reglages.dart';
import 'package:zero_perte/main.dart';
import 'package:zero_perte/services/telephone.dart';
import 'package:zero_perte/services/voix.dart';

const telephoneCompatible = InfosTelephone(
  androidSdk: 30,
  androidVersion: '11',
  fabricant: 'Tecno',
  modele: 'Spark 7',
  servicesGoogle: true,
  espaceLibreMo: 2048,
);

class FauxTelephone implements ServiceTelephone {
  FauxTelephone([this.valeur = telephoneCompatible]);
  final InfosTelephone valeur;
  @override
  Future<InfosTelephone> infos() async => valeur;
}

class FausseVoix implements Voix {
  FausseVoix({this.francais = true});
  final bool francais;
  final List<String> phrases = [];
  @override
  Future<bool> francaisDisponible() async => francais;
  @override
  Future<void> dire(String texte) async => phrases.add(texte);
  @override
  Future<void> arreter() async {}
}

class Environnement {
  Environnement(this.etat, this.voix, this.liens);
  final EtatApplication etat;
  final FausseVoix voix;
  final List<Uri> liens;
}

Future<Environnement> environnementDeTest({
  EtapeAssistant? etape,
  InfosTelephone telephone = telephoneCompatible,
  bool voixFrancaise = true,
}) async {
  final voix = FausseVoix(francais: voixFrancaise);
  final liens = <Uri>[];
  final etat = await EtatApplication.charger(
    reglages: ReglagesEnMemoire({'assistant.etape': ?etape?.name}),
    services: ServicesZp(
      telephone: FauxTelephone(telephone),
      voix: voix,
      ouvrirLien: (u) async {
        liens.add(u);
        return true;
      },
    ),
  );
  return Environnement(etat, voix, liens);
}

final infosDeTest = PackageInfo(
  appName: 'Zéro Perte',
  packageName: 'tg.zeroperte.app',
  version: '0.3.0',
  buildNumber: '12',
);

/// Écrans testés : (taille en points, densité).
const ecransDeTest = <String, (Size, double)>{
  'petit 4 pouces': (Size(320, 568), 2.0),
  'téléphone 5 pouces': (Size(360, 640), 2.0),
  'grand téléphone 6,5 pouces': (Size(412, 915), 2.625),
  'tablette': (Size(800, 1280), 1.5),
};

Future<void> afficherApp(
  WidgetTester tester,
  EtatApplication etat, {
  Size taille = const Size(360, 640),
  double densite = 2.0,
  double texte = 1.0,
}) async {
  tester.view.physicalSize = taille * densite;
  tester.view.devicePixelRatio = densite;
  tester.platformDispatcher.textScaleFactorTestValue = texte;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ZeroPerteApp(
      etat: etat,
      infosPaquet: Future.value(infosDeTest),
      maintenant: DateTime(2026, 11, 21),
    ),
  );
  await tester.pumpAndSettle();
}
