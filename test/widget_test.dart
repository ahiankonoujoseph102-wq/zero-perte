import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:zero_perte/main.dart';

void main() {
  testWidgets('L\'écran d\'accueil affiche le nom et la version', (tester) async {
    final infos = PackageInfo(
      appName: 'Zéro Perte',
      packageName: 'tg.zeroperte.app',
      version: '0.1.0',
      buildNumber: '7',
    );

    await tester.pumpWidget(ZeroPerteApp(infosPaquet: Future.value(infos)));
    await tester.pumpAndSettle();

    expect(find.text('Zéro Perte'), findsOneWidget);
    expect(find.text('Version 0.1.0 (7)'), findsOneWidget);
  });

  testWidgets('Une version d\'essai affiche le bandeau rouge', (tester) async {
    final infos = PackageInfo(
      appName: 'Zéro Perte',
      packageName: 'tg.zeroperte.app',
      version: '0.1.0',
      buildNumber: '1',
    );

    await tester.pumpWidget(ZeroPerteApp(infosPaquet: Future.value(infos)));
    await tester.pumpAndSettle();

    // Les tests ne passent pas ZP_CANAL=officiel : c'est donc une version d'essai.
    expect(find.byType(BandeauEssai), findsOneWidget);
  });
}
