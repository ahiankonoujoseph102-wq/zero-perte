// Lecteur de QR code (0.35.2) : module téléchargé à la demande, réessai,
// messages selon la cause avec le code exact, annulation sans erreur, et
// écran « Je suis vendeur » (bouton « Préparation du lecteur… », code à
// 8 chiffres sans compteur).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/theme/couleurs.dart';
import 'package:zero_perte/services/lecteur_qr.dart';
import 'package:zero_perte/synchro/invitation.dart';

import '../support/outils.dart';
import 'ajout_vendeur_test.dart' show boutiquePatron, qrDuPatron;

ErreurLecteur _mlkit(int code) => ErreurLecteur(source: 'mlkit', code: code);
ErreurLecteur _install(int code) =>
    ErreurLecteur(source: 'install', code: code);

void main() {
  group('réessai du lecteur', () {
    // Temps simulé : chaque pause avance l'horloge, sans attendre vraiment.
    late DateTime t;
    DateTime horloge() => t;
    Future<void> dormir(Duration d) async => t = t.add(d);
    setUp(() => t = DateTime(2026, 11, 23, 9));

    test(
      'module pas encore là (premier appel) : préparé puis réessayé',
      () async {
        final l = FauxLecteurQr(lire: () async => 'ZP1abc', pret: false)
          ..erreursScanner.add(_mlkit(CodesMlKit.indisponible));
        var preparation = 0;
        final r = await scannerAvecReessai(
          l,
          maintenant: horloge,
          attendre: dormir,
          enPreparation: () => preparation++,
        );
        expect(r, 'ZP1abc');
        expect(l.preparations, 1);
        expect(l.scans, 2);
        expect(preparation, 1);
      },
    );

    test(
      'pas prêt plusieurs fois : réessais jusqu\'à ce que ça marche',
      () async {
        final l = FauxLecteurQr(lire: () async => 'ok')
          ..erreursScanner.addAll([
            _mlkit(CodesMlKit.lecteurIndisponible),
            _mlkit(CodesMlKit.indisponible),
            _mlkit(CodesMlKit.dejaEnCours),
          ]);
        expect(
          await scannerAvecReessai(l, maintenant: horloge, attendre: dormir),
          'ok',
        );
        expect(l.scans, 4);
        // Une seule demande d'installation, pas une par essai.
        expect(l.preparations, 1);
      },
    );

    test(
      'toujours pas prêt après 60 s : erreur « délai » avec le dernier code',
      () async {
        final l = FauxLecteurQr();
        for (var i = 0; i < 100; i++) {
          l.erreursScanner.add(_mlkit(CodesMlKit.indisponible));
        }
        Object? e;
        try {
          await scannerAvecReessai(l, maintenant: horloge, attendre: dormir);
        } catch (x) {
          e = x;
        }
        expect(e, isA<ErreurLecteur>());
        final err = e as ErreurLecteur;
        expect(err.source, 'delai');
        expect(err.code, CodesMlKit.indisponible);
        expect(
          t.difference(DateTime(2026, 11, 23, 9)).inSeconds,
          greaterThanOrEqualTo(60),
        );
        expect(l.scans, lessThan(30));
        expect(err.message, contains('pas encore prêt'));
      },
    );

    test(
      'vraie panne (réseau pendant l\'installation) : arrêt tout de suite',
      () async {
        final l = FauxLecteurQr(pret: false)
          ..erreursScanner.add(_mlkit(CodesMlKit.indisponible))
          ..erreurPreparer = _install(CodesServicesGoogle.reseau);
        await expectLater(
          scannerAvecReessai(l, maintenant: horloge, attendre: dormir),
          throwsA(
            isA<ErreurLecteur>().having(
              (e) => e.message,
              'm',
              contains('Internet'),
            ),
          ),
        );
        expect(l.scans, 1);
      },
    );

    test('autre erreur du lecteur : pas de réessai', () async {
      final l = FauxLecteurQr()
        ..erreursScanner.add(_mlkit(CodesMlKit.appareilPhotoRefuse));
      await expectLater(
        scannerAvecReessai(l, maintenant: horloge, attendre: dormir),
        throwsA(isA<ErreurLecteur>()),
      );
      expect(l.scans, 1);
      expect(l.preparations, 0);
    });

    test('la personne ferme le lecteur : rien (nul), pas d\'erreur', () async {
      final l = FauxLecteurQr(lire: () async => null);
      expect(
        await scannerAvecReessai(l, maintenant: horloge, attendre: dormir),
        isNull,
      );
    });
  });

  group('messages selon la cause, avec le code exact', () {
    test('chaque cause a son message', () {
      expect(messageLecteur(_mlkit(CodesMlKit.reseau)), contains('Internet'));
      expect(
        messageLecteur(_install(CodesServicesGoogle.reseau)),
        contains('Internet'),
      );
      expect(
        messageLecteur(_install(CodesServicesGoogle.reseauPayant)),
        contains('Internet'),
      );
      expect(
        messageLecteur(_mlkit(CodesMlKit.placeInsuffisante)),
        contains('place'),
      );
      expect(
        messageLecteur(_install(CodesServicesGoogle.placeInsuffisante)),
        contains('place'),
      );
      expect(
        messageLecteur(_mlkit(CodesMlKit.servicesTropAnciens)),
        contains('Services Google Play'),
      );
      expect(
        messageLecteur(
          ErreurLecteur(
            source: 'api',
            code: CodesServicesGoogle.miseAJourRequise,
          ),
        ),
        contains('Services Google Play'),
      );
      expect(
        messageLecteur(_mlkit(CodesMlKit.appareilPhotoRefuse)),
        contains('appareil photo'),
      );
      expect(messageLecteur(_mlkit(205)), contains('Pas d\'appareil photo ?'));
    });

    test('code lisible pour une capture d\'écran', () {
      expect(codeLecteurLisible(_mlkit(14)), 'Code : 14 / UNAVAILABLE (mlkit)');
      expect(
        codeLecteurLisible(_install(46003)),
        'Code : 46003 / INSUFFICIENT_STORAGE (install)',
      );
      expect(
        codeLecteurLisible(ErreurLecteur(source: 'api', code: 13)),
        'Code : 13 / ERROR (api)',
      );
      expect(
        codeLecteurLisible(ErreurLecteur(source: 'autre', code: -1)),
        contains('INCONNU'),
      );
    });

    test('ce qui se réessaie et ce qui s\'arrête', () {
      expect(lecteurPasEncorePret(_mlkit(14)), isTrue);
      expect(lecteurPasEncorePret(_mlkit(200)), isTrue);
      expect(lecteurPasEncorePret(_mlkit(204)), isTrue);
      expect(lecteurPasEncorePret(_mlkit(17)), isFalse);
      expect(lecteurPasEncorePret(_mlkit(202)), isFalse);
      expect(lecteurPasEncorePret(_install(46003)), isFalse);
    });
  });

  testWidgets(
    '0.37.1 : bienvenue — « Commencer » est le bouton vert, « Je suis vendeur » en dessous',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        relais: FauxRelaisInvitations(),
        lecteur: FauxLecteurQr(),
      );
      await afficherApp(tester, env.etat);
      final commencer = find.byKey(const Key('bouton-commencer'));
      final vendeur = find.byKey(const Key('bouton-je-suis-vendeur'));
      expect(commencer, findsOneWidget);
      expect(vendeur, findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(commencer)
            .style!
            .backgroundColor!
            .resolve({}),
        CouleursZp.argentEntre,
      );
      expect(tester.widget(vendeur), isA<OutlinedButton>());
      expect(
        tester.getRect(vendeur).top,
        greaterThan(tester.getRect(commencer).bottom),
      );
      expect(find.textContaining('bouton vert « Commencer »'), findsOneWidget);
      expect(
        find.textContaining('bouton vert « Je suis vendeur »'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('écran « Je suis vendeur »', () {
    testWidgets(
      'module absent : « Préparation du lecteur… », puis « Scanner »',
      (tester) async {
        final lecteur = FauxLecteurQr(pret: false)
          ..verrouPreparer = Completer<void>();
        final env = await environnementDeTest(
          tester,
          relais: FauxRelaisInvitations(),
          lecteur: lecteur,
        );
        await afficherApp(tester, env.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        expect(
          find.byKey(const Key('bouton-preparation-lecteur')),
          findsOneWidget,
        );
        expect(find.text('Préparation du lecteur…'), findsOneWidget);
        expect(find.byKey(const Key('bouton-scanner-qr')), findsNothing);
        expect(lecteur.preparations, 1);
        lecteur.verrouPreparer!.complete();
        await attendre(tester);
        expect(find.byKey(const Key('bouton-scanner-qr')), findsOneWidget);
        expect(find.byKey(const Key('erreur-vendeur-qr')), findsNothing);
      },
    );

    testWidgets(
      'premier scan « pas encore prêt » : réessai tout seul, la boutique arrive',
      (tester) async {
        final relais = FauxRelaisInvitations();
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          preparer: boutiquePatron,
        );
        String? qr;
        final lecteur = FauxLecteurQr(lire: () async => qr)
          ..erreursScanner.add(_mlkit(CodesMlKit.indisponible));
        final kossi = await environnementDeTest(
          tester,
          relais: relais,
          drive: patron.drive,
          lecteur: lecteur,
        );
        qr = await qrDuPatron(tester, patron.etat);
        await afficherApp(tester, kossi.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        await toucher(tester, find.byKey(const Key('bouton-scanner-qr')));
        await attendre(tester, tours: 30);
        expect(find.byKey(const Key('erreur-vendeur-qr')), findsNothing);
        expect(find.byKey(const Key('bienvenue-vendeur')), findsOneWidget);
        expect(lecteur.scans, 2);
      },
    );

    testWidgets(
      '0.37.1 : lecteur de Google en panne (-1) → le lecteur de secours lit le QR',
      (tester) async {
        final relais = FauxRelaisInvitations();
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          preparer: boutiquePatron,
        );
        String? qr;
        final lecteur = FauxLecteurQr()
          ..erreursScanner.add(
            ErreurLecteur(
              source: 'autre',
              code: -1,
              detail: 'IllegalStateException : panne',
            ),
          )
          ..lireSecours = () async => qr;
        final kossi = await environnementDeTest(
          tester,
          relais: relais,
          drive: patron.drive,
          lecteur: lecteur,
        );
        qr = await qrDuPatron(tester, patron.etat);
        await afficherApp(tester, kossi.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        await toucher(tester, find.byKey(const Key('bouton-scanner-qr')));
        await attendre(tester, tours: 30);
        expect(lecteur.scans, 1);
        expect(lecteur.scansSecours, 1);
        expect(find.byKey(const Key('erreur-vendeur-qr')), findsNothing);
        expect(find.byKey(const Key('bienvenue-vendeur')), findsOneWidget);
      },
    );

    testWidgets(
      '0.37.1 : les deux lecteurs échouent → message, détail exact et secours',
      (tester) async {
        final lecteur = FauxLecteurQr()
          ..erreursScanner.add(
            ErreurLecteur(
              source: 'autre',
              code: -1,
              detail: 'IllegalStateException : panne',
            ),
          )
          ..erreurSecours = ErreurLecteur(
            source: 'secours',
            code: -2,
            detail: 'pas d\'appareil photo',
          );
        final env = await environnementDeTest(
          tester,
          relais: FauxRelaisInvitations(),
          lecteur: lecteur,
        );
        await afficherApp(tester, env.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        await toucher(tester, find.byKey(const Key('bouton-scanner-qr')));
        await attendre(tester, tours: 10);
        expect(find.byKey(const Key('erreur-vendeur-qr')), findsOneWidget);
        expect(find.textContaining('IllegalStateException'), findsOneWidget);
        expect(
          find.byKey(const Key('lien-pas-appareil-photo')),
          findsOneWidget,
        );
      },
    );

    testWidgets('fermer le lecteur : retour à l\'écran, sans message rouge', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        relais: FauxRelaisInvitations(),
        lecteur: FauxLecteurQr(lire: () async => null),
      );
      await afficherApp(tester, env.etat);
      await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
      await toucher(tester, find.byKey(const Key('bouton-scanner-qr')));
      await attendre(tester, tours: 6);
      expect(find.byKey(const Key('erreur-vendeur-qr')), findsNothing);
      expect(find.byKey(const Key('bouton-scanner-qr')), findsOneWidget);
    });

    testWidgets(
      'pas d\'Internet pour le module : message adapté + code en petit',
      (tester) async {
        final lecteur = FauxLecteurQr(pret: false)
          ..erreurPreparer = _install(CodesServicesGoogle.reseau);
        final env = await environnementDeTest(
          tester,
          relais: FauxRelaisInvitations(),
          lecteur: lecteur,
        );
        await afficherApp(tester, env.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        await attendre(tester, tours: 6);
        expect(
          find.textContaining('Connectez-vous à Internet'),
          findsOneWidget,
        );
        expect(find.text('Code : 7 / NETWORK_ERROR (install)'), findsOneWidget);
        // Le secours reste là.
        expect(
          find.byKey(const Key('lien-pas-appareil-photo')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('bouton-scanner-qr')), findsOneWidget);
      },
    );

    testWidgets(
      'code de secours : pas de compteur, 8 chiffres avec tiret ou espace',
      (tester) async {
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
        final code = await tester.runAsync(() async {
          final p = await patron.etat.preparerInvitation('Kossi');
          return patron.etat.ouvrirCodeSecours(p);
        });
        await afficherApp(tester, kossi.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        expect(find.textContaining('/9'), findsNothing);
        expect(find.textContaining('/8'), findsNothing);
        await tester.enterText(
          find.byKey(const Key('champ-code-secours')),
          '${code!.substring(0, 4)}-${code.substring(4)}',
        );
        await toucher(
          tester,
          find.byKey(const Key('bouton-valider-code-secours')),
        );
        await attendre(tester, tours: 10);
        expect(
          find.textContaining('Montrez ce téléphone au patron'),
          findsOneWidget,
        );
        expect(codeSecoursNettoye('4821 0937'), '48210937');
        expect(codeSecoursNettoye('4821-0937'), '48210937');
      },
    );
  });
}
