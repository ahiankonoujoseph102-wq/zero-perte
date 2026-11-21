import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/vente/page_encaisser.dart';
import 'package:zero_perte/ecrans/vente/page_vendre.dart';

import '../support/outils.dart';

/// Boutique installée + arrivage : 2 sacs de riz (100 kg) achetés 50 000 F.
Future<void> boutiqueAvecStock(EtatApplication etat) async {
  await boutiqueInstallee(etat);
  final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
  final sac = (await etat.journal.conditionnements(riz.id))
      .firstWhere((c) => c.nom == 'sac de 50 kg');
  await etat.enregistrerArrivage(
    produit: riz,
    conditionnement: sac,
    nombre: 2,
    coutTotal: 50000,
  );
}

Future<void> ouvrirVendre(
  WidgetTester tester,
  Environnement env, {
  Size taille = const Size(360, 640),
  double densite = 2,
}) async {
  await afficherApp(tester, env.etat, taille: taille, densite: densite);
  await toucher(tester, find.byKey(const Key('bouton-vendre')));
  await ouvrirLaCaisseSiDemande(tester);
  expect(find.byType(PageVendre), findsOneWidget);
}

/// Première vente de la journée : la caisse est ouverte avec [fonds] F.
Future<void> ouvrirLaCaisseSiDemande(
  WidgetTester tester, {
  int fonds = 0,
}) async {
  await attendre(tester, tours: 8);
  if (find.byKey(const Key('bouton-valider-montant-page')).evaluate().isEmpty) {
    return;
  }
  for (final c in fonds.toString().split('')) {
    if (fonds == 0) break;
    await toucher(tester, find.byKey(Key('montant-$c')));
  }
  await toucher(tester, find.byKey(const Key('bouton-valider-montant-page')));
  await attendre(tester, tours: 12);
}

void main() {
  testWidgets(
    'vente en espèces : 2 kg de riz + 1 paquet de sucre = 2 000 F, le client donne 5 000 F → rendre 3 000 F',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(tester, env);

      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.sucre')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      expect(find.text('2 kg · Riz'), findsOneWidget); // regroupé
      expect(find.text('2 000 F'), findsWidgets); // total

      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      expect(env.voix.phrases.last, 'À payer : 2000 francs');
      await toucher(tester, find.byKey(const Key('rapide-5000')));
      expect(find.byKey(const Key('a-rendre')), findsOneWidget);
      expect(find.text('3 000 F'), findsWidgets);
      expect(find.text('1 × 2 000 F'), findsOneWidget); // un billet de 2 000
      expect(find.text('1 × 1 000 F'), findsOneWidget); // un billet de 1 000

      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      expect(find.byKey(const Key('numero-recu')), findsOneWidget);
      expect(find.text('Reçu n° A-000001'), findsWidgets); // en-tête + reçu
      expect(find.byKey(const Key('rendre-final')), findsOneWidget);
      expect(env.voix.phrases.last, 'Vente enregistrée. Rendez 3000 francs.');

      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(env.etat.stock(riz.id), 98000); // 100 kg − 2 kg

      await toucher(tester, find.byKey(const Key('bouton-nouvelle-vente')));
      expect(find.byType(PageVendre), findsOneWidget);
      expect(
        find.text('Touchez les produits vendus.'),
        findsOneWidget,
      ); // panier vidé

      final m = await tester.runAsync(
        () => env.journal.mouvementsCaisse(ModePaiement.especes),
      );
      expect(m!.ventes, 2000);
    },
  );

  testWidgets('pas assez d\'argent : « Il manque », impossible de valider', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await ouvrirVendre(tester, env);
    await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
    await toucher(tester, find.byKey(const Key('choix-base')));
    await toucher(tester, find.byKey(const Key('bouton-encaisser')));
    await toucher(tester, find.byKey(const Key('montant-5')));
    await toucher(tester, find.byKey(const Key('montant-0')));
    await toucher(tester, find.byKey(const Key('montant-0')));
    expect(find.byKey(const Key('il-manque')), findsOneWidget); // 500 pour 600
    final bouton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('bouton-valider-vente')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(bouton.onPressed, isNull);
  });

  testWidgets('Mixx (T-Money) avec référence ; « donne pour 100 F » de riz', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await ouvrirVendre(tester, env);
    await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
    await toucher(tester, find.byKey(const Key('choix-montant')));
    await toucher(tester, find.byKey(const Key('rapide-100')));
    await toucher(tester, find.byKey(const Key('bouton-valider-montant')));
    expect(find.text('Riz pour 100 F'), findsOneWidget);

    await toucher(tester, find.byKey(const Key('bouton-encaisser')));
    await toucher(tester, find.byKey(const Key('mode-mixx')));
    await tester.enterText(find.byKey(const Key('champ-reference')), '4821');
    await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
    expect(find.text('Reçu n° A-000001'), findsWidgets);
    expect(find.textContaining('Mixx (T-Money)'), findsWidgets);

    final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
    expect(env.etat.stock(riz.id), 100000 - 167); // 100 F ÷ 600 F = 0,167 kg
    final mixx = await tester.runAsync(
      () => env.journal.mouvementsCaisse(ModePaiement.mixx),
    );
    expect(mixx!.ventes, 100);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('Vendre + Encaisser sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(tester, env, taille: taille, densite: densite);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-1000')));
      expect(tester.takeException(), isNull);
      expect(find.byType(PageEncaisser), findsOneWidget);
    });
  }
}
