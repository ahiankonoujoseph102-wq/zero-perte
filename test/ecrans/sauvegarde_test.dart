import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/sauvegarde.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'tableau_test.dart' show journee;
import 'vendeurs_test.dart' show ouvrirEspacePatron;

/// Nouveau téléphone vide (base dans un fichier temporaire).
Future<EtatApplication> nouveauTelephone(EtatApplication modele) async {
  final dossier = Directory.systemTemp.createTempSync('zp_');
  final j = await JournalLocal.ouvrir(
    fabrique: databaseFactoryFfi,
    chemin: '${dossier.path}/zp.db',
  );
  return EtatApplication.charger(journal: j, services: modele.services);
}

void main() {
  group('chiffrement', () {
    final clair = utf8.encode('{"format":1,"operations":[]}');

    test('aller-retour avec le bon code', () async {
      final f = await chiffrerSauvegarde(clair, '482713');
      expect(f.sublist(0, 4), utf8.encode('ZPS2'));
      expect(utf8.decode(f, allowMalformed: true), isNot(contains('format')));
      expect(await dechiffrerSauvegarde(f, '482713'), clair);
    });

    test('un ancien fichier « ZPS1 » se lit toujours', () async {
      final f = await chiffrerSauvegarde(clair, '4827', format: 1);
      expect(f.sublist(0, 4), utf8.encode('ZPS1'));
      expect(await dechiffrerSauvegarde(f, '4827'), clair);
    });

    test('code faux → refus', () async {
      final f = await chiffrerSauvegarde(clair, '482713');
      expect(
        () => dechiffrerSauvegarde(f, '1111'),
        throwsA(isA<ErreurSauvegarde>()),
      );
    });

    test('un octet modifié → refus ; autre fichier → message clair', () async {
      final f = Uint8List.fromList(await chiffrerSauvegarde(clair, '482713'));
      f[f.length - 1] ^= 1;
      expect(
        () => dechiffrerSauvegarde(f, '482713'),
        throwsA(isA<ErreurSauvegarde>()),
      );
      expect(
        () => dechiffrerSauvegarde(utf8.encode('photo.jpg' * 10), '482713'),
        throwsA(
          isA<ErreurSauvegarde>().having(
            (e) => e.message,
            'message',
            contains('pas une sauvegarde'),
          ),
        ),
      );
    });
  });

  testWidgets(
    'sauvegarde puis restauration sur un téléphone neuf : tout revient, les reçus continuent',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await tester.runAsync(() async {
        final avant = env.etat;
        final fichier = await avant.creerSauvegarde('482713');

        final neuf = await nouveauTelephone(avant);
        expect(neuf.produits, isEmpty);
        // Mauvais code : rien n'est écrit.
        await expectLater(
          neuf.restaurerSauvegarde(fichier, '0000'),
          throwsA(isA<ErreurSauvegarde>()),
        );
        expect(await neuf.journal.nombreOperations(), 0);

        final n = await neuf.restaurerSauvegarde(fichier, '482713');
        expect(n, await avant.journal.nombreOperations());
        expect(neuf.config.nom, 'Boutique Mama Ama');
        expect(neuf.patron!.nom, 'Ama');
        final riz = neuf.produits.firstWhere((p) => p.nom == 'Riz');
        expect(neuf.stock(riz.id), 98000); // 100 kg − 2 kg
        expect(neuf.journal.telephoneId, avant.journal.telephoneId);
        expect(await neuf.journal.verifierMaChaine(), isEmpty);
        final caisse = await neuf.journal.caisseEnCours();
        expect(caisse[ModePaiement.especes]!.depenses, 1500);

        // La vente suivante continue la numérotation : A-000002.
        final v = await neuf.journal.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
          mode: ModePaiement.especes,
          montantRecu: 600,
          auteurId: neuf.auteurActuel,
        );
        expect(v.recu, 'A-000002');

        // Restaurer sur un téléphone qui a déjà des ventes : refusé.
        await expectLater(
          neuf.restaurerSauvegarde(fichier, '482713'),
          throwsA(isA<ErreurZeroPerte>()),
        );
      });
    },
  );

  testWidgets('sauvegarde modifiée (montant changé) : restauration refusée', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: journee);
    await tester.runAsync(() async {
      final json = utf8.decode(await env.journal.exporterJournal());
      expect(json, contains('"total\\":2000'));
      final triche = utf8.encode(
        json.replaceFirst('"total\\":2000', '"total\\":200'),
      );
      final neuf = await nouveauTelephone(env.etat);
      await expectLater(
        neuf.journal.restaurerJournal(triche),
        throwsA(
          isA<ErreurZeroPerte>().having(
            (e) => e.message,
            'message',
            contains('modifiée'),
          ),
        ),
      );
      expect(await neuf.journal.nombreOperations(), 0);
    });
  });

  testWidgets('écran Sauvegarde : code faux puis bon code → fichier envoyé', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: journee);
    await afficherApp(tester, env.etat);
    await ouvrirEspacePatron(tester);
    await toucher(tester, find.byKey(const Key('patron-sauvegarde')));
    await attendre(tester, tours: 8);
    await tester.scrollUntilVisible(
      find.byKey(const Key('derniere-sauvegarde')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aucune sauvegarde pour l\'instant.'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('bouton-creer-sauvegarde')));
    await taperPin(tester, '111111');
    expect(find.text('Code faux.'), findsOneWidget);
    await taperPin(tester, '482713');
    for (var i = 0; i < 10 && env.partages.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await attendre(tester);
    }
    await attendre(tester, tours: 10);
    expect(env.partages, hasLength(1));
    final (octets, nom) = env.partages.single;
    expect(utf8.decode(octets.sublist(0, 4)), 'ZPS2');
    expect(
      nom,
      matches(RegExp(r'^ZeroPerte-Boutique-Mama-Ama-\d{4}-\d\d-\d\d\.zps$')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('derniere-sauvegarde')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Dernière sauvegarde : le '), findsOneWidget);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('écran Sauvegarde sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-sauvegarde')));
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('bouton-creer-sauvegarde')));
      expect(tester.takeException(), isNull);
    });
  }
}
