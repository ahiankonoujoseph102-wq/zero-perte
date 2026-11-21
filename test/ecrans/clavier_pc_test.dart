import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/outils.dart';
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

void main() {
  testWidgets(
    'PC : taper 5 0 0 0 au clavier → le client donne 5 000 F ; Retour arrière ; Échap revient',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(
        tester,
        env,
        taille: const Size(1366, 768),
        densite: 1,
      );
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      for (final k in [
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit0,
      ]) {
        await tester.sendKeyEvent(k);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await attendre(tester);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('montant-recu')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '5 000 F',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await attendre(tester);
      expect(find.byKey(const Key('bouton-encaisser')), findsOneWidget);
    },
  );
}
