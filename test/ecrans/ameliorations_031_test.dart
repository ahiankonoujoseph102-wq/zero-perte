// Améliorations de la 0.31 : résumé du jour du patron sur téléphone,
// recherche dans « Vendre », pages vides expliquées.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/ecrans/vente/page_vendre.dart' show correspond;

import '../support/outils.dart';

void main() {
  test('recherche : début des mots, sans accents', () {
    expect(correspond('Riz', 'ri'), isTrue);
    expect(correspond('Sucrerie en bouteille', 'ri'), isFalse);
    expect(correspond('Pâtes, spaghettis', 'pate'), isTrue);
    expect(correspond('Pâtes, spaghettis', 'spag'), isTrue);
    expect(correspond('Concentré de tomate', 'tomate'), isTrue);
    expect(correspond('Eau minérale 1,5 L', 'minerale'), isTrue);
    expect(correspond('Huile', 'riz'), isFalse);
  });

  testWidgets('téléphone du patron : résumé du jour sur l\'accueil', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueInstallee);
    await afficherApp(tester, env.etat, taille: const Size(412, 915));
    await attendre(tester, tours: 10);
    expect(find.byKey(const Key('resume-du-jour')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('resume-ventes'))).data,
      formatFrancs(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grande boutique : chercher un produit dans « Vendre »', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.termine,
      preparer: (etat) async {
        await etat.ajouterDuCatalogue(
          etat.catalogue.produitsDe(['alimentation', 'boissons']).take(30),
        );
      },
    );
    await afficherApp(tester, env.etat);
    await toucher(tester, find.byKey(const Key('bouton-vendre')));
    if (find
        .byKey(const Key('bouton-valider-montant-page'))
        .evaluate()
        .isNotEmpty) {
      await toucher(
        tester,
        find.byKey(const Key('bouton-valider-montant-page')),
      );
    }
    await attendre(tester, tours: 6);
    expect(find.byKey(const Key('recherche-produit')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('recherche-produit')), 'riz');
    await attendre(tester, tours: 4);
    expect(find.byKey(const Key('vendre-alimentation.riz')), findsOneWidget);
    expect(find.byKey(const Key('vendre-alimentation.huile')), findsNothing);
    await tester.enterText(find.byKey(const Key('recherche-produit')), 'zzz');
    await attendre(tester, tours: 4);
    expect(find.byKey(const Key('recherche-vide')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
