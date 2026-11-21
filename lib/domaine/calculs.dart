/// Calculs de contrôle de Zéro Perte : stock, caisse, bénéfice, emballages.
/// Tous les montants sont des entiers en F, toutes les quantités en millièmes.
library;

/// Stock = somme de tous les mouvements (arrivages +, ventes −, pertes −,
/// annulations de vente +). On ne « modifie » jamais un stock : on ajoute des mouvements.
int stockDepuisMouvements(Iterable<int> mouvementsMilliemes) =>
    mouvementsMilliemes.fold(0, (somme, m) => somme + m);

/// État d'une caisse comptée : juste, il manque de l'argent, ou il y en a trop.
enum EtatCaisse { juste, manque, surplus }

/// Ce qui doit se trouver dans une caisse (espèces, ou un compte Mobile Money)
/// à la fermeture. Chaque moyen de paiement a sa propre caisse.
class MouvementsCaisse {
  const MouvementsCaisse({
    this.fondsDeCaisse = 0,
    this.ventes = 0,
    this.remboursementsCredits = 0,
    this.consignesEncaissees = 0,
    this.depenses = 0,
    this.retraitsPatron = 0,
    this.consignesRendues = 0,
  });

  /// Argent laissé le matin pour rendre la monnaie (espèces seulement).
  final int fondsDeCaisse;

  /// Ventes encaissées avec ce moyen de paiement (annulations déjà déduites).
  final int ventes;

  /// Clients qui ont remboursé une partie de leur crédit.
  final int remboursementsCredits;

  /// Consignes payées par les clients (casiers, bouteilles, gaz).
  final int consignesEncaissees;

  /// Dépenses payées avec cette caisse.
  final int depenses;

  /// Argent pris par le patron.
  final int retraitsPatron;

  /// Consignes rendues aux clients qui ont ramené l'emballage.
  final int consignesRendues;

  /// Montant qui DEVRAIT être dans la caisse.
  int get attendu =>
      fondsDeCaisse +
      ventes +
      remboursementsCredits +
      consignesEncaissees -
      depenses -
      retraitsPatron -
      consignesRendues;
}

/// Résultat de la fermeture d'une caisse.
class ResultatCaisse {
  const ResultatCaisse({required this.attendu, required this.compte});

  final int attendu;

  /// Montant compté par le vendeur (sans voir l'attendu : comptage aveugle).
  final int compte;

  /// Écart = compté − attendu. Négatif : il manque de l'argent.
  int get ecart => compte - attendu;

  EtatCaisse get etat => ecart == 0
      ? EtatCaisse.juste
      : (ecart < 0 ? EtatCaisse.manque : EtatCaisse.surplus);
}

/// Calcule l'écart de caisse à la fermeture.
ResultatCaisse fermerCaisse(
  MouvementsCaisse mouvements, {
  required int compte,
}) {
  if (compte < 0) {
    throw ArgumentError('Un montant compté ne peut pas être négatif.');
  }
  return ResultatCaisse(attendu: mouvements.attendu, compte: compte);
}

/// Une ligne vendue, pour le calcul du bénéfice.
class LigneVendue {
  const LigneVendue({required this.prixVente, required this.coutAchat});

  /// Prix encaissé pour cette ligne (F).
  final int prixVente;

  /// Coût d'achat estimé de la quantité vendue (F), calculé au moment de la vente.
  final int coutAchat;

  int get benefice => prixVente - coutAchat;
}

/// Bénéfice estimé = somme (prix de vente − coût d'achat) des lignes vendues.
/// « Estimé » parce que le coût d'achat est celui du dernier arrivage connu.
int beneficeEstime(Iterable<LigneVendue> lignes) =>
    lignes.fold(0, (somme, l) => somme + l.benefice);

/// Solde d'emballages consignés (casiers, bouteilles, bouteilles de gaz) :
/// somme des mouvements (+ arrivés ou ramenés, − partis avec un client).
int soldeEmballages(Iterable<int> mouvements) =>
    mouvements.fold(0, (somme, m) => somme + m);
