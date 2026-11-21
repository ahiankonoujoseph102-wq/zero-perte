import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/inventaire.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'caisse_test.dart' show taperMontant;
import 'credit_test.dart' show boutiqueAvecKofi;
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

/// Riz 100 kg (600 F/kg) ; sucre : 10 paquets (800 F).
Future<void> boutiquePourInventaire(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  final sucre = etat.produits.firstWhere((p) => p.nom.startsWith('Sucre'));
  await etat.enregistrerArrivage(produit: sucre, nombre: 10, coutTotal: 7000);
}

void main() {
  group('tolérance', () {
    test('produit au bol : 2 % d\'écart → toléré ; au kg → il manque', () {
      expect(
        etatLigne(attendu: 100000, compte: 98000, tolerance: true),
        EtatLigneInventaire.tolere,
      );
      expect(
        etatLigne(attendu: 100000, compte: 98000, tolerance: false),
        EtatLigneInventaire.manque,
      );
      expect(
        etatLigne(attendu: 100000, compte: 90000, tolerance: true),
        EtatLigneInventaire.manque,
      );
      // Limite exacte : 5 % toléré, 6 % non (une seule valeur : 5 %).
      expect(tolerancePourcent, 5);
      expect(
        etatLigne(attendu: 100000, compte: 95000, tolerance: true),
        EtatLigneInventaire.tolere,
      );
      expect(
        etatLigne(attendu: 100000, compte: 94000, tolerance: true),
        EtatLigneInventaire.manque,
      );
      expect(avecTolerance(uniteBase: 'bol', auMontant: false), isTrue);
      expect(avecTolerance(uniteBase: 'kg', auMontant: true), isTrue);
      expect(avecTolerance(uniteBase: 'kg', auMontant: false), isFalse);
    });
  });

  testWidgets(
    'inventaire aveugle : riz compté 90 kg (attendu 100) → il manque 10 kg = 6 000 F ; sucre juste',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiquePourInventaire,
      );
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-inventaire')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('bouton-inventaire-complet')));
      await attendre(tester, tours: 6);
      // Le compteur ne voit jamais l'attendu.
      expect(find.textContaining('100 kg'), findsNothing);
      expect(find.text('Produit 1 sur 2'), findsOneWidget);
      await taperMontant(tester, '90');
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 6);
      await taperMontant(tester, '10');
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 12);

      expect(
        tester.widget<Text>(find.byKey(const Key('inventaire-total'))).data,
        'Marchandise manquante : 6\u202F000\u00A0F',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('inventaire-Riz'))).data,
        'Il manque 10 kg (6\u202F000\u00A0F)',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('inventaire-Sucre en poudre')))
            .data,
        'Juste',
      );
      // Le stock prend la valeur comptée.
      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(env.etat.stock(riz.id), 90000);
      final invs = await tester.runAsync(env.journal.inventaires);
      expect(invs!.single.ecartFrancs, -6000);
    },
  );

  testWidgets(
    '« Ne plus faire crédit » : Kofi est refusé, puis « Refaire crédit »',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueAvecKofi);
      await afficherApp(tester, env.etat);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('client-Kofi')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-credit-arret')));
      await attendre(tester, tours: 8);
      expect(find.text('Plus de crédit (décision du patron)'), findsOneWidget);
      await tester.runAsync(() async {
        final k = (await env.etat.clients()).single;
        final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
        await expectLater(
          env.journal.enregistrerVente(
            lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
            mode: ModePaiement.credit,
            clientId: k.id,
            auteurId: env.etat.auteurActuel,
          ),
          throwsA(
            isA<ErreurZeroPerte>().having(
              (e) => e.message,
              'message',
              'Le patron ne fait plus crédit à Kofi.',
            ),
          ),
        );
      });
      await toucher(tester, find.byKey(const Key('bouton-credit-arret')));
      await attendre(tester, tours: 8);
      expect(find.text('Peut encore prendre 5 000 F'), findsOneWidget);
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('inventaire sur ${e.key} : rien ne déborde', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiquePourInventaire,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-inventaire')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('bouton-inventaire-complet')));
      await attendre(tester, tours: 6);
      expect(tester.takeException(), isNull);
      await taperMontant(tester, '97');
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 12);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('inventaire-total')), findsOneWidget);
    });
  }
}
