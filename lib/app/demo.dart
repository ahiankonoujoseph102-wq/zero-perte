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
  await etat.allerA(EtapeAssistant.termine);
  return etat;
}
