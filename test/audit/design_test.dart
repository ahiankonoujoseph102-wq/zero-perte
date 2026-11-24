// Audit 0.37 : navigation simple (5 destinations), Gestion rangée en 4
// rubriques, aucune fonction disparue, accueil en 3 grandes cartes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/ecrans/patron/espace_patron.dart';

import '../ecrans/refonte_036_test.dart' show boutiqueVide;
import '../support/outils.dart';

void main() {
  test('Gestion : toutes les fonctions d\'avant sont là, rangées', () {
    final cles = {for (final e in entreesPatron) e.cle};
    for (final c in [
      'arrivages',
      'compter-stock',
      'produits',
      'inventaire',
      'fermetures',
      'fournisseurs',
      'retrait',
      'retours',
      'devis',
      'ajouter-vendeur',
      'vendeurs',
      'appareils',
      'ma-boutique',
      'a-faire',
      'synchro',
      'sauvegarde',
    ]) {
      expect(cles, contains(c));
    }
    for (final g in GroupeGestion.values) {
      expect(entreesPatron.where((e) => e.groupe == g), isNotEmpty);
    }
  });

  for (final (taille, nom) in [
    (const Size(360, 720), 'petit téléphone'),
    (const Size(1366, 768), 'PC'),
  ]) {
    testWidgets('$nom : accueil du patron, 3 cartes et 5 destinations', (
      tester,
    ) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await afficherApp(tester, env.etat, taille: taille);
      await attendre(tester, tours: 10);
      final grand = taille.width >= 840;
      for (final c in [
        'bouton-vendre',
        'bouton-ma-caisse',
        'bouton-credit',
        grand ? 'menu-chiffres' : 'accueil-chiffres',
        'bouton-espace-patron',
      ]) {
        expect(find.byKey(Key(c)), findsOneWidget, reason: c);
      }
      for (final c in ['arrivages', 'inventaire', 'devis', 'vendeurs']) {
        expect(find.byKey(Key('menu-$c')), findsNothing);
        expect(find.byKey(Key('accueil-$c')), findsNothing);
      }
      expect(
        find.byKey(Key(grand ? 'bord-caisse' : 'resume-caisse')),
        findsOneWidget,
      );
      await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
      await attendre(tester, tours: 6);
      for (final g in GroupeGestion.values) {
        expect(find.byKey(Key('rubrique-${g.name}')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
