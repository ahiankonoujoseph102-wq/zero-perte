// Afi en médaillon (essai, pas encore activé) : à vitesse réelle, sur les 4
// tailles, chaque bouton de la visite est trouvé et entouré, et le panneau
// d'Afi ne le cache jamais (haut du bouton toujours visible, au plus un quart
// recouvert pour les très grands éléments sur 4 pouces).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/demo_guidee/afi_v2.dart';
import 'package:zero_perte/demo_guidee/visite_guidee.dart';

import '../support/outils.dart';
import 'visite_guidee_test.dart' show ouvrirDemo, visite;

void main() {
  const tailles = {
    '4pouces': (Size(320, 568), 2.0),
    'telephone': (Size(412, 915), 2.625),
    'tablette_paysage': (Size(1280, 800), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };

  testWidgets('le médaillon suit le regard et la bouche', (tester) async {
    final bouche = ValueNotifier<double>(0);
    addTearDown(bouche.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MedaillonAfi(
            bouche: bouche,
            cible: const Offset(1, 0),
            anime: false,
          ),
        ),
      ),
    );
    bouche.value = 0.8;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MedaillonAfi)), const Size(96, 96));
  });

  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('médaillon ne cache aucun bouton montré ${e.key}', (
      tester,
    ) async {
      afiMedaillonVisite = true;
      addTearDown(() => afiMedaillonVisite = false);
      await ouvrirDemo(
        tester,
        taille: taille,
        densite: densite,
        heure: DateTime(2026, 11, 21, 9),
      );
      final caches = <String>{};
      var verifies = 0;
      for (var i = 0; i < 900 && !visite(tester).termine; i++) {
        await attendre(tester, tours: 2);
        final v = visite(tester);
        final local = v.cibleMontree;
        final panneau = find.byKey(const Key('visite-panneau'));
        if (local == null || panneau.evaluate().isEmpty) continue;
        // La place du bouton est mesurée dans la zone de la visite.
        final bouton = local.shift(
          tester.getTopLeft(find.byType(VisiteGuidee)),
        );
        final rectPanneau = tester.getRect(panneau);
        // Les boutons d'Afi elle-même (« Quitter ») sont dans le panneau.
        if (v.chapitre == v.chapitres.length - 1 &&
            rectPanneau.contains(bouton.center)) {
          continue;
        }
        verifies++;
        // Caché = le haut du bouton (son titre, 40 px) est sous le panneau,
        // ou plus d'un quart de sa partie à l'écran est recouvert alors que le
        // panneau tenait à côté (sinon, sur 4 pouces, au plus la moitié).
        final ecran = Offset.zero & tester.view.physicalSize / densite;
        final visible = bouton.intersect(ecran);
        final commun = visible.intersect(rectPanneau);
        final haut = Rect.fromLTRB(
          visible.left,
          visible.top,
          visible.right,
          visible.top + 40,
        ).intersect(rectPanneau);
        final recouvert = commun.width > 0 && commun.height > 0
            ? commun.width * commun.height / (visible.width * visible.height)
            : 0.0;
        final zone = tester.getRect(find.byType(VisiteGuidee));
        final tenait =
            bouton.top - zone.top >= rectPanneau.height + 8 ||
            zone.bottom - bouton.bottom >= rectPanneau.height + 8;
        final limite = tenait ? 0.0 : 0.5;
        if ((haut.width > 0 && haut.height > 0) || recouvert > limite) {
          caches.add(
            'chapitre ${v.chapitre + 1} étape ${v.etape + 1} : bouton $bouton,'
            ' panneau $rectPanneau, recouvert ${(recouvert * 100).round()} %',
          );
        }
      }
      expect(visite(tester).termine, isTrue);
      expect(visite(tester).ciblesManquantes, isEmpty);
      expect(verifies, greaterThan(20));
      expect(caches, isEmpty, reason: 'boutons cachés par Afi (${e.key})');
    });
  }
}
