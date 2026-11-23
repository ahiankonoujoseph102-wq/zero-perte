# Refonte « commerçant » (version 0.36.0) — état des lieux et plan

Rédigé le 23 novembre 2026 (chantier de nuit). Point de départ : version 0.35.2.

## Pourquoi
Les premiers clients trouvent l'application « difficile » et « pas adaptée ». Un client veut vendre
« en gros et en détail » et gérer le stock de son « magasin ». Les commerçants pensent que c'est « un travail
de plus ». Le moteur est bon ; ce qui manque : **les mots du marché**, **un démarrage court sans inventaire**,
et **la valeur visible dès le premier jour**.

Problème résolu (une phrase) : *le patron perd de l'argent sans savoir où ni combien ; Zéro Perte lui
montre chaque vente, sa caisse et son bénéfice sur son téléphone, même absent, et l'alerte s'il manque de
l'argent.*

## État des lieux, point par point

| Sujet | Ce qui existe (0.35.2) | Ce qui manque | Plan 0.36 |
|---|---|---|---|
| Installation | 11 étapes : bienvenue, vérification, activation, types de boutique, nom + photo, contact, couleur, **choix des produits**, **prix de chaque produit**, reçu, code patron | Trop long ; l'inventaire (produits + prix) bloque le premier jour | **3 étapes** après l'activation : 1. nom de la boutique ; 2. deux questions (vente : détail / gros / les deux ; qui vend : moi / un vendeur / plusieurs) ; 3. code du patron → « Vous pouvez vendre ! ». Types, contact, couleur, reçu, produits : plus tard (Gestion → « Ma boutique », « Produits et prix »). |
| Profil de la boutique | Aucun | L'app montre tout à tout le monde | Réglages `vente` et `qui_vend` dans la configuration (synchronisés), modifiables dans Gestion → « Ma boutique ». Boutiques existantes : rien ne change (pas de questions), valeurs déduites. |
| Produits au départ | Catalogue + prix obligatoires dans l'assistant | Impossible de vendre sans avoir tout saisi | **Produit créé pendant la vente** : « + Nouveau produit » dans Vendre (nom + prix ; carton facultatif). |
| Stock jamais compté | Affiché négatif (« -3 »), alerte « épuisé » s'il se vend | Fausse alerte, chiffre faux | « **Pas encore compté** » ; aucune alerte de stock tant que le produit n'est pas compté ou reçu. |
| Compter le stock | Inventaire complet, inventaire du jour (3 à 5 produits) | Rien pour démarrer petit à petit | Page « **Compter mon stock** » : d'abord les 20 produits les plus vendus ou les plus chers, barre de progression ; le premier comptage d'un produit n'est **pas** un écart (pas de fausse perte). |
| Choses à faire plus tard | Dispersées (Drive, vendeurs, sauvegarde, prix d'achat) | Le patron ne sait pas quoi faire ensuite | Carte d'accueil « **À faire quand vous avez le temps** » (stock à compter, vendeur, Google, prix d'achat, téléphone sur le reçu). |
| Gros / détail | « Emballages » (carton, sac, casier) avec leur prix ; vente par emballage ; arrivage par emballage ; stock en unités | Le mot ; pas de prix revendeur ; stock peu lisible ; vente « gros seulement » | Section « **Vente en gros** » (nom libre, nombre d'unités, prix de gros, **prix revendeur** facultatif) ; Vendre : « **Détail** » / « **Gros** » ; stock « **3 cartons et 5 boîtes** » ; un produit vendu seulement en gros a le carton pour unité. Les anciens emballages SONT la vente en gros (même donnée : aucune migration de base nécessaire). |
| Mots | « Clients », « Fournisseurs », « Chiffres », « Arrivages », « Emballages », « Bénéfice estimé », « Mixx (T-Money) »… | Langage d'informaticien par endroits | Lot 3 (liste avant/après dans le journal). |
| Accueil du patron | Ventes du jour, bénéfice estimé, crédits clients | État de la caisse ; ventes par vendeur ; message si le prix d'achat manque | « **Vendu aujourd'hui** — **Bénéfice** — **Caisse : juste ✅ / manque 2 000 F ❌** », ventes par vendeur s'il y en a plusieurs, « Ajoutez le prix d'achat pour voir votre bénéfice ». |
| Fermeture de caisse | Comptage à l'aveugle, écart au patron, résumé du soir (WhatsApp) côté patron | Rien à envoyer pour celui qui ferme | Bouton « **Envoyer sur WhatsApp** » (texte) : sans l'écart pour le vendeur (comptage à l'aveugle gardé). |
| Démonstration | Boutique fictive à part (base effacée à chaque ouverture), visite d'Afi, bouton à l'étape « Activation » | Peu visible, produits sans gros, pas de vendeur ni de manque de caisse | Bouton « **Voir un exemple** » dès le premier écran ; boutique d'exemple : Lait, Riz, Boisson, Huile, Savon (avec gros), un vendeur, une caisse fermée avec un manque, des crédits. Toujours une base à part. |
| Crédit client | Carnet complet (nom, téléphone obligatoire pour le crédit, plafond, remboursements partiels, rappel WhatsApp, retards 14 jours) | Le nom « Clients » | « **Ce qu'on me doit** ». |
| Dettes fournisseurs | « Fournisseurs » (achats à crédit, paiements) | Le nom | « **Ce que je dois** ». |
| Paiement | Espèces, Flooz, Mixx (T-Money), Crédit ; une caisse par moyen | Nom « T-Money » dépassé ; « caisse juste » mélangeait les caisses | « **Mixx by Yas** » (T-Money est devenu Mixx by Yas ; Moov Africa garde « Flooz »). La caisse de l'accueil = **espèces**. |
| Réserve (« magasin ») | Un seul stock par produit | Stock du magasin séparé | **Pas cette nuit** (touche stock, inventaires, synchronisation et rapports : trop risqué sans essai réel). Plan ci-dessous. |

## Plan de la réserve (« magasin »), pour une prochaine version
1. Réglage « J'ai une réserve (magasin) » dans Gestion → Ma boutique, désactivé par défaut.
2. Nouvelle nature de mouvement `transfert` : −N en réserve, +N en boutique (même opération, synchronisée).
   Stock affiché « Boutique : 2 cartons — Réserve : 10 cartons ». Les ventes sortent de la boutique.
3. Arrivage : choix « dans la réserve » ou « dans la boutique » (par défaut : réserve si l'option est active).
4. Bouton « Transférer de la réserve à la boutique » (nombre de cartons).
5. Inventaire : on compte la boutique et la réserve séparément.
6. Anciennes versions sur un autre appareil : elles ignorent `transfert` (types inconnus conservés) et
   verraient un stock total juste ; à tester avant de publier.
Effort : moyen. Risque : moyen (stock et rapports).

## Règles respectées
- Données des clients gardées : **aucun changement de schéma de base** ; nouvelles informations dans la
  configuration (JSON) et dans les lignes d'inventaire (`premier`). Test sur une base fabriquée par le code de
  la 0.35.2 (`test/fixtures/mise_a_jour/v0.35.2.db`).
- Licences, codes d'activation, clés, secrets, relais : non touchés.
- Anti-vol (codes, alertes, Mes appareils, QR) : inchangé.
- Aucune fonction supprimée : ce qui n'est pas essentiel est dans Gestion.
