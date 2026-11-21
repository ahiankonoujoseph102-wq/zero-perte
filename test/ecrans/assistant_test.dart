import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/verification_telephone.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/services/aide.dart';
import 'package:zero_perte/services/telephone.dart';

import '../domaine/licence_test.dart' show codeLicence, codeExtension;
import '../support/outils.dart';

const sansGoogle = InfosTelephone(
  androidSdk: 29,
  androidVersion: '10',
  fabricant: 'HUAWEI',
  modele: 'P40 lite',
  servicesGoogle: false,
  espaceLibreMo: 5000,
);

void main() {
  group('Contrôles du téléphone (calculs)', () {
    test('téléphone compatible : tout est vert', () {
      final c = evaluerTelephone(telephoneCompatible, voixFrancaise: true);
      expect(c.every((x) => x.niveau == NiveauControle.ok), isTrue);
      expect(peutContinuer(c), isTrue);
    });
    test('sans services Google : bloquant', () {
      final c = evaluerTelephone(sansGoogle, voixFrancaise: true);
      expect(
        c.firstWhere((x) => x.cle == 'google').niveau,
        NiveauControle.bloquant,
      );
      expect(peutContinuer(c), isFalse);
    });
    test('place : 80 Mo bloquant, 250 Mo attention, 400 Mo ok', () {
      NiveauControle niveau(int mo) => evaluerTelephone(
        InfosTelephone(
          androidSdk: 30,
          androidVersion: '11',
          fabricant: 'x',
          modele: 'y',
          servicesGoogle: true,
          espaceLibreMo: mo,
        ),
        voixFrancaise: true,
      ).firstWhere((x) => x.cle == 'espace').niveau;
      expect(niveau(80), NiveauControle.bloquant);
      expect(niveau(250), NiveauControle.attention);
      expect(niveau(400), NiveauControle.ok);
    });
    test('pas de voix française : avertissement, mais on peut continuer', () {
      final c = evaluerTelephone(telephoneCompatible, voixFrancaise: false);
      expect(
        c.firstWhere((x) => x.cle == 'voix').niveau,
        NiveauControle.attention,
      );
      expect(peutContinuer(c), isTrue);
    });
    test('lien WhatsApp vers l\'assistance, message encodé', () {
      final u = lienWhatsApp('+228 72 24 02 31', 'Étape : verification');
      expect(u.toString(), startsWith('https://wa.me/22872240231?text='));
      expect(Uri.decodeComponent(u.query.substring(5)), 'Étape : verification');
    });
  });

  testWidgets('parcours : bienvenue → vérification → accueil', (tester) async {
    final env = await environnementDeTest();
    await afficherApp(tester, env.etat);
    expect(find.text('Bienvenue dans Zéro Perte'), findsOneWidget);
    expect(env.voix.phrases.first, startsWith('Bienvenue dans Zéro Perte'));

    await tester.tap(find.byKey(const Key('bouton-commencer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('verification-ok')), findsOneWidget);
    expect(find.byKey(const Key('controle-google-ok')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bouton-continuer')));
    await tester.pumpAndSettle();
    expect(env.etat.etape, EtapeAssistant.activation);
    expect(find.byKey(const Key('bouton-coller-code')), findsOneWidget);
  });

  group('Activation', () {
    testWidgets('message WhatsApp copié → boutique activée → accueil', (
      tester,
    ) async {
      final env = await environnementDeTest(etape: EtapeAssistant.activation);
      env.pressePapiers.texte =
          'Bonjour, voici votre code :\n$codeLicence\nMerci';
      await afficherApp(tester, env.etat);
      await tester.tap(find.byKey(const Key('bouton-coller-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activation-reussie')), findsOneWidget);
      expect(find.textContaining('Boutique Mama Ama'), findsOneWidget);
      expect(find.textContaining('2 téléphones'), findsOneWidget);
      expect(env.voix.phrases.last, contains('Code accepté'));

      await tester.tap(find.byKey(const Key('bouton-continuer')));
      await tester.pumpAndSettle();
      expect(find.byType(AccueilVendeur), findsOneWidget);
    });

    testWidgets('code faux : message rouge, on reste bloqué', (tester) async {
      final env = await environnementDeTest(etape: EtapeAssistant.activation);
      env.pressePapiers.texte = codeLicence.replaceRange(20, 21, 'X');
      await afficherApp(tester, env.etat);
      await tester.tap(find.byKey(const Key('bouton-coller-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activation-erreur')), findsOneWidget);
      expect(env.etat.licence, isNull);
      expect(find.byKey(const Key('bouton-continuer')), findsNothing);
    });

    testWidgets('rien de copié : message clair', (tester) async {
      final env = await environnementDeTest(etape: EtapeAssistant.activation);
      await afficherApp(tester, env.etat);
      await tester.tap(find.byKey(const Key('bouton-coller-code')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucun code Zéro Perte'), findsOneWidget);
    });

    testWidgets('extension « téléphone en plus » sans licence : refusée', (
      tester,
    ) async {
      final env = await environnementDeTest(etape: EtapeAssistant.activation);
      env.pressePapiers.texte = codeExtension;
      await afficherApp(tester, env.etat);
      await tester.tap(find.byKey(const Key('bouton-coller-code')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Activez d\'abord la licence'),
        findsOneWidget,
      );
    });

    testWidgets(
      'version sans clé publique : activation impossible, message clair',
      (tester) async {
        final env = await environnementDeTest(
          etape: EtapeAssistant.activation,
          clePublique: 'ABSENTE',
        );
        env.pressePapiers.texte = codeLicence;
        await afficherApp(tester, env.etat);
        await tester.tap(find.byKey(const Key('bouton-coller-code')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('ne peut pas encore vérifier'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets(
    'téléphone sans services Google : bloqué, aide WhatsApp proposée',
    (tester) async {
      final env = await environnementDeTest(
        etape: EtapeAssistant.verification,
        telephone: sansGoogle,
      );
      await afficherApp(tester, env.etat);
      expect(find.byKey(const Key('verification-bloquee')), findsOneWidget);
      expect(find.byKey(const Key('controle-google-bloquant')), findsOneWidget);
      expect(find.text('Demander de l\'aide'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bouton-continuer')));
      await tester.pumpAndSettle();
      expect(find.text('Besoin d\'aide ?'), findsOneWidget);
      for (final n in numerosAssistance) {
        expect(find.byKey(Key('aide-$n')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('aide-+228 79 16 23 90')));
      await tester.pumpAndSettle();
      expect(
        env.liens.single.toString(),
        startsWith('https://wa.me/22879162390?text='),
      );
      expect(
        Uri.decodeComponent(env.liens.single.query),
        contains('HUAWEI P40 lite'),
      );
      // On reste bloqué : l'installation n'est pas terminée.
      expect(env.etat.installationTerminee, isFalse);
    },
  );

  testWidgets('reprise : l\'assistant repart à l\'étape mémorisée', (
    tester,
  ) async {
    final env = await environnementDeTest(etape: EtapeAssistant.verification);
    await afficherApp(tester, env.etat);
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
    expect(
      await env.etat.reglages.lireParametre('assistant.etape'),
      'verification',
    );
  });

  testWidgets('bouton « Écouter » : relit la consigne', (tester) async {
    final env = await environnementDeTest();
    await afficherApp(tester, env.etat);
    await tester.tap(find.byKey(const Key('bouton-ecouter')));
    await tester.pump();
    expect(env.voix.phrases.length, 2);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    for (final etape in [
      EtapeAssistant.bienvenue,
      EtapeAssistant.verification,
    ]) {
      testWidgets(
        'assistant « ${etape.name} » sur ${e.key} (texte ×1,5) : rien ne déborde',
        (tester) async {
          final env = await environnementDeTest(
            etape: etape,
            voixFrancaise: false,
          );
          await afficherApp(
            tester,
            env.etat,
            taille: taille,
            densite: densite,
            texte: 1.5,
          );
          expect(tester.takeException(), isNull);
          for (final cle in ['bouton-aide', 'bouton-ecouter']) {
            final r = tester.getRect(find.byKey(Key(cle)));
            expect(
              r.bottom <= taille.height && r.top >= 0,
              isTrue,
              reason: cle,
            );
          }
        },
      );
    }
  }
}
