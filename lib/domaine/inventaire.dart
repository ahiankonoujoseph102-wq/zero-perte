/// Inventaire : tolérance pour les produits vendus au bol, au tas ou au montant
/// (on ne peut pas les recompter au gramme près).
library;

import 'dart:math';

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

/// Inventaire tournant : choisit [nombre] produits pour aujourd'hui, au
/// hasard mais en privilégiant ceux qui valent cher et se vendent vite
/// (poids = prix × (quantité vendue en 7 jours + 1)). Le même jour donne
/// toujours le même choix (pas de triche en relançant).
List<String> produitsDuJour({
  required DateTime jour,
  required Map<String, int> poids,
  int nombre = 3,
}) {
  final candidats = poids.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final r = Random(jour.year * 10000 + jour.month * 100 + jour.day);
  final choisis = <String>[];
  while (choisis.length < nombre && candidats.isNotEmpty) {
    final total = candidats.fold<int>(0, (s, e) => s + e.value);
    var tirage = r.nextInt(total);
    var i = 0;
    while (tirage >= candidats[i].value) {
      tirage -= candidats[i].value;
      i++;
    }
    choisis.add(candidats.removeAt(i).key);
  }
  return choisis;
}
