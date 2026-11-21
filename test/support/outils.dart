// Outils communs aux tests d'écran : vraie base SQLite en mémoire, faux services
// (téléphone, voix, liens, photos, raccourci) et tailles d'écran.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/services/google.dart' show ConnexionStockage;
import 'package:zero_perte/services/partage.dart';
import 'package:zero_perte/synchro/synchro.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/licence.dart';
import 'package:zero_perte/donnees/journal_local.dart';
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

/// Presse-papiers simulé (le test y « copie » un code).
class PressePapiers {
  String? texte;
}

/// Clé publique de test (clé jetable, voir test/domaine/licence_test.dart).
const clePubliqueDeTest = 'bTbX4S7szORvKgHF/5VT1JzJquzDFJOhEXRlbPp6/Sc=';

/// Petite image PNG (1 × 1 pixel) utilisée comme « photo » dans les tests.
final Uint8List photoDeTest = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0xF0,
  0x1F,
  0x00,
  0x05,
  0x00,
  0x01,
  0xFF,
  0x89,
  0x99,
  0x3D,
  0x1D,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class Environnement {
  Environnement(
    this.etat,
    this.voix,
    this.liens,
    this.pressePapiers,
    this.raccourcis,
    this.partages, {
    required this.drive,
    required this.fichiers,
  });

  /// Google Drive de la boutique (simulé).
  final StockageMemoire drive;

  /// Fichiers que « choisir un fichier » renverra, dans l'ordre.
  final List<Uint8List> fichiers;
  final EtatApplication etat;
  final FausseVoix voix;
  final List<Uri> liens;
  final PressePapiers pressePapiers;
  final List<String> raccourcis;

  /// Reçus partagés : (image PNG, texte).
  final List<(Uint8List, String)> partages;
  JournalLocal get journal => etat.journal;
}

int _compteurBases = 0;

final String _catalogue = File('assets/catalogues/catalogues.json')
    .readAsStringSync();

/// Crée un environnement complet avec une VRAIE base SQLite en mémoire.
/// À appeler dans un testWidgets : l'ouverture de la base se fait hors du temps simulé.
Future<Environnement> environnementDeTest(
  WidgetTester tester, {
  EtapeAssistant? etape,
  InfosTelephone telephone = telephoneCompatible,
  bool voixFrancaise = true,
  String clePublique = clePubliqueDeTest,
  Future<void> Function(EtatApplication etat)? preparer,
  StockageMemoire? drive,
}) async {
  final leDrive = drive ?? StockageMemoire();
  final fichiers = <Uint8List>[];
  final voix = FausseVoix(francais: voixFrancaise);
  final liens = <Uri>[];
  final presse = PressePapiers();
  final raccourcis = <String>[];
  final partages = <(Uint8List, String)>[];
  final etat = await tester.runAsync(() async {
    sqfliteFfiInit();
    // Une base en mémoire PROPRE à cet environnement (deux appareils
    // simulés dans le même test ne partagent pas leur base).
    final journal = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: 'file:zp${_compteurBases++}?mode=memory&cache=private',
    );
    if (etape != null) {
      await journal.ecrireParametre('assistant.etape', etape.name);
    }
    final e = await EtatApplication.charger(
      journal: journal,
      services: ServicesZp(
        telephone: FauxTelephone(telephone),
        voix: voix,
        ouvrirLien: (u) async {
          liens.add(u);
          return true;
        },
        lirePressePapiers: () async => presse.texte,
        clePublique: () async => lireClePublique(clePublique),
        lireCatalogue: () async => _catalogue,
        prendrePhoto: (_) async => photoDeTest,
        creerRaccourci: (nom, png) async {
          raccourcis.add(nom);
          return true;
        },
        partagerImage: (png, texte) async {
          partages.add((png, texte));
          return ResultatPartage.whatsapp;
        },
        partagerFichier: (octets, nom) async {
          partages.add((octets, nom));
          return ResultatPartage.autre;
        },
        connecterDrive: ({bool silencieux = false}) async => ConnexionStockage(
          compte: 'boutique.ama@gmail.com',
          stockage: leDrive,
        ),
        choisirFichier: () async =>
            fichiers.isEmpty ? null : fichiers.removeAt(0),
      ),
    );
    if (preparer != null) await preparer(e);
    return e;
  });
  addTearDown(() => tester.runAsync(() => etat!.journal.fermer()));
  return Environnement(
    etat!,
    voix,
    liens,
    presse,
    raccourcis,
    partages,
    drive: leDrive,
    fichiers: fichiers,
  );
}

/// Laisse la base SQLite (qui tourne hors du temps simulé) finir son travail,
/// puis redessine l'écran.
Future<void> attendre(WidgetTester tester, {int tours = 4}) async {
  for (var i = 0; i < tours; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Laisse finir les animations courtes, sans jamais attendre indéfiniment
  // (un rond de chargement tourne sans fin).
  for (var i = 0; i < 40 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Touche un élément puis attend la base.
Future<void> toucher(WidgetTester tester, Finder f) async {
  // Élément pas encore construit (plus bas dans une liste) : on fait défiler.
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(f);
  await attendre(tester);
}

final infosDeTest = PackageInfo(
  appName: 'Zéro Perte',
  packageName: 'tg.zeroperte.app',
  version: '0.5.0',
  buildNumber: '12',
);

/// Écrans testés : (taille en points, densité).
const ecransDeTest = <String, (Size, double)>{
  'petit 4 pouces': (Size(320, 568), 2.0),
  'téléphone 5 pouces': (Size(360, 640), 2.0),
  'grand téléphone 6,5 pouces': (Size(412, 915), 2.625),
  'tablette': (Size(800, 1280), 1.5),
  'tablette 10 pouces paysage': (Size(1280, 800), 1.5),
  'PC 1366×768': (Size(1366, 768), 1.0),
};

Future<void> afficherApp(
  WidgetTester tester,
  EtatApplication etat, {
  Size taille = const Size(360, 640),
  double densite = 2.0,
  double texte = 1.0,
  Future<EtatApplication> Function()? creerDemo,
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
      creerDemo: creerDemo,
    ),
  );
  await attendre(tester);
}

/// Boutique installée : patron « Ama » (code 482713), riz (sac de 50 kg) et sucre.
Future<void> boutiqueInstallee(EtatApplication etat) async {
  await etat.enregistrerConfig(
    etat.config.copie(nom: 'Boutique Mama Ama', types: ['alimentation']),
  );
  await etat.definirPatron(nom: 'Ama', pin: '482713');
  final cat = etat.catalogue.produitsDe(['alimentation']);
  await etat.ajouterDuCatalogue(
    cat.where(
      (p) => p.id == 'alimentation.riz' || p.id == 'alimentation.sucre',
    ),
  );
  for (final p in etat.produits) {
    final conds = await etat.journal.conditionnements(p.id);
    await etat.fixerPrix(p, p.nom == 'Riz' ? 600 : 800, {
      for (final c in conds)
        c: c.nom == 'sac de 50 kg'
            ? 28000
            : (c.nom == 'sac de 25 kg' ? 14500 : 8000),
    });
  }
  await etat.allerA(EtapeAssistant.termine);
}

/// Écran d'entrée : taper son code puis « OK ».
Future<void> taperCode(WidgetTester tester, String code) async {
  for (final c in code.split('')) {
    await tester.tap(find.byKey(Key('code-$c')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('code-OK')));
  // Le calcul du code est volontairement lent (sécurité) : on lui laisse le temps.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await attendre(tester);
  }
}

Future<void> taperPin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.tap(find.byKey(Key('pin-$c')));
    await tester.pump();
  }
  await attendre(tester, tours: 8);
}
