/// Démonstration : une boutique fictive pour découvrir Zéro Perte avant
/// d'avoir le code d'activation.
///
/// Garanties (décision du propriétaire) :
/// - la base de démonstration est un fichier À PART, effacé à chaque ouverture :
///   rien ne peut s'y accumuler, donc pas de vraie boutique tenue en démo ;
/// - aucun produit ne peut y être ajouté (l'assistant n'y est jamais montré) ;
/// - pas de sauvegarde possible en démo, et les reçus portent « DÉMONSTRATION » ;
/// - la vraie base du téléphone n'est jamais ouverte par la démo : ses
///   données ne peuvent pas passer dans une boutique activée.
library;

import 'package:sqflite/sqflite.dart';

import '../domaine/panier.dart';
import '../donnees/journal_local.dart';
import 'etat_application.dart';

/// Code du patron de la démonstration (affiché à l'écran).
const String codePatronDemo = '135790';

/// Produits de la démonstration : (id du catalogue, prix de l'unité de base,
/// stock en unités de base).
const List<(String, int, int)> produitsDemo = [
  ('alimentation.riz', 600, 100),
  ('alimentation.sucre', 800, 30),
  ('alimentation.huile', 1300, 40),
  ('alimentation.pates', 350, 60),
  ('alimentation.sardines', 500, 48),
  ('alimentation.savon', 250, 80),
];

/// Crée une démonstration toute neuve dans [chemin] (l'ancienne est effacée).
Future<EtatApplication> preparerDemo({
  required DatabaseFactory fabrique,
  required String chemin,
  required ServicesZp services,
}) async {
  await fabrique.deleteDatabase(chemin);
  final journal = await JournalLocal.ouvrir(
    fabrique: fabrique,
    chemin: chemin,
    prefixeRecu: 'D',
  );
  final etat = await EtatApplication.charger(
    journal: journal,
    services: services,
  );
  etat.estDemo = true;
  await etat.enregistrerConfig(
    etat.config.copie(
      nom: 'Boutique Démo',
      types: ['alimentation'],
      ville: 'Lomé',
      quartier: 'Démonstration',
    ),
  );
  await etat.definirPatron(nom: 'Patron démo', pin: codePatronDemo);
  final ids = {for (final p in produitsDemo) p.$1};
  await etat.ajouterDuCatalogue(
    etat.catalogue
        .produitsDe(['alimentation'])
        .where((p) => ids.contains(p.id)),
  );
  for (final (id, prix, stock) in produitsDemo) {
    final p = etat.produits.where((p) => p.catalogueId == id).firstOrNull;
    if (p == null) continue;
    final conds = await journal.conditionnements(p.id);
    await etat.fixerPrix(p, prix, {
      for (final c in conds) c: prix * c.facteurMilliemes ~/ 1000,
    });
    final maj = etat.produits.firstWhere((x) => x.id == p.id);
    await etat.enregistrerArrivage(
      produit: maj,
      nombre: stock,
      coutTotal: stock * prix * 85 ~/ 100,
    );
  }
  await _exempleDuJour(etat);
  await etat.allerA(EtapeAssistant.termine);
  return etat;
}

/// Produits ajoutés en 0.36 pour montrer le gros et le détail :
/// (nom, unité, prix au détail, prix d'achat, vente en gros, stock).
const List<(String, String, int, int, (String, int, int), int)> grosDemo = [
  ('Lait', 'boîte', 550, 450, ('carton de 24', 24, 12000), 72),
  ('Boisson gazeuse', 'bouteille', 400, 300, ('casier de 12', 12, 4200), 48),
];

/// La journée d'exemple (0.36) : un vendeur (Kossi), des ventes au détail et
/// au carton, une caisse fermée par Kossi avec 2 000 F de moins (le patron le
/// voit tout de suite), et un client à crédit (Yawa).
Future<void> _exempleDuJour(EtatApplication etat) async {
  final j = etat.journal;
  // Prix de gros réalistes (moins cher que 50 fois le kilo).
  const prixGros = {
    'sac de 50 kg': 27500,
    'sac de 25 kg': 14000,
    'bidon de 25 L': 30000,
  };
  for (final p in etat.produits) {
    for (final c in await j.conditionnements(p.id)) {
      final prix = prixGros[c.nom];
      if (prix != null) await etat.changerPrixConditionnement(p, c, prix);
    }
  }
  for (final (nom, unite, prix, achat, gros, stock) in grosDemo) {
    await etat.creerProduit(
      nom: nom,
      uniteBase: unite,
      prixVente: prix,
      prixAchat: achat,
      conditionnements: [gros],
      stockDepart: stock,
    );
  }
  Produit produit(String nom) => etat.produits.firstWhere((p) => p.nom == nom);
  Future<void> vendre(
    Produit p,
    int nombre, {
    String? gros,
    ModePaiement mode = ModePaiement.especes,
    String? client,
  }) async {
    final c = gros == null
        ? null
        : (await j.conditionnements(p.id)).firstWhere((x) => x.nom == gros);
    final panier = Panier()
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
    await etat.vendre(
      panier,
      mode: mode,
      montantRecu: mode == ModePaiement.especes ? panier.total : null,
      clientId: client,
    );
  }

  final patron = etat.patron!;
  final kossi = await etat.ajouterVendeur(nom: 'Kossi');
  await etat.ouvrirCaisse(10000);
  // Kossi vend le matin.
  etat.changerPersonneEnDemo(kossi.vendeur);
  await vendre(produit('Riz'), 3);
  await vendre(produit('Lait'), 1, gros: 'carton de 24');
  await vendre(produit('Lait'), 4);
  await vendre(produit('Boisson gazeuse'), 6, mode: ModePaiement.mixx);
  // Il ferme la caisse avec 2 000 F de moins que prévu.
  etat.changerPersonneEnDemo(patron);
  final attendus = (await etat.etatCaisse()).attendus;
  etat.changerPersonneEnDemo(kossi.vendeur);
  await etat.fermerCaisse({
    ModePaiement.especes: (attendus[ModePaiement.especes] ?? 0) - 2000,
    ModePaiement.flooz: attendus[ModePaiement.flooz] ?? 0,
    ModePaiement.mixx: attendus[ModePaiement.mixx] ?? 0,
  });
  // Le patron reprend l'après-midi.
  etat.changerPersonneEnDemo(patron);
  await etat.ouvrirCaisse(10000);
  await vendre(produit('Savon en morceau'), 4);
  final yawa = await etat.enregistrerClient(
    nom: 'Yawa',
    telephone: '91223344',
    plafond: 50000,
  );
  await vendre(
    produit('Lait'),
    1,
    gros: 'carton de 24',
    mode: ModePaiement.credit,
    client: yawa,
  );
  // Le résumé du soir de Kossi est déjà « vu » (pas de fenêtre en démo).
  final r = await etat.resumeDuSoir();
  if (r != null) await etat.marquerResumeVu(r);
}
