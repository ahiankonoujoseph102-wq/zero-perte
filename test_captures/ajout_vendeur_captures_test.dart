// Captures de l'ajout d'un vendeur par QR code (0.35) sur les 4 tailles.
// Lancement : flutter test test_captures/ajout_vendeur_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/ecrans/ajout_vendeur_test.dart' show boutiquePatron, qrDuPatron;
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;

import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/synchro/invitation.dart';

import '../test/support/outils.dart';

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

Future<void> capture(WidgetTester tester, String nom) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('captures/ajout_vendeur/$nom.png'),
);

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
    final grand = taille.width >= 840;

    testWidgets('patron ${e.key}', (tester) async {
      final relais = FauxRelaisInvitations();
      final patron = await environnementDeTest(
        tester,
        relais: relais,
        preparer: boutiquePatron,
      );
      await afficherApp(tester, patron.etat, taille: taille, densite: densite);
      await capture(tester, 'accueil_patron_${e.key}');
      if (grand) {
        await toucher(tester, find.byKey(const Key('menu-ajouter-vendeur')));
      } else {
        await toucher(
          tester,
          find.byKey(const Key('bouton-ajouter-mon-vendeur')),
        );
      }
      await tester.enterText(
        find.byKey(const Key('champ-prenom-vendeur')),
        'Kossi',
      );
      await attendre(tester);
      await capture(tester, 'prenom_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-continuer-vendeur')));
      await attendre(tester, tours: 20);
      expect(find.byKey(const Key('qr-invitation')), findsOneWidget);
      await capture(tester, 'qr_${e.key}');
      await toucher(tester, find.byKey(const Key('lien-pas-appareil-photo')));
      await attendre(tester, tours: 10);
      await capture(tester, 'code_secours_${e.key}');
      relais.boites.clear();
      relais.demandes[relais.attentes.single] = const DemandeEntree(
        clePublique: 'AAAA',
        appareil: 'Tecno Spark 7',
      );
      await tester.pump(const Duration(seconds: 3));
      await attendre(tester, tours: 6);
      await capture(tester, 'demande_oui_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('vendeur ${e.key}', (tester) async {
      final relais = FauxRelaisInvitations();
      final patron = await environnementDeTest(
        tester,
        relais: relais,
        preparer: boutiquePatron,
      );
      String? qr;
      final kossi = await environnementDeTest(
        tester,
        relais: relais,
        drive: patron.drive,
        scanner: () async => qr,
      );
      qr = await qrDuPatron(tester, patron.etat);
      await afficherApp(tester, kossi.etat, taille: taille, densite: densite);
      await capture(tester, 'bienvenue_installation_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
      await capture(tester, 'je_suis_vendeur_${e.key}');
      await toucher(tester, find.byKey(const Key('lien-pas-appareil-photo')));
      await capture(tester, 'taper_code_${e.key}');
      Navigator.of(tester.element(find.byKey(const Key('champ-code-secours'))))
          .pop();
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
      await toucher(tester, find.byKey(const Key('bouton-scanner-qr')));
      await attendre(tester, tours: 30);
      expect(find.byKey(const Key('bienvenue-vendeur')), findsOneWidget);
      await capture(tester, 'code_vendeur_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('mes appareils ${e.key}', (tester) async {
      final relais = FauxRelaisInvitations();
      final patron = await environnementDeTest(
        tester,
        relais: relais,
        preparer: boutiquePatron,
      );
      final kossi = await environnementDeTest(
        tester,
        relais: relais,
        drive: patron.drive,
      );
      final texte = await qrDuPatron(tester, patron.etat);
      await tester.runAsync(() => kossi.etat.entrerParQr(texte));
      await afficherApp(tester, patron.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await capture(tester, 'gestion_${e.key}');
      await toucher(tester, find.byKey(const Key('patron-appareils')));
      await attendre(tester, tours: 10);
      await capture(tester, 'mes_appareils_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('appareil retiré ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueInstallee(etat);
          await etat.journal.ecrireParametre('appareil.retire', '1');
        },
      );
      final etat = await tester.runAsync(
        () => EtatApplication.charger(
          journal: env.journal,
          services: env.etat.services,
        ),
      );
      await afficherApp(tester, etat!, taille: taille, densite: densite);
      await capture(tester, 'retire_${e.key}');
    });
  }
}
