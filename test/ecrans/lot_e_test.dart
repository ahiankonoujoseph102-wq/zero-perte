// Lot E : devis (facture proforma), retours partiels, rapports.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/clavier_montant.dart';
import 'package:zero_perte/ecrans/vente/page_vendre.dart';

import '../support/outils.dart';
import 'credit_test.dart' show boutiqueAvecKofi;
import 'synchronisation_test.dart' show FauxRelais;
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

/// Panier : [kgRiz] kg de riz (600 F) et [paquetsSucre] paquets de sucre (800 F).
Panier panier(EtatApplication etat, {int kgRiz = 0, int paquetsSucre = 0}) {
  final p = Panier();
  final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
  final sucre = etat.produits.firstWhere((p) => p.nom.startsWith('Sucre'));
  if (kgRiz > 0) {
    p.ajouter(
      LignePanier(
        produitId: riz.id,
        nomProduit: riz.nom,
        uniteBase: riz.uniteBase,
        nombre: kgRiz,
        prixUnitaire: riz.prixUnitaire,
      ),
    );
  }
  if (paquetsSucre > 0) {
    p.ajouter(
      LignePanier(
        produitId: sucre.id,
        nomProduit: sucre.nom,
        uniteBase: sucre.uniteBase,
        nombre: paquetsSucre,
        prixUnitaire: sucre.prixUnitaire,
      ),
    );
  }
  return p;
}

/// Ouvre « Ventes du jour » puis la vente [recu], puis « Retour ».
Future<void> ouvrirRetour(WidgetTester tester, String recu) async {
  await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
  await toucher(tester, find.byKey(Key('vente-$recu')));
  await toucher(tester, find.byKey(const Key('bouton-retour')));
  await attendre(tester, tours: 6);
}

void main() {
  // ---------------------------------------------------------------------------
  // Retours partiels
  // ---------------------------------------------------------------------------

  testWidgets('retour partiel : sur 3 kg de riz + 2 sucres (3 400 F), le client rend 1 kg '
      'et 1 sucre → 1 400 F rendus, stock et caisse justes', (tester) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ouvrirCaisse(5000);
        await etat.vendre(
          panier(etat, kgRiz: 3, paquetsSucre: 2),
          mode: ModePaiement.especes,
          montantRecu: 3400,
        );
      },
    );
    final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
    expect(env.etat.stock(riz.id), 97000);

    await ouvrirVendre(tester, env);
    await ouvrirRetour(tester, 'A-000001');
    expect(find.text('Choisissez ce qui revient'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('retour-plus-0')));
    await toucher(tester, find.byKey(const Key('retour-plus-1')));
    expect(
      tester
          .widget<MontantGeant>(find.byKey(const Key('total-retour')))
          .montant,
      1400,
    );
    // Sans motif : impossible de valider.
    final bouton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('bouton-valider-retour')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(bouton.onPressed, isNull);
    await toucher(tester, find.byKey(const Key('motif-retour-Produit abîmé')));
    await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
    await attendre(tester, tours: 10);

    expect(
      tester
          .widget<MontantGeant>(find.byKey(const Key('retour-a-rendre')))
          .montant,
      1400,
    );
    expect(env.voix.phrases.last, startsWith('Retour enregistré. Rendez'));
    // Le reçu du retour dit ce qui est RENDU (1 kg), pas ce qui était vendu.
    expect(find.text('Rendu : 1 kg de Riz'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('bouton-envoyer-recu-retour')));
    await attendre(tester, tours: 10);
    expect(
      env.partages.last.$2,
      'Retour sur le reçu n° A-000001 – Boutique Mama Ama : '
      '${formatFrancs(1400)} rendus.',
    );

    expect(env.etat.stock(riz.id), 98000); // 97 kg + 1 kg rendu
    await tester.runAsync(() async {
      final caisse = await env.journal.mouvementsCaisse(ModePaiement.especes);
      expect(caisse.fondsDeCaisse, 5000);
      expect(caisse.ventes, 2000); // 3 400 − 1 400
      expect(caisse.attendu, 7000);

      // Rapport du jour : ventes nettes, retours, bénéfice du riz gardé.
      final r = await env.etat.rapport(Periode.jour);
      expect(r.ventes, 2000);
      expect(r.nombreVentes, 1);
      expect(r.retours, 1400);
      // Riz : 2 kg gardés, vendus 1 200 F, achetés 500 F le kg → 200 F
      // (le sucre, sans prix d'achat, n'est pas compté).
      expect(r.benefice, 200);

      // Rendre encore 3 kg : refusé (il n'en reste que 2).
      final vente = (await env.etat.ventesDuJour()).single;
      await expectLater(
        env.etat.retournerVente(
          vente,
          rendus: {0: 3},
          mode: ModePaiement.especes,
          motif: 'Erreur',
        ),
        throwsA(
          isA<ErreurZeroPerte>().having(
            (e) => e.message,
            'message',
            'On ne peut rendre que 2 de cet article.',
          ),
        ),
      );
      // Annuler toute la vente après un retour : refusé (sinon double compte).
      await expectLater(
        env.etat.annulerVente(vente, 'Erreur en tapant la vente'),
        throwsA(isA<ErreurZeroPerte>()),
      );
      // Le reste peut revenir : 2 kg + 1 sucre = 2 000 F.
      await env.etat.retournerVente(
        vente,
        rendus: {0: 2, 1: 1},
        mode: ModePaiement.especes,
        motif: 'Le client a changé d\'avis',
      );
      expect(
        (await env.journal.mouvementsCaisse(ModePaiement.especes)).ventes,
        0,
      );
    });
    expect(env.etat.stock(riz.id), 100000);
  });

  testWidgets(
    'retour sur une vente à crédit : la dette baisse, aucune caisse ne bouge',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecKofi(etat);
          final kofi = (await etat.journal.clients()).single;
          final p = panier(etat, kgRiz: 3)..choisirClient(kofi.id, kofi.nom);
          await etat.vendre(p, mode: ModePaiement.credit, clientId: kofi.id);
        },
      );
      await ouvrirVendre(tester, env);
      await ouvrirRetour(tester, 'A-000001');
      expect(
        find.text('Vente à crédit : ce que le client doit va diminuer.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('retour-mode-especes')), findsNothing);
      await toucher(tester, find.byKey(const Key('retour-plus-0')));
      await toucher(
        tester,
        find.byKey(const Key('motif-retour-Mauvais produit')),
      );
      await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
      await attendre(tester, tours: 10);
      expect(find.text('Le crédit du client diminue de'), findsOneWidget);
      expect(env.voix.phrases.last, 'Retour enregistré.');

      await tester.runAsync(() async {
        final kofi = (await env.journal.clients()).single;
        expect(await env.journal.soldeClient(kofi.id), 1200); // 1 800 − 600
        expect(
          (await env.journal.mouvementsCaisse(ModePaiement.especes)).ventes,
          0,
        );
        await env.etat.rembourser(kofi, 500, mode: ModePaiement.especes);
        final r = await env.etat.rapport(Periode.jour);
        expect(r.creditAccorde, 1200);
        expect(r.creditRembourse, 500);
        expect(r.creditsDus, 700);
        expect(r.ventes, 1200);
      });
    },
  );

  testWidgets(
    'retour de 28 000 F par le vendeur : le code du patron est demandé ; '
    'le patron est prévenu',
    (tester) async {
      final relais = FauxRelais();
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.journal.ecrireParametre('relais.jeton', 'jeton-test');
          etat.transportAlertes = relais;
          etat.deconnecter();
          await etat.connecterParCode('5913');
          await etat.ouvrirCaisse(30000);
          final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
          final sac = (await etat.journal.conditionnements(riz.id))
              .firstWhere((c) => c.nom == 'sac de 50 kg');
          final p = Panier()
            ..ajouter(
              LignePanier(
                produitId: riz.id,
                nomProduit: riz.nom,
                uniteBase: riz.uniteBase,
                conditionnement: sac,
                nombre: 1,
                prixUnitaire: sac.prixVente,
              ),
            );
          await etat.vendre(p, mode: ModePaiement.especes, montantRecu: 28000);
        },
      );
      expect(env.etat.utilisateurActuel!.nom, 'Kossi');
      await ouvrirVendre(tester, env);
      await ouvrirRetour(tester, 'A-000001');
      await toucher(tester, find.byKey(const Key('retour-plus-0')));
      expect(find.byKey(const Key('retour-accord-patron')), findsOneWidget);
      await toucher(
        tester,
        find.byKey(const Key('motif-retour-Produit abîmé')),
      );
      await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
      // Code du patron : un faux code ne passe pas.
      await taperPin(tester, '111111');
      expect(find.byKey(const Key('retour-a-rendre')), findsNothing);
      await taperPin(tester, '482713');
      await attendre(tester, tours: 10);
      expect(
        tester
            .widget<MontantGeant>(find.byKey(const Key('retour-a-rendre')))
            .montant,
        28000,
      );
      // Toujours Kossi aux commandes (l'accord ne connecte pas le patron).
      expect(env.etat.utilisateurActuel!.nom, 'Kossi');
      await tester.runAsync(() async {
        final r = (await env.journal.retours()).single;
        expect(r.donnees['accord'], env.etat.patron!.id);
        expect(r.auteurId, env.etat.vendeurs.single.id);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      expect(relais.recues.single.$2.type, 'retour');
      expect(
        relais.recues.single.$2.message,
        contains('Kossi a fait un retour sur la vente A-000001'),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Devis
  // ---------------------------------------------------------------------------

  testWidgets(
    'devis de 2 kg de riz (1 200 F) : ni stock ni caisse ; envoyé ; le prix '
    'passe à 650 F ; transformé le jour même au prix du devis (1 200 F)',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ouvrirCaisse(0);
        },
      );
      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      await ouvrirVendre(tester, env);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('plus-0')));
      await toucher(tester, find.byKey(const Key('bouton-devis')));
      await attendre(tester, tours: 8);
      expect(find.text('Devis DV-A-0001'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton-envoyer-devis')));
      await attendre(tester, tours: 10);
      expect(
        env.partages.last.$2,
        'Devis n° DV-A-0001 – Boutique Mama Ama : ${formatFrancs(1200)}. '
        'Valable 7 jours.',
      );
      expect(env.etat.stock(riz.id), 100000);
      await tester.runAsync(() async {
        expect(
          (await env.journal.mouvementsCaisse(ModePaiement.especes)).ventes,
          0,
        );
        // Le patron augmente le riz : 650 F le kg.
        final conds = await env.journal.conditionnements(riz.id);
        await env.etat.fixerPrix(riz, 650, {
          for (final c in conds) c: c.prixVente,
        });
      });

      await toucher(tester, find.byKey(const Key('bouton-devis-en-vente')));
      await attendre(tester, tours: 10);
      // Devis encore valable : pas de message, le prix du devis est gardé.
      expect(find.textContaining('Devis expiré'), findsNothing);
      expect(find.byType(PageVendre), findsWidgets);
      await tester.pump(const Duration(seconds: 6)); // le message s'en va
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-exact')));
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      await toucher(tester, find.byKey(const Key('bouton-nouvelle-vente')));
      await attendre(tester, tours: 10);

      expect(env.etat.stock(riz.id), 98000);
      await tester.runAsync(() async {
        final ventes = await env.etat.ventesDuJour();
        expect(ventes.single.recu, 'A-000001');
        expect(ventes.single.total, 1200);
        final devis = await env.journal.devis();
        expect(devis.single.$1.total, 1200);
        expect(devis.single.$2, 'A-000001'); // devis vendu
      });

      // Le patron rouvre le devis : « Déjà vendu », plus de bouton.
      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-devis')));
      expect(find.textContaining('vendu (A-000001)'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('devis-0')));
      await attendre(tester, tours: 6);
      expect(find.byKey(const Key('devis-deja-vendu')), findsOneWidget);
      expect(find.byKey(const Key('bouton-devis-en-vente')), findsNothing);
    },
  );

  testWidgets('devis avec un panier vide : refusé avec un message', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await ouvrirVendre(tester, env);
    await toucher(tester, find.byKey(const Key('bouton-devis')));
    expect(
      find.text('Ajoutez d\'abord les produits du devis.'),
      findsOneWidget,
    );
    final devis = await tester.runAsync(() => env.journal.devis());
    expect(devis, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Rapports
  // ---------------------------------------------------------------------------

  testWidgets('rapport du jour : ventes, retours, dépenses ; semaine et mois ; '
      'envoi en fichier Excel', (tester) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ouvrirCaisse(5000);
        await etat.vendre(
          panier(etat, kgRiz: 3, paquetsSucre: 2),
          mode: ModePaiement.especes,
          montantRecu: 3400,
        );
        final v = (await etat.ventesDuJour()).single;
        await etat.retournerVente(
          v,
          rendus: {1: 1},
          mode: ModePaiement.especes,
          motif: 'Produit abîmé',
        );
        await etat.depenser(
          500,
          motif: 'Transport',
          mode: ModePaiement.especes,
        );
      },
    );
    await afficherApp(tester, env.etat);
    await ouvrirEspacePatron(tester);
    await toucher(tester, find.byKey(const Key('patron-rapports')));
    await attendre(tester, tours: 10);
    String montant(String cle) =>
        tester.widget<Text>(find.byKey(Key(cle))).data!;
    expect(montant('rapport-ventes'), formatFrancs(2600)); // 3 400 − 800
    expect(montant('rapport-retours'), formatFrancs(800));
    expect(montant('rapport-depenses'), formatFrancs(500));

    await toucher(tester, find.byKey(const Key('bouton-export-csv')));
    await attendre(tester, tours: 6);
    final (octets, nom) = env.partages.last;
    expect(nom, startsWith('rapport-jour-'));
    expect(nom, endsWith('.csv'));
    final csv = utf8.decode(octets.sublist(3));
    expect(csv, contains('Ventes (F);2600'));
    expect(csv, contains('Retours rendus (F);800'));
    expect(csv, contains('Dépenses (F);500'));

    // Semaine et mois : mêmes chiffres (tout s'est passé aujourd'hui).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await attendre(tester);
    await toucher(tester, find.byKey(const Key('rapport-semaine')));
    await attendre(tester, tours: 10);
    expect(montant('rapport-ventes'), formatFrancs(2600));
    await toucher(tester, find.byKey(const Key('rapport-mois')));
    await attendre(tester, tours: 10);
    expect(montant('rapport-ventes'), formatFrancs(2600));
    // Mois précédent : rien.
    await toucher(tester, find.byKey(const Key('rapport-precedent')));
    await attendre(tester, tours: 10);
    expect(montant('rapport-ventes'), formatFrancs(0));
  });

  // ---------------------------------------------------------------------------
  // Écrans : rien ne déborde
  // ---------------------------------------------------------------------------

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('retour, devis, rapports sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ouvrirCaisse(0);
          await etat.vendre(
            panier(etat, kgRiz: 3, paquetsSucre: 2),
            mode: ModePaiement.especes,
            montantRecu: 3400,
          );
          await etat.creerDevis(panier(etat, kgRiz: 2));
        },
      );
      await ouvrirVendre(tester, env, taille: taille, densite: densite);
      await ouvrirRetour(tester, 'A-000001');
      await toucher(tester, find.byKey(const Key('retour-plus-0')));
      await toucher(tester, find.byKey(const Key('motif-retour-Autre')));
      expect(tester.takeException(), isNull);
      await toucher(
        tester,
        find.byKey(const Key('motif-retour-Produit abîmé')),
      );
      await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
      await attendre(tester, tours: 10);
      expect(find.byKey(const Key('retour-a-rendre')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-rapports')));
      await attendre(tester, tours: 10);
      expect(tester.takeException(), isNull);
      await toucher(tester, find.byKey(const Key('rapport-mois')));
      await attendre(tester, tours: 10);
      expect(tester.takeException(), isNull);

      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-devis')));
      await toucher(tester, find.byKey(const Key('devis-0')));
      await attendre(tester, tours: 6);
      expect(tester.takeException(), isNull);

      await revenirAccueil(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-retours')));
      expect(find.byKey(const Key('retour-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
