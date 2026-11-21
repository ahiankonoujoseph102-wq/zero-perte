import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

/// Boutique avec stock + Yao (client sans téléphone) + Kofi (avec téléphone).
Future<void> boutiqueAvecClients(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  await etat.ouvrirCaisse(0);
  await etat.enregistrerClient(nom: 'Yao');
  await etat.enregistrerClient(nom: 'Kofi', telephone: '90112233');
}

Future<void> riz2kg(WidgetTester tester) async {
  await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
  await toucher(tester, find.byKey(const Key('choix-base')));
  await toucher(tester, find.byKey(const Key('plus-0')));
}

void main() {
  testWidgets(
    'vente en espèces pour Yao (sans téléphone) : client choisi en un toucher, inscrit sur le reçu',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecClients,
      );
      await ouvrirVendre(tester, env);
      await riz2kg(tester);
      // Par défaut : vente sans client.
      expect(find.byKey(const Key('bouton-client-panier')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-client-panier')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('client-Yao')));
      expect(find.byKey(const Key('client-panier')), findsOneWidget);
      expect(find.text('Yao'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-exact')));
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      await attendre(tester, tours: 10);
      await tester.scrollUntilVisible(
        find.byKey(const Key('recu-credit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Client : Yao'), findsOneWidget);
      // Pas de dette pour une vente payée.
      final yao = (await tester.runAsync(env.etat.clients))!
          .firstWhere((c) => c.nom == 'Yao');
      expect(yao.solde, 0);
    },
  );

  testWidgets('client du panier → « Crédit » : déjà choisi à l\'encaissement', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: boutiqueAvecClients,
    );
    await ouvrirVendre(tester, env);
    await riz2kg(tester);
    await toucher(tester, find.byKey(const Key('bouton-client-panier')));
    await attendre(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('client-Kofi')));
    await toucher(tester, find.byKey(const Key('bouton-encaisser')));
    await attendre(tester, tours: 6);
    await toucher(tester, find.byKey(const Key('mode-credit')));
    expect(find.byKey(const Key('client-choisi')), findsOneWidget);
    expect(find.text('Après cette vente, il devra 1 200 F.'), findsOneWidget);
  });

  testWidgets('retirer le client du panier : la vente redevient sans client', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: boutiqueAvecClients,
    );
    await ouvrirVendre(tester, env);
    await riz2kg(tester);
    await toucher(tester, find.byKey(const Key('bouton-client-panier')));
    await attendre(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('client-Yao')));
    await toucher(tester, find.byKey(const Key('client-panier')));
    expect(find.byKey(const Key('bouton-client-panier')), findsOneWidget);
  });

  testWidgets(
    'billets : total 1 200 F → pas de 1 000 F, 2 000 F → rendre 800 F',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecClients,
      );
      await ouvrirVendre(tester, env);
      await riz2kg(tester);
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      expect(find.byKey(const Key('rapide-exact')), findsOneWidget);
      expect(find.byKey(const Key('rapide-1000')), findsNothing);
      expect(find.byKey(const Key('rapide-2000')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('rapide-2000')));
      expect(find.text('800\u00A0F'), findsWidgets); // à rendre
    },
  );

  testWidgets('filtre par catégorie : seulement si plusieurs catégories', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ouvrirCaisse(0);
        final boissons = etat.catalogue.categories.firstWhere(
          (c) => c.id != 'alimentation',
        );
        await etat.ajouterDuCatalogue(
          etat.catalogue.produitsDe([boissons.id]).take(1),
        );
      },
    );
    await ouvrirVendre(tester, env);
    expect(find.byKey(const Key('categorie-tous')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('categorie-alimentation')));
    expect(find.byKey(const Key('vendre-alimentation.riz')), findsOneWidget);
    final autre = env.etat.produits.firstWhere(
      (p) => !(p.catalogueId ?? '').startsWith('alimentation'),
    );
    expect(find.byKey(Key('vendre-${autre.catalogueId}')), findsNothing);
  });

  testWidgets('tableau : barres des 7 derniers jours, aujourd\'hui = 1 200 F', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecClients(etat);
        final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
        await etat.journal.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 2)],
          mode: ModePaiement.especes,
          montantRecu: 1200,
          auteurId: etat.auteurActuel,
        );
      },
    );
    final t = (await tester.runAsync(() => env.etat.tableau(Periode.jour)))!;
    expect(t.septJours, hasLength(7));
    expect(t.septJours.last.$2, 1200);
    expect(t.septJours.take(6).every((j) => j.$2 == 0), isTrue);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('panier avec client sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecClients,
      );
      await ouvrirVendre(tester, env, taille: taille, densite: densite);
      await riz2kg(tester);
      await toucher(tester, find.byKey(const Key('bouton-client-panier')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('client-Yao')));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('client-panier')), findsOneWidget);
    });
  }
}
