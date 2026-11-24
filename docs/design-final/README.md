# Design 0.37.0 — avant / après

Captures faites par `test_captures/design_final_captures_test.dart` (même boutique, mêmes ventes) sur 3
tailles : petit téléphone (360 × 720), tablette (1280 × 800) et PC Windows (1366 × 768).
`avant/` = version 0.36 (sans la démonstration) ; `apres/` = version 0.37.0.

Écrans : 1 bienvenue (premier lancement), 2 accueil du patron, 3 Vendre, 4 Ma caisse, 5 Ce qu'on me doit,
6 Mon bénéfice, 7 accueil du vendeur, 8 Gestion.

## Ce qui a changé
- **Un seul système de design** : un arrondi pour toutes les cartes et tous les boutons (18), un petit pour
  les pastilles (10), des espacements réguliers (4, 8, 12, 16, 24), une seule famille d'icônes (Material
  arrondies), deux couleurs d'accent (ciel, mauve) en plus des couleurs de l'argent (vert = entre, rouge =
  sort, ambre = crédit) et du bleu de la marque. Boutons d'au moins 52 points de haut.
- **Accueil du patron** : 3 grandes cartes **Vendu, Bénéfice, Caisse** ; la carte de la caisse dit
  « Ouverte », « Juste » (vert) ou « Il manque 2 000 F » (rouge) et ouvre « Ma caisse ».
- **5 destinations, toujours au même endroit** : Vendre, Ma caisse, Ce qu'on me doit, Mon bénéfice,
  Gestion (menu de gauche sur tablette et PC). Le vendeur garde Vendre, Ma caisse, Ce qu'on me doit.
- **Gestion rangée en 4 rubriques** : Stock et produits, Argent, Vendeurs et appareils, Ma boutique.
- **Tablette et PC** : 4 cartes (Vendu, Bénéfice, Ma caisse, Ce qu'on me doit), courbe des 7 jours,
  meilleures ventes, stock bas — un vrai tableau de bord, pas un téléphone étiré.
- **Produit sans image** : son initiale sur une pastille de couleur (plus de carré vide).
- **Écrans vides utiles** : « Aucune vente aujourd'hui. Touchez « Vendre » pour commencer. »
- **Transitions courtes** entre les pages (fondu), animations de vente gardées.
- **Mode sombre seulement** : l'application est conçue en bleu nuit à fort contraste (lisible au soleil) ;
  un mode clair à moitié fini aurait été moins bon. Les reçus et devis restent sur fond blanc.
