// Scènes 2 à 9 de l'enregistrement d'écran (voir film.dart).
// Lancement : ZP_FILM=<dossier> flutter test --dart-define=ZP_CANAL=officiel test_captures/film/scenes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/patron/compter_stock.dart';

import '../../test/support/faux_relais_invitations.dart';
import '../../test/support/outils.dart';
import 'boutique_film.dart';
import 'film.dart';

Future<Environnement> _boutique(
  WidgetTester tester, {
  FauxRelaisInvitations? relais,
  FauxLecteurQr? lecteur,
  bool avecVendeur = true,
}) async {
  final env = await environnementDeTest(
    tester,
    horloge: horlogeFilm,
    relais: relais,
    lecteur: lecteur,
  );
  await tester.runAsync(() => boutiqueFilm(env.etat, avecVendeur: avecVendeur));
  return env;
}

/// Touche un produit dans Vendre (par son nom), puis Détail ou Gros.
Future<void> _produit(Film f, String nom, {String? gros}) async {
  await f.toucher(find.text(nom).first, pause: 0.6);
  final choix = gros == null
      ? find.byKey(const Key('choix-base'))
      : find.byKey(Key('choix-$gros'));
  if (choix.evaluate().isNotEmpty) await f.toucher(choix, pause: 0.8);
}

/// Tape un montant sur le clavier de l'application.
Future<void> _montant(Film f, String chiffres) async {
  for (final c in chiffres.split('')) {
    await f.cle('montant-$c', pause: 0.15);
  }
  await f.image(0.8);
}

void main() {
  setUpAll(chargerPolices);

  testWidgets('scène 2 : vendre', (tester) async {
    final env = await _boutique(tester);
    final f = Film(tester, '02_vendre');
    await f.ouvrir(env.etat);
    await f.image(2.5);
    await f.cle('bouton-vendre');
    // Ouverture de la caisse (fond de 5 000 F).
    if (find
        .byKey(const Key('bouton-valider-montant-page'))
        .evaluate()
        .isNotEmpty) {
      await _montant(f, '5000');
      await f.cle('bouton-valider-montant-page', pause: 1.5);
    }
    await f.image(2);
    await _produit(f, 'Riz');
    await _produit(f, 'Riz');
    await _produit(f, 'Sucre');
    await _produit(f, 'Lait concentré', gros: 'carton de 24');
    await f.image(2);
    await f.cle('bouton-encaisser', pause: 1.5);
    await _montant(f, '15000');
    await f.image(2);
    await f.cle('bouton-valider-vente', pause: 3);
    await f.cle('bouton-envoyer-recu', pause: 2);
    await f.cle('bouton-nouvelle-vente', pause: 1.5);
    // Un produit qui manque : on l'ajoute pendant la vente.
    await f.cle('vendre-nouveau-produit', pause: 1);
    await f.vivre(1);
    await f.ecrire(find.byKey(const Key('nouveau-produit-nom')), 'Chaussures');
    await f.cle('nouveau-produit-unite-pièce', pause: 0.6);
    await f.ecrire(find.byKey(const Key('nouveau-produit-prix')), '7500');
    await f.cle('bouton-creer-produit-vente', pause: 2);
    await f.cle('bouton-encaisser', pause: 1);
    await f.cle('mode-flooz', pause: 1.5);
    await f.cle('bouton-valider-vente', pause: 2.5);
    await f.cle('bouton-nouvelle-vente', pause: 1);
    await f.cle('bouton-ventes-du-jour', pause: 3);
    f.finir();
  });

  testWidgets('scène 3 : crédit et remboursement', (tester) async {
    final env = await _boutique(tester);
    final f = Film(tester, '03_credit');
    await f.ouvrir(env.etat);
    await f.image(1.5);
    await f.cle('bouton-vendre');
    if (find
        .byKey(const Key('bouton-valider-montant-page'))
        .evaluate()
        .isNotEmpty) {
      await f.cle('bouton-valider-montant-page', pause: 1);
    }
    await _produit(f, 'Lait concentré', gros: 'carton de 24');
    await f.cle('bouton-encaisser', pause: 1);
    await f.cle('mode-credit', pause: 1.2);
    await f.cle('bouton-choisir-client', pause: 1.5);
    await f.cle('client-Afi', pause: 2);
    await f.cle('bouton-valider-vente', pause: 3);
    await f.cle('bouton-nouvelle-vente', pause: 0.8);
    await f.retour();
    await f.cle('bouton-credit', pause: 2.5);
    await f.cle('client-Kofi', pause: 2.5);
    await f.cle('bouton-rembourse', pause: 1);
    await _montant(f, '5000');
    await f.cle('bouton-valider-montant-page', pause: 3);
    await f.cle('bouton-fin-remboursement', pause: 1.5);
    await f.cle('bouton-rappeler', pause: 2);
    await f.retour();
    await f.cle('bouton-nouveau-client', pause: 1);
    await f.ecrire(find.byKey(const Key('champ-nom-client')), 'Yawa');
    await f.ecrire(
      find.byKey(const Key('champ-telephone-client')),
      '92 45 67 89',
    );
    await f.cle('bouton-enregistrer-client', pause: 2.5);
    f.finir();
  });

  testWidgets('scène 4 : la caisse, du matin au soir', (tester) async {
    final env = await _boutique(tester);
    final f = Film(tester, '04_caisse');
    await f.ouvrir(env.etat);
    await f.image(1.5);
    await f.cle('bouton-ma-caisse', pause: 2);
    await f.cle('bouton-ouvrir-caisse', pause: 1);
    await _montant(f, '5000');
    await f.cle('bouton-valider-montant-page', pause: 2);
    // Quelques ventes de la matinée (faites par la boutique).
    await tester.runAsync(() async {
      final e = env.etat;
      heureFilm = DateTime(2026, 11, 25, 10);
      for (final (n, q) in [('Riz', 4), ('Coca-Cola', 6), ('Savon', 3)]) {
        final p = e.produits.firstWhere((x) => x.nom == n);
        heureFilm = heureFilm.add(const Duration(minutes: 30));
        await e.vendre(
          await _panier(e, p, q),
          mode: ModePaiement.especes,
          montantRecu: p.prixUnitaire * q,
        );
      }
    });
    await f.vivre(1);
    await f.cle('bouton-depense', pause: 1);
    await f.cle('choix-depense-argent', pause: 1);
    await _montant(f, '1000');
    await f.toucher(find.byKey(const Key('motif-Transport')), pause: 0.8);
    await f.cle('bouton-valider-montant-page', pause: 2);
    await f.retour();
    await f.cle('bouton-retrait', pause: 1);
    await _montant(f, '2000');
    await f.cle('bouton-valider-montant-page', pause: 2);
    await f.defiler(300);
    await f.defiler(-300);
    // Le soir : fermeture, l'argent est compté sans voir l'attendu.
    await f.cle('bouton-fermer-caisse', pause: 1.5);
    await _montant(f, '6050');
    await f.cle('bouton-suivant-fermeture', pause: 3.5);
    for (var i = 0; i < 2; i++) {
      if (find
          .byKey(const Key('bouton-suivant-fermeture'))
          .evaluate()
          .isNotEmpty) {
        await f.cle('montant-0', pause: 0.3);
        await f.cle('bouton-suivant-fermeture', pause: 2);
      }
    }
    await f.defiler(250);
    await f.cle('bouton-envoyer-fermeture', pause: 2);
    await f.cle('bouton-fin-fermeture', pause: 1);
    await revenirAccueil(tester);
    await f.vivre(1);
    await f.image(3.5);
    f.finir();
  });

  testWidgets('scène 5 : gestion', (tester) async {
    final env = await _boutique(tester);
    final f = Film(tester, '05_gestion');
    await f.ouvrir(env.etat);
    await f.image(1);
    await f.cle('bouton-espace-patron', pause: 2.5);
    await f.defiler(500);
    await f.defiler(-500);
    for (final (cle, actions) in <(String, Future<void> Function())>[
      (
        'patron-arrivages',
        () async {
          await f.toucher(find.text('Coca-Cola').first, pause: 1);
          final casier = find.byKey(const Key('unite-casier de 24'));
          if (casier.evaluate().isNotEmpty) await f.toucher(casier, pause: 0.6);
          await f.cle('plus', pause: 0.3);
          await f.ecrire(find.byKey(const Key('champ-cout')), '17600');
          await f.cle('bouton-enregistrer-arrivage', pause: 2);
        },
      ),
      (
        'patron-compter-stock',
        () async {
          await f.defiler(200);
        },
      ),
      (
        'patron-produits',
        () async {
          await f.toucher(find.text('Riz').first, pause: 2);
          await f.defiler(600);
          await f.retour();
        },
      ),
      ('patron-inventaire', () async {}),
      ('patron-fermetures', () async {}),
      ('patron-fournisseurs', () async {}),
      ('patron-retrait', () async {}),
      ('patron-retours', () async {}),
      ('patron-devis', () async {}),
      ('patron-vendeurs', () async {}),
      ('patron-appareils', () async {}),
      (
        'patron-ma-boutique',
        () async {
          await f.defiler(500);
        },
      ),
      ('patron-a-faire', () async {}),
      ('patron-synchro', () async {}),
      ('patron-sauvegarde', () async {}),
    ]) {
      if (await f.cle(cle, pause: 2.5)) {
        await actions();
        await f.retour();
      }
    }
    await f.page(PageCompterStock(etat: env.etat), pause: 0.5);
    f.finir();
  });

  testWidgets('scène 6 : mon bénéfice', (tester) async {
    final env = await _boutique(tester);
    await _ventesDuMatin(tester, env.etat);
    final f = Film(tester, '06_benefice');
    await f.ouvrir(env.etat);
    await f.image(1);
    await f.cle('accueil-chiffres', pause: 3);
    await f.defiler(500);
    await f.defiler(500);
    await f.defiler(-1000);
    await f.cle('periode-semaine', pause: 2.5);
    await f.cle('periode-mois', pause: 2.5);
    await f.defiler(600);
    final commander = find.byKey(const Key('bouton-commander'));
    if (commander.evaluate().isNotEmpty) {
      await f.toucher(commander, pause: 2);
      await f.retour();
    }
    await f.defiler(-600);
    await f.cle('onglet-rapport', pause: 3);
    await f.defiler(400);
    f.finir();
  });

  testWidgets('scène 7 : ajouter un vendeur (patron)', (tester) async {
    final relais = FauxRelaisInvitations();
    final env = await _boutique(tester, relais: relais, avecVendeur: false);
    await tester.runAsync(() async {
      await env.etat.connecterSynchro();
      await env.etat.synchroniser();
    });
    final f = Film(tester, '07_ajouter_vendeur');
    await f.ouvrir(env.etat);
    await f.image(1.5);
    if (!await f.cle('bouton-ajouter-mon-vendeur', pause: 1.5)) {
      await f.cle('bouton-espace-patron', pause: 1);
      await f.cle('patron-ajouter-vendeur', pause: 1.5);
    }
    await f.ecrire(find.byKey(const Key('champ-prenom-vendeur')), 'Kossi');
    await f.cle('bouton-continuer-vendeur', pause: 0.5);
    for (var i = 0; i < 10; i++) {
      await attendre(tester, tours: 2);
      if (find.byKey(const Key('qr-invitation')).evaluate().isNotEmpty) break;
    }
    await f.image(5);
    await f.cle('lien-pas-appareil-photo', pause: 3.5);
    f.finir();
  });

  testWidgets('scène 8 : le vendeur', (tester) async {
    final relais = FauxRelaisInvitations();
    final patron = await _boutique(tester, relais: relais, avecVendeur: false);
    await tester.runAsync(() async {
      await patron.etat.connecterSynchro();
      await patron.etat.synchroniser();
    });
    final qr = await tester.runAsync(() async {
      final p = await patron.etat.preparerInvitation('Kossi');
      return (await patron.etat.publierQr(p)).texte;
    });
    final kossi = await environnementDeTest(
      tester,
      relais: relais,
      drive: patron.drive,
      lecteur: FauxLecteurQr(lire: () async => qr),
    );
    final f = Film(tester, '08_vendeur');
    await f.ouvrir(kossi.etat);
    await f.image(2.5);
    await f.cle('bouton-je-suis-vendeur', pause: 2);
    await f.cle('bouton-scanner-qr', pause: 0.5);
    for (var i = 0; i < 10; i++) {
      await attendre(tester, tours: 3);
      if (find.byKey(const Key('bienvenue-vendeur')).evaluate().isNotEmpty) {
        break;
      }
    }
    await f.vivre(1);
    await f.image(4);
    final suite = find.byKey(const Key('bouton-continuer-vendeur'));
    if (suite.evaluate().isNotEmpty) await f.toucher(suite, pause: 2);
    await f.vivre(1);
    await f.image(3);
    f.finir();
  });

  testWidgets('scène 9 : sur PC et tablette', (tester) async {
    final env = await _boutique(tester);
    await _ventesDuMatin(tester, env.etat);
    final f = Film(tester, '09_pc', taille: const Size(1366, 768));
    await f.ouvrir(env.etat);
    await f.image(4);
    await f.defiler(400);
    await f.defiler(-400);
    for (final c in [
      'bouton-vendre',
      'bouton-ma-caisse',
      'bouton-credit',
      'menu-chiffres',
      'bouton-espace-patron',
      'menu-accueil',
    ]) {
      await f.cle(c, pause: 3);
    }
    f.finir();
  });
}

/// Quelques ventes ce matin (chiffres du jour non nuls).
Future<void> _ventesDuMatin(WidgetTester tester, EtatApplication e) async {
  await tester.runAsync(() async {
    heureFilm = DateTime(2026, 11, 25, 8, 40);
    await e.ouvrirCaisse(5000);
    for (final (n, q) in [
      ('Riz', 6),
      ('Lait concentré', 4),
      ('Coca-Cola', 12),
      ('Huile', 3),
      ('Savon', 8),
      ('Spaghetti', 5),
    ]) {
      final p = e.produits.firstWhere((x) => x.nom == n);
      heureFilm = heureFilm.add(const Duration(minutes: 25));
      await e.vendre(
        await _panier(e, p, q),
        mode: ModePaiement.especes,
        montantRecu: p.prixUnitaire * q,
      );
    }
  });
}

Future<Panier> _panier(EtatApplication e, Produit p, int q) async =>
    Panier()..ajouter(ligneFilm(p, nombre: q));
