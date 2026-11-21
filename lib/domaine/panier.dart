/// Panier d'une vente en cours (avant l'encaissement).
library;

import 'quantites.dart';

/// Une ligne du panier : « 3 kg de riz », « 1 sac de 50 kg de riz » ou « riz pour 100 F ».
class LignePanier {
  const LignePanier({
    required this.produitId,
    required this.nomProduit,
    required this.uniteBase,
    this.emoji,
    this.conditionnement,
    this.nombre,
    this.montant,
    required this.prixUnitaire,
    this.prixDuDevis = false,
  }) : assert((nombre == null) != (montant == null));

  /// Vrai si [prixUnitaire] vient d'un devis encore valable (il est gardé
  /// même si le prix du produit a changé depuis).
  final bool prixDuDevis;

  final String produitId;
  final String nomProduit;
  final String uniteBase;
  final String? emoji;

  /// Conditionnement vendu (sac, casier…), ou nul pour l'unité de base.
  final Conditionnement? conditionnement;

  /// Nombre d'unités vendues (vente à la quantité).
  final int? nombre;

  /// Montant demandé par le client (vente au montant).
  final int? montant;

  /// Prix d'une unité vendue (de l'unité de base ou du conditionnement), en F.
  final int prixUnitaire;

  bool get auMontant => montant != null;

  /// Prix de la ligne en F.
  int get prix => montant ?? nombre! * prixUnitaire;

  /// Unité vendue (« kg », « sac de 50 kg »).
  String get unite => conditionnement?.nom ?? uniteBase;

  /// Libellé lisible : « 3 kg de Riz », « Riz pour 100 F ».
  String get libelle => auMontant
      ? '$nomProduit pour $montant F'
      : '$nombre ${pluriel(unite, nombre!)} · $nomProduit';

  /// Même produit et même unité (pour regrouper « + 1 »).
  bool memeArticle(LignePanier autre) =>
      !auMontant &&
      !autre.auMontant &&
      autre.produitId == produitId &&
      autre.conditionnement?.id == conditionnement?.id &&
      autre.prixDuDevis == prixDuDevis;

  LignePanier avecNombre(int n) => LignePanier(
    produitId: produitId,
    nomProduit: nomProduit,
    uniteBase: uniteBase,
    emoji: emoji,
    conditionnement: conditionnement,
    nombre: n,
    prixUnitaire: prixUnitaire,
    prixDuDevis: prixDuDevis,
  );
}

class Panier {
  final List<LignePanier> _lignes = [];

  List<LignePanier> get lignes => List.unmodifiable(_lignes);
  bool get vide => _lignes.isEmpty;

  /// Total à payer, en F.
  int get total => _lignes.fold(0, (s, l) => s + l.prix);

  /// Ajoute une ligne ; si le même article est déjà là, ajoute à sa quantité.
  void ajouter(LignePanier ligne) {
    final i = _lignes.indexWhere((l) => l.memeArticle(ligne));
    if (i >= 0) {
      _lignes[i] = _lignes[i].avecNombre(_lignes[i].nombre! + ligne.nombre!);
    } else {
      _lignes.add(ligne);
    }
  }

  /// Ajoute (+1) ou retire (−1) une unité ; la ligne disparaît à 0.
  void changer(int index, int delta) {
    final l = _lignes[index];
    if (l.auMontant) {
      if (delta < 0) _lignes.removeAt(index);
      return;
    }
    final n = l.nombre! + delta;
    if (n <= 0) {
      _lignes.removeAt(index);
    } else {
      _lignes[index] = l.avecNombre(n);
    }
  }

  void retirer(int index) => _lignes.removeAt(index);

  /// Client choisi pour cette vente (facultatif ; par défaut : sans client).
  String? clientId;
  String? clientNom;

  void choisirClient(String? id, String? nom) {
    clientId = id;
    clientNom = id == null ? null : nom;
  }

  void vider() {
    _lignes.clear();
    clientId = null;
    clientNom = null;
  }
}
