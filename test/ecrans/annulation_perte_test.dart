import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

/// Vend 2 kg de riz (1 200 F) en espèces, compte exact.
Future<void> vendreDeuxKg(WidgetTester tester) async {
  await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
  await toucher(tester, find.byKey(const Key('choix-base')));
  await toucher(tester, find.byKey(const Key('plus-0')));
  await toucher(tester, find.byKey(const Key('bouton-encaisser')));
  await toucher(tester, find.byKey(const Key('rapide-exact')));
  await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
  await toucher(tester, find.byKey(const Key('bouton-nouvelle-vente')));
}

void main() {
  testWidgets(
    'annulation « Retour du client » : le riz revient en stock, l\'argent sort de la caisse',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(tester, env);
      await vendreDeuxKg(tester);
      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(env.etat.stock(riz.id), 98000);

      await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
      expect(find.byKey(const Key('vente-A-000001')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('vente-A-000001')));
      await toucher(tester, find.byKey(const Key('bouton-annuler-vente')));
      await toucher(tester, find.byKey(const Key('motif-Retour du client')));
      await attendre(tester, tours: 25);

      expect(env.etat.stock(riz.id), 100000);
      final caisse = await tester.runAsync(
        () => env.journal.mouvementsCaisse(ModePaiement.especes),
      );
      expect(caisse!.ventes, 0); // 1 200 − 1 200
      expect(find.text('Annulée : Retour du client'), findsOneWidget);
      expect(env.voix.phrases.last, 'Vente annulée.');

      // Une vente annulée ne peut plus être annulée.
      await toucher(tester, find.byKey(const Key('vente-A-000001')));
      expect(find.byKey(const Key('bouton-annuler-vente')), findsNothing);
      expect(find.byKey(const Key('vente-annulee')), findsOneWidget);
    },
  );

  testWidgets('motif libre (« Autre »)', (tester) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await ouvrirVendre(tester, env);
    await vendreDeuxKg(tester);
    await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
    await toucher(tester, find.byKey(const Key('vente-A-000001')));
    await toucher(tester, find.byKey(const Key('bouton-annuler-vente')));
    await toucher(tester, find.byKey(const Key('motif-Autre')));
    await tester.enterText(
      find.byKey(const Key('champ-motif')),
      'Mauvais client',
    );
    await toucher(tester, find.byKey(const Key('bouton-valider-motif')));
    await attendre(tester, tours: 25);
    expect(find.text('Annulée : Mauvais client'), findsOneWidget);
  });

  testWidgets('perte : 3 kg de riz mouillé → stock 97 kg', (tester) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await afficherApp(tester, env.etat);
    await toucherDansMaCaisse(tester, 'bouton-depense');
    await toucher(tester, find.byKey(const Key('choix-perte')));
    await toucher(tester, find.byKey(const Key('perte-alimentation.riz')));
    await toucher(tester, find.byKey(const Key('plus')));
    await toucher(tester, find.byKey(const Key('plus')));
    // Sans motif : impossible.
    final bouton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('bouton-enregistrer-perte')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(bouton.onPressed, isNull);
    await toucher(tester, find.byKey(const Key('motif-perte-Mouillé')));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer-perte')));
    final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
    expect(env.etat.stock(riz.id), 97000);
    expect(
      find.textContaining('Perte enregistrée : 3 kg de Riz'),
      findsOneWidget,
    );
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('ventes du jour + perte sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(tester, env, taille: taille, densite: densite);
      await vendreDeuxKg(tester);
      await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
      await toucher(tester, find.byKey(const Key('vente-A-000001')));
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('bouton-annuler-vente')));
      expect(tester.takeException(), isNull);
    });
  }
}
