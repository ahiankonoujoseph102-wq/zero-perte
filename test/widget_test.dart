import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:zero_perte/main.dart';

final _infos = PackageInfo(
  appName: 'Zéro Perte',
  packageName: 'tg.zeroperte.app',
  version: '0.2.0',
  buildNumber: '12',
);

/// Écrans testés (taille en points « logiques » × densité).
const _ecrans = <String, (Size, double)>{
  'petit 4 pouces (320 × 568)': (Size(320, 568), 2.0),
  'téléphone 5 pouces (360 × 640)': (Size(360, 640), 2.0),
  'grand téléphone 6,5 pouces (412 × 915)': (Size(412, 915), 2.625),
  'tablette 10 pouces (800 × 1280)': (Size(800, 1280), 1.5),
};

Future<void> _afficher(
  WidgetTester tester,
  Size taille,
  double densite, {
  double texte = 1.0,
}) async {
  tester.view.physicalSize = taille * densite;
  tester.view.devicePixelRatio = densite;
  tester.platformDispatcher.textScaleFactorTestValue = texte;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ZeroPerteApp(
      infosPaquet: Future.value(_infos),
      maintenant: DateTime(2026, 11, 21),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final e in _ecrans.entries) {
    final (taille, densite) = e.value;
    for (final texte in [1.0, 1.5]) {
      testWidgets(
        'écran ${e.key}, texte ×$texte : 4 boutons visibles, rien ne déborde',
        (tester) async {
          await _afficher(tester, taille, densite, texte: texte);
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
    await _afficher(tester, const Size(360, 640), 2.0);
    expect(find.text('Ma boutique'), findsOneWidget);
    expect(find.text('21 nov.'), findsOneWidget);
    expect(find.text('Zéro Perte · version 0.2.0 (12)'), findsOneWidget);
    expect(find.text('Vendre'), findsOneWidget);
    expect(find.text('Crédit'), findsOneWidget);
    expect(find.text('Dépense'), findsOneWidget);
    expect(find.text('Fermer la caisse'), findsOneWidget);
  });

  testWidgets('version d\'essai : bandeau rouge', (tester) async {
    await _afficher(tester, const Size(360, 640), 2.0);
    expect(find.byType(BandeauEssai), findsOneWidget);
  });

  testWidgets('un bouton sans fonction affiche « arrive bientôt »', (
    tester,
  ) async {
    await _afficher(tester, const Size(360, 640), 2.0);
    await tester.tap(find.byKey(const Key('bouton-vendre')));
    await tester.pump();
    expect(find.text('« Vendre » arrive bientôt.'), findsOneWidget);
  });
}
