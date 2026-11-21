// Captures de l'avatar Afi (expressions, bouche, gestes).
// Lancement : flutter test test_captures/avatar_captures_test.dart --update-goldens
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/demo_guidee/avatar.dart';
import 'package:zero_perte/demo_guidee/script_visite.dart';

void main() {
  testWidgets('avatar Afi : planche', (tester) async {
    tester.view.physicalSize = const Size(1200, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget afi(Expression e, double b, double? g) => Padding(
      padding: const EdgeInsets.all(8),
      child: AvatarAfi(
        taille: 180,
        bouche: ValueNotifier(b),
        expression: e,
        geste: g,
        anime: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF132447),
          body: Row(
            children: [
              afi(Expression.sourire, 0, null),
              afi(Expression.sourire, 0.8, null),
              afi(Expression.contente, 0.3, null),
              afi(Expression.sourire, 0.4, -math.pi / 4),
              afi(Expression.neutre, 0.5, math.pi * 0.9),
              afi(Expression.auRevoir, 0, -math.pi / 2),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/avatar/planche.png'),
    );
  });
}
