import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/domaine/utilisateurs.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/ecrans/code_patron.dart';

import '../support/outils.dart';

/// Boutique installée AVANT la version 0.17 : patron avec un code de 4 chiffres.
Future<void> ancienneBoutique(EtatApplication etat) async {
  await boutiqueInstallee(etat);
  final p = etat.patron!;
  final sel = nouveauSel();
  // Ancien enregistrement : ni « longueur » ni « tours » (20 000 tours).
  await etat.journal.definirUtilisateur(
    Utilisateur(
      id: p.id,
      nom: p.nom,
      role: Role.patron,
      sel: sel,
      hachage: await hacherPin('4827', sel),
    ),
    auteurId: p.id,
  );
  await etat.rechargerTout();
  etat.deconnecter();
}

void main() {
  test('codes trop faciles refusés, 6 chiffres pour le patron', () {
    expect(problemePin('482713', longueur: 6), isNull);
    for (final c in ['123456', '654321', '111111', '121212', '000000']) {
      expect(problemePin(c, longueur: 6), isNotNull, reason: c);
    }
    expect(problemePin('4827', longueur: 6), 'Le code doit avoir 6 chiffres.');
    expect(problemePin('4827'), isNull); // vendeur : 4 chiffres
  });

  test('ancien enregistrement lu comme 4 chiffres / 20 000 tours', () {
    final u = Utilisateur.depuisDonnees({
      'utilisateur': 'u1',
      'nom': 'Ama',
      'role': 'patron',
      'sel': 'AAAA',
      'hachage': 'BBBB',
    });
    expect(u.longueurCode, 4);
    expect(u.tours, 20000);
    expect(u.doitPasserA6Chiffres, isTrue);
  });

  testWidgets(
    'patron installé avant 0.17 : code actuel 4827 → nouveau 6 chiffres, une seule fois',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: ancienneBoutique);
      await afficherApp(tester, env.etat);
      expect(find.byType(PageNouveauCodePatron), findsOneWidget);

      await taperPin(tester, '1111'); // code actuel faux
      expect(find.text('Code faux.'), findsOneWidget);
      await taperPin(tester, '4827'); // code actuel bon
      await taperPin(tester, '123456'); // trop facile
      expect(find.byKey(const Key('pin-erreur')), findsOneWidget);
      await taperPin(tester, '730518');
      await taperPin(tester, '730518');
      await attendre(tester, tours: 20);

      expect(find.byType(PageNouveauCodePatron), findsNothing);
      expect(find.byType(AccueilVendeur), findsOneWidget);
      final p = env.etat.patron!;
      expect(p.longueurCode, 6);
      expect(p.tours, toursPinPatron);
      expect(await tester.runAsync(() => pinCorrect(p, '730518')), isTrue);
      expect(await tester.runAsync(() => pinCorrect(p, '4827')), isFalse);
      // Le code n'apparaît nulle part dans le journal.
      final ops = (await tester.runAsync(
        () => env.journal.operationsDuTelephone(env.journal.telephoneId),
      ))!;
      expect(
        ops
            .where((o) => o.type == TypeOperation.utilisateurDefini)
            .every((o) => !jsonEncode(o.donnees).contains('730518')),
        isTrue,
      );
    },
  );

  testWidgets(
    'nouvelle installation : le patron a déjà 6 chiffres, pas d\'écran',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      expect(env.etat.patron!.longueurCode, 6);
      await afficherApp(tester, env.etat);
      expect(find.byType(PageNouveauCodePatron), findsNothing);
    },
  );

  testWidgets('sauvegarde : 6 chiffres, refusée avec un mauvais code', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueInstallee);
    await tester.runAsync(() async {
      final f = await env.etat.creerSauvegarde('482713');
      expect(utf8.decode(f.sublist(0, 4)), 'ZPS2');
    });
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('écran nouveau code sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(tester, preparer: ancienneBoutique);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      expect(tester.takeException(), isNull);
      await taperPin(tester, '4827');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pin-points')), findsOneWidget);
    });
  }

  testWidgets(
    'carnet : le vendeur ajoute, ne peut ni modifier, ni supprimer, ni exporter',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueInstallee(etat);
          await etat.enregistrerClient(
            nom: 'Afi',
            telephone: '91223344',
            quartier: 'Bè',
            email: 'afi@exemple.tg',
          );
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.verifierPin(etat.vendeurs.first, '5913');
        },
      );
      await tester.runAsync(() async {
        final afi = (await env.etat.clients()).single;
        expect(afi.quartier, 'Bè');
        expect(afi.email, 'afi@exemple.tg');
        await expectLater(
          env.etat.enregistrerClient(existant: afi, nom: 'Afi M.'),
          throwsA(isA<ErreurZeroPerte>()),
        );
        await expectLater(
          env.etat.supprimerClient(afi),
          throwsA(isA<ErreurZeroPerte>()),
        );
        await expectLater(
          env.etat.exporterClientsCsv(),
          throwsA(isA<ErreurZeroPerte>()),
        );
        // Le vendeur peut ajouter un client sans téléphone…
        await env.etat.enregistrerClient(nom: 'Yao');
        // … mais pas lui faire crédit.
        final yao = (await env.etat.clients()).firstWhere(
          (c) => c.nom == 'Yao',
        );
        final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
        await expectLater(
          env.journal.enregistrerVente(
            lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
            mode: ModePaiement.credit,
            clientId: yao.id,
            auteurId: env.etat.auteurActuel,
          ),
          throwsA(
            isA<ErreurZeroPerte>().having(
              (e) => e.message,
              'message',
              'Ajoutez le téléphone de Yao pour lui faire crédit.',
            ),
          ),
        );
      });
      await afficherApp(tester, env.etat);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('bouton-exporter-clients')), findsNothing);
      await toucher(tester, find.byKey(const Key('client-Afi')));
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('bouton-modifier-client')), findsNothing);
      expect(find.byKey(const Key('bouton-supprimer-client')), findsNothing);
    },
  );

  testWidgets('carnet : le patron cherche par téléphone, exporte, supprime', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueInstallee(etat);
        await etat.enregistrerClient(nom: 'Afi', telephone: '91223344');
        await etat.enregistrerClient(
          nom: 'Kofi "le grand"',
          telephone: '90112233',
          quartier: 'Bè',
        );
      },
    );
    await afficherApp(tester, env.etat);
    await toucher(tester, find.byKey(const Key('bouton-credit')));
    await attendre(tester, tours: 8);
    await tester.enterText(find.byKey(const Key('recherche-client')), '90 11');
    await attendre(tester);
    expect(find.byKey(const Key('client-Kofi "le grand"')), findsOneWidget);
    expect(find.byKey(const Key('client-Afi')), findsNothing);

    await toucher(tester, find.byKey(const Key('bouton-exporter-clients')));
    for (var i = 0; i < 6 && env.partages.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await attendre(tester);
    }
    final (octets, nom) = env.partages.single;
    expect(nom, 'clients.csv');
    final csv = utf8.decode(octets.sublist(3));
    expect(
      csv,
      startsWith('nom;telephone;quartier;email;doit (F);plafond (F)'),
    );
    expect(
      csv,
      contains('"Kofi ""le grand""";"+228 90 11 22 33";"Bè";"";0;5000'),
    );

    await tester.enterText(find.byKey(const Key('recherche-client')), '');
    await attendre(tester);
    await toucher(tester, find.byKey(const Key('client-Afi')));
    await attendre(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('bouton-supprimer-client')));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    await attendre(tester, tours: 10);
    expect(find.byKey(const Key('client-Afi')), findsNothing);
    expect((await tester.runAsync(env.etat.clients))!.map((c) => c.nom), [
      'Kofi "le grand"',
    ]);
  });
}
