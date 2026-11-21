/// Inventaire : tolérance pour les produits vendus au bol, au tas ou au montant
/// (on ne peut pas les recompter au gramme près).
library;

/// Écart toléré, en pourcentage du stock attendu.
const int tolerancePourcent = 5;

enum EtatLigneInventaire { juste, tolere, manque, surplus }

/// Le produit est-il vendu « à la mesure » (bol, tas) ou au montant ?
bool avecTolerance({required String uniteBase, required bool auMontant}) =>
    auMontant || const {'bol', 'tas'}.contains(uniteBase.trim().toLowerCase());

/// État d'une ligne : juste, dans la tolérance, il manque, ou en trop.
EtatLigneInventaire etatLigne({
  required int attendu,
  required int compte,
  required bool tolerance,
}) {
  final ecart = compte - attendu;
  if (ecart == 0) return EtatLigneInventaire.juste;
  if (tolerance && ecart.abs() * 100 <= attendu.abs() * tolerancePourcent) {
    return EtatLigneInventaire.tolere;
  }
  return ecart < 0 ? EtatLigneInventaire.manque : EtatLigneInventaire.surplus;
}
