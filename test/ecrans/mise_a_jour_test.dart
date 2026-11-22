// Le patron apprend qu'une nouvelle version existe (sans rien installer tout
// seul, sans bloquer une boutique sans Internet).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/services/mise_a_jour.dart';

import '../support/outils.dart';

const _json =
    '{"version":"0.31.0","versionCode":64,"canal":"officiel","apk":{}}';

void main() {
  test('version.json : plus récente → lien ; même version ou abîmé → rien', () {
    final m = InfosMiseAJour.depuisJson(
      _json,
      versionInstallee: 57,
      windows: false,
    );
    expect(m?.version, '0.31.0');
    expect(
      m?.lien.toString(),
      endsWith('/releases/latest/download/ZeroPerte.apk'),
    );
    expect(
      InfosMiseAJour.depuisJson(
        _json,
        versionInstallee: 57,
        windows: true,
      )?.lien.toString(),
      endsWith('/ZeroPerte-Windows.zip'),
    );
    expect(
      InfosMiseAJour.depuisJson(_json, versionInstallee: 64, windows: false),
      isNull,
    );
    expect(
      InfosMiseAJour.depuisJson('<html>', versionInstallee: 1, windows: false),
      isNull,
    );
  });

  testWidgets('nouvelle version publiée → message sur l\'accueil', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.termine,
    );
    VerificateurMiseAJour.instance.fixer(
      InfosMiseAJour.depuisJson(_json, versionInstallee: 1, windows: false),
    );
    await afficherApp(tester, env.etat);
    await attendre(tester, tours: 6);
    expect(find.byKey(const Key('bouton-mise-a-jour')), findsOneWidget);
    expect(
      find.textContaining('Nouvelle version disponible (0.31.0)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rien de nouveau (ou pas d\'Internet) → la version, sans message',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.termine,
      );
      await afficherApp(tester, env.etat);
      await attendre(tester, tours: 6);
      expect(find.byKey(const Key('bouton-mise-a-jour')), findsNothing);
      expect(find.byKey(const Key('texte-version')), findsOneWidget);
    },
  );
}
