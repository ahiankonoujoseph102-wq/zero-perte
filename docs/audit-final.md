# Audit final — version 0.37.0

Audit fait le 24 novembre 2026 sur tout l'application, pour les 3 rôles (patron, vendeur, premier lancement)
et 3 tailles d'écran (petit téléphone 360 × 720, tablette 1280 × 800, PC Windows 1366 × 768).
Chaque correction a son test automatique (dossier `test/audit/` et tests existants mis à jour).

Gravité : **grave** = chiffre faux ou blocage ; **moyen** = gêne réelle ou risque d'erreur ;
**faible** = confort, mots, présentation.

## 1. Problèmes trouvés et corrigés

### 1.1 L'accueil du patron gardait les chiffres de la veille après minuit — grave
- **Constat** : « Vendu », « Bénéfice » et « Caisse » (accueil téléphone) et le tableau de bord (tablette,
  PC) ne se rechargeaient qu'après une action. Un téléphone resté allumé la nuit montrait le matin les
  ventes d'hier comme si c'était aujourd'hui.
- **Correction** : un minuteur recharge ces écrans à minuit (heure du téléphone), puis chaque nuit.
- **Test** : `test/audit/calculs_test.dart` — « à minuit, l'accueil du patron repart à zéro tout seul »
  (le test échoue sans la correction : vérifié).

### 1.2 Premier arrivage d'un produit vendu avant d'être compté : stock faux — moyen
- **Constat** : un produit créé pendant la vente puis vendu (3 pains) a un stock de −3, affiché « pas
  encore compté ». À son premier arrivage (10 pains), l'application affichait 7 pains, alors qu'il y en a
  au moins 10.
- **Correction** : au premier arrivage d'un produit jamais compté dont le stock est négatif, on repart de
  0 (enregistré comme un premier comptage, donc **sans** écart reproché à personne), puis on ajoute
  l'arrivage. Les produits déjà comptés gardent exactement le calcul d'avant.
- **Test** : « premier arrivage d'un produit vendu sans stock : repart de 0 ».

### 1.3 Prix sans limite de chiffres — moyen
- **Constat** : dans « Nouveau produit » (pendant la vente) et dans la fiche d'un produit, on pouvait taper
  un prix de 15 ou 20 chiffres. 20 chiffres donnaient le message trompeur « Écrivez le prix » ; 15 chiffres
  donnaient des totaux absurdes.
- **Correction** : 9 chiffres au plus (999 999 999 F), comme les autres montants de l'application.
- **Test** : « prix tapé avec trop de chiffres : 9 chiffres au plus ».

### 1.4 Navigation trop chargée — moyen (design)
- **Constat** : 7 gros boutons sur l'accueil du téléphone du patron, 12 entrées dans le menu de gauche
  (tablette, PC), et 17 cases sans ordre dans « Gestion » (dont « Mon bénéfice » en double). « Inventaire »
  et « Compter mon stock » se ressemblaient sans qu'on sache lequel choisir.
- **Correction** : 5 destinations principales, partout au même endroit : **Vendre, Ma caisse, Ce qu'on me
  doit, Mon bénéfice, Gestion**. « Gestion » est rangée en 4 rubriques : Stock et produits, Argent, Vendeurs
  et appareils, Ma boutique. « Inventaire » devient « Inventaire complet ». Aucune fonction n'a disparu :
  Arrivage, Devis, Retours, Ce que je dois, Vendeurs, Ajouter mon vendeur sont dans Gestion. Le vendeur
  garde ses 3 boutons (Vendre, Ma caisse, Ce qu'on me doit).
- **Tests** : toute la suite (les tests qui ouvrent ces pages passent par Gestion).

### 1.5 L'état de la caisse était une petite ligne de texte — moyen (design)
- **Constat** : « Caisse : ouverte » était écrit en petit sous les chiffres, et sur tablette et PC il
  flottait au-dessus des cartes.
- **Correction** : 3 grandes cartes sur le téléphone (**Vendu, Bénéfice, Caisse**) ; sur tablette et PC, une
  carte **Ma caisse (espèces)** à côté de « Vendu », « Bénéfice » et « Ce qu'on me doit ». Les dépenses du
  jour sont écrites sous la carte de la caisse. Toucher la carte de la caisse ouvre « Ma caisse ».

### 1.6 Démonstration et voix d'Afi encore dans l'application — moyen
- **Constat** : la démonstration n'était plus proposée mais son code et ses 50 fichiers de voix étaient
  encore dans l'application (plus lourde, code mort).
- **Correction** : tout est supprimé (code, voix, tests). L'action GitHub « 6 » est gardée telle quelle.
- **Test** : « 0.37 : plus aucune démonstration dans l'application ».

### 1.7 Mots techniques — faible
- « Synchronisation… », « Synchroniser maintenant », « La synchronisation n'a pas pu se faire »,
  « Google Drive » : remplacés par « Envoi en cours… », « Envoyer et recevoir maintenant », « L'envoi n'a pas
  pu se faire. Vérifiez Internet et réessayez. », « compte Google ». « 2 envoyée(s) » devient « 2 envoyées ».
- Gardé volontairement : « Scanner le QR code » (mot connu de tous, écrit sur les téléphones).

### 1.8 Produit sans image : carré vide sur certains téléphones — faible
- **Constat** : un produit sans photo ni image affichait l'émoji « carton », qui sort en carré vide sur les
  téléphones sans police d'émojis.
- **Correction** : l'initiale du produit sur une pastille de couleur (toujours lisible).

### 1.9 Écrans vides peu utiles — faible
- « Ventes du jour » vide : « Aucune vente aujourd'hui. Touchez « Vendre » pour commencer. »
- « Ce qu'on me doit » vide : « Personne ne vous doit d'argent. » et comment faire un crédit.
- « Arrivage » sans produit : comment ajouter le premier produit.

## 2. Vérifié, sans problème (tests ajoutés)

- **Gros et détail** : 2 cartons de 24 reçus, 1 carton et 2 boîtes vendus → 22 boîtes, « 22 boîtes » affiché.
- **Bénéfice** : carton à 12 000 F acheté 24 × 450 F → 1 200 F ; 2 boîtes à 550 F → 200 F ; total 1 400 F.
- **Caisse en espèces seulement** : fond 5 000 + vente espèces 12 000 + remboursement espèces 300 − dépense
  1 000 = 16 300 F attendus ; le Flooz (1 100 + 200) et le crédit restent à part ; un comptage de 16 000 F
  affiche « il manque 300 F » au patron.
- **Crédit et remboursements partiels** : 1 100 F de crédit, 300 F puis 200 F remboursés → reste 600 F.
- **Très gros montants** : 19 999 sacs à 5 500 F = 109 994 500 F, bien affiché, bénéfice juste.
- **Retour sur une vente à crédit** : la dette baisse, la caisse ne bouge pas (déjà vérifié en 0.36).
- **Mise à jour sans perte** depuis la 0.35.2 **et** depuis la 0.36.0 (bases fabriquées par le vrai code de
  ces versions) : produits, stocks, ventes en gros, prix revendeur, produits comptés, ventes, crédits,
  vendeur, licence, profil de la boutique, chaîne du journal. Test `test/audit/mise_a_jour_0360_test.dart`.
- **Sans Internet, vendeur retiré, téléphone changé, codes vendeurs, « Mes appareils », QR et code à 8
  chiffres** : couverts par les tests existants, tous verts, rien n'a été modifié dans ces fonctions.
- **Les 3 rôles × 3 tailles** : chaque écran principal est ouvert dans les captures
  `test_captures/design_final_captures_test.dart`, sans erreur ni débordement.

## 3. Rapidité (boutique de 300 produits, 10 934 opérations, environ 10 000 ventes)

| Mesure | Temps |
|---|---|
| Démarrage complet de l'application | 33 ms |
| Résumé de l'accueil (vendu, bénéfice, caisse) | 8 ms |
| Ouvrir Vendre (produits et stocks) | 9 ms |
| Encaisser une vente | 12 ms |
| Tableau du patron (jour, semaine, mois) | 2 à 5 ms |
| Inventaire complet de 300 produits | 152 ms |
| Sauvegarde (fichier de 1,5 Mo) | 2,5 s (avec message d'attente) |

Mesuré sur PC (test `test_perf/un_an_test.dart`, `ZP_PERF_JOURS=50`). Un petit téléphone Android est
environ 5 à 10 fois plus lent : tout reste sous une demi-seconde, sauf la sauvegarde (quelques secondes).

## 4. Reste à surveiller (pas un défaut aujourd'hui)

- La sauvegarde complète prend quelques secondes sur un petit téléphone avec une très grosse boutique :
  un message d'attente est affiché ; à améliorer si un client s'en plaint.
- Les mots « QR code » et « Flooz », « Mixx by Yas » sont gardés : ce sont les mots du marché.
