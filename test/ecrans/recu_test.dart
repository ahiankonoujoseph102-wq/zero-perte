import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/recu.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/recu/recu_vente.dart';

import '../support/outils.dart';
import 'annulation_perte_test.dart' show vendreDeuxKg;
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

/// Vend 2 kg de riz et reste sur l'écran « Vente enregistrée ».
Future<void> vendreEtGarderLeRecu(WidgetTester tester) async {
  await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
  await toucher(tester, find.byKey(const Key('choix-base')));
  await toucher(tester, find.byKey(const Key('plus-0')));
  await toucher(tester, find.byKey(const Key('bouton-encaisser')));
  await toucher(tester, find.byKey(const Key('rapide-exact')));
  await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
  await attendre(tester, tours: 8);
}

void main() {
  test('texte et date du reçu', () {
    expect(
      dateRecu(DateTime(2026, 11, 21, 9, 5).millisecondsSinceEpoch),
      '21/11/2026 09:05',
    );
  });

  testWidgets(
    'après la vente : reçu « 2 kg de Riz » affiché, envoyé en image avec son texte',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(tester, env);
      await vendreEtGarderLeRecu(tester);

      expect(find.byKey(const Key('apercu-recu')), findsOneWidget);
      expect(find.text('2 kg de Riz'), findsOneWidget);
      expect(find.text('Reçu n° A-000001'), findsWidgets);

      await toucher(tester, find.byKey(const Key('bouton-envoyer-recu')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await attendre(tester, tours: 10);

      expect(env.partages, hasLength(1));
      final (png, texte) = env.partages.single;
      // Une vraie image PNG (signature 89 50 4E 47).
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(texte, startsWith('Reçu n° A-000001 – Boutique Mama Ama : 1 200 F.'));
    },
  );

  testWidgets('le reçu peut être renvoyé depuis « Ventes du jour »', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await ouvrirVendre(tester, env);
    await vendreDeuxKg(tester);
    await vendreDeuxKg(tester);
    await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
    await toucher(tester, find.byKey(const Key('vente-A-000002')));
    await attendre(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('bouton-envoyer-recu')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await attendre(tester, tours: 10);
    expect(env.partages.single.$2, startsWith('Reçu n° A-000002'));
  });

  testWidgets('numéros de reçu sans trou : A-000001, A-000002, A-000003', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await tester.runAsync(() async {
      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      for (var i = 0; i < 3; i++) {
        await env.journal.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
          mode: ModePaiement.especes,
          montantRecu: 600,
          auteurId: env.etat.auteurActuel,
        );
      }
    });
    final ventes = await tester.runAsync(() => env.journal.ventesDepuis(0));
    final numeros = [for (final v in ventes!) v.donnees['numero_recu'] as int];
    expect(numeros.toSet(), {1, 2, 3});
    expect(numerosManquants(numeros), isEmpty);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('reçu après la vente sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await ouvrirVendre(tester, env, taille: taille, densite: densite);
      await vendreEtGarderLeRecu(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('apercu-recu')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await attendre(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
