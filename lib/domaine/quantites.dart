/// Quantités et conditionnements (sac → bol, casier → bouteille, carton → pièce…).
///
/// Pour ne jamais utiliser de virgule, toutes les quantités sont comptées en
/// **millièmes de l'unité de base** du produit :
///   - 1 bol = 1 000 millièmes ;
///   - « donne pour 100 F » de riz à 175 F le bol = 571 millièmes (0,571 bol).
/// L'unité de base est la plus petite unité qu'on compte (bol, bouteille, pièce, mètre…).
library;

/// Nombre de millièmes dans une unité de base.
const int milliemesParUnite = 1000;

/// Un conditionnement d'un produit, avec son facteur et son propre prix.
/// Exemple : « sac » = 40 bols, vendu 23 000 F.
class Conditionnement {
  const Conditionnement({
    required this.id,
    required this.nom,
    required this.facteurMilliemes,
    required this.prixVente,
  }) : assert(facteurMilliemes > 0),
       assert(prixVente >= 0);

  /// Raccourci pour un facteur entier : `Conditionnement.unites(nom: 'sac', unites: 40, …)`.
  const Conditionnement.unites({
    required String id,
    required String nom,
    required int unites,
    required int prixVente,
  }) : this(
         id: id,
         nom: nom,
         facteurMilliemes: unites * milliemesParUnite,
         prixVente: prixVente,
       );

  final String id;
  final String nom;

  /// Combien de millièmes d'unité de base contient ce conditionnement.
  final int facteurMilliemes;

  /// Prix de vente de ce conditionnement, en F.
  final int prixVente;
}

/// Convertit un nombre de conditionnements en millièmes d'unité de base.
/// Exemple : 2 sacs de 40 bols = 80 000 millièmes (80 bols).
int versMilliemes(int nombre, Conditionnement conditionnement) =>
    nombre * conditionnement.facteurMilliemes;

/// Une ligne de la répartition d'un stock : « 2 sacs ».
class PartStock {
  const PartStock(this.conditionnement, this.nombre);
  final Conditionnement conditionnement;
  final int nombre;
}

/// Un stock exprimé en conditionnements + un reste en unités de base.
/// Exemple : 85 bols avec des sacs de 40 → 2 sacs + 5 bols.
class RepartitionStock {
  const RepartitionStock(this.parts, this.resteMilliemes);
  final List<PartStock> parts;
  final int resteMilliemes;
}

/// Répartit un stock (en millièmes) en conditionnements, du plus grand au plus petit.
/// Un stock négatif (erreur ou vente avant arrivage) n'est pas réparti.
RepartitionStock repartirStock(
  int stockMilliemes,
  List<Conditionnement> conditionnements,
) {
  if (stockMilliemes <= 0) return RepartitionStock(const [], stockMilliemes);
  final tries = [...conditionnements]
    ..sort((a, b) => b.facteurMilliemes.compareTo(a.facteurMilliemes));
  var reste = stockMilliemes;
  final parts = <PartStock>[];
  for (final c in tries) {
    final nombre = reste ~/ c.facteurMilliemes;
    if (nombre > 0) {
      parts.add(PartStock(c, nombre));
      reste -= nombre * c.facteurMilliemes;
    }
  }
  return RepartitionStock(parts, reste);
}

/// Division entière arrondie au plus proche (0,5 vers le haut), pour des entiers positifs.
int diviserArrondi(int numerateur, int denominateur) {
  if (denominateur <= 0) throw ArgumentError('Diviseur nul ou négatif.');
  if (numerateur < 0) return -diviserArrondi(-numerateur, denominateur);
  return (numerateur * 2 + denominateur) ~/ (denominateur * 2);
}

/// Vente au montant : « donne pour 100 F ».
/// Renvoie la quantité correspondante en millièmes d'unité de base, arrondie au
/// millième le plus proche.
/// Exemple : 100 F de riz à 175 F le bol → 571 millièmes (0,571 bol).
int quantitePourMontant({required int montant, required int prixUnitaire}) {
  if (montant < 0) throw ArgumentError('Montant négatif.');
  if (prixUnitaire <= 0) throw ArgumentError('Le produit n\'a pas de prix.');
  return diviserArrondi(montant * milliemesParUnite, prixUnitaire);
}

/// Prix (en F entiers) d'une quantité en millièmes, à partir du prix d'une unité de base.
int prixPourQuantite({required int milliemes, required int prixUnitaire}) =>
    diviserArrondi(milliemes * prixUnitaire, milliemesParUnite);

/// Coût d'achat (en F entiers) d'une quantité, à partir d'un achat de référence.
/// Exemple : sac de 40 bols acheté 23 000 F ; 5 bols coûtent 2 875 F.
int coutPourQuantite({
  required int milliemes,
  required int coutAchat,
  required int milliemesAchetes,
}) {
  if (milliemesAchetes <= 0) throw ArgumentError('Quantité achetée nulle.');
  return diviserArrondi(milliemes * coutAchat, milliemesAchetes);
}
