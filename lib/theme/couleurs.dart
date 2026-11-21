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
  // Marque
  static const Color marque = Color(0xFF1D3557); // bleu nuit
  static const Color marqueFoncee = Color(0xFF142640);
  static const Color marquePale = Color(0xFFE6ECF4);

  // Argent (contrastes vérifiés avec du texte blanc ≥ 4,5:1, sauf l'ambre : texte foncé)
  static const Color argentEntre = Color(0xFF17803A);
  static const Color argentEntreClair = Color(0xFF24A04D);
  static const Color argentSort = Color(0xFFC62828);
  static const Color argentSortClair = Color(0xFFE0453B);
  static const Color credit = Color(0xFFF2A33A);
  static const Color creditClair = Color(0xFFF8BE5F);
  static const Color texteSurCredit = Color(0xFF3A2600);

  // Fond et texte
  static const Color fond = Color(0xFFF7F3EC); // crème chaleureux
  static const Color surface = Color(0xFFFFFFFF);
  static const Color texte = Color(0xFF1B2430);
  static const Color texteDoux = Color(0xFF5B6573);
  static const Color ligne = Color(0xFFE4DDD1);
}
