// Audit 0.37 : les calculs que le patron regarde (stock gros/détail,
// bénéfice, caisse en espèces seulement, crédits et remboursements partiels,
// très gros montants, passage de minuit).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/quantites.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../ecrans/refonte_036_test.dart' show boutiqueVide;
import '../support/outils.dart';

Panier _panier(Produit p, {Conditionnement? c, int nombre = 1}) => Panier()
  ..ajouter(
    LignePanier(
      produitId: p.id,
      nomProduit: p.nom,
      uniteBase: p.uniteBase,
      conditionnement: c,
      nombre: nombre,
      prixUnitaire: c?.prixVente ?? p.prixUnitaire,
    ),
  );

Future<Produit> _lait(EtatApplication etat) async {
  final p = await etat.creerProduit(
    nom: 'Lait',
    uniteBase: 'boîte',
    prixVente: 550,
    prixAchat: 450,
    conditionnements: const [('carton de 24', 24, 12000)],
  );
  // Arrivage : 2 cartons payés 21 600 F (450 F la boîte).
  await etat.enregistrerArrivage(
    produit: p,
    conditionnement: etat.grosDe(p.id).first,
    nombre: 2,
    coutTotal: 21600,
  );
  return p;
}

void main() {
  testWidgets('gros et détail : stock, vendu et bénéfice justes', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueVide);
    final etat = env.etat;
    await tester.runAsync(() async {
      final lait = await _lait(etat);
      final carton = etat.grosDe(lait.id).first;
      expect(etat.stock(lait.id), 48 * milliemesParUnite);
      expect(etat.stockLisible(lait), '2 cartons de 24');
      await etat.vendre(
        _panier(lait, c: carton),
        mode: ModePaiement.especes,
        montantRecu: 12000,
      );
      await etat.vendre(
        _panier(lait, nombre: 2),
        mode: ModePaiement.especes,
        montantRecu: 1100,
      );
      expect(etat.stock(lait.id), 22 * milliemesParUnite);
      expect(etat.stockLisible(lait), '22 boîtes');
      final r = await etat.resumeJour();
      expect(r.vendu, 13100);
      expect(r.nombreVentes, 2);
      // Carton : 12 000 − 24 × 450 = 1 200 ; détail : 2 × (550 − 450) = 200.
      expect(r.benefice.benefice, 1400);
      expect(r.benefice.lignesSansCout, 0);
    });
  });

  testWidgets(
    'caisse : seules les espèces comptent ; crédit et remboursements partiels',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      final etat = env.etat;
      await tester.runAsync(() async {
        final lait = await _lait(etat);
        final carton = etat.grosDe(lait.id).first;
        await etat.ouvrirCaisse(5000);
        await etat.vendre(
          _panier(lait, c: carton),
          mode: ModePaiement.especes,
          montantRecu: 12000,
        );
        await etat.vendre(_panier(lait, nombre: 2), mode: ModePaiement.flooz);
        final kodjo = await etat.enregistrerClient(
          nom: 'Kodjo',
          telephone: '90 12 34 56',
        );
        await etat.vendre(
          _panier(lait, nombre: 2),
          mode: ModePaiement.credit,
          clientId: kodjo,
        );
        Future<Client> leClient() async =>
            (await etat.clients()).firstWhere((c) => c.id == kodjo);
        expect((await leClient()).solde, 1100);
        // Deux remboursements partiels : 300 F en espèces, 200 F par Flooz.
        await etat.rembourser(
          await leClient(),
          300,
          mode: ModePaiement.especes,
        );
        await etat.rembourser(await leClient(), 200, mode: ModePaiement.flooz);
        expect((await leClient()).solde, 600);
        expect(await etat.journal.totalCredits(), 600);
        await etat.depenser(1000, motif: 'Transport', mode: ModePaiement.especes);
        final c = await etat.etatCaisse();
        // 5 000 + 12 000 + 300 − 1 000 ; le Flooz et le crédit à part.
        expect(c.attendus[ModePaiement.especes], 16300);
        expect(c.attendus[ModePaiement.flooz], 1300);
        // Le vendu du jour compte toutes les ventes (crédit compris).
        expect((await etat.resumeJour()).vendu, 14200);
        // Fermeture avec 300 F de moins : le patron voit le manque.
        await etat.fermerCaisse({
          ModePaiement.especes: 16000,
          ModePaiement.flooz: 1300,
        });
        final r = await etat.resumeJour();
        expect(r.caisse, EtatCaisseResume.manque);
        expect(r.ecartEspeces, -300);
      });
    },
  );

  testWidgets('très gros montants : pas de débordement, affichage lisible', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueVide);
    final etat = env.etat;
    await tester.runAsync(() async {
      final ciment = await etat.creerProduit(
        nom: 'Ciment',
        uniteBase: 'sac',
        prixVente: 5500,
        prixAchat: 5000,
      );
      await etat.enregistrerArrivage(
        produit: ciment,
        nombre: 20000,
        coutTotal: 100000000,
      );
      await etat.vendre(
        _panier(ciment, nombre: 19999),
        mode: ModePaiement.especes,
        montantRecu: 109994500,
      );
      final r = await etat.resumeJour();
      expect(r.vendu, 109994500);
      expect(r.benefice.benefice, 19999 * 500);
      expect(
        formatFrancs(r.vendu).replaceAll(RegExp(r'\s'), ' '),
        '109 994 500 F',
      );
      expect(etat.stockLisible(ciment), '1 sac');
    });
  });

  testWidgets('à minuit, l\'accueil du patron repart à zéro tout seul', (
    tester,
  ) async {
    var heure = DateTime(2026, 11, 24, 23, 59, 30);
    final env = await environnementDeTest(
      tester,
      preparer: boutiqueVide,
      horloge: () => heure.millisecondsSinceEpoch,
    );
    final etat = env.etat..maintenant = (() => heure);
    await tester.runAsync(() async {
      final lait = await _lait(etat);
      await etat.vendre(
        _panier(lait, nombre: 2),
        mode: ModePaiement.especes,
        montantRecu: 1100,
      );
    });
    await afficherApp(tester, etat, taille: const Size(412, 915));
    await attendre(tester, tours: 10);
    String vendu() =>
        tester.widget<Text>(find.byKey(const Key('resume-ventes'))).data!;
    expect(vendu(), contains(formatFrancs(1100)));
    heure = DateTime(2026, 11, 25, 0, 0, 5);
    await tester.pump(const Duration(seconds: 40));
    await attendre(tester, tours: 6);
    expect(vendu(), isNot(contains(formatFrancs(1100))));
    expect(vendu(), contains(formatFrancs(0)));
  });
}
