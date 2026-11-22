// Ajout d'un vendeur par QR code (0.35) : chiffrement, 10 minutes, une seule
// fois, licence, retrait, « Couper tous », vente sans réseau, code de secours,
// et les écrans (patron, vendeur, Mes appareils).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/vendeur_qr.dart';
import 'package:zero_perte/synchro/invitation.dart';
import 'package:zero_perte/synchro/synchro.dart';

import '../domaine/licence_test.dart' show codeLicence;
import '../support/outils.dart';
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

const _paquetTest = PaquetInvitation(
  invitation: 'inv-1',
  compte: 'boutique.ama@gmail.com',
  jetonLong: 'jeton-long-secret-1234567890',
  jetonRelais: 'jeton-relais-boutique-123456',
  vendeurId: 'v1',
  vendeurNom: 'Kossi',
  codeVendeur: '4821',
  nomBoutique: 'Boutique Mama Ama',
);

/// Boutique du patron, licence 2 appareils, Drive relié et synchronisé.
Future<void> boutiquePatron(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  await etat.activer(codeLicence);
  await etat.connecterSynchro();
  await etat.synchroniser();
}

/// Le patron prépare l'invitation et publie le QR code ; rend le texte du QR.
Future<String> qrDuPatron(
  WidgetTester tester,
  EtatApplication patron, [
  String prenom = 'Kossi',
]) async {
  final texte = await tester.runAsync(() async {
    final p = await patron.preparerInvitation(prenom);
    return (await patron.publierQr(p)).texte;
  });
  return texte!;
}

void main() {
  group('chiffrement du paquet', () {
    test(
      'QR : aller-retour, et rien de lisible dans le QR ni sur le relais',
      () async {
        final qr = QrInvitation.nouveau();
        final chiffre = await chiffrerPourQr(_paquetTest, qr);
        expect(qr.texte, startsWith('ZP1'));
        expect(qr.texte.length, lessThan(80));
        for (final secret in [
          'jeton-long-secret',
          'jeton-relais',
          '4821',
          'Kossi',
        ]) {
          expect(qr.texte, isNot(contains(secret)));
          expect(chiffre, isNot(contains(secret)));
          expect(
            utf8.decode(
              base64Url.decode(base64Url.normalize(chiffre)),
              allowMalformed: true,
            ),
            isNot(contains(secret)),
          );
        }
        final lu = QrInvitation.lire(qr.texte);
        final p = await dechiffrerDepuisQr(chiffre, lu);
        expect(p.jetonLong, _paquetTest.jetonLong);
        expect(p.codeVendeur, '4821');
      },
    );

    test('QR : une autre clé ne peut pas ouvrir le paquet', () async {
      final qr = QrInvitation.nouveau();
      final chiffre = await chiffrerPourQr(_paquetTest, qr);
      final autre = QrInvitation(qr.boite, QrInvitation.nouveau().cle);
      await expectLater(
        dechiffrerDepuisQr(chiffre, autre),
        throwsA(isA<ErreurInvitation>()),
      );
      expect(
        () => QrInvitation.lire('https://exemple.com'),
        throwsA(isA<ErreurInvitation>()),
      );
      expect(
        () => QrInvitation.lire('ZP1abc'),
        throwsA(isA<ErreurInvitation>()),
      );
    });

    test(
      'code de secours : seul le téléphone qui a demandé peut ouvrir',
      () async {
        final code = nouveauCodeSecours();
        expect(code, matches(RegExp(r'^\d{8}$')));
        expect(codeSecoursLisible('48210937'), '4821 0937');
        expect(codeSecoursNettoye('4821 0937'), '48210937');
        expect(codeSecoursNettoye('4821'), isNull);
        final vendeur = await DemandeParCode.nouvelle(code);
        final pirate = await DemandeParCode.nouvelle(code);
        final chiffre = await chiffrerPourDemande(
          _paquetTest,
          code,
          vendeur.clePublique,
        );
        expect((await vendeur.ouvrir(chiffre)).vendeurNom, 'Kossi');
        // Même code, autre téléphone : il ne peut pas lire le paquet.
        await expectLater(
          pirate.ouvrir(chiffre),
          throwsA(isA<ErreurInvitation>()),
        );
        // La boîte ne révèle pas le code.
        expect(boiteDuCode(code), isNot(contains(code)));
        expect(boiteDuCode(code).length, 32);
      },
    );
  });

  group('parcours complet', () {
    testWidgets(
      'QR : le vendeur scanne, reçoit la boutique et son code ; une seule fois',
      (tester) async {
        final relais = FauxRelaisInvitations();
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          preparer: boutiquePatron,
        );
        final vendeur = await environnementDeTest(
          tester,
          relais: relais,
          drive: patron.drive,
        );
        final autre = await environnementDeTest(
          tester,
          relais: relais,
          drive: patron.drive,
        );

        final texte = await qrDuPatron(tester, patron.etat);
        // Rien de secret dans la boîte du relais.
        final (paquet, _) = relais.boites.values.single;
        expect(paquet, isNot(contains('jeton-long')));

        final p = await tester.runAsync(() => vendeur.etat.entrerParQr(texte));
        expect(p!.vendeurNom, 'Kossi');
        expect(p.codeVendeur, matches(RegExp(r'^\d{4}$')));
        final v = vendeur.etat;
        expect(v.etape, EtapeAssistant.termine);
        expect(v.licence, isNotNull);
        expect(
          v.produits.map((e) => e.nom),
          containsAll(['Riz', 'Sucre en poudre']),
        );
        expect(v.vendeurs.map((e) => e.nom), contains('Kossi'));
        // Son code marche, il n'est pas patron.
        final kossi = v.vendeurs.firstWhere((e) => e.nom == 'Kossi');
        expect(
          await tester.runAsync(() => v.verifierPin(kossi, p.codeVendeur)),
          isTrue,
        );
        expect(v.voitTout, isFalse);
        // Aucun mot de passe ni compte Google sur ce téléphone : il passe par le relais.
        expect(await tester.runAsync(v.estEntreParInvitation), isTrue);
        expect(relais.appels, contains('acces'));

        // Le patron voit que le QR code a servi.
        expect(
          await tester.runAsync(
            () => patron.etat.invitationPrise(QrInvitation.lire(texte)),
          ),
          isTrue,
        );
        // Le même QR code ne marche pas une deuxième fois.
        await tester.runAsync(() async {
          await expectLater(
            autre.etat.entrerParQr(texte),
            throwsA(isA<ErreurInvitation>()),
          );
        });
        // Le vendeur est inscrit avec l'empreinte de son jeton (pas le jeton).
        final fichier = patron.drive.fichiers.entries.firstWhere(
          (e) => e.key == 'appareil-${v.journal.telephoneId}.json',
        );
        final d = jsonDecode(utf8.decode(fichier.value)) as Map;
        expect(d['invitation'], isNotNull);
        expect(d['empreinte'], hasLength(64));
        expect(utf8.decode(fichier.value), isNot(contains('jeton-long')));
      },
    );

    testWidgets('10 minutes : après, le QR code ne marche plus', (
      tester,
    ) async {
      var t = DateTime(2026, 11, 22, 10);
      final relais = FauxRelaisInvitations(horloge: () => t);
      final patron = await environnementDeTest(
        tester,
        relais: relais,
        preparer: boutiquePatron,
      );
      final vendeur = await environnementDeTest(
        tester,
        relais: relais,
        drive: patron.drive,
      );
      final texte = await qrDuPatron(tester, patron.etat);
      t = t.add(const Duration(minutes: 10, seconds: 1));
      await tester.runAsync(() async {
        await expectLater(
          vendeur.etat.entrerParQr(texte),
          throwsA(
            isA<ErreurInvitation>().having(
              (e) => e.message,
              'message',
              contains('expiré'),
            ),
          ),
        );
      });
      expect(vendeur.etat.etape, isNot(EtapeAssistant.termine));
    });

    testWidgets(
      'licence 2 appareils : pas de 3e ; « Retirer » libère la place',
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
        await tester.runAsync(
          () async => kossi.etat.entrerParQr(await () async {
            final p = await patron.etat.preparerInvitation('Kossi');
            return (await patron.etat.publierQr(p)).texte;
          }()),
        );
        expect(kossi.etat.etape, EtapeAssistant.termine);

        // 2 appareils sur 2 : refusé, AVANT de demander l'accord de Google.
        final avant = relais.appels.where((a) => a == 'echange').length;
        await tester.runAsync(() async {
          await expectLater(
            patron.etat.preparerInvitation('Afi'),
            throwsA(isA<ErreurLicencePleine>()),
          );
        });
        expect(relais.appels.where((a) => a == 'echange').length, avant);
        expect(patron.etat.proposerAjoutVendeur, isFalse);

        // Le patron retire Kossi : liste noire du relais + place libérée.
        final liste = await tester.runAsync(patron.etat.mesAppareils);
        final a = liste!.actifs.firstWhere(
          (x) => x.id == kossi.journal.telephoneId,
        );
        await tester.runAsync(() => patron.etat.retirerAppareil(a));
        expect(relais.listeNoire, contains(a.empreinte));
        final apres = await tester.runAsync(patron.etat.mesAppareils);
        expect(apres!.actifs.length, 1);
        expect(apres.retires, contains(a.id));
        // Le téléphone de Kossi est bloqué à sa prochaine synchronisation.
        await tester.runAsync(kossi.etat.synchroniser);
        expect(kossi.etat.appareilRetire, isTrue);
        // Une nouvelle invitation est de nouveau possible.
        await tester.runAsync(() async {
          final p = await patron.etat.preparerInvitation('Afi');
          expect(p.vendeurNom, 'Afi');
        });
      },
    );

    testWidgets(
      'licence pleine : refaire le QR de Kossi est permis, mais un AUTRE téléphone est refusé',
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
        final intrus = await environnementDeTest(
          tester,
          relais: relais,
          drive: patron.drive,
        );
        final premier = await qrDuPatron(tester, patron.etat);
        await tester.runAsync(() => kossi.etat.entrerParQr(premier));
        final second = await qrDuPatron(tester, patron.etat);
        await tester.runAsync(() async {
          await expectLater(
            intrus.etat.entrerParQr(second),
            throwsA(isA<ErreurLicencePleine>()),
          );
        });
        final l = await tester.runAsync(patron.etat.mesAppareils);
        expect(l!.actifs.length, 2);
      },
    );

    testWidgets(
      'appareil retiré : ses ventes faites APRÈS le retrait sont refusées',
      (tester) async {
        var t = DateTime(2026, 11, 22, 9).millisecondsSinceEpoch;
        final relais = FauxRelaisInvitations();
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          horloge: () => t,
          preparer: boutiquePatron,
        );
        final kossi = await environnementDeTest(
          tester,
          relais: relais,
          horloge: () => t,
          drive: patron.drive,
        );
        patron.etat.maintenant = () => DateTime.fromMillisecondsSinceEpoch(t);
        final texte = await qrDuPatron(tester, patron.etat);
        await tester.runAsync(() => kossi.etat.entrerParQr(texte));
        final opsAvant = await tester.runAsync(
          () => patron.journal.dernierNumero(kossi.journal.telephoneId),
        );
        final liste = await tester.runAsync(patron.etat.mesAppareils);
        t += 60000;
        await tester.runAsync(
          () => patron.etat.retirerAppareil(
            liste!.actifs.firstWhere((x) => x.id == kossi.journal.telephoneId),
          ),
        );
        // Kossi écrit encore (par exemple sans réseau), puis un fichier arrive
        // quand même dans le Drive : le patron l'ignore.
        t += 60000;
        await tester.runAsync(() async {
          await kossi.etat.enregistrerConfig(
            kossi.etat.config.copie(nom: 'Piratée'),
          );
          final ops = await kossi.journal.mesOperationsApres(0);
          await patron.drive.ecrire(
            'ops-${kossi.journal.telephoneId}-00000001-${ops.last.numero.toString().padLeft(8, '0')}.json',
            JournalLocal.operationsVersJson(ops),
          );
          await patron.etat.synchroniser();
        });
        expect(patron.etat.config.nom, isNot('Piratée'));
        final opsApres = await tester.runAsync(
          () => patron.journal.dernierNumero(kossi.journal.telephoneId),
        );
        expect(opsApres, opsAvant);
      },
    );

    testWidgets(
      'sans réseau : le vendeur VEND, et tout part quand le relais revient',
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
        final texte = await qrDuPatron(tester, patron.etat);
        await tester.runAsync(() => kossi.etat.entrerParQr(texte));

        relais.horsLigne = true;
        await tester.runAsync(() async {
          // Une écriture du vendeur pendant la coupure (comme une vente).
          await kossi.etat.enregistrerClient(
            nom: 'Client sans réseau',
            telephone: '90000001',
          );
          expect(await kossi.etat.synchroniser(), isNull);
        });
        expect(kossi.etat.appareilRetire, isFalse);
        expect(kossi.etat.accesCoupe, isFalse);
        final avant = await tester.runAsync(() async {
          await patron.etat.synchroniser();
          return patron.etat.clients();
        });
        expect(avant!.map((c) => c.nom), isNot(contains('Client sans réseau')));

        relais.horsLigne = false;
        final apres = await tester.runAsync(() async {
          expect(await kossi.etat.synchroniser(), isNotNull);
          await patron.etat.synchroniser();
          return patron.etat.clients();
        });
        expect(apres!.map((c) => c.nom), contains('Client sans réseau'));
      },
    );

    testWidgets('code de secours : le patron dit OUI, le bon téléphone entre', (
      tester,
    ) async {
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
      await tester.runAsync(() async {
        final p = await patron.etat.preparerInvitation('Kossi');
        final code = await patron.etat.ouvrirCodeSecours(p);
        // Code faux : refusé, rien n'est demandé au patron.
        expect(
          await kossi.etat.demanderParCode('11112222', 'Tecno Spark 7'),
          isNull,
        );
        final d = await kossi.etat.demanderParCode(code, 'Tecno Spark 7');
        expect(d, isNotNull);
        // Pas encore de OUI : rien.
        expect(await kossi.etat.verifierReponse(d!), isNull);
        final demande = await patron.etat.demandeRecue(p, code);
        expect(demande!.appareil, 'Tecno Spark 7');
        await patron.etat.accepterDemande(p, code, demande);
        final recu = await kossi.etat.verifierReponse(d);
        expect(recu!.vendeurNom, 'Kossi');
        expect(await patron.etat.codeSecoursUtilise(code), isTrue);
      });
      expect(kossi.etat.etape, EtapeAssistant.termine);
    });

    testWidgets('« Couper tous les vendeurs » : accord Google, tous retirés', (
      tester,
    ) async {
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
      final n = await tester.runAsync(patron.etat.couperTousLesVendeurs);
      expect(n, 1);
      expect(relais.jetonsAnnules, isNotEmpty);
      await tester.runAsync(kossi.etat.synchroniser);
      expect(kossi.etat.appareilRetire, isTrue);
      // Le patron, lui, continue.
      expect(await tester.runAsync(patron.etat.synchroniser), isNotNull);
    });

    testWidgets(
      'accès coupé par Google : ventes gardées, nouveau QR → même téléphone',
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
        await tester.runAsync(
          () async => kossi.etat.entrerParQr(await () async {
            final p = await patron.etat.preparerInvitation('Kossi');
            return (await patron.etat.publierQr(p)).texte;
          }()),
        );
        final id = kossi.journal.telephoneId;
        // Google annule l'autorisation (compte de la boutique…), sans retrait.
        relais.jetonsAnnules.addAll(relais.jetonsDonnes);
        await tester.runAsync(() async {
          await kossi.etat.enregistrerClient(
            nom: 'Client gardé',
            telephone: '90000002',
          );
          await kossi.etat.synchroniser();
        });
        expect(kossi.etat.accesCoupe, isTrue);
        expect(kossi.etat.appareilRetire, isFalse);
        // Nouveau QR code : même téléphone (pas de place prise en plus), et la
        // vente faite pendant la coupure arrive chez le patron.
        final texte = await qrDuPatron(tester, patron.etat);
        final cl = await tester.runAsync(() async {
          await kossi.etat.entrerParQr(texte);
          await patron.etat.synchroniser();
          return patron.etat.clients();
        });
        expect(kossi.journal.telephoneId, id);
        expect(kossi.etat.accesCoupe, isFalse);
        expect(cl!.map((c) => c.nom), contains('Client gardé'));
        final l = await tester.runAsync(patron.etat.mesAppareils);
        expect(l!.actifs.length, 2);
      },
    );

    testWidgets(
      'accord Google annulé ou relais pas prêt : message clair, rien de créé',
      (tester) async {
        final relais = FauxRelaisInvitations()..idWeb = null;
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          preparer: boutiquePatron,
        );
        await tester.runAsync(() async {
          await expectLater(
            patron.etat.preparerInvitation('Kossi'),
            throwsA(
              isA<ErreurZeroPerte>().having(
                (e) => e.message,
                'm',
                contains('Cloudflare'),
              ),
            ),
          );
        });
        expect(patron.etat.vendeurs, isEmpty);
        final p2 = await environnementDeTest(
          tester,
          relais: FauxRelaisInvitations(),
          accordGoogle: false,
          preparer: boutiquePatron,
        );
        await tester.runAsync(() async {
          await expectLater(
            p2.etat.preparerInvitation('Kossi'),
            throwsA(
              isA<ErreurZeroPerte>().having(
                (e) => e.message,
                'm',
                contains('annulé'),
              ),
            ),
          );
        });
        expect(p2.etat.vendeurs, isEmpty);
      },
    );
  });

  group('écrans', () {
    testWidgets(
      'patron : accueil → « Ajouter mon vendeur » → prénom → QR → ajouté',
      (tester) async {
        final relais = FauxRelaisInvitations();
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          preparer: boutiquePatron,
        );
        await afficherApp(tester, patron.etat);
        expect(
          find.byKey(const Key('bouton-ajouter-mon-vendeur')),
          findsOneWidget,
        );
        await toucher(
          tester,
          find.byKey(const Key('bouton-ajouter-mon-vendeur')),
        );
        await tester.enterText(
          find.byKey(const Key('champ-prenom-vendeur')),
          'Kossi',
        );
        await toucher(
          tester,
          find.byKey(const Key('bouton-continuer-vendeur')),
        );
        await attendre(tester, tours: 20);
        expect(find.byKey(const Key('qr-invitation')), findsOneWidget);
        expect(find.textContaining('une seule fois'), findsOneWidget);
        // Le vendeur prend le paquet : l'écran du patron le voit.
        relais.boites.clear();
        await tester.pump(const Duration(seconds: 3));
        await attendre(tester, tours: 6);
        expect(find.byKey(const Key('vendeur-ajoute')), findsOneWidget);
        await toucher(tester, find.byKey(const Key('bouton-vendeur-termine')));
      },
    );

    testWidgets(
      'patron : le QR code expire après 10 minutes, on peut en refaire un',
      (tester) async {
        var t = DateTime(2026, 11, 22, 10);
        final relais = FauxRelaisInvitations(horloge: () => t);
        final patron = await environnementDeTest(
          tester,
          relais: relais,
          preparer: boutiquePatron,
        );
        await afficherApp(tester, patron.etat);
        await tester.pumpWidget(
          MaterialApp(
            home: PageAjouterMonVendeur(etat: patron.etat, horloge: () => t),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('champ-prenom-vendeur')),
          'Kossi',
        );
        await toucher(
          tester,
          find.byKey(const Key('bouton-continuer-vendeur')),
        );
        await attendre(tester, tours: 20);
        expect(find.byKey(const Key('qr-invitation')), findsOneWidget);
        t = t.add(const Duration(minutes: 10, seconds: 2));
        await tester.pump(const Duration(seconds: 1));
        await attendre(tester);
        expect(find.byKey(const Key('bouton-refaire-qr')), findsOneWidget);
        await toucher(tester, find.byKey(const Key('bouton-refaire-qr')));
        await attendre(tester, tours: 10);
        expect(find.byKey(const Key('qr-invitation')), findsOneWidget);
        // Pas de nouvel accord Google : le même paquet, une nouvelle boîte.
        expect(relais.appels.where((a) => a == 'echange').length, 1);
      },
    );

    testWidgets(
      'vendeur : « Je suis vendeur » → scanner → bienvenue + code → entrée',
      (tester) async {
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
        await afficherApp(tester, kossi.etat);
        expect(find.byKey(const Key('bouton-je-suis-vendeur')), findsOneWidget);
        expect(
          find.byKey(const Key('bouton-retrouver-boutique')),
          findsNothing,
        );
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        await toucher(tester, find.byKey(const Key('bouton-scanner-qr')));
        await attendre(tester, tours: 30);
        expect(find.byKey(const Key('bienvenue-vendeur')), findsOneWidget);
        final code = tester
            .widget<Text>(find.byKey(const Key('code-vendeur-recu')))
            .data!
            .replaceAll(' ', '');
        await toucher(tester, find.byKey(const Key('bouton-code-retenu')));
        await attendre(tester, tours: 6);
        // Écran d'entrée : son code le fait entrer, il voit Vendre.
        await taperCode(tester, code);
        expect(find.byKey(const Key('bouton-vendre')), findsOneWidget);
        expect(
          find.byKey(const Key('bouton-ajouter-mon-vendeur')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'vendeur sans appareil photo : code de secours → OUI du patron',
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
        final pc = await tester.runAsync(() async {
          final p = await patron.etat.preparerInvitation('Kossi');
          return (p, await patron.etat.ouvrirCodeSecours(p));
        });
        await afficherApp(tester, kossi.etat);
        await toucher(tester, find.byKey(const Key('bouton-je-suis-vendeur')));
        // Pas de lecteur de QR sur ce téléphone : le code est demandé tout de suite.
        expect(find.byKey(const Key('champ-code-secours')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('champ-code-secours')),
          codeSecoursLisible(pc!.$2),
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
        expect(find.textContaining('Tecno Spark 7'), findsOneWidget);
        await tester.runAsync(() async {
          final d = await patron.etat.demandeRecue(pc.$1, pc.$2);
          await patron.etat.accepterDemande(pc.$1, pc.$2, d!);
        });
        await tester.pump(const Duration(seconds: 3));
        await attendre(tester, tours: 30);
        expect(find.byKey(const Key('bienvenue-vendeur')), findsOneWidget);
      },
    );

    testWidgets('Mes appareils : liste, Retirer, Couper tous', (tester) async {
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
      await afficherApp(tester, patron.etat);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-appareils')));
      await attendre(tester, tours: 10);
      expect(find.textContaining('2 appareil(s) sur 2'), findsOneWidget);
      expect(find.text('Téléphone de Kossi'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('bouton-couper-tous')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('bouton-couper-tous')), findsOneWidget);
      final prefixe = kossi.journal.prefixeRecu;
      await toucher(tester, find.byKey(Key('retirer-$prefixe')));
      await toucher(tester, find.byKey(const Key('confirmer-retrait')));
      await attendre(tester, tours: 12);
      expect(find.textContaining('1 appareil(s) sur 2'), findsOneWidget);
      expect(find.textContaining('1 appareil(s) retiré(s)'), findsOneWidget);
    });

    testWidgets('téléphone retiré : écran bloqué', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (e) async {
          await boutiqueInstallee(e);
          await e.journal.ecrireParametre('appareil.retire', '1');
        },
      );
      final etat = await tester.runAsync(
        () => EtatApplication.charger(
          journal: env.journal,
          services: env.etat.services,
        ),
      );
      await afficherApp(tester, etat!);
      expect(find.byKey(const Key('page-appareil-retire')), findsOneWidget);
    });
  });
}
