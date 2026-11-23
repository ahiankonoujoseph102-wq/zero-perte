// Installation : « Retour » à chaque étape (sauf la première), geste retour
// d'Android, activation jamais annulée, ce qui est rempli est gardé ; logo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/ecrans/logo_zero_perte.dart';

import '../domaine/licence_test.dart' show codeLicence;
import '../support/outils.dart';

Future<Environnement> activee(WidgetTester tester) async {
  final env = await environnementDeTest(
    tester,
    etape: EtapeAssistant.activation,
  );
  env.pressePapiers.texte = 'Voici votre code :\n$codeLicence\nMerci';
  await afficherApp(tester, env.etat);
  await toucher(tester, find.byKey(const Key('bouton-coller-code')));
  await attendre(tester, tours: 6);
  expect(find.byKey(const Key('activation-reussie')), findsOneWidget);
  return env;
}

void main() {
  testWidgets(
    'Retour : nom (étape 1) → activation (toujours activée) → bienvenue',
    (tester) async {
      final env = await activee(tester);
      expect(
        find.textContaining('2 appareils (téléphone, tablette ou PC)'),
        findsOneWidget,
      );
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.etape, EtapeAssistant.identite);

      await toucher(tester, find.byKey(const Key('bouton-etape-precedente')));
      expect(env.etat.etape, EtapeAssistant.activation);
      expect(find.byKey(const Key('activation-reussie')), findsOneWidget);
      expect(env.etat.licence, isNotNull); // l'activation n'est pas annulée

      // La vérification du téléphone (qui passe seule) est sautée.
      await toucher(tester, find.byKey(const Key('bouton-etape-precedente')));
      expect(env.etat.etape, EtapeAssistant.bienvenue);
      expect(find.byKey(const Key('bouton-etape-precedente')), findsNothing);
      expect(env.etat.licence, isNotNull);

      // « Commencer » : on repasse (vérification refaite) et on retrouve
      // l'activation déjà faite.
      await toucher(tester, find.byKey(const Key('bouton-commencer')));
      await attendre(tester, tours: 8);
      expect(env.etat.etape, EtapeAssistant.activation);
      expect(find.byKey(const Key('activation-reussie')), findsOneWidget);
    },
  );

  testWidgets('geste « retour » d\'Android = étape précédente', (tester) async {
    final env = await activee(tester);
    await toucher(tester, find.byKey(const Key('bouton-continuer')));
    expect(env.etat.etape, EtapeAssistant.identite);
    await tester.binding.handlePopRoute();
    await attendre(tester, tours: 4);
    expect(env.etat.etape, EtapeAssistant.activation);
    expect(env.etat.licence, isNotNull);
  });

  testWidgets('ce qui a été rempli est gardé quand on revient', (tester) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.profil,
      preparer: (etat) => etat.enregistrerConfig(
        etat.config.copie(nom: 'Boutique Afi', types: ['alimentation']),
      ),
    );
    await afficherApp(tester, env.etat);
    await toucher(tester, find.byKey(const Key('bouton-etape-precedente')));
    expect(env.etat.etape, EtapeAssistant.identite);
    expect(find.text('Boutique Afi'), findsWidgets);
  });

  testWidgets('le logo Zéro Perte est en haut de l\'installation', (
    tester,
  ) async {
    final env = await environnementDeTest(tester);
    await afficherApp(tester, env.etat);
    expect(find.byType(LogoZeroPerte), findsOneWidget);
    expect(find.text('ZP'), findsNothing);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('en-tête avec « Retour » sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      for (final t in [1.0, 1.5]) {
        await afficherApp(
          tester,
          env.etat,
          taille: taille,
          densite: densite,
          texte: t,
        );
        expect(
          find.byKey(const Key('bouton-etape-precedente')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
