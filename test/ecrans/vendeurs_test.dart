import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/ecrans/connexion.dart';
import 'package:zero_perte/ecrans/patron/espace_patron.dart';

import '../support/outils.dart';
import 'vente_test.dart' show boutiqueAvecStock;

Future<void> ouvrirEspacePatron(WidgetTester tester) async {
  await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
  await taperPin(tester, '4827');
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
      await taperPin(tester, '5913');
      await taperPin(tester, '5913');
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
      expect(find.byType(PageConnexion), findsOneWidget);
      expect(find.text('Ama'), findsOneWidget);
      expect(find.text('Kossi'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('connexion-Kossi')));
      await taperPin(
        tester,
        '4827',
      ); // le code du patron ne marche pas pour Kossi
      expect(find.textContaining('Code faux'), findsOneWidget);
      await taperPin(tester, '5913');
      expect(find.byType(AccueilVendeur), findsOneWidget);
      expect(find.text('Kossi'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton-vendre')));
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
      await toucher(tester, find.byKey(const Key('connexion-Kossi')));
      expect(find.textContaining('bloqué'), findsWidgets);
      expect(find.byType(AccueilVendeur), findsNothing);

      await tester.runAsync(
        () => env.etat.bloquer(env.etat.vendeurs.single, bloque: false),
      );
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('connexion-Kossi')));
      await taperPin(tester, '5913');
      expect(find.byType(AccueilVendeur), findsOneWidget);
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('écran « Qui êtes-vous ? » sur ${e.key} : rien ne déborde', (
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
}
