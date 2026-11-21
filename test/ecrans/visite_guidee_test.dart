// Démonstration guidée avec Afi : la visite entière se joue sur chaque taille
// d'écran, chaque bouton montré est trouvé, la vente est vraiment faite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/demo_guidee/phrases.dart';
import 'package:zero_perte/demo_guidee/script_visite.dart';
import 'package:zero_perte/demo_guidee/visite_guidee.dart';
import 'package:zero_perte/demo_guidee/voix_demo.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'demo_test.dart' show cheminDemo, demo;

/// Ouvre la démonstration (bouton de l'étape « Code d'activation »).
Future<(Environnement, EtatApplication)> ouvrirDemo(
  WidgetTester tester, {
  Size taille = const Size(360, 640),
  double densite = 2,
  DateTime? heure,
}) async {
  final env = await environnementDeTest(
    tester,
    etape: EtapeAssistant.activation,
  );
  final d = (await tester.runAsync(() => demo(env, cheminDemo())))!;
  if (heure != null) d.maintenant = () => heure;
  await afficherApp(
    tester,
    env.etat,
    taille: taille,
    densite: densite,
    creerDemo: () async => d,
  );
  await toucher(tester, find.byKey(const Key('bouton-demonstration')));
  await attendre(tester, tours: 8);
  return (env, d);
}

EtatVisite visite(WidgetTester tester) =>
    tester.state<EtatVisite>(find.byType(VisiteGuidee));

/// Laisse la visite avancer jusqu'à la fin (ou [max] tours).
Future<void> jouerJusquaLaFin(WidgetTester tester, {int max = 900}) async {
  for (var i = 0; i < max; i++) {
    if (visite(tester).termine) return;
    await attendre(tester, tours: 2);
  }
  final v = visite(tester);
  fail(
    'la visite ne s\'est pas terminée : chapitre ${v.chapitre}, étape '
    '${v.etape}, manquants ${v.ciblesManquantes}',
  );
}

/// Attend (au plus [max] tours) que [condition] soit vraie.
Future<void> attendreQue(
  WidgetTester tester,
  bool Function() condition, {
  int max = 120,
}) async {
  for (var i = 0; i < max && !condition(); i++) {
    await attendre(tester, tours: 1);
  }
  expect(condition(), isTrue);
}

/// Ferme la visite et laisse finir ses attentes (fin de test propre).
Future<void> arreterVisite(WidgetTester tester) async {
  final q = find.byKey(const Key('visite-quitter'));
  if (q.evaluate().isNotEmpty) await tester.tap(q);
  await tester.pump(const Duration(seconds: 3));
  await attendre(tester, tours: 2);
}

int nombreEtapes() => chapitresVisite().fold(0, (s, c) => s + c.etapes.length);

void main() {
  setUp(() {
    dureeParoleVisite = (_) => const Duration(milliseconds: 30);
    pauseEntrePhrasesVisite = const Duration(milliseconds: 10);
  });
  tearDown(() {
    dureeParoleVisite = dureeEstimee;
    pauseEntrePhrasesVisite = const Duration(milliseconds: 700);
  });

  test(
    'le texte de la voix est exactement celui de docs/demo/texte-voix.md',
    () {
      final md = File('docs/demo/texte-voix.md').readAsStringSync();
      final lignes = RegExp(
        r'^\| (\d{3}) \| (\S+) \| ([^|]+) \| ([^|]+) \|$',
        multiLine: true,
      ).allMatches(md).toList();
      expect(lignes, hasLength(phrasesVisite.length));
      for (final l in lignes) {
        expect(l.group(2), '${l.group(1)}.webm');
        expect(
          phrasesVisite[l.group(1)],
          l.group(4)!.trim(),
          reason: l.group(1),
        );
      }
      // Chaque étape de la visite a sa phrase.
      for (final c in chapitresVisite()) {
        for (final e in c.etapes) {
          expect(phrasesVisite.containsKey(e.phrase), isTrue, reason: e.phrase);
        }
      }
    },
  );

  test('« Bonjour » avant 15 h, « Bonsoir » à partir de 15 h', () {
    expect(heureBonsoir, 15);
    expect(phraseSalutation(DateTime(2026, 11, 21, 14, 59)), '001');
    expect(phraseSalutation(DateTime(2026, 11, 21, 15, 0)), '002');
    expect(phrasesVisite['001'], 'Bonjour !');
    expect(phrasesVisite['002'], 'Bonsoir !');
  });

  test('durée : environ 5 minutes avec la voix de synthèse', () {
    var ms = 0;
    for (final c in chapitresVisite()) {
      for (final e in c.etapes) {
        ms += dureeEstimee(e.texte).inMilliseconds + 700;
        if (e.toucher) ms += 650;
        if (e.revenirAccueil) ms += 450;
      }
    }
    final minutes = ms / 60000;
    expect(minutes, inInclusiveRange(4.0, 6.0));
  });

  test('voix enregistrée : bouches.json lu, bouche calculée d\'avance', () {
    final v = VoixEnregistree.depuisJson(
      '{"version":1,"service":"gemini","phrases":{"003":{"fichier":"003.webm",'
      '"duree_ms":150,"bouche":"095"}}}',
    );
    expect(v.mentionIA, isTrue);
    final p = v.phrases['003']!;
    expect(p.boucheA(0), 0);
    expect(p.boucheA(60), 1);
    expect(p.boucheA(120), closeTo(5 / 9, 1e-9));
    expect(p.boucheA(400), 0);
    // Fichier vide ou abîmé : pas de voix enregistrée (voix de synthèse).
    expect(VoixEnregistree.depuisJson('{}').phrases, isEmpty);
    expect(VoixEnregistree.depuisJson('pas du json').mentionIA, isFalse);
    // Le fichier livré aujourd'hui est vide (la voix n'est pas encore faite).
    final livre = VoixEnregistree.depuisJson(
      File('assets/demo/voix/bouches.json').readAsStringSync(),
    );
    expect(livre.phrases, isEmpty);
  });

  for (final (nom, taille, densite) in [
    ('petit 4 pouces', const Size(320, 568), 2.0),
    ('grand téléphone', const Size(412, 915), 2.625),
    ('tablette 10 pouces paysage', const Size(1280, 800), 1.5),
    ('PC 1366×768', const Size(1366, 768), 1.0),
  ]) {
    testWidgets(
      'visite complète sur $nom : chaque bouton est trouvé, la vente est faite',
      (tester) async {
        final (env, d) = await ouvrirDemo(
          tester,
          taille: taille,
          densite: densite,
          heure: DateTime(2026, 11, 21, 9),
        );
        expect(find.byKey(const Key('visite-panneau')), findsOneWidget);
        await jouerJusquaLaFin(tester);
        final v = visite(tester);
        expect(v.ciblesManquantes, isEmpty);
        expect(v.etapesJouees, nombreEtapes());
        expect(tester.takeException(), isNull);
        // La voix (de synthèse ici) a dit les phrases, dans l'ordre.
        final dites = env.voix.phrases;
        final debut = dites.indexOf('Bonjour !');
        expect(debut, greaterThanOrEqualTo(0));
        expect(dites.indexOf(phrasesVisite['016']!), greaterThan(debut));
        expect(dites.last, phrasesVisite['050']);
        // La vente de 2 kg de riz a vraiment été faite (et le crédit de Kofi).
        final ventes = await tester.runAsync(d.ventesDuJour);
        expect(
          ventes!.where(
            (x) => x.mode == ModePaiement.especes && x.total == 1200,
          ),
          hasLength(1),
        );
        expect(find.text('Visite terminée'), findsOneWidget);
      },
    );
  }

  testWidgets('« Bonsoir » à 16 h', (tester) async {
    final (env, _) = await ouvrirDemo(
      tester,
      heure: DateTime(2026, 11, 21, 16),
    );
    await attendreQue(tester, () => env.voix.phrases.contains('Bonsoir !'));
    expect(env.voix.phrases, isNot(contains('Bonjour !')));
    await arreterVisite(tester);
  });

  testWidgets('Pause, Reprendre, Suivant, Rejouer, Quitter, Visite', (
    tester,
  ) async {
    // Phrases longues : la visite reste sur la même étape pendant le test.
    dureeParoleVisite = (_) => const Duration(seconds: 4);
    final (env, _) = await ouvrirDemo(tester);
    await attendreQue(
      tester,
      () =>
          env.voix.phrases.contains('Bonjour !') ||
          env.voix.phrases.contains('Bonsoir !'),
    );
    // Pause : la voix s'arrête, le message le dit, l'écran redevient libre.
    await tester.tap(find.byKey(const Key('visite-pause')));
    await attendre(tester, tours: 2);
    expect(find.textContaining('Pause. Touchez'), findsOneWidget);
    final dites = env.voix.phrases.length;
    await attendre(tester, tours: 6);
    expect(env.voix.phrases.length, dites);
    // Reprendre.
    await tester.tap(find.byKey(const Key('visite-pause')));
    await attendreQue(tester, () => env.voix.phrases.length > dites);
    // Suivant : passe au chapitre « Vendre ».
    await tester.tap(find.byKey(const Key('visite-suivant')));
    await attendre(tester, tours: 3);
    expect(visite(tester).chapitre, 1);
    expect(find.textContaining('Vendre'), findsWidgets);
    // Suivant encore : saute « La monnaie » et « Le reçu » (même groupe).
    await tester.tap(find.byKey(const Key('visite-suivant')));
    await attendre(tester, tours: 3);
    expect(
      visite(tester).chapitres[visite(tester).chapitre].titre,
      'Client et crédit',
    );
    // Rejouer : recommence ce chapitre.
    await tester.tap(find.byKey(const Key('visite-rejouer')));
    await attendre(tester, tours: 2);
    expect(visite(tester).etape, lessThanOrEqualTo(1));
    // Quitter : la visite disparaît, la démo reste ; « Visite » la relance.
    await tester.tap(find.byKey(const Key('visite-quitter')));
    await attendre(tester, tours: 3);
    expect(find.byKey(const Key('visite-panneau')), findsNothing);
    expect(find.byKey(const Key('bandeau-demo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bouton-relancer-visite')));
    await attendre(tester, tours: 3);
    expect(find.byKey(const Key('visite-panneau')), findsOneWidget);
    expect(visite(tester).chapitre, 0);
    await arreterVisite(tester);
  });

  testWidgets(
    'voix enregistrée : les fichiers sont joués, la bouche bouge, mention IA',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      final d = (await tester.runAsync(() => demo(env, cheminDemo())))!;
      d.maintenant = () => DateTime(2026, 11, 21, 9);
      final joues = <String>[];
      final ctrl = ControleurVisite();
      final nav = GlobalKey<NavigatorState>();
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          builder: (context, enfant) => VisiteGuidee(
            etat: d,
            controleur: ctrl,
            navigateur: nav,
            voix: env.voix,
            lecteur: _FauxLecteur(joues),
            voixEnregistree: Future.value(
              VoixEnregistree.depuisJson(
                '{"service":"gemini","phrases":{'
                '"001":{"fichier":"001.webm","duree_ms":400,"bouche":"0594"},'
                '"003":{"fichier":"003.webm","duree_ms":400,"bouche":"0594"}}}',
              ),
            ),
            dureeParole: (_) => const Duration(milliseconds: 30),
            pauseEntrePhrases: const Duration(milliseconds: 10),
            child: enfant!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      await attendreQue(tester, () => joues.length >= 2);
      await attendreQue(
        tester,
        () => env.voix.phrases.contains(phrasesVisite['004']),
      );
      expect(joues.take(2), ['001.webm', '003.webm']);
      // Les phrases sans fichier passent par la voix de synthèse.
      expect(env.voix.phrases, isNot(contains('Bonjour !')));
      expect(env.voix.phrases, contains(phrasesVisite['004']));
      expect(find.byKey(const Key('visite-mention-ia')), findsOneWidget);
      ctrl.quitter();
      await tester.pump(const Duration(seconds: 3));
      await attendre(tester);
    },
  );
}

class _FauxLecteur implements LecteurVoixDemo {
  _FauxLecteur(this.joues);
  final List<String> joues;
  @override
  Future<bool> jouer(String fichier) async {
    joues.add(fichier);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return true;
  }

  @override
  Future<void> arreter() async {}
}
