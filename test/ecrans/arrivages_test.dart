import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/ecrans/patron/espace_patron.dart';

import '../support/outils.dart';

/// Boutique installée : patron « Ama » (code 4827), riz (sac de 50 kg) et sucre.
Future<void> boutiqueInstallee(EtatApplication etat) async {
  await etat.enregistrerConfig(
    etat.config.copie(nom: 'Boutique Mama Ama', types: ['alimentation']),
  );
  await etat.definirPatron(nom: 'Ama', pin: '4827');
  final cat = etat.catalogue.produitsDe(['alimentation']);
  await etat.ajouterDuCatalogue(
    cat.where(
      (p) => p.id == 'alimentation.riz' || p.id == 'alimentation.sucre',
    ),
  );
  for (final p in etat.produits) {
    final conds = await etat.journal.conditionnements(p.id);
    await etat.fixerPrix(p, p.nom == 'Riz' ? 600 : 800, {
      for (final c in conds)
        c: c.nom == 'sac de 50 kg'
            ? 28000
            : (c.nom == 'sac de 25 kg' ? 14500 : 8000),
    });
  }
  await etat.allerA(EtapeAssistant.termine);
}

Future<void> taperPin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.tap(find.byKey(Key('pin-$c')));
    await tester.pump();
  }
  await attendre(tester, tours: 8);
}

void main() {
  testWidgets(
    'espace patron : code secret, puis arrivage de 2 sacs de riz → stock 100 kg',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      await afficherApp(tester, env.etat);

      await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
      expect(find.textContaining('Code secret de Ama'), findsOneWidget);
      await taperPin(tester, '4827');
      expect(find.byType(EspacePatron), findsOneWidget);

      await toucher(tester, find.byKey(const Key('patron-arrivages')));
      expect(find.textContaining('En stock : 0 kg'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('arrivage-alimentation.riz')));
      // Par défaut : le plus grand conditionnement (sac de 50 kg).
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('unite-sac de 50 kg')))
            .selected,
        isTrue,
      );
      await toucher(tester, find.byKey(const Key('plus')));
      expect(find.text('2'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('champ-cout')), '50000');
      await tester.pump();
      expect(find.textContaining('Soit 25'), findsOneWidget); // 25 000 F le sac
      await toucher(
        tester,
        find.byKey(const Key('bouton-enregistrer-arrivage')),
      );

      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(env.etat.stock(riz.id), 100000); // 2 × 50 kg
      expect(
        find.textContaining('Arrivage enregistré : 2 sacs de 50 kg de Riz'),
        findsOneWidget,
      );
      expect(find.textContaining('En stock : 2 sacs de 50 kg'), findsOneWidget);
    },
  );

  testWidgets('5 codes faux : bloqué 5 minutes, même le bon code est refusé', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueInstallee);
    await afficherApp(tester, env.etat);
    await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
    for (var i = 0; i < 4; i++) {
      await taperPin(tester, '1111');
    }
    expect(find.textContaining('Encore 1 essai'), findsOneWidget);
    await taperPin(tester, '1111');
    expect(find.textContaining('Trop d\'erreurs'), findsOneWidget);
    await taperPin(tester, '4827'); // bon code, mais bloqué
    expect(find.byType(EspacePatron), findsNothing);

    // 6 minutes plus tard : débloqué.
    env.etat.maintenant = () => DateTime.now().add(const Duration(minutes: 6));
    await taperPin(tester, '4827');
    expect(find.byType(EspacePatron), findsOneWidget);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('formulaire d\'arrivage sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => EspacePatron(etat: env.etat)));
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('patron-arrivages')));
      await toucher(tester, find.byKey(const Key('arrivage-alimentation.riz')));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('bouton-enregistrer-arrivage')),
        findsOneWidget,
      );
    });
  }
}
