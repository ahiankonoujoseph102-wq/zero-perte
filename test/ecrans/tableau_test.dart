import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

/// Riz : 100 kg reçus (500 F/kg), 2 kg vendus 1 200 F.
/// Sucre : 1 kg reçu (700 F), 1 kg vendu 800 F → épuisé.
/// Dépense transport 1 500 F.
Future<void> journee(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
  final sucre = etat.produits.firstWhere((p) => p.nom.startsWith('Sucre'));
  await etat.enregistrerArrivage(produit: sucre, nombre: 1, coutTotal: 700);
  await etat.journal.enregistrerVente(
    lignes: [
      LigneDemandee.quantite(produitId: riz.id, nombre: 2),
      LigneDemandee.quantite(produitId: sucre.id, nombre: 1),
    ],
    mode: ModePaiement.especes,
    montantRecu: 2000,
    auteurId: etat.auteurActuel,
  );
  await etat.depenser(1500, motif: 'Transport', mode: ModePaiement.especes);
  await etat.rechargerProduits();
}

void main() {
  group('périodes', () {
    final samedi = DateTime(2026, 11, 21, 15, 30);
    test('jour = minuit', () {
      expect(Periode.jour.debut(samedi), DateTime(2026, 11, 21));
    });
    test('semaine = lundi 16 novembre', () {
      expect(Periode.semaine.debut(samedi), DateTime(2026, 11, 16));
      expect(
        Periode.semaine.debut(DateTime(2026, 11, 16, 8)),
        DateTime(2026, 11, 16),
      );
    });
    test('mois = 1er novembre', () {
      expect(Periode.mois.debut(samedi), DateTime(2026, 11));
    });
  });

  group('stock bas', () {
    test('épuisé seulement si le produit a déjà été reçu ou vendu', () {
      expect(
        stockBas(stock: 0, seuil: 0, venduSur7Jours: 0, dejaRecu: false),
        isNull,
      );
      expect(
        stockBas(stock: 0, seuil: 0, venduSur7Jours: 0, dejaRecu: true),
        RaisonStockBas.epuise,
      );
    });
    test('seuil du patron : 5 kg restants pour un seuil de 5 kg', () {
      expect(
        stockBas(stock: 5000, seuil: 5000, venduSur7Jours: 0, dejaRecu: true),
        RaisonStockBas.sousLeSeuil,
      );
      expect(
        stockBas(
          stock: 5001,
          seuil: 5000,
          venduSur7Jours: 90000,
          dejaRecu: true,
        ),
        isNull,
      );
    });
    test('sans seuil : 3 kg restants, 10 kg vendus en 7 jours', () {
      expect(
        stockBas(stock: 3000, seuil: 0, venduSur7Jours: 10000, dejaRecu: true),
        RaisonStockBas.moinsDUneSemaine,
      );
      expect(
        stockBas(stock: 30000, seuil: 0, venduSur7Jours: 10000, dejaRecu: true),
        isNull,
      );
    });
  });

  testWidgets(
    'tableau du jour : ventes 2 000 F, bénéfice 300 F, dépenses 1 500 F, sucre épuisé',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'chiffres');
      await attendre(tester, tours: 10);

      String texte(String cle) =>
          tester.widget<Text>(find.byKey(Key(cle))).data!;
      expect(texte('chiffre-ventes'), '2 000 F');
      // Riz : 1 200 − 2 × 500 = 200 ; sucre : 800 − 700 = 100...
      // + 100 → 300 ? Non : voir le calcul ci-dessous.
      final b = await tester.runAsync(() => env.journal.beneficeEstime());
      expect(texte('chiffre-benefice'), isNot(isEmpty));
      expect(b!.benefice, 300); // (1 200 − 1 000) + (800 − 700)
      expect(texte('chiffre-benefice'), '300 F');
      expect(texte('chiffre-depenses'), '1 500 F');
      expect(find.text('2 ventes'), findsNothing);
      expect(find.text('1 vente'), findsOneWidget);
      // Les plus vendus : riz (1 200 F) puis sucre (800 F).
      expect(
        find.descendant(
          of: find.byKey(const Key('meilleur-0')),
          matching: find.text('1. Riz'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('stock-bas-Sucre en poudre')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Épuisé'), findsOneWidget);
      expect(find.byKey(const Key('stock-bas-Riz')), findsNothing);

      // Changer de période recharge les chiffres (même résultat ici).
      await tester.scrollUntilVisible(
        find.byKey(const Key('periode-mois')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await toucher(tester, find.byKey(const Key('periode-mois')));
      await attendre(tester, tours: 10);
      expect(texte('chiffre-ventes'), '2 000 F');
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('tableau sur ${e.key} : rien ne déborde', (tester) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      expect(tester.takeException(), isNull);
      await ouvrirPagePatron(tester, 'chiffres');
      await attendre(tester, tours: 10);
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('periode-semaine')));
      await attendre(tester, tours: 10);
      expect(tester.takeException(), isNull);
    });
  }
}
