// Planche de la nouvelle Afi (à valider par le propriétaire).
// Lancement : flutter test test_captures/afi_v2_planche_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/demo_guidee/afi_v2.dart';

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
  testWidgets('planche Afi v2', (tester) async {
    tester.view.physicalSize = const Size(2000, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget case_(String titre, EtatAfi e) => Column(
      children: [
        Container(
          color: const Color(0xFF0B1730),
          child: AfiV2(etat: e, taille: 300),
        ),
        const SizedBox(height: 6),
        Text(
          titre,
          style: const TextStyle(
            fontFamily: 'AtkinsonHyperlegible',
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    Widget bouche(String t, FormeBouche f, double o) => Column(
      children: [
        ClipRect(
          child: Align(
            alignment: const Alignment(0, -0.09),
            heightFactor: 0.32,
            widthFactor: 0.45,
            child: Container(
              color: const Color(0xFF0B1730),
              child: AfiV2(
                etat: EtatAfi(forme: f, ouverture: o, humeur: Humeur.neutre),
                taille: 420,
              ),
            ),
          ),
        ),
        Text(
          t,
          style: const TextStyle(
            fontFamily: 'AtkinsonHyperlegible',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0B1730),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    case_('Repos', const EtatAfi(humeur: Humeur.neutre)),
                    case_(
                      'Parle',
                      const EtatAfi(forme: FormeBouche.a, ouverture: 0.7),
                    ),
                    case_('Sourit', const EtatAfi(humeur: Humeur.joie)),
                    case_(
                      'Regarde à gauche',
                      const EtatAfi(regard: -1, regardY: 0.3),
                    ),
                    case_(
                      'Regarde à droite',
                      const EtatAfi(regard: 1, regardY: 0.3),
                    ),
                    case_(
                      'Au revoir',
                      const EtatAfi(
                        humeur: Humeur.joie,
                        inclinaison: 0.09,
                        forme: FormeBouche.e,
                        ouverture: 0.35,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    bouche('fermée', FormeBouche.fermee, 0),
                    bouche('« a »', FormeBouche.a, 0.8),
                    bouche('« o »', FormeBouche.o, 0.6),
                    bouche('« é »', FormeBouche.e, 0.4),
                    bouche('« m »', FormeBouche.m, 0),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/afi_v2/planche.png'),
    );
  });

  testWidgets('gros plan Afi v2', (tester) async {
    tester.view.physicalSize = const Size(1600, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0B1730),
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AfiV2(
                etat: EtatAfi(forme: FormeBouche.a, ouverture: 0.6),
                taille: 700,
              ),
              AfiV2(etat: EtatAfi(regard: 1, regardY: 0.3), taille: 700),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/afi_v2/gros_plan.png'),
    );
  });
}
