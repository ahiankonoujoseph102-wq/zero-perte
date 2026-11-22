// Journée complète d'une boutique (vérification avant publication) : caisse,
// produit ajouté, prix changé, ventes en espèces / Flooz / Mixx / crédit,
// reçus, retour, devis, dépense, fermeture à l'aveugle, Tableau.
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';

Panier _panier(EtatApplication etat, Map<String, int> quoi) {
  final p = Panier();
  for (final MapEntry(key: nom, value: n) in quoi.entries) {
    final x = etat.produits.firstWhere((p) => p.nom.startsWith(nom));
    p.ajouter(
      LignePanier(
        produitId: x.id,
        nomProduit: x.nom,
        uniteBase: x.uniteBase,
        nombre: n,
        prixUnitaire: x.prixUnitaire,
      ),
    );
  }
  return p;
}

void main() {
  testWidgets('une journée complète, chiffres justes du matin au soir', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueInstallee);
    final etat = env.etat;
    await tester.runAsync(() async {
      await etat.ouvrirCaisse(5000);
      // Produit ajouté puis prix changé.
      final savon = await etat.creerProduit(
        nom: 'Savon Lux',
        uniteBase: 'pièce',
        prixVente: 400,
        prixAchat: 300,
        stockDepart: 20,
      );
      await etat.modifierProduit(savon, prixVente: 450);
      expect(
        etat.produits.firstWhere((p) => p.id == savon.id).prixUnitaire,
        450,
      );

      // Ventes : espèces, Flooz, Mixx, crédit.
      final v1 = await etat.vendre(
        _panier(etat, {'Riz': 2, 'Savon': 1}),
        mode: ModePaiement.especes,
        montantRecu: 5000,
      );
      expect(v1.total, 1650);
      expect(v1.recu, 'A-000001');
      expect(v1.monnaie?.aRendre, 3350);
      final v2 = await etat.vendre(
        _panier(etat, {'Sucre': 1}),
        mode: ModePaiement.flooz,
        reference: 'FL123',
      );
      expect(v2.total, 800);
      final v3 = await etat.vendre(
        _panier(etat, {'Savon': 1}),
        mode: ModePaiement.mixx,
        reference: 'MX456',
      );
      expect(v3.total, 450);
      final kofi = await etat.enregistrerClient(
        nom: 'Kofi',
        telephone: '+22890112233',
        plafond: 10000,
      );
      final v4 = await etat.vendre(
        _panier(etat, {'Riz': 2}),
        mode: ModePaiement.credit,
        clientId: kofi,
      );
      expect(v4.total, 1200);
      expect(await etat.journal.totalCredits(), 1200);
      expect(
        [v1.recu, v2.recu, v3.recu, v4.recu],
        ['A-000001', 'A-000002', 'A-000003', 'A-000004'],
      );

      // Retour : le client rend le savon de la vente en espèces.
      final ventes = await etat.ventesDuJour();
      final vEspeces = ventes.firstWhere(
        (v) => v.donnees['recu'] == 'A-000001',
      );
      await etat.retournerVente(
        vEspeces,
        rendus: {1: 1},
        mode: ModePaiement.especes,
        motif: 'Abîmé',
      );
      expect(etat.stock(savon.id), 19000); // 20 − 1 − 1 + 1

      // Devis (ne bouge ni le stock ni la caisse).
      await etat.creerDevis(_panier(etat, {'Sucre': 3}));

      // Dépense.
      await etat.depenser(500, motif: 'Transport', mode: ModePaiement.especes);

      // Fermeture à l'aveugle : 5 000 + 1 650 − 450 − 500 = 5 700 attendus,
      // le vendeur compte 5 600.
      final f = await etat.fermerCaisse({
        ModePaiement.especes: 5600,
        ModePaiement.flooz: 800,
        ModePaiement.mixx: 450,
      });
      expect(f.resultat(ModePaiement.especes).attendu, 5700);
      expect(f.resultat(ModePaiement.especes).ecart, -100);
      expect(f.resultat(ModePaiement.flooz).ecart, 0);
      expect(f.resultat(ModePaiement.mixx).ecart, 0);

      // Tableau du jour.
      final t = await etat.tableau(Periode.jour);
      expect(t.nombreVentes, 4);
      expect(t.depenses, 500);
      expect(t.credits, 1200);
      expect(t.ventes, greaterThan(0));
    });
  });
}
