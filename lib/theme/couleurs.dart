import 'package:flutter/material.dart';

/// Couleurs de Zéro Perte.
///
/// Règle fixe, partout dans l'application, quelle que soit la couleur choisie
/// par la boutique (personnalisation, étape B3) :
///   - VERT  = l'argent qui ENTRE (vendre, encaisser, remboursement) ;
///   - ROUGE = l'argent qui SORT (dépense, perte, manque en caisse) ;
///   - AMBRE = l'argent qu'on attend encore (crédit des clients).
/// Ces trois couleurs ne servent à rien d'autre. La marque est donc bleu nuit.
abstract final class CouleursZp {
  // Allure « logiciel de caisse professionnel » : fond bleu nuit, cartes nettes,
  // textes clairs à fort contraste (≥ 7:1 pour le texte principal).

  // Marque (bleu vif des éléments actifs ; la couleur de la boutique colore
  // les boutons principaux, voir [couleurBouton]).
  static const Color marque = Color(0xFF2F7DF6);
  static const Color marqueFoncee = Color(0xFF1C3A6E);
  static const Color marquePale = Color(0xFF1B3358);

  // Argent (lisible sur le fond sombre ; texte blanc sur les boutons)
  static const Color argentEntre = Color(0xFF1E9E5C);
  static const Color argentEntreClair = Color(0xFF2BC77A);
  static const Color argentSort = Color(0xFFE5484D);
  static const Color argentSortClair = Color(0xFFF06A6E);
  static const Color credit = Color(0xFFF2A33A);
  static const Color creditClair = Color(0xFFF8BE5F);
  static const Color texteSurCredit = Color(0xFF2E1E00);

  /// Ambre pour un TEXTE de crédit (ce qu'un client doit) sur le fond sombre.
  static const Color creditTexte = Color(0xFFF7B955);

  // Fond et texte
  static const Color fond = Color(0xFF0B1730); // bleu nuit
  static const Color surface = Color(0xFF132447); // cartes
  static const Color menu = Color(0xFF0F1D3A); // menu de gauche
  static const Color texte = Color(0xFFEEF3FB);
  static const Color texteDoux = Color(0xFFA9B8D0);
  static const Color ligne = Color(0xFF263D66);
}

/// Couleurs des REÇUS et DEVIS (images envoyées aux clients) : toujours sur
/// fond blanc, lisibles sur n'importe quel téléphone et à l'impression.
abstract final class CouleursRecu {
  static const Color fond = Color(0xFFFFFFFF);
  static const Color cadre = Color(0xFFF2F4F8);
  static const Color texte = Color(0xFF1B2430);
  static const Color texteDoux = Color(0xFF5B6573);
  static const Color ligne = Color(0xFFE1E5EC);
  static const Color vert = Color(0xFF17803A);
  static const Color rouge = Color(0xFFC62828);
  static const Color ambre = CouleursZp.creditTexte;
}

/// Couleur de la boutique pour les boutons principaux, éclaircie si elle est
/// trop sombre pour se voir sur le fond bleu nuit (garde sa teinte).
Color couleurBouton(Color boutique) {
  // Ancienne couleur par défaut (bleu nuit) : on prend le bleu vif.
  if (boutique.toARGB32() == 0xFF1D3557) return CouleursZp.marque;
  final hsl = HSLColor.fromColor(boutique);
  if (hsl.lightness >= 0.42) return boutique;
  return hsl
      .withLightness(0.45)
      .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
      .toColor();
}
