// Refonte « commerçant » (0.36) : mise à jour depuis la 0.35.2 sans perte,
// démarrage en 3 étapes, vente sans inventaire (produit créé pendant la
// vente, « pas encore compté »), compter petit à petit, gros et détail
// (revendeur, stock lisible), bénéfice, caisse en espèces, récapitulatif
// WhatsApp, démonstration isolée.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/boutique.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/quantites.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';
import 'package:zero_perte/ecrans/patron/ma_boutique.dart';

import '../domaine/licence_test.dart' show codeLicence;
import '../support/outils.dart';
import 'synchronisation_test.dart' show FauxRelais;
import 'vente_test.dart' show ouvrirLaCaisseSiDemande;

/// Boutique minimale : patron, licence, rien d'autre (aucun produit).
Future<void> boutiqueVide(EtatApplication etat) async {
  await etat.activer(codeLicence);
  await etat.enregistrerConfig(etat.config.copie(nom: 'Boutique Mama Ama'));
  await etat.definirPatron(nom: 'Ama', pin: '482713');
  await etat.allerA(EtapeAssistant.termine);
}

LignePanier _ligne(Produit p, {Conditionnement? c, int nombre = 1}) =>
    LignePanier(
      produitId: p.id,
      nomProduit: p.nom,
      uniteBase: p.uniteBase,
      conditionnement: c,
      nombre: nombre,
      prixUnitaire: c?.prixVente ?? p.prixUnitaire,
    );

Future<VenteEnregistree> _vendre(
  EtatApplication etat,
  List<LignePanier> lignes, {
  ModePaiement mode = ModePaiement.especes,
}) {
  final panier = Panier();
  for (final l in lignes) {
    panier.ajouter(l);
  }
  return etat.vendre(
    panier,
    mode: mode,
    montantRecu: mode == ModePaiement.especes ? panier.total : null,
  );
}

void main() {
  testWidgets(
    'mise à jour depuis la 0.35.2 : tout est gardé, pas de démarrage',
    (tester) async {
      final attendu = jsonDecode(
        File('test/fixtures/mise_a_jour/v0.35.2.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final dossier = Directory.systemTemp.createTempSync('zp-0352');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final chemin = '${dossier.path}/base.db';
      File('test/fixtures/mise_a_jour/v0.35.2.db').copySync(chemin);
      final env = await environnementDeTest(tester, chemin: chemin);
      final etat = env.etat;
      await tester.runAsync(() async {
        final j = etat.journal;
        // Les clients existants ne repassent pas par le démarrage.
        expect(etat.etape, EtapeAssistant.termine);
        expect(etat.installationTerminee, isTrue);
        expect(etat.config.nom, attendu['boutique']);
        expect(etat.config.vente, isNull);
        expect(etat.licence, isNotNull);
        expect([for (final v in etat.vendeurs) v.nom], attendu['vendeurs']);
        // Mêmes stocks, mêmes ventes, mêmes crédits, chaîne intacte.
        expect({
          for (final p in etat.produits) p.nom: etat.stock(p.id),
        }, (attendu['stocks'] as Map).cast<String, int>());
        expect(await j.totalCredits(), attendu['credits']);
        final r = await j.resumeVentes(depuis: 0);
        expect(r.total, attendu['ventes']);
        expect(r.nombre, attendu['nombre_ventes']);
        final ops = await j.mesOperationsApres(0);
        expect(ops.length, attendu['operations']);
        expect(ops.last.empreinte, attendu['derniere_empreinte']);
        expect(verifierChaine(ops), isEmpty);
        // Les anciens « emballages » SONT la vente en gros (même nombre d'unités).
        final conds = (attendu['conditionnements'] as Map).cast<String, List>();
        for (final p in etat.produits) {
          expect([
            for (final c in etat.grosDe(p.id))
              [c.nom, c.facteurMilliemes, c.prixVente],
          ], conds[p.nom]);
        }
        // Stock lisible ; « Pain » (vendu, jamais reçu) : pas encore compté.
        final lait = etat.produits.firstWhere((p) => p.nom == 'Lait');
        final pain = etat.produits.firstWhere((p) => p.nom == 'Pain');
        expect(etat.stockLisible(lait), '1 carton de 24 et 22 boîtes');
        expect(etat.stockLisible(pain), 'pas encore compté');
        final t = await etat.tableau(Periode.mois);
        expect(t.stockBas.map((e) => e.$1.nom), isNot(contains('Pain')));
        // On continue à vendre au carton.
        final v = await _vendre(etat, [
          _ligne(lait, c: etat.grosDe(lait.id).first),
        ]);
        expect(v.recu, 'A-000005');
        expect(etat.stockLisible(lait), '22 boîtes');
        // La base n'a pas changé de version (aucune migration de schéma).
        final db = await databaseFactoryFfi.openDatabase(
          chemin,
          options: OpenDatabaseOptions(singleInstance: false, readOnly: true),
        );
        expect(await db.getVersion(), 6);
        await db.close();
      });
      // Pas de démarrage : directement l'écran d'entrée par le code.
      await afficherApp(tester, etat);
      expect(find.byKey(const Key('numero-etape')), findsNothing);
      expect(find.byKey(const Key('bouton-je-suis-vendeur')), findsNothing);
      expect(etat.installationTerminee, isTrue);
    },
  );

  testWidgets(
    'démarrage en 3 étapes : nom, deux questions, code → « Vous pouvez vendre ! »',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.identite,
        preparer: (e) => e.activer(codeLicence),
      );
      await afficherApp(
        tester,
        env.etat,
        taille: const Size(412, 915),
        densite: 2.625,
      );
      expect(find.text('Étape 1 sur 3'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('champ-nom')),
        'Boutique Mama Ama',
      );
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.etape, EtapeAssistant.profil);
      expect(find.text('Étape 2 sur 3'), findsOneWidget);
      expect(find.text('Vous vendez :'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('vente-les_deux')));
      await toucher(tester, find.byKey(const Key('qui-un')));
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.config.vente, FaconDeVendre.lesDeux);
      expect(env.etat.config.quiVend, QuiVend.unVendeur);
      expect(env.etat.etape, EtapeAssistant.codePatron);
      expect(find.text('Étape 3 sur 3'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('champ-nom-patron')), 'Ama');
      await taperPin(tester, '482713');
      await taperPin(tester, '482713');
      expect(env.etat.etape, EtapeAssistant.fin);
      expect(find.byKey(const Key('vous-pouvez-vendre')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-commencer-vendre')));
      expect(find.byType(AccueilVendeur), findsOneWidget);
      // Aucun produit demandé au démarrage ; « À faire » propose la suite.
      expect(env.etat.produits, isEmpty);
      expect(
        env.etat.tachesAFaire.map((t) => t.type),
        containsAll([TypeTache.vendeur, TypeTache.google, TypeTache.telephone]),
      );
      expect(find.byKey(const Key('carte-a-faire')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vendre sans inventaire : le produit se crée pendant la vente', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueVide);
    await afficherApp(tester, env.etat);
    await toucher(tester, find.byKey(const Key('bouton-vendre')));
    await ouvrirLaCaisseSiDemande(tester);
    await toucher(tester, find.byKey(const Key('bouton-nouveau-produit')));
    await tester.pump(const Duration(seconds: 2));
    await tester.enterText(
      find.byKey(const Key('nouveau-produit-nom')),
      'Lait Bonnet Rouge',
    );
    final boite = find.byKey(const Key('nouveau-produit-unite-boîte'));
    await tester.tap(boite);
    await attendre(tester);
    await tester.enterText(
      find.byKey(const Key('nouveau-produit-prix')),
      '550',
    );
    await toucher(tester, find.byKey(const Key('bouton-creer-produit-vente')));
    await attendre(tester, tours: 6);
    // Le produit est dans le panier, prêt à encaisser.
    expect(find.textContaining('Lait Bonnet Rouge'), findsWidgets);
    expect(find.byKey(const Key('total-panier')), findsOneWidget);
    final lait = env.etat.produits.single;
    expect(lait.nom, 'Lait Bonnet Rouge');
    expect(lait.uniteBase, 'boîte');
    expect(env.etat.stockLisible(lait), 'pas encore compté');
    // Vendu sans stock : pas de fausse alerte « épuisé ».
    await tester.runAsync(() => _vendre(env.etat, [_ligne(lait, nombre: 3)]));
    final t = await tester.runAsync(() => env.etat.tableau(Periode.jour));
    expect(t!.stockBas, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un vendeur peut créer un produit qui manque : le patron est prévenu',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      final relais = FauxRelais();
      env.etat.transportAlertes = relais;
      await tester.runAsync(() async {
        await env.journal.ecrireParametre(
          'relais.jeton',
          'jeton-test-0123456789',
        );
        final kossi = await env.etat.ajouterVendeur(nom: 'Kossi', pin: '5927');
        env.etat.deconnecter();
        await env.etat.verifierPin(kossi.vendeur, '5927');
        await env.etat.creerProduit(
          nom: 'Biscuit',
          uniteBase: 'paquet',
          prixVente: 100,
          pendantLaVente: true,
        );
        // L'alerte part en tâche de fond : on lui laisse le temps.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        // Sans « pendant la vente », le vendeur ne peut pas toucher aux produits.
        await expectLater(
          env.etat.creerProduit(
            nom: 'Autre',
            uniteBase: 'pièce',
            prixVente: 50,
          ),
          throwsA(isA<ErreurZeroPerte>()),
        );
      });
      await attendre(tester, tours: 6);
      expect(relais.recues.single.$2.message, contains('Kossi a ajouté'));
      expect(relais.recues.single.$2.message, contains('Biscuit à 100'));
    },
  );

  testWidgets(
    'compter petit à petit : les plus vendus d\'abord, premier comptage sans écart',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await tester.runAsync(() async {
        final e = env.etat;
        final savon = await e.creerProduit(
          nom: 'Savon',
          uniteBase: 'morceau',
          prixVente: 250,
        );
        await e.creerProduit(nom: 'Huile', uniteBase: 'litre', prixVente: 1300);
        final riz = await e.creerProduit(
          nom: 'Riz',
          uniteBase: 'bol',
          prixVente: 500,
        );
        await _vendre(e, [_ligne(savon, nombre: 20)]); // 5 000 F
        await _vendre(e, [_ligne(riz, nombre: 2)]); // 1 000 F
        // Plus vendus d'abord, puis le plus cher (huile, jamais vendue).
        expect((await e.produitsACompter()).map((p) => p.nom), [
          'Savon',
          'Riz',
          'Huile',
        ]);
        expect(e.nombreProduitsComptes, 0);
        // Premier comptage du savon : 40 morceaux. Pas un écart (vendu avant).
        final inv = await e.faireInventaire({savon.id: 40 * milliemesParUnite});
        expect(inv.ecartFrancs, 0);
        expect(inv.lignes.single.premier, isTrue);
        expect(e.stock(savon.id), 40 * milliemesParUnite);
        expect(e.stockLisible(savon), '40 morceaux');
        expect(e.nombreProduitsComptes, 1);
        expect((await e.produitsACompter()).map((p) => p.nom), [
          'Riz',
          'Huile',
        ]);
        // Deuxième comptage : là, un manque est un vrai écart.
        final inv2 = await e.faireInventaire({
          savon.id: 38 * milliemesParUnite,
        });
        expect(inv2.ecartFrancs, -500);
        // Le compte de « À faire ».
        expect(
          e.tachesAFaire
              .firstWhere((t) => t.type == TypeTache.compterStock)
              .detail,
          '1 sur 3 produits comptés',
        );
      });
    },
  );

  testWidgets(
    'gros et détail : carton de 24, revendeur, stock lisible, arrivage en cartons',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await tester.runAsync(() async {
        final e = env.etat;
        final lait = await e.creerProduit(
          nom: 'Lait',
          uniteBase: 'boîte',
          prixVente: 550,
          prixAchat: 450,
          conditionnements: [
            ('carton de 24', 24, 12000),
            (nomRevendeur('carton de 24'), 24, 11500),
          ],
        );
        final gros = e.grosDe(lait.id);
        final carton = gros.firstWhere((c) => !estPrixRevendeur(c));
        final revendeur = gros.firstWhere(estPrixRevendeur);
        // Arrivage : 10 cartons.
        await e.enregistrerArrivage(
          produit: lait,
          conditionnement: carton,
          nombre: 10,
          coutTotal: 108000,
        );
        expect(e.stockLisible(lait), '10 cartons de 24');
        // 1 carton + 2 boîtes : le stock se calcule tout seul.
        final v = await _vendre(e, [
          _ligne(lait, c: carton),
          _ligne(lait, nombre: 2),
        ]);
        expect(v.total, 13100);
        expect(e.stock(lait.id), (240 - 26) * milliemesParUnite);
        expect(e.stockLisible(lait), '8 cartons de 24 et 22 boîtes');
        // Prix revendeur : un carton moins cher, même stock.
        final v2 = await _vendre(e, [_ligne(lait, c: revendeur)]);
        expect(v2.total, 11500);
        expect(e.stockLisible(lait), '7 cartons de 24 et 22 boîtes');
      });
    },
  );

  test(
    'stock lisible : « 3 cartons et 5 boîtes », le revendeur ne compte pas',
    () {
      const carton = Conditionnement.unites(
        id: 'c',
        nom: 'carton',
        unites: 24,
        prixVente: 12000,
      );
      const rev = Conditionnement.unites(
        id: 'r',
        nom: 'carton (revendeur)',
        unites: 24,
        prixVente: 11500,
      );
      expect(
        decrireStock(77000, 'boîte', [carton, rev]),
        '3 cartons et 5 boîtes',
      );
      expect(decrireStock(5000, 'boîte', [carton]), '5 boîtes');
      expect(decrireStock(48000, 'boîte', [carton]), '2 cartons');
      expect(
        stockBas(stock: -3000, seuil: 0, venduSur7Jours: 3000, dejaRecu: false),
        isNull,
      );
      expect(
        stockBas(stock: 0, seuil: 0, venduSur7Jours: 0, dejaRecu: true),
        RaisonStockBas.epuise,
      );
    },
  );

  testWidgets(
    'accueil : bénéfice (ou « Ajoutez le prix d\'achat ») et caisse en espèces',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await tester.runAsync(() async {
        final e = env.etat;
        final pain = await e.creerProduit(
          nom: 'Pain',
          uniteBase: 'pièce',
          prixVente: 100,
        );
        await e.ouvrirCaisse(5000);
        await _vendre(e, [_ligne(pain, nombre: 10)]);
        var r = await e.resumeJour();
        expect(r.vendu, 1000);
        expect(r.beneficeInconnu, isTrue); // ni prix d'achat ni arrivage
        expect(r.caisse, EtatCaisseResume.ouverte);
        final savon = await e.creerProduit(
          nom: 'Savon',
          uniteBase: 'morceau',
          prixVente: 250,
          prixAchat: 190,
        );
        await _vendre(e, [_ligne(savon, nombre: 4)], mode: ModePaiement.mixx);
        r = await e.resumeJour();
        expect(r.beneficeInconnu, isFalse);
        expect(r.benefice.benefice, 240);
        // Fermeture : espèces avec 2 000 F de moins ; Mixx juste. Seules les
        // espèces font « la caisse ».
        final att = (await e.etatCaisse()).attendus;
        await e.fermerCaisse({
          ModePaiement.especes: att[ModePaiement.especes]! - 2000,
          ModePaiement.flooz: 0,
          ModePaiement.mixx: att[ModePaiement.mixx]!,
        });
        r = await e.resumeJour();
        expect(r.caisse, EtatCaisseResume.manque);
        expect(r.ecartEspeces, -2000);
        // Rouverte : le manque du jour reste affiché.
        await e.ouvrirCaisse(0);
        expect((await e.resumeJour()).caisse, EtatCaisseResume.manque);
      });
      await afficherApp(
        tester,
        env.etat,
        taille: const Size(412, 915),
        densite: 2.625,
      );
      await attendre(tester, tours: 10);
      expect(find.textContaining('Caisse : il manque'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('Vendu aujourd\'hui'), findsOneWidget);
    },
  );

  testWidgets(
    'récapitulatif WhatsApp de la fermeture : sans écart pour le vendeur',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await tester.runAsync(() async {
        final e = env.etat;
        final pain = await e.creerProduit(
          nom: 'Pain',
          uniteBase: 'pièce',
          prixVente: 100,
        );
        final kossi = await e.ajouterVendeur(nom: 'Kossi', pin: '5927');
        await e.ouvrirCaisse(1000);
        e.deconnecter();
        await e.verifierPin(kossi.vendeur, '5927');
        await _vendre(e, [_ligne(pain, nombre: 5)]);
        final f = await e.fermerCaisse({
          ModePaiement.especes: 1000,
          ModePaiement.flooz: 0,
          ModePaiement.mixx: 0,
        });
        final vendeur = await e.texteFermeture(f);
        expect(vendeur, contains('par Kossi'));
        expect(vendeur, contains('Compté Espèces'));
        expect(vendeur, isNot(contains('manque')));
        e.deconnecter();
        await e.verifierPin(e.patron!, '482713');
        final patron = await e.texteFermeture(f);
        expect(patron, contains('Espèces : il manque'));
        expect(patron, contains('❌'));
      });
    },
  );

  testWidgets('0.37 : plus aucune démonstration dans l\'application', (
    tester,
  ) async {
    for (final etape in [EtapeAssistant.bienvenue, EtapeAssistant.activation]) {
      final env = await environnementDeTest(tester, etape: etape);
      await afficherApp(tester, env.etat);
      expect(find.byKey(const Key('bouton-voir-exemple')), findsNothing);
      expect(find.byKey(const Key('bouton-demonstration')), findsNothing);
      expect(find.textContaining('démonstration'), findsNothing);
    }
  });

  testWidgets(
    'Gestion → Ma boutique : le téléphone se règle plus tard (Enregistrer → retour)',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await afficherApp(tester, env.etat);
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
      ).push(MaterialPageRoute(builder: (_) => PageMaBoutique(etat: env.etat)));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('ma-boutique-contact')));
      await tester.enterText(
        find.byKey(const Key('champ-telephone')),
        '90123456',
      );
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('champ-ville')));
      await toucher(tester, find.text('Lomé').last);
      expect(find.text('Enregistrer'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      await attendre(tester, tours: 6);
      expect(env.etat.config.telephone, '+228 90 12 34 56');
      // Retour sur « Ma boutique », l'installation n'a pas bougé.
      expect(find.byKey(const Key('ma-boutique-contact')), findsOneWidget);
      expect(env.etat.etape, EtapeAssistant.termine);
      expect(
        env.etat.tachesAFaire.map((t) => t.type),
        isNot(contains(TypeTache.telephone)),
      );
    },
  );
}
