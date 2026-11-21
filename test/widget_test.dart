import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/main.dart';

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
    for (final texte in [1.0, 1.5]) {
      testWidgets(
        'écran ${e.key}, texte ×$texte : 4 boutons visibles, rien ne déborde',
        (tester) async {
          await afficherAccueil(tester, taille, densite, texte: texte);
          // Un débordement (texte coupé, bande jaune et noire) lèverait une exception.
          expect(tester.takeException(), isNull);
          for (final cle in [
            'bouton-vendre',
            'bouton-credit',
            'bouton-depense',
            'bouton-fermer-caisse',
          ]) {
            final bouton = find.byKey(Key(cle));
            expect(bouton, findsOneWidget);
            final r = tester.getRect(bouton);
            // Entièrement à l'écran, et assez grand pour un gros doigt (≥ 72 points).
            expect(
              r.top >= 0 && r.bottom <= taille.height,
              isTrue,
              reason: cle,
            );
            expect(r.height, greaterThanOrEqualTo(72), reason: cle);
          }
          // « Vendre » est le plus gros bouton.
          final vendre = tester.getRect(find.byKey(const Key('bouton-vendre')));
          for (final autre in [
            'bouton-credit',
            'bouton-depense',
            'bouton-fermer-caisse',
          ]) {
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

  testWidgets('nom, date en français et numéro de version affichés', (
    tester,
  ) async {
    await afficherAccueil(tester, const Size(360, 640), 2.0);
    expect(find.text('Ma boutique'), findsOneWidget);
    expect(find.text('21 nov.'), findsOneWidget);
    expect(find.text('Zéro Perte · version 0.5.0 (12)'), findsOneWidget);
    expect(find.text('Vendre'), findsOneWidget);
    expect(find.text('Crédit'), findsOneWidget);
    expect(find.text('Dépense'), findsOneWidget);
    expect(find.text('Fermer la caisse'), findsOneWidget);
  });

  testWidgets('version d\'essai : bandeau rouge', (tester) async {
    await afficherAccueil(tester, const Size(360, 640), 2.0);
    expect(find.byType(BandeauEssai), findsOneWidget);
  });

  testWidgets('un bouton sans fonction affiche « arrive bientôt »', (
    tester,
  ) async {
    await afficherAccueil(tester, const Size(360, 640), 2.0);
    await tester.tap(find.byKey(const Key('bouton-vendre')));
    await tester.pump();
    expect(find.text('« Vendre » arrive bientôt.'), findsOneWidget);
  });
}
