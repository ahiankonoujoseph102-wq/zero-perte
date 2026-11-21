// Captures de la version 0.28 sur les 4 tailles demandées.
// Lancement manuel : flutter test test_captures/v028_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../test/support/outils.dart';
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;
import 'allure_captures_test.dart' show boutiqueVivante, horlogeCaptures;

Future<void> _chargerPolices() async {
  final manifeste =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final famille in manifeste.cast<Map<String, dynamic>>()) {
    final chargeur = FontLoader(famille['family'] as String);
    for (final f in (famille['fonts'] as List).cast<Map<String, dynamic>>()) {
      chargeur.addFont(rootBundle.load(f['asset'] as String));
    }
    await chargeur.load();
  }
}

void main() {
  setUpAll(_chargerPolices);
  const tailles = {
    '4pouces': (Size(320, 568), 2.0),
    'telephone': (Size(412, 915), 2.625),
    'tablette_paysage': (Size(1280, 800), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };
  Future<void> capture(String nom) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('captures/v028/$nom.png'),
  );

  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('0.28 ${e.key}', (tester) async {
      late String recu;
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueVivante(etat);
          await etat.noterAvertissementsInstallation([
            'Peu de place libre (250 Mo) : libérez de la place bientôt.',
            'Pas de voix française : l\'application ne parlera pas.',
          ]);
          final kofi = (await etat.clients()).single;
          final riz = etat.produits.firstWhere(
            (p) => p.catalogueId == 'alimentation.riz',
          );
          // Kofi : 3 kg à crédit aujourd'hui, puis il paie toute sa dette.
          final v = await etat.journal.enregistrerVente(
            lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 3)],
            mode: ModePaiement.credit,
            clientId: kofi.id,
            auteurId: etat.auteurActuel,
          );
          recu = v.recu;
          final dette = await etat.journal.soldeClient(kofi.id);
          await etat.rembourser(kofi, dette, mode: ModePaiement.especes);
          await etat.creerDevis(
            Panier()..ajouter(
              LignePanier(
                produitId: riz.id,
                nomProduit: riz.nom,
                uniteBase: riz.uniteBase,
                nombre: 2,
                prixUnitaire: riz.prixUnitaire,
              ),
            ),
          );
          await etat.rechargerProduits();
        },
        horloge: horlogeCaptures,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await attendre(tester, tours: 10);
      await capture('20_bandeau_avertissements_${e.key}');
      await toucher(
        tester,
        find.byKey(const Key('bouton-avertissements-compris')),
      );

      // Retour sur une vente à crédit déjà payée.
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
      await toucher(tester, find.byKey(Key('vente-$recu')));
      await toucher(tester, find.byKey(const Key('bouton-retour')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('retour-plus-0')));
      await toucher(
        tester,
        find.byKey(const Key('motif-retour-Mauvais produit')),
      );
      await attendre(tester, tours: 4);
      await capture('21_retour_credit_paye_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
      await attendre(tester, tours: 10);
      await capture('22_retour_especes_${e.key}');

      // Devis encore valable.
      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-devis')));
      await toucher(tester, find.byKey(const Key('devis-0')));
      await attendre(tester, tours: 6);
      await capture('23_devis_valable_${e.key}');
    });
  }
}
