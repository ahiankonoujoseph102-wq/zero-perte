import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'caisse_test.dart' show taperMontant;
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

void main() {
  testWidgets(
    'fournisseur Sika : achat à crédit 50 000 F, paiement 20 000 F en espèces → on lui doit 30 000 F, caisse −20 000 F',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ouvrirCaisse(25000);
        },
      );
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'fournisseurs');
      await attendre(tester, tours: 6);
      await toucher(
        tester,
        find.byKey(const Key('bouton-nouveau-fournisseur')),
      );
      await tester.enterText(
        find.byKey(const Key('champ-nom-fournisseur')),
        'Grossiste Sika',
      );
      await tester.enterText(
        find.byKey(const Key('champ-telephone-fournisseur')),
        '90 00 11 22',
      );
      await attendre(tester);
      await toucher(
        tester,
        find.byKey(const Key('bouton-enregistrer-fournisseur')),
      );
      await attendre(tester, tours: 8);
      await toucher(
        tester,
        find.byKey(const Key('fournisseur-Grossiste Sika')),
      );
      await attendre(tester, tours: 8);

      await toucher(tester, find.byKey(const Key('bouton-achat-credit')));
      await taperMontant(tester, '50000');
      await toucher(
        tester,
        find.byKey(const Key('bouton-valider-montant-page')),
      );
      await attendre(tester, tours: 10);
      expect(
        tester.widget<Text>(find.byKey(const Key('doit-fournisseur'))).data,
        'On lui doit 50 000 F',
      );

      await toucher(tester, find.byKey(const Key('bouton-payer-fournisseur')));
      await taperMontant(tester, '20000');
      await toucher(
        tester,
        find.byKey(const Key('bouton-valider-montant-page')),
      );
      await attendre(tester, tours: 10);
      expect(
        tester.widget<Text>(find.byKey(const Key('doit-fournisseur'))).data,
        'On lui doit 30 000 F',
      );
      final caisse = await tester.runAsync(
        () => env.journal.mouvementsCaisse(ModePaiement.especes),
      );
      expect(caisse!.attendu, 5000); // 25 000 − 20 000
      final f = (await tester.runAsync(env.etat.fournisseurs))!.single;
      expect(f.telephone, '+228 90 00 11 22');
    },
  );

  testWidgets('payer plus que la dette : refusé', (tester) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await tester.runAsync(() async {
      final id = await env.etat.ajouterFournisseur(nom: 'Sika');
      final f = (await env.etat.fournisseurs()).firstWhere((x) => x.id == id);
      await env.etat.achatFournisseur(f, 10000);
      await expectLater(
        env.etat.payerFournisseur(f, 15000, mode: ModePaiement.especes),
        throwsA(
          isA<ErreurZeroPerte>().having(
            (e) => e.message,
            'message',
            'La boutique doit seulement 10 000 F.',
          ),
        ),
      );
    });
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('fournisseurs sur ${e.key} : rien ne déborde', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          final id = await etat.ajouterFournisseur(nom: 'Grossiste Sika');
          final f = (await etat.fournisseurs()).firstWhere((x) => x.id == id);
          await etat.achatFournisseur(f, 125000);
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'fournisseurs');
      await attendre(tester, tours: 6);
      expect(tester.takeException(), isNull);
      await toucher(
        tester,
        find.byKey(const Key('fournisseur-Grossiste Sika')),
      );
      await attendre(tester, tours: 8);
      expect(tester.takeException(), isNull);
    });
  }
}
