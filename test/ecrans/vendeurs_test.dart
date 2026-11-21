import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/ecrans/connexion.dart';
import 'package:zero_perte/ecrans/patron/espace_patron.dart';

import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'vente_test.dart' show boutiqueAvecStock, ouvrirLaCaisseSiDemande;

Future<void> ouvrirEspacePatron(WidgetTester tester) async {
  // Le patron est entré avec son code : « Gestion » s'ouvre sans le redemander.
  // (On revient d'abord à l'accueil si une page est ouverte.)
  if (find.byKey(const Key('bouton-espace-patron')).evaluate().isEmpty) {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((r) => r.isFirst);
    await attendre(tester, tours: 4);
  }
  await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
  await attendre(tester, tours: 4);
  expect(find.byType(EspacePatron), findsOneWidget);
}

void main() {
  testWidgets(
    'le patron ajoute Kossi ; Kossi se connecte avec son code et vend : la vente porte son nom',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-vendeurs')));
      await toucher(tester, find.byKey(const Key('bouton-ajouter-vendeur')));
      await tester.enterText(
        find.byKey(const Key('champ-nom-vendeur')),
        'Kossi',
      );
      // Le code n'est pas choisi : l'application le tire au hasard et le
      // montre une seule fois au patron.
      await toucher(tester, find.byKey(const Key('bouton-creer-code')));
      await attendre(tester, tours: 10);
      final code = tester
          .widget<Text>(find.byKey(const Key('code-vendeur-cree')))
          .data!
          .replaceAll(' ', '');
      expect(code, matches(RegExp(r'^\d{4}$')));
      await toucher(tester, find.byKey(const Key('bouton-code-note')));
      expect(find.textContaining('Kossi est ajouté'), findsOneWidget);
      expect(find.text('Peut vendre'), findsOneWidget);

      // Retour à l'accueil, puis « Changer d'utilisateur ».
      await tester.pageBack();
      await attendre(tester);
      await tester.pageBack();
      await attendre(tester);
      await toucher(
        tester,
        find.byKey(const Key('bouton-changer-utilisateur')),
      );
      // Écran d'entrée : on tape son code, il reconnaît la personne.
      expect(find.byType(PageConnexion), findsOneWidget);
      expect(find.text('Tapez votre code'), findsOneWidget);
      final faux = code == '4827' ? '4829' : '4827';
      await taperCode(tester, faux); // aucun code ne correspond
      expect(find.textContaining('Code faux'), findsOneWidget);
      await taperCode(tester, code);
      expect(find.byType(AccueilVendeur), findsOneWidget);
      expect(find.text('Kossi'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await ouvrirLaCaisseSiDemande(tester);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-exact')));
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      final ops = await tester.runAsync(
        () => env.journal.operationsDuTelephone(env.journal.telephoneId),
      );
      final vente = ops!.lastWhere((o) => o.type == TypeOperation.vente);
      expect(vente.auteurId, env.etat.vendeurs.single.id);
    },
  );

  testWidgets(
    'vendeur bloqué : il ne peut plus se connecter ; débloqué : il peut',
    (tester) async {
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
      await toucher(tester, find.byKey(const Key('bloquer-Kossi')));
      expect(find.text('Bloqué'), findsOneWidget);

      env.etat.deconnecter();
      await tester.pageBack();
      await attendre(tester);
      await tester.pageBack();
      await attendre(tester);
      expect(find.byType(PageConnexion), findsOneWidget);
      await taperCode(tester, '5913');
      expect(find.textContaining('bloqué'), findsWidgets);
      expect(find.byType(AccueilVendeur), findsNothing);

      await tester.runAsync(
        () => env.etat.bloquer(env.etat.vendeurs.single, bloque: false),
      );
      await attendre(tester);
      await taperCode(tester, '5913');
      expect(find.byType(AccueilVendeur), findsOneWidget);
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('écran d\'entrée (code) sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.ajouterVendeur(nom: 'Afi', pin: '6024');
          etat.deconnecter();
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      expect(find.byType(PageConnexion), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'deux personnes ne peuvent pas avoir le même code ; 5 codes faux → bloqué',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
        },
      );
      await tester.runAsync(() async {
        await expectLater(
          env.etat.ajouterVendeur(nom: 'Afi', pin: '5913'),
          throwsA(isA<ErreurZeroPerte>()),
        );
        env.etat.deconnecter();
        expect((await env.etat.connecterParCode('482713'))!.nom, 'Ama');
        env.etat.deconnecter();
        for (var i = 0; i < 5; i++) {
          expect(await env.etat.connecterParCode('1111'), isNull);
        }
        expect(await env.etat.entreeBloqueeJusqua(), isNotNull);
        // Même le bon code est refusé pendant le blocage.
        expect(await env.etat.connecterParCode('5913'), isNull);
      });
    },
  );
}
