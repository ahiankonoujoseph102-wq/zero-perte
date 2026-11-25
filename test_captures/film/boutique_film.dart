// Boutique de démonstration pour les vidéos : produits avec images, lait au
// carton, crédits, un vendeur et une semaine de ventes (courbe des 7 jours).
import 'dart:convert';
import 'dart:io';

import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/boutique.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/quantites.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../../test/domaine/licence_test.dart' show codeLicence;

/// Heure de la boutique (le journal et l'état la lisent).
DateTime heureFilm = DateTime(2026, 11, 25, 9);
int horlogeFilm() => heureFilm.millisecondsSinceEpoch;

LignePanier ligneFilm(Produit p, {Conditionnement? c, int nombre = 1}) =>
    LignePanier(
      produitId: p.id,
      nomProduit: p.nom,
      uniteBase: p.uniteBase,
      conditionnement: c,
      nombre: nombre,
      prixUnitaire: c?.prixVente ?? p.prixUnitaire,
    );

Future<void> _vendre(
  EtatApplication e,
  List<LignePanier> lignes, {
  ModePaiement mode = ModePaiement.especes,
  String? client,
}) async {
  final p = Panier();
  for (final l in lignes) {
    p.ajouter(l);
  }
  await e.vendre(
    p,
    mode: mode,
    montantRecu: mode == ModePaiement.especes ? p.total : null,
    clientId: client,
  );
}

/// [avecVendeur] : ajoute Kossi (code 5913).
Future<void> boutiqueFilm(EtatApplication e, {bool avecVendeur = true}) async {
  heureFilm = DateTime(2026, 11, 19, 8);
  e.maintenant = () => heureFilm;
  await e.activer(codeLicence);
  await e.enregistrerConfig(
    e.config.copie(
      nom: 'Boutique Mama Ama',
      vente: FaconDeVendre.lesDeux,
      quiVend: QuiVend.unVendeur,
    ),
  );
  await e.definirPatron(nom: 'Ama', pin: '482713');
  await e.allerA(EtapeAssistant.termine);
  // Photos des produits (dessinées à partir des émojis : ZP_PHOTOS).
  final photos = Platform.environment['ZP_PHOTOS'];
  String? photo(String f) {
    if (photos == null) return null;
    final x = File('$photos/$f.png');
    return x.existsSync() ? base64.encode(x.readAsBytesSync()) : null;
  }

  const fichiers = {
    'Riz': 'riz',
    'Lait concentré': 'lait',
    'Huile': 'huile',
    'Sucre': 'sucre',
    'Savon': 'savon',
    'Spaghetti': 'spaghetti',
    'Tomate': 'tomate',
    'Sardine': 'sardine',
    'Coca-Cola': 'coca',
    'Eau minérale': 'eau',
    'Biscuit': 'biscuit',
    'Pain': 'pain',
  };
  const produits = [
    ('Riz', 'bol', 500, '🍚', [('sac de 50 kg', 110, 27500)]),
    ('Lait concentré', 'boîte', 550, '🥫', [('carton de 24', 24, 12000)]),
    ('Huile', 'litre', 1300, '🫗', [('bidon de 20 L', 20, 24000)]),
    ('Sucre', 'paquet', 600, '🍬', <(String, int, int)>[]),
    ('Savon', 'morceau', 250, '🧼', [('carton de 40', 40, 9000)]),
    ('Spaghetti', 'paquet', 400, '🍝', <(String, int, int)>[]),
    ('Tomate', 'boîte', 300, '🍅', <(String, int, int)>[]),
    ('Sardine', 'boîte', 450, '🐟', <(String, int, int)>[]),
    ('Coca-Cola', 'bouteille', 400, '🥤', [('casier de 24', 24, 8800)]),
    ('Eau minérale', 'bouteille', 300, '💧', [('pack de 6', 6, 1600)]),
    ('Biscuit', 'paquet', 100, '🍪', <(String, int, int)>[]),
    ('Pain', 'pièce', 150, '🥖', <(String, int, int)>[]),
  ];
  for (final (nom, unite, prix, emoji, gros) in produits) {
    final p = await e.creerProduit(
      nom: nom,
      uniteBase: unite,
      prixVente: prix,
      prixAchat: (prix * 0.8).round(),
      emoji: photos == null ? emoji : null,
      photo: photo(fichiers[nom]!),
      seuilAlerteMilliemes: nom == 'Sucre' ? 30 * 1000 : 0,
      conditionnements: gros,
    );
    final n = switch (nom) {
      'Sucre' => 12,
      'Lait concentré' => 480, // 20 cartons de 24
      _ => 60,
    };
    await e.enregistrerArrivage(
      produit: p,
      nombre: n,
      coutTotal: (prix * 0.8).round() * n,
    );
  }
  final lait = e.produits.firstWhere((p) => p.nom == 'Lait concentré');
  final kofi = await e.enregistrerClient(
    nom: 'Kofi',
    telephone: '90 12 34 56',
    plafond: 50000,
  );
  await e.enregistrerClient(
    nom: 'Afi',
    telephone: '91 22 33 44',
    plafond: 20000,
  );
  if (avecVendeur) await e.ajouterVendeur(nom: 'Kossi', pin: '5913');
  // Une semaine de ventes (du plus ancien au plus récent).
  final autres = e.produits
      .where((p) => !p.auMontant && p.id != lait.id)
      .toList();
  for (var j = 0; j < 6; j++) {
    heureFilm = DateTime(2026, 11, 19 + j, 9);
    await e.ouvrirCaisse(5000);
    for (var v = 0; v < 4 + j; v++) {
      heureFilm = heureFilm.add(const Duration(minutes: 47));
      final p = autres[(j * 3 + v) % autres.length];
      await _vendre(e, [
        ligneFilm(p, nombre: 1 + v % 3),
        if (v.isEven) ligneFilm(lait, nombre: 2),
      ]);
    }
    if (j == 2) {
      await _vendre(
        e,
        [ligneFilm(lait, c: e.grosDe(lait.id).first)],
        mode: ModePaiement.credit,
        client: kofi,
      );
    }
    heureFilm = DateTime(2026, 11, 19 + j, 19);
    final att = await e.etatCaisse();
    await e.fermerCaisse({
      for (final m in ModePaiement.caisses) m: att.attendus[m] ?? 0,
    });
  }
  heureFilm = DateTime(2026, 11, 25, 8, 30);
  e.deconnecter();
  await e.verifierPin(e.patron!, '482713');
}
