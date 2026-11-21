import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/credit/clients.dart';

import '../support/outils.dart';
import 'caisse_test.dart' show taperMontant;
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

/// Boutique avec stock, caisse ouverte, et le client Kofi (plafond 5 000 F).
Future<void> boutiqueAvecKofi(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  await etat.ouvrirCaisse(0);
  await etat.enregistrerClient(
    nom: 'Kofi',
    telephone: '90112233',
    plafond: 5000,
  );
}

/// Panier : [kg] kg de riz, puis « Encaisser » → « Crédit ».
Future<void> panierACredit(WidgetTester tester, int kg) async {
  await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
  await toucher(tester, find.byKey(const Key('choix-base')));
  for (var i = 1; i < kg; i++) {
    await toucher(tester, find.byKey(const Key('plus-0')));
  }
  await toucher(tester, find.byKey(const Key('bouton-encaisser')));
  await toucher(tester, find.byKey(const Key('mode-credit')));
}

Future<Client> kofi(Environnement env) async =>
    (await env.journal.clients()).firstWhere((c) => c.nom == 'Kofi');

void main() {
  testWidgets(
    'vente à crédit : 3 kg de riz pour Kofi → il doit 1 800 F, rien en caisse, reçu « À crédit »',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueAvecKofi);
      await ouvrirVendre(tester, env);
      await panierACredit(tester, 3);

      // Sans client : impossible de valider.
      FilledButton valider() => tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('bouton-valider-vente')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(valider().onPressed, isNull);

      await toucher(tester, find.byKey(const Key('bouton-choisir-client')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('client-Kofi')));
      expect(find.text('Après cette vente, il devra 1 800 F.'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      await attendre(tester, tours: 10);

      await tester.scrollUntilVisible(
        find.byKey(const Key('recu-credit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Client : Kofi — reste à payer : 1 800 F'),
        findsOneWidget,
      );
      final k = (await tester.runAsync(() => kofi(env)))!;
      expect(k.solde, 1800);
      final caisse = await tester.runAsync(() => env.journal.caisseEnCours());
      expect(caisse!.values.every((m) => m.ventes == 0), isTrue);
    },
  );

  testWidgets('plafond : Kofi doit déjà 4 500 F → 2 kg (1 200 F) bloqués', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecKofi(etat);
        final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
        final k = (await etat.journal.clients()).single;
        await etat.journal.enregistrerVente(
          lignes: [LigneDemandee.auMontant(produitId: riz.id, montant: 4500)],
          mode: ModePaiement.credit,
          clientId: k.id,
          auteurId: etat.auteurActuel,
        );
      },
    );
    await ouvrirVendre(tester, env);
    await panierACredit(tester, 2);
    await toucher(tester, find.byKey(const Key('bouton-choisir-client')));
    await attendre(tester, tours: 8);
    expect(find.text('Peut encore prendre 500 F'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('client-Kofi')));
    expect(
      find.text('Plafond dépassé : il peut encore prendre 500 F.'),
      findsOneWidget,
    );
    final bouton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('bouton-valider-vente')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(bouton.onPressed, isNull);
  });

  testWidgets(
    'Kofi doit 1 800 F, rembourse 1 000 F en espèces → reste 800 F, reçu envoyé, caisse +1 000 F',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecKofi(etat);
          final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
          final k = (await etat.journal.clients()).single;
          await etat.journal.enregistrerVente(
            lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 3)],
            mode: ModePaiement.credit,
            clientId: k.id,
            auteurId: etat.auteurActuel,
          );
        },
      );
      await afficherApp(tester, env.etat);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      expect(find.text('Doit 1 800 F'), findsOneWidget);
      expect(find.byKey(const Key('total-credits')), findsOneWidget);

      await toucher(tester, find.byKey(const Key('client-Kofi')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-rembourse')));
      await taperMontant(tester, '1000');
      await toucher(
        tester,
        find.byKey(const Key('bouton-valider-montant-page')),
      );
      await attendre(tester, tours: 12);

      expect(find.byKey(const Key('recu-remboursement')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('reste-a-payer'))).data,
        '800 F',
      );
      await toucher(tester, find.byKey(const Key('bouton-envoyer-recu')));
      for (var i = 0; i < 6 && env.partages.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await attendre(tester);
      }
      expect(
        env.partages.single.$2,
        'Boutique Mama Ama : Kofi a remboursé 1 000 F. '
        'Reste à payer : 800 F. Merci !',
      );
      final especes = await tester.runAsync(
        () => env.journal.mouvementsCaisse(ModePaiement.especes),
      );
      expect(especes!.remboursementsCredits, 1000);
      expect(especes.attendu, 1000);

      // Retour à la fiche : 800 F, historique à jour.
      await toucher(tester, find.byKey(const Key('bouton-fin-remboursement')));
      await attendre(tester, tours: 8);
      expect(find.text('Doit 800 F'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('− 1\u202F000\u00A0F'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('− 1 000 F'), findsOneWidget);
    },
  );

  testWidgets('« Rappeler » ouvre WhatsApp avec le message au bon numéro', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecKofi(etat);
        final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
        final k = (await etat.journal.clients()).single;
        await etat.journal.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
          mode: ModePaiement.credit,
          clientId: k.id,
          auteurId: etat.auteurActuel,
        );
      },
    );
    await afficherApp(tester, env.etat);
    await toucher(tester, find.byKey(const Key('bouton-credit')));
    await attendre(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('client-Kofi')));
    await attendre(tester, tours: 8);
    await toucher(tester, find.byKey(const Key('bouton-rappeler')));
    final lien = env.liens.single;
    expect(lien.host, 'wa.me');
    expect(lien.path, '/22890112233');
    expect(
      lien.queryParameters['text'],
      'Bonjour Kofi, petit rappel de Boutique Mama Ama : il reste 600 F à payer. Merci !',
    );
  });

  testWidgets(
    'nouveau client par un vendeur : plafond fixé à 5 000 F, pas de choix',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.verifierPin(etat.vendeurs.first, '5913');
        },
      );
      await afficherApp(tester, env.etat);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-nouveau-client')));
      await tester.enterText(find.byKey(const Key('champ-nom-client')), 'Afi');
      await tester.enterText(
        find.byKey(const Key('champ-telephone-client')),
        '+228 91 22 33 44',
      );
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('bouton-photo-client')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('plafond-fixe')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('plafond-fixe')), findsOneWidget);
      expect(find.byKey(const Key('plafond-20000')), findsNothing);
      await toucher(tester, find.byKey(const Key('bouton-enregistrer-client')));
      await attendre(tester, tours: 10);
      final afi = (await tester.runAsync(env.journal.clients))!.single;
      expect(afi.plafond, 5000);
      expect(afi.telephone, '+228 91 22 33 44');
      expect(afi.photo, isNotNull);
      expect(find.text('Ne doit rien'), findsOneWidget);
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('crédit sur ${e.key} : rien ne déborde', (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueAvecKofi);
      await ouvrirVendre(tester, env, taille: taille, densite: densite);
      await panierACredit(tester, 1);
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('bouton-choisir-client')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('client-Kofi')));
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await attendre(tester);
      await tester.pageBack();
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('client-Kofi')));
      await attendre(tester, tours: 8);
      expect(tester.takeException(), isNull);
      expect(find.byType(PageClient), findsOneWidget);
    });
  }

  testWidgets('tableau du patron : « Les clients doivent » 1 800 F', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecKofi(etat);
        final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
        final k = (await etat.journal.clients()).single;
        await etat.journal.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 3)],
          mode: ModePaiement.credit,
          clientId: k.id,
          auteurId: etat.auteurActuel,
        );
      },
    );
    final t = await tester.runAsync(() => env.etat.tableau(Periode.jour));
    expect(t!.credits, 1800);
    expect(t.ventes, 1800); // une vente à crédit reste une vente
  });
}
