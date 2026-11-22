import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/app/demo.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/ecrans/assistant/assistant_installation.dart';

import '../support/outils.dart';
import 'vente_test.dart' show ouvrirLaCaisseSiDemande;

String cheminDemo() =>
    '${Directory.systemTemp.createTempSync('zp_demo_').path}/demo.db';

Future<EtatApplication> demo(Environnement env, String chemin) async =>
    preparerDemo(
      fabrique: databaseFactoryFfi,
      chemin: chemin,
      services: env.etat.services,
    );

/// Ferme la visite guidée et laisse finir ses attentes.
Future<void> quitterVisite(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('visite-quitter')));
  await tester.pump(const Duration(seconds: 15));
  await attendre(tester, tours: 4);
}

void main() {
  testWidgets(
    'la démo est neuve à chaque ouverture et ne touche pas la vraie base',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      await tester.runAsync(() async {
        final chemin = cheminDemo();
        final d1 = await demo(env, chemin);
        expect(d1.estDemo, isTrue);
        expect(d1.installationTerminee, isTrue);
        expect(d1.config.nom, 'Boutique Démo');
        expect(d1.produits, hasLength(produitsDemo.length));
        final riz = d1.produits.firstWhere((p) => p.nom == 'Riz');
        expect(d1.stock(riz.id), 100000);
        final v = await d1.journal.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 2)],
          mode: ModePaiement.especes,
          montantRecu: 1200,
          auteurId: d1.auteurActuel,
        );
        expect(v.recu, 'D-000001'); // préfixe « D » : jamais confondu

        // Deuxième ouverture : tout est effacé et recréé.
        final d2 = await demo(env, chemin);
        final riz2 = d2.produits.firstWhere((p) => p.nom == 'Riz');
        expect(d2.stock(riz2.id), 100000);
        expect(await d2.ventesDuJour(), isEmpty);

        // Ni sauvegarde ni restauration en démo.
        await expectLater(
          d2.creerSauvegarde(codePatronDemo),
          throwsA(isA<ErreurZeroPerte>()),
        );

        // La vraie base du téléphone est restée vide, licence toujours absente.
        expect(await env.journal.nombreOperations(), 0);
        expect(env.etat.licence, isNull);
      });
    },
  );

  testWidgets(
    'activation → « Voir une démonstration » → vente → reçu « SANS VALEUR » → Quitter',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      final d = (await tester.runAsync(() => demo(env, cheminDemo())))!;
      await afficherApp(tester, env.etat, creerDemo: () async => d);
      expect(find.byType(AssistantInstallation), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton-demonstration')));
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('bandeau-demo')), findsOneWidget);
      expect(
        find.textContaining('Code du patron : $codePatronDemo'),
        findsOneWidget,
      );
      expect(find.byType(AccueilVendeur), findsOneWidget);
      // La visite guidée démarre seule : on la quitte pour essayer soi-même.
      await quitterVisite(tester);

      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await ouvrirLaCaisseSiDemande(tester);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-exact')));
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      await attendre(tester, tours: 8);
      await tester.scrollUntilVisible(
        find.byKey(const Key('recu-demo')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('DÉMONSTRATION — SANS VALEUR'), findsOneWidget);

      // Quitter : retour à l'étape « Code d'activation » de la vraie boutique.
      await toucher(tester, find.byKey(const Key('bouton-quitter-demo')));
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('bandeau-demo')), findsNothing);
      expect(find.byKey(const Key('bouton-coller-code')), findsOneWidget);
      expect(await tester.runAsync(env.journal.nombreOperations), 0);
    },
  );

  testWidgets('pas de tuile « Sauvegarde » dans l\'espace patron de la démo', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.activation,
    );
    final d = (await tester.runAsync(() => demo(env, cheminDemo())))!;
    await afficherApp(tester, d);
    await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
    expect(find.byKey(const Key('patron-chiffres')), findsOneWidget);
    expect(find.byKey(const Key('patron-sauvegarde')), findsNothing);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('démo sur ${e.key} : rien ne déborde', (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      final d = (await tester.runAsync(() => demo(env, cheminDemo())))!;
      await afficherApp(
        tester,
        env.etat,
        taille: taille,
        densite: densite,
        creerDemo: () async => d,
      );
      await toucher(tester, find.byKey(const Key('bouton-demonstration')));
      await attendre(tester, tours: 8);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('bandeau-demo')), findsOneWidget);
      // La visite guidée démarre seule ; on la ferme : « Visite » la relance.
      expect(find.byKey(const Key('visite-panneau')), findsOneWidget);
      await quitterVisite(tester);
      expect(find.byKey(const Key('bouton-relancer-visite')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
