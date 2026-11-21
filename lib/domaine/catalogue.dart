/// Catalogue prérempli : types de boutiques et produits courants au Togo
/// (fichier assets/catalogues/catalogues.json, voir docs/categories.md).
library;

import 'dart:convert';

class ConditionnementCatalogue {
  const ConditionnementCatalogue(
    this.nom,
    this.unites, {
    this.aVerifier = false,
  });

  final String nom;

  /// Nombre d'unités de base dans ce conditionnement (ex. 40 bols).
  final int unites;

  /// Vrai si ce nombre est une estimation à confirmer par le patron.
  final bool aVerifier;
}

class ProduitCatalogue {
  const ProduitCatalogue({
    required this.id,
    required this.nom,
    required this.emoji,
    required this.unite,
    this.conditionnements = const [],
    this.auMontant = false,
    this.emballage,
  });

  final String id;
  final String nom;
  final String emoji;

  /// Unité de base (bol, pièce, bouteille, kg…).
  final String unite;
  final List<ConditionnementCatalogue> conditionnements;
  final bool auMontant;

  /// Emballage consigné (casier, bouteille de gaz…), ou nul.
  final String? emballage;
}

class CategorieCatalogue {
  const CategorieCatalogue({
    required this.id,
    required this.nom,
    required this.emoji,
    required this.produits,
  });

  final String id;
  final String nom;
  final String emoji;
  final List<ProduitCatalogue> produits;
}

class Catalogue {
  const Catalogue(this.categories);

  final List<CategorieCatalogue> categories;

  CategorieCatalogue? categorie(String id) =>
      categories.where((c) => c.id == id).firstOrNull;

  /// Produits des catégories choisies, sans doublon de nom (ex. « Œufs » présents
  /// dans deux catégories).
  List<ProduitCatalogue> produitsDe(Iterable<String> idsCategories) {
    final vus = <String>{};
    return [
      for (final id in idsCategories)
        for (final p in categorie(id)?.produits ?? const <ProduitCatalogue>[])
          if (vus.add(p.nom.toLowerCase())) p,
    ];
  }

  factory Catalogue.depuisJson(String texte) {
    final j = jsonDecode(texte) as Map<String, dynamic>;
    return Catalogue([
      for (final c in (j['categories'] as List).cast<Map<String, dynamic>>())
        CategorieCatalogue(
          id: c['id'] as String,
          nom: c['nom'] as String,
          emoji: c['emoji'] as String,
          produits: [
            for (final p
                in (c['produits'] as List).cast<Map<String, dynamic>>())
              ProduitCatalogue(
                id: p['id'] as String,
                nom: p['nom'] as String,
                emoji: p['emoji'] as String,
                unite: p['unite'] as String,
                auMontant: (p['au_montant'] as bool?) ?? false,
                emballage: p['emballage'] as String?,
                conditionnements: [
                  for (final k
                      in ((p['conditionnements'] as List?) ?? const [])
                          .cast<Map<String, dynamic>>())
                    ConditionnementCatalogue(
                      k['nom'] as String,
                      k['unites'] as int,
                      aVerifier: (k['a_verifier'] as bool?) ?? false,
                    ),
                ],
              ),
          ],
        ),
    ]);
  }
}
