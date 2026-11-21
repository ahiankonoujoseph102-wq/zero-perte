// Sécurité de l'écran d'entrée : le code seul reconnaît la personne.
// - Les codes des vendeurs sont tirés au hasard par l'application : personne
//   ne choisit un code, donc personne ne peut apprendre qu'un code « est déjà
//   pris » par quelqu'un d'autre.
// - 5 codes faux → écran bloqué 5 minutes + alerte « codes faux » au patron.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/utilisateurs.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/ecrans/connexion.dart';

import '../support/outils.dart';
import 'synchronisation_test.dart' show FauxRelais;
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

/// « Hasard » prévisible : renvoie les nombres donnés, dans l'ordre.
class HasardFixe implements Random {
  HasardFixe(this.suite);
  final List<int> suite;
  int _i = 0;
  @override
  int nextInt(int max) => suite[_i++ % suite.length] % max;
  @override
  double nextDouble() => 0.5;
  @override
  bool nextBool() => false;
}

/// Lit le code affiché une seule fois au patron.
String codeAffiche(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('code-vendeur-cree')))
    .data!
    .replaceAll(' ', '');

void main() {
  testWidgets(
    'tirage : un code déjà pris ou trop facile est sauté sans rien dire',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
        },
      );
      await tester.runAsync(() async {
        // 5913 = code de Kossi, 1111 = trop facile, 0042 = libre.
        final code = await env.etat.tirerCodeVendeur(
          hasard: HasardFixe([5913, 1111, 42]),
        );
        expect(code, '0042');
        // 30 tirages réels : 4 chiffres, jamais facile, jamais celui de Kossi.
        for (var i = 0; i < 30; i++) {
          final c = await env.etat.tirerCodeVendeur();
          expect(c, matches(RegExp(r'^\d{4}$')));
          expect(problemePin(c), isNull);
          expect(c, isNot('5913'));
        }
      });
    },
  );

  testWidgets(
    'un code déjà pris : le message ne dit jamais qu\'il est à quelqu\'un',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
        },
      );
      await tester.runAsync(() async {
        try {
          await env.etat.ajouterVendeur(nom: 'Afi', pin: '5913');
          fail('le code de Kossi ne doit pas être accepté');
        } on ErreurZeroPerte catch (e) {
          expect(e.message, isNot(contains('Kossi')));
          expect(e.message, isNot(contains('autre personne')));
          expect(e.message, isNot(contains('déjà')));
        }
      });
    },
  );

  testWidgets('le patron ajoute Afi puis change le code de Kossi : codes tirés au hasard, '
      'l\'ancien code ne marche plus', (tester) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
      },
    );
    await afficherApp(tester, env.etat);
    await ouvrirEspacePatron(tester);
    await toucher(tester, find.byKey(const Key('patron-vendeurs')));

    // Ajout d'Afi : aucun clavier de code, seulement le prénom.
    await toucher(tester, find.byKey(const Key('bouton-ajouter-vendeur')));
    expect(find.textContaining('Code du vendeur'), findsNothing);
    // Sans prénom : refusé.
    await toucher(tester, find.byKey(const Key('bouton-creer-code')));
    expect(find.byKey(const Key('erreur-vendeur')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('champ-nom-vendeur')), 'Afi');
    await toucher(tester, find.byKey(const Key('bouton-creer-code')));
    await attendre(tester, tours: 10);
    final codeAfi = codeAffiche(tester);
    expect(codeAfi, isNot('5913'));
    expect(
      find.textContaining('Il ne sera plus jamais affiché'),
      findsOneWidget,
    );
    await toucher(tester, find.byKey(const Key('bouton-code-note')));
    expect(env.etat.vendeurs.map((v) => v.nom), containsAll(['Kossi', 'Afi']));

    // Nouveau code pour Kossi (on laisse d'abord partir le message).
    await tester.pump(const Duration(seconds: 6));
    await attendre(tester);
    await toucher(tester, find.byKey(const Key('changer-code-Kossi')));
    expect(find.text('Code de Kossi'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('bouton-creer-code')));
    await attendre(tester, tours: 20);
    final codeKossi = codeAffiche(tester);
    expect(codeKossi, isNot(codeAfi));
    await toucher(tester, find.byKey(const Key('bouton-code-note')));

    await tester.runAsync(() async {
      env.etat.deconnecter();
      expect(await env.etat.connecterParCode('5913'), isNull);
      expect((await env.etat.connecterParCode(codeKossi))!.nom, 'Kossi');
      env.etat.deconnecter();
      expect((await env.etat.connecterParCode(codeAfi))!.nom, 'Afi');
    });
  });

  testWidgets(
    '5 codes faux à l\'écran d\'entrée : bloqué 5 minutes, même le bon code ; '
    'le patron reçoit l\'alerte « codes faux »',
    (tester) async {
      final relais = FauxRelais();
      var heure = DateTime(2026, 11, 21, 10, 0);
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.journal.ecrireParametre('relais.jeton', 'jeton-test');
          etat.transportAlertes = relais;
          etat.maintenant = () => heure;
          etat.deconnecter();
        },
      );
      await afficherApp(tester, env.etat);
      expect(find.byType(PageConnexion), findsOneWidget);

      for (var i = 1; i <= 4; i++) {
        await taperCode(tester, '2468');
        expect(find.textContaining('Code faux'), findsOneWidget);
        expect(find.textContaining('Encore ${5 - i} essai'), findsOneWidget);
      }
      expect(relais.recues, isEmpty);
      await taperCode(tester, '2468'); // 5e code faux
      expect(find.textContaining('Trop de codes faux'), findsOneWidget);
      expect(find.textContaining('10:05'), findsOneWidget);
      expect(env.voix.phrases.last, 'Trop de codes faux.');

      // L'alerte part vers le patron.
      expect(relais.recues, hasLength(1));
      final alerte = relais.recues.single.$2;
      expect(alerte.type, 'code');
      expect(alerte.message, contains('5 codes faux'));

      // Pendant le blocage, même le bon code est refusé.
      await taperCode(tester, '5913');
      expect(find.byType(AccueilVendeur), findsNothing);
      expect(find.textContaining('Trop de codes faux'), findsOneWidget);

      // 6 minutes plus tard : le bon code passe.
      heure = heure.add(const Duration(minutes: 6));
      await taperCode(tester, '5913');
      expect(find.byType(AccueilVendeur), findsOneWidget);

      // Sur le téléphone du patron : l'alerte arrive (bandeau + voix).
      final patron = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.journal.ecrireParametre('relais.jeton', 'jeton-test');
          etat.transportAlertes = relais;
          await etat.releverAlertes();
        },
      );
      expect(patron.etat.alertes.single.message, contains('5 codes faux'));
      expect(patron.voix.phrases.last, startsWith('Alerte. 5 codes faux'));
    },
  );

  testWidgets(
    'fermer et rouvrir l\'application ne remet pas le compte des codes faux à zéro',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          etat.deconnecter();
        },
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          expect(await env.etat.connecterParCode('2468'), isNull);
        }
        // « Nouvelle ouverture » : un nouvel état sur la même base.
        final rouvert = await EtatApplication.charger(
          journal: env.journal,
          services: env.etat.services,
        );
        expect(await rouvert.connecterParCode('2468'), isNull);
        expect(await rouvert.entreeBloqueeJusqua(), isNull);
        expect(await rouvert.connecterParCode('2468'), isNull);
        expect(await rouvert.entreeBloqueeJusqua(), isNotNull);
      });
    },
  );

  testWidgets('un bon code remet le compte des codes faux à zéro', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
        etat.deconnecter();
      },
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await env.etat.connecterParCode('2468');
      }
      expect((await env.etat.connecterParCode('5913'))!.nom, 'Kossi');
      env.etat.deconnecter();
      for (var i = 0; i < 4; i++) {
        await env.etat.connecterParCode('2468');
      }
      expect(await env.etat.entreeBloqueeJusqua(), isNull);
    });
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('code du vendeur créé sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-vendeurs')));
      await toucher(tester, find.byKey(const Key('bouton-ajouter-vendeur')));
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const Key('champ-nom-vendeur')),
        'Kossi',
      );
      await toucher(tester, find.byKey(const Key('bouton-creer-code')));
      await attendre(tester, tours: 10);
      expect(find.byKey(const Key('code-vendeur-cree')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
