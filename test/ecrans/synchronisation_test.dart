import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/synchro/relais.dart';
import 'package:zero_perte/synchro/synchro.dart';

import '../support/outils.dart';
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

/// Relais simulé (comme relais/worker.js) : une liste partagée.
class FauxRelais implements TransportAlertes {
  final List<(String, Alerte)> recues = [];

  @override
  Future<void> envoyer(String jeton, Alerte alerte) async =>
      recues.add((jeton, alerte));

  @override
  Future<List<Alerte>> relever(String jeton, int depuis) async => [
    for (final (j, a) in recues)
      if (j == jeton && a.heure > depuis) a,
  ];
}

void main() {
  testWidgets(
    'patron : « Appareils et Drive » → connecter → le Drive reçoit la boutique',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-synchro')));
      await attendre(tester, tours: 6);
      expect(find.text('Pas encore connecté'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-connecter-drive')));
      await attendre(tester, tours: 15);
      expect(find.text('boutique.ama@gmail.com'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('(celui-ci)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('(celui-ci)'), findsOneWidget);
      expect(find.byKey(const Key('derniere-synchro')), findsOneWidget);
      expect(
        env.drive.fichiers.keys.where((n) => n.startsWith('ops-')),
        isNotEmpty,
      );
      expect(env.drive.fichiers.keys, contains('boutique.json'));
    },
  );

  testWidgets(
    'téléphone neuf : « J\'ai déjà une boutique » → Drive → appareil en plus → accueil',
    (tester) async {
      // Le patron a déjà synchronisé sa boutique.
      final ancien = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.connecterSynchro();
          await etat.synchroniser();
        },
      );
      final neuf = await environnementDeTest(tester, drive: ancien.drive);
      await afficherApp(tester, neuf.etat);
      await toucher(tester, find.byKey(const Key('bouton-retrouver-boutique')));
      await toucher(tester, find.byKey(const Key('retrouver-drive')));
      await attendre(tester, tours: 10);
      expect(find.byKey(const Key('remplacer-A')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('nouvel-appareil')));
      await attendre(tester, tours: 20);

      expect(neuf.etat.installationTerminee, isTrue);
      expect(neuf.etat.config.nom, 'Boutique Mama Ama');
      final riz = neuf.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(neuf.etat.stock(riz.id), 100000);
      expect(neuf.journal.prefixeRecu, 'B'); // 2e appareil : reçus « B »
      expect(find.byType(AccueilVendeur), findsNothing); // connexion d'abord
    },
  );

  testWidgets(
    'téléphone neuf : depuis un fichier .zps avec le code du patron',
    (tester) async {
      final ancien = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      final fichier = (await tester.runAsync(
        () => ancien.etat.creerSauvegarde('482713'),
      ))!;
      final neuf = await environnementDeTest(tester);
      neuf.fichiers.add(fichier);
      await afficherApp(tester, neuf.etat);
      await toucher(tester, find.byKey(const Key('bouton-retrouver-boutique')));
      await toucher(tester, find.byKey(const Key('retrouver-fichier')));
      await attendre(tester, tours: 6);
      await taperPin(tester, '111111');
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await attendre(tester);
      }
      expect(find.byKey(const Key('pin-erreur')), findsOneWidget);
      await taperPin(tester, '482713');
      for (var i = 0; i < 15 && !neuf.etat.installationTerminee; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await attendre(tester);
      }
      expect(neuf.etat.installationTerminee, isTrue);
      expect(neuf.etat.config.nom, 'Boutique Mama Ama');
    },
  );

  testWidgets(
    'alerte : le vendeur ferme avec 2 000 F de moins → bandeau rouge chez le patron',
    (tester) async {
      final relais = FauxRelais();
      final drive = StockageMemoire();
      // Appareil du vendeur.
      final vendeur = await environnementDeTest(
        tester,
        drive: drive,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.connecterSynchro();
          await etat.synchroniser();
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.verifierPin(etat.vendeurs.first, '5913');
          etat.transportAlertes = relais;
          await etat.ouvrirCaisse(5000);
          await etat.fermerCaisse({ModePaiement.especes: 3000});
          // L'alerte part sans bloquer l'écran : on lui laisse le temps.
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
      );
      expect(relais.recues, hasLength(1));
      expect(
        relais.recues.single.$2.message,
        'Caisse fermée par Kossi : il manque 2 000 F (especes).',
      );
      // Appareil du patron (même boutique, même Drive, même jeton de relais).
      final patron = await environnementDeTest(tester, drive: drive);
      await tester.runAsync(() async {
        await patron.etat.connecterSynchro();
        await patron.etat.retrouverBoutiqueDepuisDrive();
        await patron.etat.verifierPin(patron.etat.patron!, '482713');
        patron.etat.transportAlertes = relais;
        expect(await patron.etat.releverAlertes(), 1);
      });
      await afficherApp(tester, patron.etat);
      expect(find.byKey(const Key('bandeau-alerte')), findsOneWidget);
      expect(patron.voix.phrases.last, startsWith('Alerte. Caisse fermée'));
      await toucher(tester, find.byKey(const Key('bouton-alerte-vue')));
      expect(find.byKey(const Key('bandeau-alerte')), findsNothing);
      expect(vendeur.etat.alertes, isEmpty);
    },
  );

  testWidgets('le patron qui ferme lui-même : pas d\'alerte', (tester) async {
    final relais = FauxRelais();
    await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.connecterSynchro();
        await etat.synchroniser();
        etat.transportAlertes = relais;
        await etat.ouvrirCaisse(5000);
        await etat.fermerCaisse({ModePaiement.especes: 0});
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
    );
    expect(relais.recues, isEmpty);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets(
      'écrans Drive et « retrouver » sur ${e.key} : rien ne déborde',
      (tester) async {
        final env = await environnementDeTest(
          tester,
          preparer: boutiqueAvecStock,
        );
        await tester.runAsync(() async {
          await env.etat.connecterSynchro();
          await env.etat.synchroniser();
        });
        await afficherApp(tester, env.etat, taille: taille, densite: densite);
        await ouvrirEspacePatron(tester);
        await toucher(tester, find.byKey(const Key('patron-synchro')));
        await attendre(tester, tours: 8);
        expect(tester.takeException(), isNull);
        final neuf = await environnementDeTest(tester, drive: env.drive);
        await tester.pumpWidget(const SizedBox()); // nouvelle application
        await afficherApp(tester, neuf.etat, taille: taille, densite: densite);
        await toucher(
          tester,
          find.byKey(const Key('bouton-retrouver-boutique')),
        );
        await toucher(tester, find.byKey(const Key('retrouver-drive')));
        await attendre(tester, tours: 10);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
