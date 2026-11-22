// Produits et prix après l'installation (priorité 1) : ajouter, modifier,
// changer un prix (ancien prix au journal), masquer sans perdre l'historique,
// patron seul.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'vendeurs_test.dart' show ouvrirEspacePatron;

void main() {
  testWidgets('créer avec stock et prix d\'achat ; prix, historique, masquer', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueInstallee);
    final etat = env.etat;
    await tester.runAsync(() async {
      final savon = await etat.creerProduit(
        nom: 'Savon Lux',
        uniteBase: 'pièce',
        prixVente: 400,
        prixAchat: 300,
        seuilAlerteMilliemes: 5000,
        conditionnements: [('carton de 24', 24, 9000)],
        stockDepart: 48,
      );
      expect(savon.prixAchat, 300);
      expect(savon.seuilAlerteMilliemes, 5000);
      expect(etat.stock(savon.id), 48000);
      expect(
        (await etat.journal.conditionnements(savon.id)).single.prixVente,
        9000,
      );
      expect(
        () => etat.creerProduit(
          nom: 'savon lux',
          uniteBase: 'pièce',
          prixVente: 400,
        ),
        throwsA(isA<ErreurZeroPerte>()),
      );
      // Produit sans arrivage : le bénéfice vient du prix d'achat saisi.
      final lait = await etat.creerProduit(
        nom: 'Lait concentré',
        uniteBase: 'boîte',
        prixVente: 500,
        prixAchat: 350,
      );
      final vente = await etat.journal.enregistrerVente(
        lignes: [LigneDemandee.quantite(produitId: lait.id, nombre: 2)],
        mode: ModePaiement.especes,
        montantRecu: 1000,
        auteurId: etat.auteurActuel,
      );
      expect(vente.total, 1000);
      final b = await etat.journal.beneficeEstime(depuis: 0);
      expect(b.benefice, 300);
      // Changement de prix : ancien prix au journal, ventes passées inchangées.
      await etat.modifierProduit(lait, prixVente: 550);
      final h = await etat.journal.historiquePrix(lait.id);
      expect([for (final (_, prix) in h) prix], [500, 550]);
      final ops = await etat.journal.mesOperationsApres(0);
      final derniere = ops.lastWhere(
        (o) => o.type == TypeOperation.produitDefini,
      );
      expect(derniere.donnees['prix_precedent'], 500);
      expect(derniere.donnees['prix_unitaire'], 550);
      expect((await etat.journal.ventesDepuis(0)).single.total, 1000);
      // Masquer : plus dans « Vendre », toujours dans la liste complète.
      await etat.masquerProduit(await etat.journal.produit(lait.id));
      expect(etat.produits.any((x) => x.id == lait.id), isFalse);
      expect(
        (await etat.tousLesProduits()).any((x) => x.id == lait.id && !x.actif),
        isTrue,
      );
      expect((await etat.journal.ventesDepuis(0)).single.total, 1000);
      // Remettre en vente.
      await etat.masquerProduit(
        await etat.journal.produit(lait.id),
        masquer: false,
      );
      expect(etat.produits.any((x) => x.id == lait.id), isTrue);
    });
  });

  testWidgets('un vendeur ne peut pas changer les produits ni les prix', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueInstallee);
    final etat = env.etat;
    await tester.runAsync(() async {
      await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
      etat.deconnecter();
      expect(await etat.connecterParCode('5913'), isNotNull);
      expect(
        () => etat.creerProduit(nom: 'X', uniteBase: 'pièce', prixVente: 1),
        throwsA(isA<ErreurZeroPerte>()),
      );
      expect(
        () => etat.modifierProduit(etat.produits.first, prixVente: 1),
        throwsA(isA<ErreurZeroPerte>()),
      );
    });
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('Produits et prix sur ${e.key} : ajouter un produit', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'produits');
      expect(tester.takeException(), isNull);
      expect(find.text('Riz'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-ajouter-produit')));
      expect(tester.takeException(), isNull);
      // Les champs plus bas ne sont construits qu'une fois visibles.
      Future<void> saisir(String cle, String texte) async {
        final f = find.byKey(Key(cle));
        if (f.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            f,
            150,
            // Le défilement de la fiche (pas celui d'un champ de texte).
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(f);
        await tester.enterText(f, texte);
        await tester.pump();
      }

      await saisir('champ-nom-produit', 'Savon Lux');
      await saisir('champ-prix-vente', '400');
      await saisir('champ-prix-achat', '300');
      await saisir('champ-stock-depart', '24');
      await attendre(tester);
      await toucher(
        tester,
        find.byKey(const Key('bouton-enregistrer-produit')),
      );
      await attendre(tester, tours: 6);
      expect(tester.takeException(), isNull);
      final savon = env.etat.produits.firstWhere((p) => p.nom == 'Savon Lux');
      expect(savon.prixUnitaire, 400);
      expect(savon.prixAchat, 300);
      expect(env.etat.stock(savon.id), 24000);
      expect(find.text('Savon Lux'), findsOneWidget);
      // Le message « enregistré » disparaît (il couvre le bas de l'écran).
      await tester.pump(const Duration(seconds: 6));
      await attendre(tester);
      // Changer son prix depuis la fiche.
      await toucher(tester, find.byKey(Key('produit-${savon.id}')));
      expect(tester.takeException(), isNull);
      await saisir('champ-prix-vente', '450');
      await toucher(
        tester,
        find.byKey(const Key('bouton-enregistrer-produit')),
      );
      await attendre(tester, tours: 6);
      expect(
        env.etat.produits.firstWhere((p) => p.nom == 'Savon Lux').prixUnitaire,
        450,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
