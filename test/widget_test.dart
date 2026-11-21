import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/main.dart';

import 'package:zero_perte/ecrans/credit/clients.dart';

import 'support/outils.dart';

void main() {
  Future<void> afficherAccueil(
    WidgetTester tester,
    Size taille,
    double densite, {
    double texte = 1.0,
  }) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.termine,
    );
    await afficherApp(
      tester,
      env.etat,
      taille: taille,
      densite: densite,
      texte: texte,
    );
  }

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    final grand = taille.width >= 840;
    for (final texte in [1.0, 1.5]) {
      testWidgets(
        'écran ${e.key}, texte ×$texte : menu du patron visible, rien ne déborde',
        (tester) async {
          await afficherAccueil(tester, taille, densite, texte: texte);
          // Un débordement (texte coupé, bande jaune et noire) lèverait une exception.
          expect(tester.takeException(), isNull);
          final cles = grand
              ? [
                  'menu-accueil',
                  'bouton-vendre',
                  'bouton-ma-caisse',
                  'bouton-credit',
                  'menu-tableau',
                  'menu-arrivages',
                  'menu-inventaire',
                  'menu-fournisseurs',
                  'menu-vendeurs',
                  'bouton-espace-patron',
                ]
              : [
                  'bouton-vendre',
                  'bouton-ma-caisse',
                  'bouton-credit',
                  'accueil-tableau',
                  'accueil-arrivages',
                  'accueil-inventaire',
                  'bouton-espace-patron',
                ];
          for (final cle in cles) {
            final bouton = find.byKey(Key(cle));
            expect(bouton, findsOneWidget, reason: cle);
            if (grand) continue; // menu de gauche : il défile si besoin
            final r = tester.getRect(bouton);
            // Entièrement à l'écran, et assez grand pour un gros doigt (≥ 72 points).
            expect(
              r.top >= 0 && r.bottom <= taille.height,
              isTrue,
              reason: cle,
            );
            expect(r.height, greaterThanOrEqualTo(72), reason: cle);
          }
          if (grand) {
            // Tablette et PC : menu fixe à gauche + tableau de bord.
            expect(find.byKey(const Key('menu-gauche')), findsOneWidget);
            expect(find.byKey(const Key('tableau-de-bord')), findsOneWidget);
            expect(find.byKey(const Key('courbe-sept-jours')), findsOneWidget);
            return;
          }
          // « Vendre » est le plus gros bouton.
          final vendre = tester.getRect(find.byKey(const Key('bouton-vendre')));
          for (final autre in cles.skip(1)) {
            final r = tester.getRect(find.byKey(Key(autre)));
            expect(
              vendre.width * vendre.height,
              greaterThan(r.width * r.height),
            );
          }
        },
      );
    }
  }

  for (final taille in const [Size(320, 568), Size(1366, 768)]) {
    testWidgets(
      'vendeur (${taille.width.toInt()}×${taille.height.toInt()}) : il ne voit que Vendre, Ma caisse et Clients',
      (tester) async {
        final env = await environnementDeTest(
          tester,
          preparer: (etat) async {
            await boutiqueInstallee(etat);
            await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
            etat.deconnecter();
            await etat.connecterParCode('5913');
          },
        );
        await afficherApp(
          tester,
          env.etat,
          taille: taille,
          densite: taille.width > 800 ? 1.0 : 2.0,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('bouton-vendre')), findsOneWidget);
        expect(find.byKey(const Key('bouton-ma-caisse')), findsOneWidget);
        expect(find.byKey(const Key('bouton-credit')), findsOneWidget);
        for (final cle in [
          'bouton-espace-patron',
          'accueil-tableau',
          'menu-tableau',
          'menu-accueil',
          'menu-vendeurs',
        ]) {
          expect(find.byKey(Key(cle)), findsNothing, reason: cle);
        }
        // Dans « Ma caisse », le vendeur ne voit jamais l'attendu.
        await toucher(tester, find.byKey(const Key('bouton-ma-caisse')));
        await attendre(tester, tours: 6);
        expect(find.byKey(const Key('bouton-depense')), findsOneWidget);
        expect(find.byKey(const Key('bouton-fermer-caisse')), findsOneWidget);
        expect(find.byKey(const Key('bouton-retrait')), findsNothing);
        expect(find.textContaining('Doit être dans la caisse'), findsNothing);
      },
    );
  }

  testWidgets('nom, date en français et numéro de version affichés', (
    tester,
  ) async {
    await afficherAccueil(tester, const Size(360, 640), 2.0);
    expect(find.text('Ma boutique'), findsOneWidget);
    expect(find.text('21 nov.'), findsOneWidget);
    expect(find.textContaining('Zéro Perte · version'), findsOneWidget);
    expect(find.text('Vendre'), findsOneWidget);
    expect(find.text('Ma caisse'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('Gestion'), findsOneWidget);
  });

  testWidgets('version d\'essai : bandeau rouge', (tester) async {
    await afficherAccueil(tester, const Size(360, 640), 2.0);
    expect(find.byType(BandeauEssai), findsOneWidget);
  });

  testWidgets(
    'les boutons de l\'accueil fonctionnent (« Clients » ouvre la liste)',
    (tester) async {
      await afficherAccueil(tester, const Size(360, 640), 2.0);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 6);
      expect(find.byType(PageClients), findsOneWidget);
      expect(find.textContaining('arrive bientôt'), findsNothing);
    },
  );

  testWidgets(
    'PC : le menu de gauche reste visible, la page s\'ouvre à droite',
    (tester) async {
      await afficherAccueil(tester, const Size(1366, 768), 1.0);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 6);
      expect(find.byType(PageClients), findsOneWidget);
      expect(find.byKey(const Key('menu-gauche')), findsOneWidget);
      final menu = tester.getRect(find.byKey(const Key('menu-gauche')));
      final page = tester.getRect(find.byType(PageClients));
      expect(page.left, greaterThanOrEqualTo(menu.right - 1));
      // Retour à l'accueil par le menu.
      await toucher(tester, find.byKey(const Key('menu-accueil')));
      await attendre(tester, tours: 6);
      expect(find.byType(PageClients), findsNothing);
      expect(find.byKey(const Key('tableau-de-bord')), findsOneWidget);
    },
  );
}
