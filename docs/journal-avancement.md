# Zéro Perte — Journal d'avancement

Ce fichier permet à une **nouvelle session** de reprendre exactement où le travail s'est arrêté.
Il est mis à jour **à la fin de chaque étape**.

---

## 1. Où en est-on ? (à lire en premier)

| | |
|---|---|
| **Dernière étape terminée** | **0.34.0** : résumé du soir, « Commander » sur WhatsApp, crédits en retard, page « Chiffres » |
| **Version publiée** | 0.34.0 (Android et Windows, voir les Releases GitHub) |
| **Prochaine étape** | 0.31.1 (4 phrases refaites le 23/11 après 8 h 12), puis priorités 1 et 2 (branche `claude/suite-apres-031`), 0.32, relais |
| **Méthode** | Branche de travail, tests + captures sur 4 tailles, puis fusion dans `main` (= publication). Rien de non testé sur `main`. |
| **Pour tout choix non décidé** | Prendre l'option la plus simple, la noter ici et la mettre dans le rapport avec une recommandation. |

### Décisions du propriétaire (validées le 21 novembre 2026, après le rapport de fin de bloc B)

| # | Décision | Ce qui a été fait |
|---|---|---|
| Q1 | **Démonstration oui** avant le code d'activation, avec des produits fictifs ; elle ne doit jamais servir à tenir une vraie boutique, et ses données ne passent jamais dans une boutique activée. | Fait (0.15.0) : bouton « Voir une démonstration » à l'étape « Code d'activation » → base **à part**, **effacée à chaque ouverture**, reçus « D-… » marqués « DÉMONSTRATION — SANS VALEUR », pas de sauvegarde ni de restauration, aucun ajout de produit, bandeau permanent + « Quitter ». `lib/app/demo.dart`. |
| Q2 | Claude lance l'action « 3 - Créer la clé des licences » avant le 28 novembre. | Fait le 21/11 : réussie, copie de secours chiffrée dans le coffre (`cle-licences/…run44909660257.pem.chiffre`), clé publique dans `assets/licence/cle_publique.txt`, un code de test (« TEST - ne pas utiliser ») fabriqué par l'action 4 est **accepté** par l'application, un code modifié est refusé. Aucun secret dans les journaux. La ligne de test reste dans `registre-clients.csv` du coffre (à ignorer). |
| Q3 | AVANT le 28 novembre (date d'expiration de ZP_JETON_COFFRE), le propriétaire crée `ZP_JETON_CODES` (1 an, écriture du coffre seulement). | L'action 4 utilise déjà `ZP_JETON_CODES` s'il existe, sinon `ZP_JETON_COFFRE`. Autorisations à cocher : voir le rapport. |
| Q4 | Garder le texte du message d'activation. | Rien à changer. |
| Q5 | Garder les conversions « à vérifier » ; le patron peut les corriger ; les agents vérifieront sur le terrain. | Rien à changer. |
| Q6 | Garder « Merci, à bientôt ! » et le texte joint au reçu WhatsApp. | Rien à changer. |
| Q7 | Retour partiel : annuler la vente entière puis la refaire. | Rien à changer. |
| Q8 | La sauvegarde doit être protégée par un code de **6 chiffres** et une méthode lente à deviner ; si c'est le même code que celui du patron pour entrer dans l'application, ne rien changer avant d'avoir expliqué l'impact. | C'est le même code (4 chiffres). **Rien n'a été changé** ; l'impact est expliqué dans le rapport, en attente de décision. |
| — | Réduire la taille de l'APK (26 → 33 Mo), garder armeabi-v7a, lien `releases/latest/download/ZeroPerte.apk` toujours valable. | Voir « Taille de l'APK » ci-dessous. |

---

## 2. Comment reprendre le travail (environnement)

- **Dépôt** : `ahiankonoujoseph102-wq/zero-perte` (public). Travail sur `main` (décision du propriétaire), la branche `claude/pensive-einstein-jfps3a` est tenue au même niveau.
- **Flutter 3.47.9** (stable), Java 17. Dans une session cloud vierge : télécharger Flutter dans `/opt/sdk/flutter` et le SDK Android (`cmdline-tools`, `platforms;android-36`, `build-tools;36.0.0`) dans `/opt/sdk/android`.
- **Tests** : `flutter analyze` puis `flutter test` (tests dans `test/`, les outils communs dans `test/support/outils.dart`). Les tests d'écran utilisent une **vraie base SQLite en mémoire** : après un geste qui écrit dans la base, utiliser `toucher(tester, …)` ou `attendre(tester)` (jamais `pumpAndSettle` seul : il attend sans fin si un rond de chargement tourne). Toujours lancer `flutter test` avec `timeout 560`.
- **Captures d'écran avec les vraies polices** : `flutter test test_captures --update-goldens` → images dans `test_captures/captures/` (non enregistrées dans git). Les regarder à chaque étape d'écran.
- **Fabrication de l'APK** : uniquement sur GitHub Actions (« 2 - Fabriquer l'APK »), à chaque push. Sur `main`, publication d'une **Release** (officielle, signée). Dans le conteneur de Claude, la fabrication locale de l'APK échoue (Maven Central refuse : erreur 429) : ce n'est pas grave, GitHub fabrique.
- **Suivre une fabrication** : API publique `https://api.github.com/repos/ahiankonoujoseph102-wq/zero-perte/actions/runs?branch=main&per_page=1`.
- **Numéro de version** : `pubspec.yaml` (`version: x.y.z+1`). Le numéro interne (`versionCode`) = nombre de commits (calculé par le workflow).
- **Secrets GitHub existants** : `ZP_SIGNATURE_MOT_DE_PASSE`, `ZP_CLE_SIGNATURE`, `ZP_JETON_COFFRE` (expire le 28 novembre 2026). Ne jamais les afficher.

## 3. Architecture du code (repères)

| Dossier | Contenu |
|---|---|
| `lib/domaine/` | Calculs purs, sans écran ni base : argent (`12 500 F`, monnaie), quantités (millièmes, sac → bol), calculs (stock, caisse, bénéfice), reçus, opérations (journal chaîné), vérification du téléphone |
| `lib/donnees/` | Base SQLite : `schema.dart` (tables en ajout seulement + déclencheurs), `journal_local.dart` (toutes les écritures passent par une opération), `reglages.dart` (réglages locaux modifiables) |
| `lib/services/` | Accès au téléphone (canal natif `tg.zeroperte/telephone` dans `MainActivity.kt`), voix (flutter_tts), aide WhatsApp (url_launcher) |
| `lib/app/` | `EtatApplication` : état global, étape de l'assistant (mémorisée dans les réglages pour la reprise) |
| `lib/ecrans/` | Écrans : accueil vendeur, assistant d'installation, gros boutons |
| `lib/theme/` | Couleurs (vert = entre, rouge = sort, ambre = crédit, bleu nuit = marque) et thème (police Atkinson Hyperlegible) |

Règles à respecter partout : montants **entiers en F**, quantités en **millièmes**, **aucune modification ni suppression** de l'historique, SQL compatible **SQLite 3.18** (Android 8 : pas d'UPSERT, de RETURNING, de JSON ni de fonctions de fenêtre).

---

## 4. Journal des étapes

### A1 — Fondations ✅ (version 0.1.0)
Projet Flutter, fabrication des APK (universel + par processeur) sur GitHub Actions, clé de signature dans les secrets GitHub, Releases. APK universel ≈ 25,8 Mo.

### A2 — Base locale ✅ (version 0.2.0)
Journal des opérations chaîné, déclencheurs anti-modification, conditionnements, vente au montant, consignes, reçus par téléphone, caisse. Tests chiffrés validés par le chef de projet (monnaie 3 250/5 000 → 1 750 F ; bénéfice 2 019 F ; écart −500 F).

### A3 — Style visuel ✅ (version 0.2.0)
Police Atkinson Hyperlegible, marque bleu nuit, écran d'accueil vendeur à 4 gros boutons, vérifié sur 4 tailles d'écran.

### B1 — Assistant d'installation, partie 1 ✅ (version 0.3.0)
**Fait :**
- Assistant pas à pas : écran de bienvenue, puis **vérification du téléphone** : version d'Android, **services Google** (bloquant s'ils manquent), place libre (bloquant sous 100 Mo, avertissement sous 300 Mo), voix française (avertissement seulement).
- **Voix** : chaque étape est lue automatiquement une fois ; gros bouton rond **haut-parleur** pour réécouter.
- Bouton **« Aide »** toujours visible : feuille avec les **2 numéros WhatsApp** (+228 72 24 02 31, +228 79 16 23 90), message prérempli avec l'étape et le modèle du téléphone (**aucune donnée de la boutique**).
- **Reprise** : l'étape en cours est mémorisée ; si le téléphone s'éteint, l'assistant repart au même endroit.
- Canal natif Kotlin (sans bibliothèque) pour lire les informations du téléphone.

**Tests (66 au total, tous réussis)**, par exemple :
- Place libre : **80 Mo → bloquant**, **250 Mo → avertissement**, **400 Mo → OK** (seuils 100 et 300 Mo).
- Lien d'aide : numéro « +228 72 24 02 31 » → `https://wa.me/22872240231?text=…` (message correctement encodé).
- Téléphone sans services Google (Huawei P40 lite) : écran rouge « Ce téléphone ne peut pas utiliser Zéro Perte », bouton « Demander de l'aide », l'installation reste bloquée.
- Écrans vérifiés sur 4 pouces, 5 pouces, 6,5 pouces et tablette, avec le texte agrandi ×1,5 : rien ne déborde.

**Problèmes restants :** aucun bloquant. La voix réelle n'a pas pu être testée hors téléphone (testée avec une fausse voix).

### B2 — Code d'activation signé ✅ (version 0.4.0)
**Fait :**
- Codes `ZP1.<charge>.<signature>` signés **Ed25519** ; vérifiés **sans Internet** dans l'application (bibliothèque `cryptography`), avec la clé **publique** seulement (`assets/licence/cle_publique.txt`).
- Le patron **copie le message WhatsApp entier** puis touche **« Coller le code »** : le code est retrouvé même entouré de texte ou coupé sur plusieurs lignes. (WhatsApp ne rend cliquables que les liens https : un lien d'activation direct n'était pas possible simplement.)
- **2 téléphones par licence** ; code **« téléphone en plus »** (extension) ; un code ne sert qu'une fois ; extension refusée sans licence ou pour une autre boutique. Le contrôle du nombre réel de téléphones se fera en D4 (il faut le Drive).
- Activation enregistrée comme **opération du journal** (`licence.activee`) : elle sera synchronisée et restaurée avec le Drive.
- Nouvelle étape de l'assistant : **« Code d'activation »** (3 consignes illustrées, voix, message d'erreur rouge **en haut** de l'écran).
- Workflows : **« 3 - Créer la clé des licences (une seule fois) »** (clé privée en secret `ZP_CLE_LICENCES`, copie chiffrée dans le coffre, clé publique enregistrée dans l'application) et **« 4 - Générer un code d'activation »** (message prêt à transférer + **registre des clients** rangés dans le **coffre privé** ; nom et code **masqués** dans le journal public).
- Script `outils/licence.sh` (création de clé, signature OpenSSL), refuse d'écrire une clé privée dans le dépôt.

**Tests (79 au total, tous réussis)**, par exemple :
- Un code signé par **OpenSSL** (comme sur GitHub) est accepté par l'application : boutique `bq-test-0001`, « Boutique Mama Ama », **2 téléphones**.
- Licence 2 téléphones + 1 code « téléphone en plus » = **3 téléphones** ; le même code utilisé 2 fois est **refusé**.
- Une seule lettre changée dans le nom (« Ama » → « Amb ») : **signature refusée**.

**Problèmes restants :** la clé des licences n'est pas encore créée (Q2) : tant qu'elle ne l'est pas, aucune boutique ne peut être activée.

### B3 + B4 — Personnalisation et catalogues préremplis ✅ (version 0.5.0)
*Livrées ensemble : l'écran des produits fait partie de l'assistant de personnalisation.*

**Fait :**
- 9 nouvelles étapes dans l'assistant (11 étapes comptées au total) : **type(s) de boutique** (grille d'images) → **nom + photo/logo** (appareil photo ou galerie, image réduite à 480 px) → **téléphone** (format togolais vérifié, « +228 90 12 34 56 ») **+ ville** (20 villes + « Autre ») **+ quartier + repère** → **couleur** (8 couleurs, sans vert/rouge/ambre, avec aperçu) → **produits** du catalogue (« Je vends ça ») → **prix** (prix de l'unité et de chaque conditionnement ; les nombres estimés sont marqués « à vérifier ») → **aperçu du reçu** + message du bas → **code secret du patron** (4 chiffres, confirmé 2 fois, codes trop faciles refusés, haché PBKDF2) → **fin** (raccourci « Boutique … » avec son logo sur l'écran du téléphone).
- La **couleur de la boutique** colore l'application (boutons, barre de progression, « Fermer la caisse ») ; l'accueil affiche le **nom et le logo** de la boutique.
- **Catalogue** : `assets/catalogues/catalogues.json`, **26 types de boutiques, 164 produits** (pharmacie et point Mobile Money exclus de la V1, voir décisions), avec unités, conditionnements, vente au montant et emballages consignés. Emoji choisis **compatibles Android 8** (un test interdit les emoji récents qui s'afficheraient en carrés vides).
- Base locale **version 2** : colonnes ajoutées (emoji, catalogue, vente au montant, photo, « à vérifier ») avec **mise à niveau automatique** des téléphones déjà installés (testée).
- Configuration de la boutique et utilisateurs enregistrés comme **opérations du journal** (synchronisées plus tard).

**Tests (131 au total, tous réussis)**, par exemple :
- Parcours complet automatique : alimentation + boissons → « Boutique Mama Ama » avec photo → « 90 12 34 56 » devient **« +228 90 12 34 56 »**, adresse **« Bè-Kpota, Lomé »** → couleur prune → riz et bière → riz **600 F le kg**, **sac de 50 kg à 28 000 F** → code **1234 refusé** (trop facile), 4827 puis 4828 refusés (différents), 4827 deux fois accepté → raccourci ajouté → accueil.
- Initiales du logo : « Boutique Mama Ama » → **MA**, « Quincaillerie l'Espoir » → **QE**.
- Mise à niveau : une base créée par la version 0.2.0 est ouverte par la 0.5.0 sans perte, puis accepte un produit avec emoji.

**Problèmes restants :** les emoji n'apparaissent pas dans les captures d'écran de test (pas de police emoji dans l'outil), ils s'affichent sur Android. Le raccourci d'écran d'accueil dépend du lanceur du téléphone (certains refusent : un message le dit).

### B5 — Arrivages ✅ (version 0.6.0)
**Fait :**
- **Espace patron** : bouton « clé » en haut de l'accueil → **code secret du patron** → menu en grandes tuiles (les étapes suivantes y ajoutent leurs entrées : `entreesPatron` dans `lib/ecrans/patron/espace_patron.dart`).
- **Code secret** : 5 erreurs → **bloqué 5 minutes** (mémorisé, même si l'application est fermée) ; un compte bloqué par le patron est refusé.
- **Arrivages** : liste des produits avec leur **stock en mots** (« 2 sacs de 50 kg + 5 kg ») ; formulaire : unité (le plus grand conditionnement par défaut), **compteur géant − / +**, **prix payé au total** (avec le prix pour 1 sac calculé), enregistrement comme opération du journal.
- Outils communs : page standard, gros bouton, image produit (photo ou pictogramme), messages vert/rouge, demande de code secret (`lib/ecrans/communs.dart`).
- APK universel de la version 0.5.0 : **30,9 Mo** (bibliothèques photo et signature ajoutées).

**Tests (140 au total, tous réussis)**, par exemple :
- Arrivage de **2 sacs de 50 kg** de riz payés **50 000 F** → affiche « Soit 25 000 F pour 1 sac de 50 kg », stock **100 kg** = « 2 sacs de 50 kg ».
- Stock lisible : 85 kg avec des sacs de 50 kg → **« 1 sac de 50 kg + 35 kg »** ; « donne pour 100 F » de riz → **0,6 bol**.
- **5 codes faux** → « Trop d'erreurs » ; le bon code est refusé ; **6 minutes plus tard**, il est accepté.

**Problèmes restants :** aucun.

### B6 — Vendre ✅ (version 0.7.0)
**Fait :**
- **Vendre** : grille des produits (pictogramme ou photo, nom, prix « 600 F / kg ») ; un produit avec conditionnements ou « au montant » ouvre un choix : **1 kg — 600 F**, **1 sac de 50 kg — 28 000 F**, **« Pour un montant »** (50, 100, 200, 250, 500, 1 000 F ou clavier). Un produit sans prix est refusé avec un message.
- **Panier** : même article regroupé (1 kg + 1 kg = 2 kg), boutons − / + / corbeille, **total géant en vert**.
- **Encaisser** : « À payer » et « Le client donne » côte à côte, choix **Espèces / Flooz / Mixx (T-Money)**, billets rapides (compte exact, 500 … 10 000 F), clavier ; **« Rendre 3 000 F »** avec les billets et pièces à rendre, ou **« Il manque … »** en rouge (validation impossible). Mobile Money : rappel de vérifier le message reçu + **4 derniers chiffres** de la transaction (facultatif). **Voix** : « À payer : 2000 francs », « Vente enregistrée. Rendez 3000 francs ».
- **Vente enregistrée** : numéro de reçu (A-000001…), monnaie à rendre en très grand, « Nouvelle vente » (le panier se vide).

**Tests (150 au total, tous réussis)**, par exemple :
- **2 kg de riz (600 F) + 1 paquet de sucre (800 F) = 2 000 F** ; le client donne 5 000 F → **rendre 3 000 F = 1 billet de 2 000 + 1 billet de 1 000** ; reçu **A-000001** ; stock de riz **100 kg → 98 kg** ; caisse espèces **+2 000 F**.
- Riz **« pour 100 F »** payé par **Mixx** (référence 4821) : stock **−0,167 kg** (100 ÷ 600), caisse Mixx **+100 F**, caisse espèces inchangée.
- Total 600 F, le client donne 500 F → **« Il manque 100 F »**, bouton « Valider » désactivé.

**Problèmes restants :** sur un écran de 4 pouces, l'écran « Encaisser » défile un peu pour voir le bas du clavier (choix délibéré : le clavier garde des touches d'au moins 30 points).

### B7 — Vendeurs et connexion par code ✅ (version 0.8.0)
**Fait :**
- Au démarrage : écran **« Qui êtes-vous ? »** (avatars avec initiale et couleur, « Patron » / « Vendeur » / « Bloqué ») → **code secret** de la personne → accueil à son nom. Bouton **« Changer d'utilisateur »** sur l'accueil.
- Le patron qui termine l'installation est connecté automatiquement.
- Espace patron → **Vendeurs** : ajouter (prénom + code **choisi par le vendeur lui-même**, confirmé 2 fois, codes trop faciles refusés), **bloquer / débloquer**, **changer le code**. Chaque changement = nouvelle version dans le journal.
- **Chaque opération porte l'identifiant de la personne connectée** (auteur).

**Tests (156 au total, tous réussis)**, par exemple :
- Le patron ajoute **Kossi (code 5913)** ; Kossi tape le code du patron **4827 → « Code faux »**, puis **5913 → accueil « Kossi »** ; sa vente de riz est enregistrée avec **l'auteur = Kossi**.
- Kossi **bloqué** → connexion refusée (« bloqué ») ; **débloqué** → il se reconnecte.
- Écran « Qui êtes-vous ? » vérifié sur 4 tailles d'écran.

**Note :** la version 0.7.0 a d'abord été envoyée avec un test périmé (fabrication en échec), corrigé aussitôt par le commit suivant ; désormais l'enregistrement n'a lieu que si tous les tests passent.

### B8 — Annulation, retour client, perte déclarée ✅ (version 0.9.0)
**Fait :**
- Écran **Vendre** → bouton **« Ventes du jour »** : reçu, heure, vendeur, moyen de paiement, montant ; une vente annulée apparaît **barrée** avec son motif.
- Détail d'une vente → **« Annuler cette vente »** (rouge) → **motif obligatoire** : « Erreur en tapant la vente », **« Retour du client »**, « Le client a changé d'avis », ou « Autre » (texte libre). La marchandise **revient en stock**, l'argent **sort de la caisse** du bon moyen de paiement, la voix dit « Vente annulée ». Une vente ne peut être annulée qu'une fois ; rien n'est jamais effacé.
- Bouton **Dépense** → deux grands choix : « De l'argent est sorti » (B9) ou **« De la marchandise est perdue »** → produit → unité → compteur → **motif obligatoire** (cassé, périmé, pourri, rats ou insectes, volé, mouillé) → stock diminué.
- **Bug trouvé et corrigé grâce aux tests** : la liste des ventes ne se rafraîchissait pas après une annulation (`setState` appelé avec une fonction qui renvoyait une tâche asynchrone). La liste se recharge maintenant à chaque changement de la boutique.

**Tests (164 au total, tous réussis)**, par exemple :
- Vente de **2 kg de riz (1 200 F)** puis annulation « **Retour du client** » : stock **98 kg → 100 kg**, caisse espèces **1 200 F → 0 F**, liste « Annulée : Retour du client », plus de bouton « Annuler ».
- Motif libre « **Mauvais client** » enregistré tel quel.
- Perte de **3 kg de riz mouillé** : stock **100 kg → 97 kg** ; sans motif, le bouton reste désactivé.

**Problèmes restants :** le retour **partiel** (le client rend seulement une partie) n'existe pas encore : on annule la vente entière puis on refait une vente. À prévoir si les patrons le demandent.

### B9 — Fonds de caisse, dépenses, argent pris par le patron ✅ (version 0.10.0)
**Fait :**
- **Ouverture de la caisse** : au premier « Vendre » après une fermeture (ou au tout premier jour), l'application demande « Combien d'argent dans la caisse pour rendre la monnaie ? » (clavier géant, 0 accepté). Ensuite « Vendre » s'ouvre directement.
- **Dépense d'argent** (bouton Dépense → « De l'argent est sorti ») : motif obligatoire par icône (transport, repas, électricité/eau, loyer, achat de marchandise, réparation, taxes/mairie, crédit téléphone, ou « Autre » écrit), moyen de paiement (espèces, Flooz, Mixx), montant. Un rappel « Transport · Espèces » s'affiche au-dessus du montant.
- **Argent pris** (nouvelle tuile de l'espace patron) : le patron note ce qu'il prend dans la caisse, pour que la caisse ne paraisse pas volée à la fermeture.
- Un seul écran réutilisable (`lib/ecrans/caisse/saisie_montant.dart`) sert aux trois usages.
- Défaut corrigé grâce aux tests : le message « Caisse ouverte » cachait le bouton « Encaisser » de l'écran suivant ; il est supprimé.

**Tests (171 au total, tous réussis)**, par exemple :
- Caisse ouverte avec **5 000 F**, vente de **1 200 F**, dépense transport **1 500 F**, patron prend **3 000 F** → caisse espèces attendue **1 700 F**.
- Dépense « Autre : Sachets » de **500 F payée en Flooz** → compte Flooz −500 F, espèces inchangées.
- Caisse ouverte avec **10 000 F**, « Argent pris » **2 000 F** → attendu **8 000 F**. Sans motif, « Enregistrer la dépense » reste désactivé.

**Problèmes restants :** les motifs de dépense sont une liste fixe ; à ajuster selon les retours des boutiques.

### B10 — Fermeture de caisse à l'aveugle ✅ (version 0.11.0)
**Fait :**
- Bouton **« Fermer la caisse »** : un écran de comptage par moyen de paiement (« Étape 1 sur 2 »…). Toujours les **espèces** (« Comptez tout l'argent de la caisse ») ; **Flooz** et **Mixx** seulement s'ils ont reçu des paiements depuis l'ouverture (« Combien avez-vous reçu sur Flooz ? »).
- **Comptage aveugle** : le vendeur ne voit jamais combien il devrait y avoir. À la fin il voit seulement « Caisse fermée. Merci ! Le patron verra le résultat. » (et la voix le dit).
- L'attendu est **calculé et enregistré avec la fermeture** (journal non modifiable) : le patron voit l'écart même des jours plus tard. Si c'est le patron qui ferme, il voit l'écart tout de suite.
- Espace patron → nouvelle tuile **« Caisses fermées »** : liste (date, qui a fermé, « Juste » en vert / « Il manque 200 F » en rouge / « En trop : 100 F » en ambre) → détail par moyen de paiement (« Il devait y avoir », « Compté », écart).
- Après une fermeture, la caisse est fermée : le prochain « Vendre » redemande le fonds de caisse (B9). Les calculs repartent de zéro après chaque fermeture.
- **Règle Mobile Money** : pour Flooz et Mixx, on compare seulement l'**argent reçu** (ventes) ; une dépense payée par Flooz reste enregistrée mais n'entre pas dans le comptage (sinon « il devait y avoir −500 F » n'aurait pas de sens).
- Défauts corrigés grâce aux tests/captures : à l'étape 2 l'écran restait défilé et cachait la question ; titre coupé sur 4 pouces.

**Tests (180 au total, tous réussis)**, par exemple :
- Fonds **5 000 F** + vente **1 200 F** → le vendeur Kossi compte **6 000 F** : il ne voit aucun chiffre ; le patron voit « **Il manque 200 F** » (attendu 6 200 F, compté 6 000 F, fermé par Kossi).
- Fonds 5 000 F, vente 1 200 F espèces, vente 600 F Flooz, patron prend 300 F, dépense Flooz 500 F → espèces comptées **5 900 F = Juste** ; Flooz compté **700 F** → « **En trop : 100 F** ».
- Fermeture puis nouvelle ouverture avec 2 000 F et dépense repas 700 F → caisse en cours attendue **1 300 F** (l'ancienne journée n'est plus comptée).

**Problèmes restants :** la fermeture est par téléphone ; avec deux téléphones (bloc D, synchronisation) il faudra décider si chaque téléphone ferme sa propre caisse (choix provisoire : oui, une caisse par téléphone).

### B11 — Reçu partagé sur WhatsApp ✅ (version 0.12.0)
**Fait :**
- Après chaque vente, l'écran « Vente enregistrée » montre le **vrai reçu** aux couleurs de la boutique (logo ou initiales, nom, téléphone, adresse, n° de reçu, date, lignes « 2 kg de Riz », total, moyen de paiement, message de fin), et un bouton **« Envoyer le reçu sur WhatsApp »**.
- Un toucher : le reçu est transformé en **image** et WhatsApp s'ouvre directement (WhatsApp ou WhatsApp Business) pour choisir le client ; sans WhatsApp, le menu de partage d'Android s'ouvre. Texte joint : « Reçu n° A-000001 – Boutique : 1 200 F. Merci, à bientôt ! ».
- Le reçu peut être **renvoyé** depuis « Ventes du jour » → détail d'une vente (sauf vente annulée).
- Numéros de reçu **sans trou**, préfixe par téléphone (A-000001, A-000002…) : déjà en place depuis B6, vérifié par un test.
- Code Android ajouté sans nouvelle bibliothèque Flutter : partage natif (`MainActivity.kt`, méthode `partagerImage`) + `FileProvider` (`res/xml/chemins_partage.xml`, seul le dossier temporaire des reçus est partagé). Dépendance `androidx.core` ajoutée dans `android/app/build.gradle.kts`.

**Tests (188 au total, tous réussis)**, par exemple :
- Vente de **2 kg de riz** → reçu affiché « 2 kg de Riz », bouton « Envoyer » → une **vraie image PNG** est envoyée avec le texte « Reçu n° A-000001 – Boutique Mama Ama : 1 200 F. … ».
- Deux ventes puis « Ventes du jour » → A-000002 → « Envoyer » → texte « Reçu n° A-000002 ».
- Trois ventes → numéros **1, 2, 3**, aucun manquant.

**Problèmes restants :** le partage réel vers WhatsApp ne peut être vérifié que sur un téléphone (les tests simulent Android). Le **texte envoyé au client** est à valider par le propriétaire (question du rapport de fin de bloc B).

### B12 — Tableau du patron ✅ (version 0.13.0)
**Fait :**
- Espace patron → première tuile **« Tableau »**, avec trois choix : **Aujourd'hui**, **Cette semaine** (depuis lundi), **Ce mois** (depuis le 1er).
- Chiffres en grand : **Ventes** (annulations déduites, nombre de ventes), **Bénéfice estimé** (prix de vente − prix d'achat du dernier arrivage ; les produits sans prix d'achat connu sont exclus et le patron est prévenu), **Dépenses**.
- **Les plus vendus** : les 3 produits qui ont rapporté le plus sur la période.
- **Stock bas**, sans réglage : un produit apparaît s'il est **épuisé** (déjà reçu ou vendu), s'il est **sous le seuil** fixé par le patron (champ prévu, pas encore d'écran pour le régler), ou s'il reste **moins que ce qui s'est vendu ces 7 derniers jours**.

**Tests (199 au total, tous réussis)**, par exemple :
- Riz : 100 kg reçus à 500 F/kg, 2 kg vendus 1 200 F ; sucre : 1 paquet reçu 700 F, vendu 800 F ; dépense 1 500 F → **Ventes 2 000 F (1 vente), Bénéfice 300 F, Dépenses 1 500 F**, plus vendu « 1. Riz », **Sucre épuisé**, riz absent du stock bas.
- Samedi 21 novembre 15 h 30 → « Cette semaine » commence le **lundi 16 novembre**, « Ce mois » le **1er novembre**.
- Sans seuil : **3 kg** restants alors que **10 kg** se sont vendus en 7 jours → « Moins d'une semaine de vente » ; 30 kg restants → pas d'alerte.

**Problèmes restants :** pas encore d'écran pour régler le seuil d'alerte d'un produit (la règle automatique suffit pour le pilote) ; le tableau compte les ventes **de ce téléphone** jusqu'à la synchronisation (bloc D).

### B13 — Sauvegarde chiffrée ✅ (version 0.14.0)
**Fait :**
- Espace patron → tuile **« Sauvegarde »** → « Créer une sauvegarde » → code secret du patron → fichier `ZeroPerte-<boutique>-<date>.zps` envoyé par le menu de partage d'Android (WhatsApp du patron, Google Drive, Bluetooth…). L'écran affiche la date de la dernière sauvegarde (en rouge s'il n'y en a jamais eu).
- Le fichier contient **tout le journal** (la seule source des calculs), **compressé puis chiffré** (AES-256-GCM, clé tirée du code du patron par PBKDF2, 60 000 tours). Toute modification du fichier est détectée.
- **Restauration** (code prêt et testé, `EtatApplication.restaurerSauvegarde`) : seulement sur un téléphone **vide** ; chaque chaîne d'opérations est vérifiée avant d'écrire quoi que ce soit ; le téléphone reprend l'identité et le préfixe de reçu de l'ancien, donc les reçus continuent (A-000002 après A-000001).
- **Bonus Android** : sauvegarde automatique d'Android activée explicitement (`android:allowBackup="true"`) : avec le compte Google de la boutique, la base est remise sur un téléphone neuf.

**Tests (209 au total, tous réussis)**, par exemple :
- Boutique avec ventes, dépense et stock → sauvegarde → **téléphone neuf** → restauration avec le code **4827** : même nom de boutique, patron Ama, riz **98 kg**, dépenses **1 500 F**, chaîne intacte ; la vente suivante porte le reçu **A-000002**.
- Mauvais code **0000** → refus, **aucune** opération écrite ; restaurer sur un téléphone qui a déjà des ventes → refus.
- Sauvegarde trafiquée (vente de **2 000 F** changée en **200 F**) → « Sauvegarde modifiée ou incomplète : restauration refusée ».

**Problèmes restants :**
- **Pas encore d'écran pour restaurer** (choisir le fichier reçu) : il faut un accès aux fichiers du téléphone. Prévu avec le bloc D (la synchronisation Google Drive sera le moyen normal de tout retrouver) ; d'ici là la sauvegarde automatique d'Android couvre le cas du téléphone remplacé.
- Le fichier est fermé avec le **code de 4 chiffres** du patron : il arrête un curieux, pas un spécialiste qui essaierait les 10 000 codes (question Q8).

### Après le bloc B — décisions Q1 à Q8, clé des licences, démonstration ✅ (version 0.15.0)
**Fait :**
- **Clé des licences** créée (action 3, lancée par Claude avec l'accord du propriétaire) et vérifiée de bout en bout (voir Q2 plus haut).
- **Défaut corrigé dans l'action 4** grâce au code de test : un nom de boutique avec des espaces (« TEST - ne pas utiliser ») faisait échouer l'action. Les valeurs sont maintenant protégées (`printf %q`), testé aussi avec des guillemets, « » et `$(…)`.
- **Démonstration** (Q1) : voir le tableau des décisions.

**Tests (217 au total, tous réussis)**, par exemple :
- Démonstration ouverte deux fois : la vente « D-000001 » faite la première fois a disparu la deuxième (riz de nouveau à **100 kg**), et la vraie base du téléphone a toujours **0** opération.
- Activation → « Voir une démonstration » → vente → reçu « **DÉMONSTRATION — SANS VALEUR** » → « Quitter » → retour à « Coller le code ».
- La clé publique officielle est présente et fait bien **32 octets**.

### Taille de l'APK ✅ (fabrication à partir de la version 0.14.0-n27)
**Mesure avant :** APK universel **33 253 376 octets (33,3 Mo)** ; arm64 18,2 Mo ; armv7 15,6 Mo. Il n'y avait déjà ni x86 ni x86_64. Le gros du poids : les moteurs Flutter et le code de l'application (32 et 64 bits), rangés **non compressés** dans l'APK (≈ 31 Mo à eux seuls). La hausse depuis 26–27 Mo vient du code ajouté (chiffrement, photos, catalogues, écrans).
**Fait :**
- `android/app/build.gradle.kts` : `jniLibs.useLegacyPackaging = true` → les bibliothèques natives sont compressées dans l'APK (Android les décompresse à l'installation ; l'espace occupé sur le téléphone une fois installé reste à peu près le même, le **téléchargement** est divisé par deux).
- Fabrication avec `--obfuscate --split-debug-info` : le code de l'application est plus petit ; les « symboles » (pour lire un rapport de plantage) sont gardés 90 jours comme artefact GitHub, pas dans l'APK.
**Mesure après :** APK universel **14 691 004 octets (14,7 Mo)** ; arm64 **7,9 Mo** ; armv7 **7,3 Mo**. Vérifié dans l'APK publié : `native-code: arm64-v8a armeabi-v7a`, `minSdkVersion 26` (Android 8), même lien `releases/latest/download/ZeroPerte.apk`.

### C1 — Crédit client ✅ (version 0.16.0)
**Fait :**
- Bouton **« Crédit »** de l'accueil → liste des clients (ceux qui doivent le plus en haut, « Les clients doivent en tout », recherche au-delà de 5 clients) → **fiche client** : photo ou initiales, « Doit 1 800 F » en ambre, « Peut encore prendre … », historique (achats, achats annulés, remboursements).
- **Nouveau client** : nom, téléphone WhatsApp (mis au format +228), photo ; **plafond** (dette maximale) : le patron le choisit (2 000 à 50 000 F) ; un vendeur ne peut pas le choisir (5 000 F par défaut).
- **Vente à crédit** : 4e moyen de paiement « Crédit » à l'encaissement → « Choisir le client » → « Après cette vente, il devra … » ; au-delà du plafond, la vente est bloquée (« il peut encore prendre … »). Le reçu indique « À crédit » et « Client : Kofi — reste à payer : … ».
- **Remboursement partiel** : « Il rembourse » → montant + espèces/Flooz/Mixx → l'argent entre dans la caisse de ce moyen de paiement (compté à la fermeture) → **reçu de remboursement** (« A payé », « Reste à payer ») envoyé en image sur WhatsApp.
- **« Rappeler sur WhatsApp »** : ouvre WhatsApp sur le numéro du client avec le message « Bonjour Kofi, petit rappel de Boutique … : il reste 600 F à payer. Merci ! ».
- Le crédit **n'est pas une caisse** : une vente à crédit ne change aucune caisse ; une vente à crédit annulée efface la dette et remet le stock. Le tableau du patron montre « Les clients doivent (crédit) ».
- Base : schéma **version 3** (tables `clients_versions` et `mouvements_credit`, en « ajout seulement », colonne `ventes.client_id`) ; opérations `client.defini` et `credit.remboursement`.
- Écran d'encaissement : sur les boutons, « Mixx » au lieu de « Mixx (T-Money) » (avec 4 boutons, le texte devenait illisible sur 4 pouces).

**Tests (232 au total, tous réussis)**, par exemple :
- Kofi (plafond 5 000 F) prend **3 kg de riz à crédit (1 800 F)** → il doit **1 800 F**, aucune caisse ne bouge, reçu « Client : Kofi — reste à payer : 1 800 F ».
- Il **rembourse 1 000 F** en espèces → reste **800 F**, caisse espèces attendue **+1 000 F**, reçu envoyé avec « Kofi a remboursé 1 000 F. Reste à payer : 800 F. Merci ! ».
- Kofi doit déjà **4 500 F** (plafond 5 000 F) → 2 kg (1 200 F) **bloqués** : « il peut encore prendre 500 F ».

**Problèmes restants :** une fiche client ne peut pas encore être supprimée ou désactivée depuis l'écran (prévu : bouton patron « Ne plus faire crédit »). Les soldes sont ceux de ce téléphone jusqu'à la synchronisation (bloc D).








## Travail de nuit du 21 au 22 novembre 2026 (sans validation intermédiaire)

Consignes : choix non décidés → option la plus simple, notée ici et dans le rapport. Écrans vérifiés sur
petit téléphone 4 pouces, grand téléphone, tablette 10 pouces et PC 1366×768. APK universel < 20 Mo.

### Analyse du concurrent (MikahPOS) ✅
`docs/analyse-concurrent.md` (texte seulement). Les deux vidéos ont été regardées image par image sur une
copie hors du dépôt, puis effacées. Le son a été transcrit automatiquement (modèle français hors ligne),
mais le résultat est presque inutilisable (bruit) : seuls quelques mots sûrs.

### Étape 1 — Code du patron à 6 chiffres + carnet de clients ✅ (version 0.17.0)
**Fait :**
- **Code du patron : 6 chiffres** (création, connexion, sauvegarde). Hachage plus lent : 120 000 tours
  PBKDF2-SHA256 pour le patron (vendeurs : 4 chiffres, 20 000 tours, inchangé). Codes trop faciles refusés
  (un seul chiffre répété, suites 123456 / 654321, alternances 121212).
- **Écran unique « Nouveau code du patron »** pour les boutiques installées avant : le patron tape son code
  actuel (4 chiffres, pour qu'un vendeur ne puisse pas le faire), puis deux fois le nouveau (6 chiffres).
- **Sauvegarde** : nouveau format « ZPS2 », clé tirée du code par PBKDF2 300 000 tours ; les anciens
  fichiers « ZPS1 » se lisent toujours. Démonstration : code patron « 135790 ».
- **Carnet de clients** : quartier et e-mail (facultatifs), **téléphone obligatoire pour le crédit**
  (vérifié à la vente), recherche par nom ou par téléphone (même tapé avec des espaces), page « Clients ».
  Le vendeur peut **ajouter** ; seul le patron peut **modifier, supprimer** (refusé si le client doit
  encore de l'argent ; rien n'est effacé du journal, la fiche est désactivée) et **exporter** (fichier
  `clients.csv` lisible par Excel, envoyé par le menu de partage). Schéma de la base : version 4.

**Tests (244 au total, tous réussis)**, par exemple :
- Patron installé avant 0.17 avec le code **4827** : « 1111 » → « Code faux », « 4827 » → nouveau code
  « 123456 » refusé (trop facile), « 730518 » deux fois → accueil ; l'ancien code ne marche plus et le
  nouveau n'apparaît nulle part dans le journal.
- Le vendeur Kossi : ajouter Yao (sans téléphone) ✅ ; lui faire crédit ❌ « Ajoutez le téléphone de Yao
  pour lui faire crédit. » ; modifier / supprimer / exporter ❌.
- Le patron cherche « 90 11 » → seul Kofi apparaît ; l'export contient la ligne de Kofi avec son
  téléphone au format +228 et son quartier.

**Choix pris au plus simple :** 120 000 tours pour le code patron (environ 1 seconde sur un téléphone
d'entrée de gamme à chaque entrée du patron) ; export au format CSV (Excel) plutôt qu'en PDF.

### Étape 2 — Ce qui manquait face au concurrent ✅ (version 0.18.0)
**Fait :**
- **Client dans le panier, en un toucher** : sous le panier, « Client (facultatif) » → liste → le client
  apparaît en étiquette (le toucher l'enlève). Par défaut : vente sans client. Le client est enregistré
  avec la vente quel que soit le paiement, écrit sur le reçu (« Client : Yao »), et déjà choisi si l'on
  passe en « Crédit ».
- **Billets à l'encaissement** : « Compte exact », 1 000, 2 000, 5 000, 10 000 F (seulement les billets plus
  grands que le total, et toujours 10 000 F). Nous les avions déjà ; le 500 F a été retiré.
- **Filtre par catégorie** au-dessus des produits (Tous, Alimentation, Boissons…), seulement quand la
  boutique a des produits de plusieurs catégories.
- **Tableau du patron : barres des ventes des 7 derniers jours** (aujourd'hui en vert foncé).
- Classement complet des manques : `docs/analyse-concurrent.md`.

**Tests (254 au total, tous réussis)**, par exemple :
- 2 kg de riz pour **Yao** (sans téléphone), payé en espèces → reçu « Client : Yao », Yao doit **0 F**.
- Kofi choisi dans le panier → « Crédit » → déjà sélectionné : « Après cette vente, il devra 1 200 F. »
- Total **1 200 F** → pas de bouton 1 000 F ; « 2 000 F » → rendre **800 F**. Une vente de 1 200 F aujourd'hui
  → barre « auj. » = 1 200 F, les 6 autres jours à 0.

**Choix pris au plus simple :** n'importe quel client (même sans téléphone) peut être choisi pour une vente
payée ; le téléphone reste exigé seulement pour le crédit.

### Étape 3 — Tablette, paysage et PC ✅ (version 0.19.0)
**Fait :**
- **Vendre** sur grand écran (à partir de 840 points de large : tablette 10 pouces en paysage, PC) :
  produits à gauche, **panier à droite** (client, lignes, total, « Encaisser ») ; cases un peu plus grandes.
- **Tableau du patron** : chiffres à gauche, graphique des 7 jours et listes à droite.
- **Accueil** : les 4 gros boutons restent groupés au centre (900 points maximum).
- **Toutes les autres pages** (encaissement, clients, dépenses, caisse, espace patron, connexion,
  installation…) : une seule colonne centrée, 720 points maximum, au lieu d'être étirées sur tout l'écran.
- Le téléphone est **exactement** comme avant (les deux colonnes n'apparaissent qu'à partir de 840 points).
- Tous les tests « rien ne déborde » tournent maintenant aussi sur **tablette 10 pouces paysage (1280×800)**
  et **PC 1366×768**, en plus des 4 tailles d'avant.

**Tests (tous réussis)**, par exemple :
- PC 1366×768 : 1 kg de riz + 1 paquet de sucre → panier à droite, **total 1 400 F** ; « 5 000 F » → rendre
  **3 600 F** (2 000 + 1 000 + 500 + 100).
- Tablette paysage : accueil centré, aucun débordement sur aucun des écrans testés.
- Téléphone 4 pouces : captures identiques à la version 0.18.

**Choix pris au plus simple :** les pages sans intérêt à deux colonnes sont centrées plutôt que redessinées.

### Étape 4 — Bloc D : synchronisation par Google Drive, alertes, restauration ✅ (version 0.20.0)
**Fait (sans aucun compte extérieur) :**
- **Moteur de synchronisation** (`lib/synchro/synchro.dart`) : chaque appareil dépose SES opérations dans
  le dossier caché de l'application du Google Drive de la boutique (`ops-<appareil>-<n°>-<n°>.json`) et lit
  celles des autres ; aucun conflit possible. Chaque chaîne reçue est vérifiée (suite sans trou, empreintes) :
  un fichier trafiqué est refusé et rien n'est écrit.
- **Mis en commun entre appareils** : ventes, stock, caisse, clients et soldes. Le **plafond de crédit compte
  les dettes prises sur tous les appareils** (dès qu'ils ont synchronisé).
- **Appareils et licence** : chaque appareil s'inscrit (`appareil-<id>.json`) ; au-delà du nombre de la
  licence, refus clair. Un 2e appareil prend tout seul un autre préfixe de reçus (B, C…).
- **Client Google Drive** (API REST v3, sans bibliothèque) et **connexion Google** (bibliothèque
  `google_sign_in`, autorisation `drive.appdata` seulement). Relève **à chaque ouverture et toutes les 15 min**
  quand l'application est ouverte.
- **Espace patron → « Appareils et Drive »** : connecter le compte Google de la boutique, dernière
  synchronisation, erreurs, appareils (« reçus A (celui-ci) »).
- **Remettre une sauvegarde** : écran de bienvenue → « J'ai déjà une boutique : la retrouver » →
  **depuis Google Drive** (« ce téléphone remplace : Ama » = il continue ses reçus, ou « appareil en plus »)
  ou **depuis un fichier .zps** + code du patron (6 chiffres, ou 4 pour une ancienne sauvegarde).
- **Alertes graves** : relais Cloudflare prêt (`relais/worker.js`, testé avec Node) ; l'application envoie
  une alerte si un vendeur ferme la caisse avec **1 000 F ou plus de manque**, annule une vente de
  **5 000 F ou plus**, ou fait **5 codes faux** ; le téléphone du patron la relève chaque minute (application
  ouverte) : **bandeau rouge** + voix. Chaque boutique a un jeton secret, rangé dans son Drive.
- **Étapes du propriétaire** : `docs/etapes-proprietaire.md` (Google Cloud, Cloudflare, variable
  `ZP_RELAIS_URL`). La fabrication affiche maintenant aussi l'empreinte **SHA-1** (publique) demandée par Google.

**Tests (324 au total, tous réussis)**, par exemple :
- Le patron synchronise ; un téléphone neuf récupère la boutique (riz **100 kg**), devient l'appareil « B »,
  vend 2 kg (reçu **B-000001**) ; après synchronisation, le patron voit **98 kg** et **1 200 F** de ventes.
- Kofi (plafond 5 000 F) prend **4 000 F** à crédit chez le vendeur ; chez le patron, 1 500 F de plus sont
  **refusés** : « peut encore prendre 1 000 F ».
- Le vendeur Kossi ferme la caisse (fonds 5 000 F) en comptant 3 000 F → le patron reçoit « Caisse fermée par
  Kossi : il manque 2 000 F ». Licence de 2 appareils → le 3e est refusé. Fichier modifié dans le Drive → refusé.

**Choix pris au plus simple :** une seule caisse pour toute la boutique (une fermeture sur un appareil ferme la
caisse commune) ; seuils d'alerte 1 000 F (manque) et 5 000 F (annulation) ; relève des alertes seulement
application ouverte (notifications application fermée : plus tard, avec Firebase).

**Problèmes restants :** rien n'a pu être essayé avec un vrai compte Google (il faut d'abord les étapes A de
`docs/etapes-proprietaire.md`) ; la relève en arrière-plan (application fermée) n'est pas faite.

### Étape 5 — Version PC Windows (version 0.21.0)
**Fait :**
- Dossier `windows/` (application « Zéro Perte », fichier `ZeroPerte.exe`, icône de la boutique Zéro Perte).
- **Fabrication par GitHub Actions** (même action « 2 - Fabriquer l'APK », tâche `windows` sur une machine
  Windows) : `ZeroPerte-Windows.zip` est ajouté à la **même Release** que l'APK. Lien fixe :
  `…/releases/latest/download/ZeroPerte-Windows.zip`.
- Remplacements des fonctions Android :
  - base de données : SQLite fourni avec l'application, dans le dossier de données de l'utilisateur ;
  - reçu : image enregistrée dans `Documents\Zero Perte\Recus`, texte copié, WhatsApp (application PC)
    ouvert ; sinon le dossier s'ouvre ;
  - sauvegarde et export des clients : fenêtre « Enregistrer sous » (dossier `Documents\Zero Perte\Sauvegardes`) ;
  - photo : choix d'une image existante (pas d'appareil photo) ; pas de raccourci d'écran d'accueil ;
  - vérification de l'appareil : un PC est déclaré compatible.
- **Clavier physique** : chiffres (rangée du haut et pavé numérique) et Retour arrière dans tous les claviers
  de montant ; **Échap** = revenir en arrière.
- **Licence** : le code d'activation est vérifié de la même façon (aucun code propre à Android). Un PC compte
  comme un des appareils de la licence dès qu'il est relié au Drive de la boutique.

**Tests (326 au total, tous réussis)**, par exemple :
- PC 1366×768 : taper 5 0 0 0 0 au clavier puis Retour arrière → « le client donne 5 000 F » ; Échap → retour
  au panier.
- Tous les écrans vérifiés sans débordement à 1366×768 (étape 3).

**Pas encore fait (Windows) :**
- **Connexion Google sur PC** (synchronisation par Drive) : il faut un identifiant « Application de bureau »
  (étape A6 de `docs/etapes-proprietaire.md`) puis une connexion par le navigateur. En attendant, le PC
  fonctionne seul (sans synchronisation), et ne peut donc pas encore être compté dans la licence.
- **Avertissement de Windows** à la première ouverture (« Windows a protégé votre ordinateur », éditeur
  inconnu) : l'application n'est pas signée. Pour le supprimer : un certificat de signature de code
  (environ 100 à 400 dollars par an ; un certificat « EV » fait disparaître l'avertissement tout de suite,
  un certificat simple après un certain nombre de téléchargements), ou la publication dans le
  Microsoft Store (compte développeur, environ 19 dollars une fois).

### Étape 6 — C2 : inventaire complet en comptage aveugle + « Ne plus faire crédit » ✅ (version 0.22.0)
**Fait :**
- Espace patron → **« Inventaire »** : un produit à la fois (« Produit 1 sur 12 »), on choisit l'unité
  (kg, sac…) et on tape la quantité comptée au clavier de chiffres. **On ne voit jamais ce que
  l'application attend.**
- À la fin : **écart en francs** (au prix de vente), total « Marchandise manquante : 6 000 F » ou
  « en trop », et pour chaque produit « Attendu … · compté … » avec « Juste », « Il manque … (… F) »,
  « En trop … ».
- **Tolérance de 5 %** pour les produits vendus au bol, au tas ou au montant (« Presque juste »).
- Le stock prend ensuite la valeur comptée (opération `stock.inventaire`, jamais d'effacement).
- Fiche client (patron) : **« Ne plus faire crédit »** / « Refaire crédit » ; une vente à crédit est alors
  refusée : « Le patron ne fait plus crédit à Kofi. »

**Tests (334 au total, tous réussis)**, par exemple :
- Riz attendu **100 kg**, compté **90 kg** → « Il manque 10 kg (6 000 F) » ; sucre 10 paquets → « Juste » ;
  le stock du riz passe à 90 kg.
- Produit au bol : 2 % d'écart → toléré ; 10 % → « il manque ».
- « Ne plus faire crédit » pour Kofi → vente à crédit refusée ; « Refaire crédit » → il peut de nouveau
  prendre 5 000 F.

**Choix pris au plus simple :** l'écart en francs est calculé au **prix de vente** (le prix d'achat n'est pas
toujours connu) ; tolérance 5 % ; « Ne plus faire crédit » met le plafond à 0 (« Refaire crédit » le remet à
5 000 F).

**Résultat de la première fabrication Windows (v0.21.0-n34) :** réussie du premier coup.
`ZeroPerte-Windows.zip` = **13,1 Mo**. ⚠️ L'APK universel passe de 15,4 à **17,3 Mo** : la base SQLite
nécessaire à Windows est aussi incluse dans l'APK (environ 1 Mo par type de processeur). Toujours sous la
limite de 20 Mo ; à surveiller.

### Étape 6 — C3 : inventaire tournant quotidien + écarts par personne ✅ (version 0.23.0)
**Fait :**
- Chaque jour, **3 produits** (5 si la boutique en a plus de 30) sont tirés au hasard, en privilégiant ceux
  qui **valent cher et se vendent vite** (poids = prix × quantité vendue en 7 jours). Le même jour donne
  toujours le même choix (relancer ne permet pas de tricher).
- Après **« Fermer la caisse »**, le vendeur voit « **Compter les produits du jour** » (ou « Plus tard ») ; il
  compte sans voir l'attendu, puis voit seulement « Comptage enregistré. Merci ! ».
- Espace patron → **« Inventaire »** : « Tout compter » (inventaire complet), « Compter les produits du
  jour », et **« Écarts des 30 derniers jours » par personne** (ex. « Kossi − 68 000 F »).

**Tests (343 au total, tous réussis)**, par exemple :
- Même jour → même choix ; sur 300 jours, le riz (cher, vendu souvent) sort plus de 100 fois, le bonbon
  (25 F) moins de 5 fois.
- Kossi ferme la caisse, compte riz 0 kg et sucre 0 paquet → il ne voit aucun écart ; le patron voit
  « Kossi − 68 000 F » (100 kg × 600 F + 10 × 800 F).

**Choix pris au plus simple :** l'inventaire du jour est proposé après la fermeture de caisse (pas imposé).

### Étape 6 — C4 : crédit fournisseur ✅ (version 0.24.0)
**Fait :**
- Espace patron → **« Fournisseurs »** : liste avec « On lui doit … » (les plus grosses dettes en haut) et
  « La boutique doit en tout … » ; « Nouveau fournisseur » (nom, téléphone facultatif).
- Fiche : **« Achat à crédit »** (montant de la marchandise prise à crédit) ; **« Je paie »** (montant +
  espèces / Flooz / Mixx) : l'argent **sort de la caisse** correspondante (compté à la fermeture) ;
  historique. Payer plus que la dette est refusé.
- Base : schéma **version 5** (`fournisseurs_versions`, `mouvements_fournisseur`, ajout seulement).
- Défaut évité : le message de confirmation cachait le bouton « Je paie » ; la fiche montre déjà le montant.

**Tests (351 au total, tous réussis)**, par exemple :
- Sika : achat à crédit **50 000 F**, paiement **20 000 F** en espèces → « On lui doit 30 000 F » ;
  caisse ouverte avec 25 000 F → attendue **5 000 F**.
- Dette de 10 000 F, paiement de 15 000 F → « La boutique doit seulement 10 000 F. »
- Fiche fournisseur sans débordement sur les 6 tailles d'écran.

**Choix pris au plus simple :** l'achat à crédit est noté à part de l'arrivage (le patron enregistre aussi
l'arrivage pour le stock) ; les paiements fournisseurs ne comptent pas dans « Dépenses » du tableau du
patron (ce n'est pas une dépense, c'est le paiement du stock), mais ils sortent bien de la caisse.

**Bilan de la nuit (publications) :** v0.17.0 à v0.24.0 publiées, sauf **0.23.0** dont la fabrication a été
annulée par GitHub (attente trop longue d'une machine) : son contenu (C3) est inclus dans **0.24.0**.
Dernière version : **v0.24.0-n37** — APK universel **17,3 Mo** (arm64 9,4 Mo, armv7 8,8 Mo),
**ZeroPerte-Windows.zip 13,2 Mo**. Prochaine étape : bloc **E** (mise en service), après le retour du propriétaire.

## Décisions du propriétaire sur le rapport de la nuit (toutes « (a) »)
1. Une seule caisse pour toute la boutique. 2. Seuils d'alerte gardés : manque ≥ 1 000 F, annulation ≥ 5 000 F.
3. Synchronisation sur PC : branchée dès que l'identifiant « Application de bureau » existe (code prêt).
4. Message de Windows accepté pour le pilote ; préparer le Microsoft Store (MSIX). 5. Inventaire du jour : proposé.
**Nouvelle demande :** suivre de très près l'allure et le fonctionnement du logiciel concurrent (ouverture
directe par le code, menu à gauche, tableau de bord, caisse, vente, encaissement), sur téléphone, tablette et
PC — sans reprendre son nom, son logo ni ses écrans à l'identique (propriété du concurrent).

### Étape 1 et 2 — Décisions, corrections, notifications, PC, Store, entrée par le code ✅ (version 0.25.0)
**Fait :**
- **Ouverture directe par le code**, comme le concurrent : un seul écran « Tapez votre code » (clavier, touche
  ➜ ; Entrée au clavier du PC). Le code reconnaît la personne (patron 6 chiffres, vendeur 4). **Deux personnes
  ne peuvent plus avoir le même code.** 5 codes faux → écran bloqué 5 minutes + alerte au patron.
- **Pas d'écran de test à l'installation** : la vérification de l'appareil se fait en silence ; l'écran
  n'apparaît qu'en cas de problème bloquant. La démonstration reste un bouton facultatif.
- **Corrections** : `ZP_JETON_CODES` doit être créé **AVANT le 28 novembre** (docs, journal et rapport
  corrigés, avec les étapes exactes). Tolérance de l'inventaire : **une seule valeur, 5 %** (code
  `tolerancePourcent = 5`) ; nouveau test aux limites : 5 % → toléré, 6 % → « il manque ». (Le « 3 % » cité
  pendant le travail était un exemple d'écart, pas une autre tolérance.)
- **Notifications Firebase** (application du patron fermée) : code Android natif (bibliothèque
  `firebase-messaging`, sans `google-services.json`, identifiants publics donnés à la fabrication), abonnement
  du téléphone du patron au canal de sa boutique ; le relais Cloudflare envoie la notification (testé avec un
  faux Google). Étapes exactes : `docs/etapes-proprietaire.md` partie F.
- **Connexion Google sur PC** (`lib/services/google_pc.dart`) : navigateur + retour local + PKCE, reconnexion
  silencieuse ; testée avec un faux Google. S'active avec la variable `ZP_GOOGLE_PC_ID` et le secret
  `ZP_GOOGLE_PC_SECRET` (partie A6).
- **Windows** : étapes « Exécuter quand même » (partie D) ; **paquet Microsoft Store `ZeroPerte-Store.msix`**
  fabriqué à chaque version (artefact GitHub) + étapes du Partner Center (partie E).

**Tests (356 au total, tous réussis)**, par exemple :
- Écran d'entrée : « 4827 » (code de personne) → « Code faux » ; « 5913 » → Kossi entre directement.
- Ajouter Afi avec le code de Kossi → refusé ; 5 codes faux → même le bon code est refusé 5 minutes.
- Canal des alertes : même nom calculé par l'application et par le relais (`zp-` + SHA-256).

**Publiée :** v0.25.0-n39 — APK universel 17,5 Mo (arm64 9,5 Mo, armv7 8,9 Mo), Windows 13,2 Mo ; paquet
Microsoft Store fabriqué sans erreur.

### Étape 3a — Nouvelle allure professionnelle, menus selon le rôle, Ma caisse, tableau de bord ✅ (version 0.26.0)
**Fait :**
- **Thème bleu nuit** : fond bleu nuit, cartes nettes à bord fin, textes clairs à fort contraste, gros chiffres.
  La couleur de la boutique colore les boutons principaux (éclaircie automatiquement si elle est trop
  sombre pour se voir). **Les reçus restent blancs** (images WhatsApp lisibles partout).
- **Menu selon le rôle** : le vendeur ne voit que **Vendre, Ma caisse, Clients** ; le patron voit tout
  (Tableau, Arrivages, Inventaire, Fournisseurs, Vendeurs, Gestion). Le patron étant entré avec son code,
  « Gestion » ne redemande plus le code. L'accord du patron par code reste disponible (servira aux retours).
- **Téléphone** : même allure, gros boutons à grandes icônes ; « Vendre » reste le plus gros.
- **Tablette et PC** : **menu fixe à gauche** (icônes + mots courts, élément actif en surbrillance, la personne
  connectée en bas) ; les pages s'ouvrent à droite, le menu reste visible.
- **Tableau de bord** (accueil du patron sur tablette et PC) : ventes, bénéfice, dépenses et crédits du jour en
  gros chiffres, **courbe des ventes des 7 derniers jours**, **les 5 produits qui rapportent le plus sur 30
  jours**, stock bas. La page « Tableau » utilise aussi la courbe.
- **Ma caisse** : état (ouverte depuis quelle heure, par qui), **fond initial**, boutons Ouvrir / Dépense /
  Fermer (+ « Argent pris » pour le patron), **historique des sessions**. Le patron voit ce qui doit être
  dans la caisse et l'écart de chaque session ; **le vendeur ne voit aucun de ces chiffres** (fermeture
  aveugle conservée). « Dépense » et « Fermer la caisse » ont quitté l'accueil pour « Ma caisse ».
- **Encaissement en grande fenêtre** (tablette, PC) : sous-total, à encaisser, montant reçu, monnaie à rendre,
  mode de paiement, billets reçus (+500 … +10 000, compte exact), billets à rendre, clavier ; boutons
  « Annuler (Échap) » et « Valider (Entrée) ». Sur téléphone, l'écran d'encaissement ne change pas.

**Choix pris seul (le plus simple) :** les boutons « Fournisseurs » et « Vendeurs » sont dans le menu de gauche
sur PC/tablette, et dans « Gestion » sur téléphone (pour garder des boutons assez gros sur un 4 pouces).

**Tests (359 au total, tous réussis)**, par exemple :
- Vendeur Kossi (téléphone et PC) : voit Vendre, Ma caisse, Clients ; pas Tableau ni Gestion ; dans Ma caisse,
  pas de « Doit être dans la caisse » ni « Argent pris ».
- PC : « Clients » s'ouvre à droite du menu, qui reste visible ; « Accueil » ramène au tableau de bord.
- 6 tailles d'écran × texte normal et agrandi ×1,5 : rien ne déborde, chaque bouton fait au moins 72 points.

**Captures vérifiées une à une** (4", grand téléphone, tablette 10" paysage, PC 1366×768) : entrée par le code,
accueil patron, accueil vendeur, vente, encaissement, Ma caisse (patron et vendeur), tableau, clients,
gestion. Corrigé après vérification : logo de la boutique peu visible sur le fond sombre (liseré clair
ajouté) ; « Vendre » trop petit sur 4" (icône à côté du mot) ; carte « Rendre » coupée dans la fenêtre
d'encaissement (remplacée par les billets à rendre).

### Étape 3b — Devis, retours partiels, rapports ✅ (version 0.27.0)
**Fait :**
- **Devis / facture proforma** : icône « Devis » en haut de « Vendre » (panier → devis), image à envoyer sur
  WhatsApp (« DEVIS n° DV-A-0001 », « Facture proforma, valable 7 jours. Ce n'est pas un reçu de paiement. »),
  **« Transformer en vente »** en un geste : le panier est refait aux prix du jour (message si le total a
  changé). Le devis ne touche ni le stock ni la caisse. Liste des devis (« à vendre » / « vendu (A-000001) »)
  pour le patron.
- **Retours partiels** : détail d'une vente → **« Retour »** (à côté de « Annuler ») : choisir ce qui revient
  (− / +), la caisse qui rembourse (espèces / Flooz / Mixx ; pour une vente à crédit, la dette baisse), le motif
  (Produit abîmé, Mauvais produit, Le client a changé d'avis, Autre) ; **code du patron demandé au vendeur
  au-delà de 5 000 F** ; reçu du retour à envoyer ; le patron est prévenu (alerte) de chaque retour fait par un
  vendeur et voit la liste « Retours ». Les retours sont déduits des ventes, de la caisse attendue et du
  bénéfice, et la marchandise revient en stock. On peut faire plusieurs retours sur la même vente, jamais plus
  que ce qui a été vendu.
- **Rapports** : jour / semaine / mois et périodes précédentes (flèches) : ventes, bénéfice, dépenses, retours,
  crédit accordé et remboursé, ce que les clients doivent, inventaires ; jour par jour ; produits qui
  rapportent le plus ; envoi en image (WhatsApp) ou en fichier Excel (CSV).
- Sur téléphone, Rapports / Devis / Retours sont dans « Gestion » ; sur tablette et PC, dans le menu de gauche.

**Défauts trouvés par les tests et corrigés :**
- Annuler une vente **après** un retour partiel remettait deux fois le stock et l'argent : c'est maintenant
  refusé (« Cette vente a déjà eu un retour : faites « Retour » pour le reste »).
- PC 1366×768 : avec 3 rubriques de plus, le bas du menu de gauche (Fournisseurs, Vendeurs, Gestion) sortait
  de l'écran. Les lignes du menu s'adaptent maintenant à la hauteur (40 à 50 points) : tout tient sans défiler.
- Après « Transformer en vente », le retour en arrière pouvait fermer une page de trop : corrigé.
- Vu sur les captures : le reçu du retour écrivait « Rendu : 3 kg de Riz » (quantité vendue) au lieu de
  « Rendu : 1 kg de Riz » (quantité rendue) : corrigé et testé. Sous chaque ligne du retour : « vendu : 3 ».
- Vu sur les captures (4 pouces) : « Trop de codes faux. Réessayez à 19:20. » était coupé : il tient
  maintenant sur une ligne.

**Captures vérifiées** (4", grand téléphone, tablette 10" paysage, PC 1366×768) : détail d'une vente (boutons
Retour / Annuler), retour, retour enregistré + reçu, devis, rapport de la semaine, liste des retours, code du
vendeur créé, écran d'entrée bloqué. Fichier : `test_captures/lot_e_captures_test.dart`.
**Total : 383 tests, tous réussis.**

**Tests (lot E)**, par exemple :
- Vente 3 kg de riz + 2 sucres = **3 400 F** (caisse ouverte avec 5 000 F) ; le client rend 1 kg + 1 sucre →
  **1 400 F rendus** ; stock riz 97 → **98 kg** ; caisse attendue **7 000 F** ; rapport du jour : ventes
  **2 000 F**, retours 1 400 F, bénéfice **200 F** ; rendre encore 3 kg → refusé (« On ne peut rendre que 2 ») ;
  annuler toute la vente → refusé ; rendre le reste → caisse revenue à la seule mise de départ.
- Kofi prend 3 kg à crédit (1 800 F), rend 1 kg → il doit **1 200 F**, aucune caisse ne bouge ; il rembourse
  500 F → rapport : crédit accordé 1 200 F, remboursé 500 F, dû **700 F**.
- Le vendeur Kossi rend un **sac de 50 kg (28 000 F)** → code du patron demandé ; faux code refusé ; bon code
  → retour enregistré avec « accord : Ama » ; alerte « Kossi a fait un retour sur la vente A-000001 ».
- **Devis 2 kg de riz = 1 200 F** (stock et caisse inchangés, « Devis n° DV-A-0001 … Valable 7 jours. »
  envoyé) ; le riz passe à 650 F ; « Transformer en vente » → « nouveau total 1 300 F » → vente **A-000001 de
  1 300 F**, stock 98 kg ; le devis affiche « Déjà vendu (reçu A-000001) ».
- Rapport : 3 400 F vendus, 800 F rendus, 500 F de dépenses → **2 600 F**, et le fichier Excel contient
  « Ventes (F);2600 ». Semaine et mois identiques, mois précédent 0 F.
- Retour, devis, rapports, liste des retours sur les 6 tailles d'écran : rien ne déborde.

### Sécurité de l'écran d'entrée ✅ (version 0.27.0)
**Problème :** le code seul reconnaît la personne. Si un vendeur choisit lui-même son code et que l'application
répond « ce code est déjà celui d'une autre personne », il apprend le code d'un collègue.
**Solution choisie (la plus simple) : l'application tire le code du vendeur au hasard.** Le patron écrit
seulement le prénom puis touche « Ajouter et créer son code » ; l'application affiche une seule fois un code
de 4 chiffres, jamais trop facile (1111, 1234…) et jamais celui d'une autre personne, avec la consigne « Donnez
ce code au vendeur en privé ». « Changer le code » donne de la même façon un nouveau code au hasard (si le
vendeur l'a oublié). Personne ne choisit plus de code de vendeur : personne ne peut donc apprendre qu'un code
« est déjà pris ». Le patron garde son code à 6 chiffres choisi par lui (il est le seul à 6 chiffres : aucune
collision possible). Par précaution, le message d'erreur interne est devenu neutre (« Ce code ne peut pas être
utilisé »).
**Vérifié et renforcé :**
- 5 codes faux à l'écran d'entrée → écran bloqué **5 minutes** (même le bon code est refusé), message « Trop de
  codes faux. Réessayez à 10:05. » affiché **dès le 5e code** (avant, il n'apparaissait qu'au code suivant), et
  la voix le dit.
- L'alerte « 5 codes faux à l'entrée » part vers le patron (bandeau rouge + voix sur son téléphone).
- **Fermer et rouvrir l'application ne remet plus le compte à zéro** (avant, il était gardé en mémoire
  seulement : on pouvait essayer 4 codes, fermer, recommencer).
- Un bon code remet le compte à zéro.
**Tests :** tirage (un code déjà pris ou trop facile est sauté sans rien dire ; 30 tirages corrects), message
neutre, ajout d'Afi et nouveau code de Kossi par l'écran (l'ancien code ne marche plus), 5 codes faux avec
horloge simulée (bloqué à 10:00, bon code refusé, accepté à 10:06) + alerte reçue par le patron, compte gardé
après réouverture, écran « code du vendeur » sur 6 tailles.

### Vérification du téléphone à l'installation (explication, rien changé)
- **Ce qu'elle vérifie** (`lib/domaine/verification_telephone.dart`) : version d'Android (8 ou plus), services
  Google (sauvegarde, Drive, notifications), place libre (bloquant sous 100 Mo, avertissement sous 300 Mo),
  voix française (avertissement seulement). Sur PC : déclaré compatible.
- **Quand l'écran apparaît encore** : seulement en cas de problème **bloquant** : téléphone sans services
  Google (ex. Huawei récents) ou moins de 100 Mo libres → écran rouge + « Demander de l'aide » (WhatsApp).
  (Android 7 ou moins ne peut de toute façon pas installer l'APK.) Sinon on passe tout seul au code
  d'activation.
- **Ce qui est perdu en le cachant** : les deux **avertissements** non bloquants ne sont plus montrés au
  patron : « place libre entre 100 et 300 Mo » et « pas de voix française (l'application ne parlera pas) ».
  Question posée au propriétaire dans le rapport.

**Publiée :** v0.27.0-n42 (fabrication Android et Windows réussies) — APK universel **17,6 Mo** (arm64 9,5 Mo,
armv7 9,0 Mo), **ZeroPerte-Windows.zip 13,3 Mo**. (Cette ligne est ajoutée sur la branche de travail seulement,
pour ne pas publier une version de plus ; elle arrivera sur `main` avec la prochaine version.)

## Décisions du propriétaire sur le rapport 0.27 (toutes « (a) »)
Q1 avertissements non bloquants dans un bandeau orange après l'installation ; Q2 codes vendeurs tirés au
hasard (gardé) ; Q3 retour sur une vente à crédit déjà payée : rendu en espèces, la dette ne devient jamais
négative ; Q4 accord du patron au-dessus de 5 000 F (gardé).

### Version 0.28.0 ✅
**Fait :**
- **Devis : prix gardés pendant la validité** (7 jours, jusqu'à la fin du 7e jour) : « Transformer en vente »
  reprend les prix du devis même si les prix ont changé (la vente enregistre ce prix : `prixImpose` dans
  `LigneDemandee`). Après expiration : message « Devis expiré, nouveaux prix : … » et prix du jour. La page du
  devis dit « Valable jusqu'au 28/11 : les prix du devis sont gardés » ou « Expiré depuis le … ». Un même
  produit ajouté en plus depuis la grille est compté au prix du jour (ligne séparée). Le devis est marqué
  « vendu » à partir de la vente qui vient d'être enregistrée (plus de recherche dans les ventes du jour).
- **Alertes graves sans réseau** (codes faux, écart de caisse, grosse annulation, retour : toutes passent par
  la même fonction `alerter`) : l'alerte est d'abord **gardée sur l'appareil** (réglage `alertes.attente`,
  50 au plus), puis envoyée ; sans réseau elle reste et part **dès que le réseau revient** (chaque minute
  quand l'application est ouverte, et après chaque synchronisation réussie), dans l'ordre, une seule fois.
  Partie en retard, elle porte l'heure réelle : « (le 21/11 à 10:00, envoyée au retour du réseau) ».
- **Q1 — bandeau orange** après l'installation : « Peu de place libre (250 Mo) : libérez de la place
  bientôt. » / « Pas de voix française : l'application ne parlera pas. », bouton « Compris » (ne revient plus).
- **Q3 — retour sur une vente à crédit déjà payée** : la dette baisse au plus jusqu'à 0 F, le reste est rendu
  en **espèces** (sort de la caisse espèces). Messages : « Sa dette tombe à 0 F et vous lui rendez 300 F en
  espèces » / « Le client ne doit plus rien : vous lui rendez 600 F en espèces » ; reçu du retour « Dette
  réduite de 300 F. Rendu en espèces : 300 F. ».
- **Écran de retour sur 4 pouces** : total, choix de la caisse, motif et bouton sont **fixés en bas**, toujours
  visibles sans défiler ; seule la liste des articles défile. Petits écrans : libellés courts (« Abîmé »,
  « Changé d'avis », « Mixx »), le motif enregistré reste complet.
- `docs/analyse-concurrent.md` mis à jour (devis, retours, inventaires, fournisseurs, allure, Windows faits).

**Défauts vus sur les captures et corrigés :** bandeau orange trop haut sur 4 pouces (textes raccourcis) ;
« Le client a déjà payé une partie » affiché alors qu'il ne devait plus rien ; « Dette réduite de 0 F » sur le
reçu ; sur 4 pouces, la partie fixe du retour cachait les articles (rendue plus compacte).

**Tests : 397 au total, tous réussis** (nouveau fichier `test/ecrans/version_028_test.dart`), par exemple :
- Devis 2 kg de riz **1 200 F**, riz passé à 650 F : transformé **6 jours après → vente de 1 200 F** ;
  **8 jours après → « Devis expiré, nouveaux prix : 1 300 F » → vente de 1 300 F** ; fin du 7e jour à 23 h 59 :
  valable, 8e jour à 0 h 01 : expiré.
- Kofi : 3 kg à crédit (1 800 F), rembourse 1 500 F (doit 300 F), rend 1 kg (600 F) → dette **0 F**, **300 F
  rendus en espèces**, caisse attendue 1 200 F ; il rend encore 1 kg → 600 F en espèces, dette toujours 0 F.
- Relais en panne : 5 codes faux, annulation de 28 000 F, retour, caisse fermée avec 2 000 F de manque → rien
  ne part, **4 alertes gardées**, toujours 4 après fermeture/réouverture de l'application ; réseau revenu →
  **4 envoyées dans l'ordre** (code, annulation, retour, écart), pas deux fois ; le patron les reçoit.
- Installation avec 250 Mo et sans voix française → on passe au code d'activation, 2 avertissements gardés ;
  après l'installation, bandeau orange, « Compris » le ferme pour de bon.
- Écran de retour sur les 6 tailles : caisse, motif et bouton visibles sans défiler, retour validé.
Captures : `test_captures/v028_captures_test.dart` (bandeau, retour crédit payé, retour en espèces, devis
valable) + `lot_e_captures_test.dart`, vérifiées sur 4 pouces, grand téléphone, tablette 10" et PC 1366×768.

**Publiée :** v0.28.0-n44 (Android et Windows réussis) — APK universel **17,6 Mo** (arm64 9,5 Mo, armv7 9,0 Mo),
**ZeroPerte-Windows.zip 13,3 Mo**. (Ligne ajoutée sur les branches de travail seulement.)

## Décisions du propriétaire sur le rapport 0.28 (toutes « (a) »)
Q1 un devis vendu est fermé (déjà le cas). Q2 alertes en attente envoyées seulement application ouverte.
**Le propriétaire a créé `ZP_JETON_CODES`** (seul dépôt `zero-perte-coffre`, Contents lecture/écriture, sans
expiration) : partie C de `docs/etapes-proprietaire.md` marquée faite.

### Version 0.28.1 ✅
- **Action « 4 - Générer un code d'activation »** : écrit dans son journal et son résumé le **nom** du jeton
  utilisé pour le coffre (« Jeton utilisé : ZP_JETON_CODES », avertissement si c'est `ZP_JETON_COFFRE`),
  jamais sa valeur ; et **vérifie chaque code avec le même fichier que l'application**
  (`lib/domaine/licence.dart`, clé publique de `assets/licence/cle_publique.txt`) grâce au petit outil
  `outils/verifier_code` (Dart officiel 3.13.7 téléchargé avec contrôle d'empreinte). Le code et le nom de la
  boutique restent masqués. Essai local : code signé avec la bonne clé → « Code accepté par l'application :
  licence, 2 téléphone(s) » ; avec une autre clé → « Ce code n'est pas un vrai code Zéro Perte ».
- **PC / tablette avec le bandeau orange** : les lignes du menu de gauche descendent jusqu'à 32 points si
  besoin : tout le menu et la personne connectée restent dans l'écran (test sur PC 1366×768 et tablette
  1280×800, capture vérifiée).
**Tests : 399, tous réussis.**

**Vérification de `ZP_JETON_CODES` (21/11, exécution 44948248668 de l'action 4, boutique « TEST - ne pas
utiliser ») :** réussie. Journal de l'action : « Code accepté par l'application : licence, 2 téléphone(s) » et
« Jeton utilisé : ZP_JETON_CODES » ; le message et la ligne du registre ont bien été écrits dans le coffre avec
ce jeton. Aucun secret ni code affiché (masqués). La ligne de test reste dans `registre-clients.csv` du coffre
(à ignorer).
**Publiée :** v0.28.1-n46 — APK universel 17,6 Mo, Windows 13,3 Mo. (Ligne ajoutée sur les branches de travail.)

### Pages publiques pour Google (sans nouvelle version de l'application)
- `docs/site/` : `index.html` (présentation, contacts), `confidentialite.html` (politique conforme au code :
  données sur les appareils et dans le dossier caché `drive.appdata` du Drive de la boutique, e-mail du compte
  gardé sur l'appareil, aucun serveur de ventes, relais Cloudflare : type + message ≤ 300 caractères + lettre
  de l'appareil + heure, effacés après 7 jours, compteur 2 h ; Firebase : titre + message de l'alerte,
  identifiant technique Google, pas d'Analytics ; sauvegarde `.zps` AES-256-GCM ; sauvegarde Android ;
  registre des licences ; suppression), `conditions.html` (paiement unique, 2 appareils, mises à jour
  gratuites, assistance WhatsApp, responsabilité limitée au prix payé, droit togolais), `style.css` bleu nuit.
  Vérifiées dans Chromium à 360 px et 1366 px : aucun débordement.
- Action **« 5 - Publier le site »** (`.github/workflows/publier-site.yml`) : publie seulement `docs/site/`
  avec GitHub Pages (actions officielles épinglées par empreinte). Ne touche pas à la fabrication : `docs/**`
  est ignoré par l'action 2, et le commit qui ajoute l'action porte `[skip ci]`.
- **À faire par le propriétaire** : Settings → Pages → Source « GitHub Actions » (partie G de
  `docs/etapes-proprietaire.md`) : Claude n'a pas le droit de l'activer.
- Adresse e-mail **principale** de contact ajoutée aux 3 pages : `contact@talkami.net` (l'adresse Gmail reste
  en seconde adresse). Pied de page : `contact@talkami.net`.
- **En ligne (21/11, exécution 44952391190 de l'action 5)** après autorisation de GitHub Pages par le
  propriétaire : les 3 adresses répondent 200 avec la feuille de style, vérifiées aussi dans Chromium sur
  téléphone (fond bleu nuit, aucun débordement, liens du menu qui marchent) :
  https://ahiankonoujoseph102-wq.github.io/zero-perte/ ,
  …/confidentialite.html , …/conditions.html. Domaine autorisé Google : `ahiankonoujoseph102-wq.github.io`.

### Version 0.29.0 — logo Zéro Perte
- **Logo redessiné en SVG** d'après le modèle du propriétaire (`outils/logo/dessiner_logo.py`, formes
  calculées) : zéro blanc **fermé** (ovale plein percé d'un ovale, aucune coupure), coche verte devant, détachée
  par un fin contour bleu nuit, anneau or ouvert et effilé (ouvert en haut à droite, là où sort la coche),
  fond bleu nuit. Couleurs du thème : bleu nuit `#0B1730`, vert `#2BC77A`, or `#F8BE5F`, blanc.
  Vérifié à 48, 72 et 96 pixels (lisible), en rond, carré et goutte, et en monochrome.
- **Fichiers source** : `assets/logo/` (SVG complet, avant-plan, monochrome, notification ; PNG 1024 × 1024).
  `outils/logo/fabriquer_icones.py` refait toutes les icônes (rendu Chromium). Le logo n'est pas un asset
  Flutter : l'APK ne grossit que des icônes Android (~110 Ko).
- **Android** : icône adaptative (`mipmap-anydpi-v26/ic_launcher.xml` : fond bleu nuit, avant-plan dans la zone
  sûre — dessin à 70 % —, monochrome pour les icônes à thème d'Android 13+), icône classique arrondie, et
  **petite icône blanche des notifications d'alerte** (`drawable-*/ic_notification.png`, déclarée pour
  Firebase, teinte verte) : sans elle Android aurait affiché un carré blanc.
- **Windows** : `app_icon.ico` (16 à 256 px) ; **Microsoft Store** : `logo_path` du paquet MSIX = PNG 1024.
- **Site** : logo en haut des 3 pages, grand logo sur l'accueil, icône d'onglet (SVG + PNG 32, icône Apple 180).
- Le logo de chaque boutique (personnalisation, reçus, raccourci) n'a pas changé. Rien dans Google Cloud.
- Test `test/domaine/icones_test.dart` (fichiers et tailles). **Tests : 403, tous réussis.**

### Google Cloud branché (A1–A4, A6 faits par le propriétaire, 21/11)
Projet `zero-perte-515421`, consentement externe en production (`drive.appdata` seule, 3 pages publiques,
domaine `ahiankonoujoseph102-wq.github.io`), identifiant Android (SHA-1 49:27:…:B1:A3), identifiant PC.
- **Fabrication Windows** : `ZP_GOOGLE_PC_ID` et `ZP_GOOGLE_PC_SECRET` passent maintenant par l'environnement
  (plus jamais écrits dans la commande), et une étape **vérifie sans les afficher** que l'identifiant a le bon
  format et que les deux valeurs sont bien dans l'application (`data/app.so`). Essai sur la branche
  (exécution 44955019581) : « Identifiant et code secret bien présents dans l'application Windows », secret
  masqué `***`. (L'identifiant client PC, lui, n'est pas un secret.)
- Essai sur la branche avant `main` : fabrication Android avec le nouveau logo réussie (ressources adaptatives
  et monochrome compilées), MSIX créé avec le logo PNG.
- **Reste** : essai A5 par le propriétaire (téléphone, puis PC).
**Publiée :** v0.29.0-n53 (Android et Windows réussis ; vérification de la connexion Google sur PC réussie) —
APK universel **17,7 Mo** (arm64 9,6 Mo, armv7 9,1 Mo), Windows **13,3 Mo**. Site republié avec le logo
(les 3 pages, `logo.svg`, icônes d'onglet : réponse 200).

### Version 0.30.0 — corrections de l'essai + démonstration guidée avec Afi
**Résultat de l'essai du propriétaire :** APK 0.29.0 installé sur un vrai téléphone, code de test a85de6
accepté (« Boutique activée — TEST - ne pas utiliser — 2 téléphones autorisés »).

**Partie 1 — corrections :**
- **« Retour » à chaque étape de l'installation** (sauf la première) : en haut, mot « Retour » (ou flèche
  seule sur écran étroit / grand texte) ; le **geste retour d'Android** fait pareil (`PopScope`). Ce qui est
  rempli est gardé (tout est déjà enregistré) ; la vérification du téléphone, qui passe seule, est sautée ;
  **l'activation n'est jamais annulée** (l'étape montre « Boutique activée »).
- **Logo** : le rond « ZP » est remplacé partout par le logo, dessiné par l'application
  (`lib/ecrans/logo_zero_perte.dart`, mêmes formes que le SVG, aucun fichier en plus).
- **« 2 appareils (téléphone, tablette ou PC) »** dans l'application (activation, voix, Drive, messages
  d'erreur) et dans le message fabriqué par l'action « 4 ».
- **Écran « Code d'activation »** : encadré « Copiez le message entier dans WhatsApp, inutile de choisir le
  code. » ; presse-papiers vide → « Rien n'a été copié. Dans WhatsApp, appuyez longtemps… Ou touchez « Écrire
  le code ». » (affiché et dit) ; texte sans code → message clair ; bouton **« Écrire le code »** (fenêtre pour
  taper ou coller le message ou le code). Défaut trouvé par les tests et corrigé : la zone de saisie était
  détruite pendant la fermeture de la fenêtre.

**Partie 2 — démonstration guidée (`lib/demo_guidee/`) :**
- **Afi**, commerçante dessinée par l'application (CustomPainter, un seul ticker) : foulard bleu nuit à bandes
  or et vert, boucles d'oreilles or, haut bleu à motif de pagne ; clignement, mouvement de tête, bouche qui suit
  la voix (calculée d'avance, ou simulée avec la voix de synthèse), bras qui montre le bouton (du côté du
  bouton), expressions sourire / contente / au revoir (salut de la main).
- **Visite** : 13 chapitres, 50 phrases (`docs/demo/texte-voix.md`, copie exacte vérifiée par un test dans
  `lib/demo_guidee/phrases.dart`) : bienvenue, vendre, monnaie et billets à rendre, reçu WhatsApp, client et
  crédit, devis, retour, dépense, fermeture à l'aveugle, tableau du patron, inventaire, sauvegarde, au revoir.
  « Bonjour » avant 15 h, « Bonsoir » ensuite (`heureBonsoir = 15`). Chaque bouton est **entouré d'or avec une
  flèche** (le reste de l'écran assombri), et la visite **touche elle-même** les boutons pour avancer (vraie
  vente de 2 kg de riz). Durée estimée : **≈ 5 min** (3 min 50 de parole + pauses et gestes).
- Boutons toujours visibles : **Pause / Reprendre, Rejouer, Suivant, Quitter** ; sous-titres toujours affichés ;
  « Quitter » laisse la démo libre, le bouton « Visite » du bandeau la relance. Les chapitres qui continuent le
  précédent (monnaie, reçu, retour, fermeture) sont rejoués avec lui.
- La visite prépare la boutique de démo (caisse ouverte avec 10 000 F, client Kofi avec une dette).
- **Fenêtre d'encaissement (tablette, PC)** : ouverte dans le navigateur de l'application
  (`navigateurDeLApplication`) — dans la démo elle restait au-dessus de tout et cachait Afi.
- **Voix** : fichiers Opus/WebM lus par le lecteur d'Android (canal natif `jouerSon`, sans bibliothèque) ; si un
  fichier manque (ou sur PC), voix de synthèse de l'appareil. Mention « Voix générée par intelligence
  artificielle » dès que des fichiers sont présents.
- **Action « 6 - Fabriquer la voix de la démonstration »** (`outils/voix/fabriquer_voix.py`) : Gemini (voix
  `Sulafat`, modèle réglable), secours OpenAI (`gpt-4o-mini-tts`, voix `coral`), clé `ZP_CLE_VOIX` jamais
  affichée, Opus mono 24 kbit/s en WebM (Android 8), bouche calculée toutes les 50 ms, résultat poussé sur la
  branche `voix-demonstration`. Mode « essai » (bips) vérifié ici : 50 fichiers, 229 s, **880 Ko**.
- `LICENCES-TIERS.md` (conditions Gemini et OpenAI : usage commercial permis ; OpenAI exige d'annoncer la voix
  IA), partie **H** de `docs/etapes-proprietaire.md` (créer la clé depuis le téléphone).

**Tests : 426, tous réussis**, dont `visite_guidee_test.dart` (visite complète sur 4", grand téléphone,
tablette paysage et PC : 0 bouton introuvable, 50 étapes jouées, vente faite ; Bonjour/Bonsoir ; Pause,
Reprendre, Suivant, Rejouer, Quitter, Visite ; voix enregistrée jouée + mention IA ; texte identique au .md ;
durée 4 à 6 min) et `installation_retour_test.dart`. Défauts trouvés et corrigés : en-tête de l'installation
qui débordait sur 4", bandeau de la démo trop haut avec deux boutons, visite bloquée quand une page met plus de
1,8 s à s'ouvrir (attente portée à 4,5 s), cadre or mal placé après un défilement. Captures vérifiées sur les
4 tailles : `test_captures/v030_captures_test.dart`, `avatar_captures_test.dart`.
**Publiée :** v0.30.0-n57 (tests, Android et Windows réussis sur GitHub) — APK universel **17,8 Mo**
(17,7 avant ; arm64 9,7 Mo, armv7 9,2 Mo), Windows **13,3 Mo**. Avec la voix IA (≈ 0,9 Mo d'audio) : ≈ 18,7 Mo.
Images : `docs/demo/afi-expressions.png`, `docs/demo/visite-telephone.png`, `docs/demo/visite-pc.png`.
**Reste** : la clé `ZP_CLE_VOIX` (partie H), puis action 6 → branche `voix-demonstration` → vérification et
publication par Claude.

## Décisions du propriétaire sur le rapport 0.30.0
Q1 (b) même voix d'IA sur PC ; Q2 (a) la visite démarre seule ; Q3 (b) 3 extraits de voix à écouter avant de
choisir. **Refonte d'Afi demandée** (dessin jugé non professionnel) : planche à valider AVANT intégration.

### En cours (branche de travail, NON publié, en attente d'accord)
- **Afi v2** (`lib/demo_guidee/afi_v2.dart`, pas encore utilisée par l'application) : illustration plate
  soignée, cou, épaules, bras en deux parties attachés à l'épaule (coude qui plie, manche à revers or et vert),
  main avec index tendu et pouce / main ouverte pour saluer, robe à bande de pagne régulière (losanges or sur bleu
  nuit, liserés verts), foulard noué avec plis et deux pans en éventail, boucles d'oreilles or, sourcils, yeux
  avec paupière et cils, nez avec narines, lèvres (arc de Cupidon), 5 formes de bouche (fermée, a, o, é, m),
  respiration, tête qui bouge, clignements. Planche : `docs/demo/afi-v2-planche.png`, gros plan :
  `docs/demo/afi-v2-gros-plan.png` (corrigés après relecture : bras au repos qui dépassaient, bras raide en
  « L », mains trop petites, cou trop long, taches au coude, doigt coupé par le cadre).
- **Afi v2, retouche bras et mains** (réponse du propriétaire : visage, foulard, boucles, robe et bouches
  VALIDÉS, non modifiés) : avant-bras élargi (presque la largeur de la manche, poignet un peu plus fin) ;
  mains agrandies (≈ 3/4 de la hauteur du visage) ; main qui salue = vraie main ouverte (paume visible avec
  lignes, 4 doigts serrés et arrondis, pouce attaché à la base de la paume) ; manche qui part du haut de
  l'épaule avec couture visible ; au repos, les deux bras pendent le long du corps, mains visibles (dos de
  la main, doigts serrés un peu repliés, pouce) ; quand un bras se lève, l'autre reste visible le long du
  corps. Relu en gros plan (mains zoomées ×3) avant envoi.
- **DÉCISION : bras et mains abandonnés** (jugés encore non professionnels). **Afi en buste dans un
  médaillon rond** : visage, foulard, boucles, haut de robe (avec bande de pagne) et 5 bouches inchangés ;
  fond bleu de l'application, anneau or et liseré vert ; haut des manches jusqu'au bord du cercle (le buste
  n'a pas l'air coupé). Animations : parole (bouche), clignements, respiration, petits mouvements de tête,
  yeux rieurs et sourire (« content », « au revoir » avec petit signe de tête) ; Afi tourne un peu la tête
  et le regard vers le bouton montré. Tout le code des bras et des mains est supprimé.
  Planche : `docs/demo/afi-v2-planche.png` ; visite : `docs/demo/afi-medaillon-*.png`. Activable par
  `afiMedaillonVisite` (FAUX par défaut : l'application garde l'Afi actuelle jusqu'à l'accord).
- **Défauts de la visite trouvés en testant à vitesse réelle** (existent dans la 0.30.0 publiée ; les tests
  faisaient parler Afi en accéléré) et corrigés : (1) sur tablette et PC, l'étape 016 (« combien rendre »)
  n'entourait rien : le centre de la zone « À rendre en » sur deux lignes tombe entre deux billets → la
  visite essaie plusieurs points de l'élément ; (2) le panneau choisissait haut/bas en comparant à la moitié
  de l'écran entier alors que le bouton est mesuré sous les bandeaux → sur 4 pouces il cachait souvent le
  bouton ; maintenant il va du côté où il tient sans le toucher, sinon en bas (le haut du bouton, son titre
  ou son montant, reste visible) ; (3) panneau compact sur petit écran (médaillon 58, 3 lignes, boutons plus
  bas) ; (4) le bouton est amené vers le haut de la zone qui défile. Nouveau test
  `test/ecrans/afi_medaillon_test.dart` : visite entière à vitesse réelle sur les 4 tailles, chaque bouton
  trouvé, jamais touché par le panneau quand il y a la place (sur 4 pouces, 2 grands éléments restent
  recouverts à moitié par le bas, titre visible).
- **Voix sur PC (Q1)** : format **MP3 mono 24 kbit/s** (au lieu d'Opus/WebM) lu par Android (MediaPlayer) et par
  Windows (MCI de winmm.dll via `dart:ffi`, paquet `ffi` déjà présent : 0 octet de plus). Essai bips :
  50 fichiers = **693 Ko**. Le script calcule aussi la forme de la bouche (e/a/o/m) pour Afi v2.
- **Extraits (Q3)** : action 6, mode « extraits » → même phrase d'accueil (~14 s) avec Sulafat, Aoede, Achernar
  (Gemini) ou coral, nova, shimmer (OpenAI) → `docs/site/voix/` + page d'écoute publiée sur le site.
  **Fait le 22/11** : secret ZP_CLE_VOIX créé par le propriétaire, action 6 réussie (Gemini), 3 extraits MP3
  de 12 à 13 s (35 à 40 Ko) en ligne sur https://ahiankonoujoseph102-wq.github.io/zero-perte/voix/
  (vérifiés : vraie voix, mono 24 kHz, volume correct).

## Décisions du propriétaire (22/11) : Afi en médaillon VALIDÉE, voix **Sulafat**

### Version 0.31.0 (en préparation sur la branche de travail)
- Afi en médaillon dans la visite (l'ancienne Afi et son code sont supprimés), bouche synchronisée avec le
  volume ET la forme (a, é, o, m) calculés par l'action 6 ; 3 corrections de la visite (voir plus haut).
- **Repli vers la voix de l'appareil** : fichier refusé, son arrêté avant la moitié de sa durée (lecteur
  muet), ou lecteur qui ne répond plus (durée + 4 s) → la phrase est dite par la voix de l'appareil, la
  visite continue ; après 2 échecs, plus d'essai du lecteur (et plus de mention « IA »). 3 tests.
- **Action 6, quota Gemini gratuit = 10 demandes par jour et par modèle** (message exact de Google :
  `GenerateRequestsPerDayPerProjectPerModel-FreeTier = 10`). 1er essai (une demande par phrase) arrêté à
  16 phrases sans rien garder. Script refait : **lots de 5 phrases par demande** (10 demandes pour 50),
  découpés aux pauses longues, contrôlés (pauses nettement plus longues qu'à l'intérieur des phrases,
  durées cohérentes avec les textes), lot douteux redemandé une fois puis phrase par phrase ; **reprise**
  (phrases faites gardées sur la branche `voix-demonstration`, même modèle et même voix) ; arrêt propre au
  quota du jour. Testé sur sons fabriqués (découpage juste, 2 cas douteux refusés) et simulation de quota.
- 22/11 vers 3 h 36 : 1er lot fait (001–005, gemini-3.1-flash-tts-preview, Sulafat), durées cohérentes
  avec les fabrications phrase par phrase (écarts < 15 %), volume correct ; quota épuisé pour la journée.
  Relance programmée après la remise à zéro (8 h 12, heure de Lomé) : 9 lots restants.
- 22/11 vers 5 h 53 : nouvelle clé Gemini du propriétaire → même réponse de Google après 2 demandes
  (`GenerateRequestsPerDayPerProjectPerModel-FreeTier = 10`) : clé sans doute du même projet. Arrêt propre,
  5/50 phrases gardées. Les 2 demandes ont montré un lot (006–010) refusé par le contrôle : découpage refait
  (coupure dans la pause la plus proche de l'endroit attendu d'après la longueur des textes + 0,5 s par phrase ;
  sur les 16 durées réelles mesurées, écart ≤ 17 %), lot douteux redemandé en deux moitiés, chaque phrase
  gardée dès qu'elle est faite. Relance programmée à 8 h 12 maintenue.

### Audit complet de l'application (22/11, demande du propriétaire) — ajouté à la 0.31.0
Captures de toutes les pages de la boutique de démonstration (téléphone 6,5 pouces et PC), relues une à une.
Fait (simple et sûr, testé) :
- **Accueil du patron sur téléphone** : il n'y avait AUCUN chiffre (le PC en avait). Ajout d'un résumé du
  jour : ventes, bénéfice estimé, crédits clients ; un toucher ouvre « Tableau ». Caché sur les très petits
  écrans (sinon les gros boutons passent sous 72 points, règle des gros doigts).
- **Vendre** : case « Chercher un produit » au-delà de 12 produits (début des mots, sans accents : « pate »
  trouve « Pâtes », « ri » trouve « Riz » mais pas « Sucrerie ») ; message clair si rien ne correspond. Les 2
  icônes du haut portent leur nom (« Devis », « Ventes »).
- **Pages vides** (Devis, Retours, Fournisseurs, Vendeurs) : icône + à quoi sert la page, au lieu d'une
  phrase seule au milieu du vide.
- **Fournisseurs** : icône propre (poignée de main) ; avant, même camion qu'« Arrivages ».
- **Gestion** : même nom partout (la page s'appelait « Espace patron ») ; sur tablette et PC, elle ne
  répète plus les pages déjà dans le menu de gauche (il reste Caisses fermées, Argent pris, Appareils et
  Drive, Sauvegarde).
- 3 nouveaux tests ; tests passant par « Gestion » sur PC passent maintenant par le menu de gauche.
À décider par le propriétaire (voir rapport) : fusionner « Tableau » et « Rapports », retirer « Tableau » du
menu PC (l'accueil le montre déjà), rapport du soir automatique sur WhatsApp, liste d'achats aux
fournisseurs depuis le stock bas, rappel automatique des crédits.

## Décisions du propriétaire sur l'audit (22/11)
- Améliorations de l'audit VALIDÉES : elles partent avec la 0.31.0. Priorité absolue : finir la voix, publier.
- **0.32 (après la publication de la 0.31.0)** :
  - Q1 (a) résumé du soir à la fermeture de la caisse (ventes, bénéfice, écart de caisse, stock bas) : arrive
    au patron par la synchronisation (et par notification quand Firebase sera branché ; sans Firebase, il
    s'affiche à l'ouverture de l'application du patron) ; bouton « Envoyer sur WhatsApp » pour le partager.
    PAS d'envoi automatique sur WhatsApp (pas d'API payante).
  - Q2 (a) stock bas → WhatsApp s'ouvre avec la liste d'achats déjà écrite ; le patron envoie.
  - Q3 (a) rappel des crédits en retard, validé par le patron en un toucher.
  - Q4 (a) « Tableau » et « Rapports » fusionnés en « Chiffres ».
  - Mêmes règles : tests, captures 4 tailles, rapport avec questions (a)/(b).

## Décision du propriétaire sur la partie B (Cloudflare), 22/11
- (a) Juste APRÈS la publication de la 0.31.0 : correction « dernière alerte » dans `relais/worker.js` (le
  relais lit d'abord une case « dernière alerte » — lecture simple — et ne lit la liste que s'il y a du
  nouveau) + partie B de `docs/etapes-proprietaire.md` mise à jour avec les nouveaux noms des menus
  Cloudflare (Workers KV → Create instance ; Workers & Pages → Create application → Start with Hello World! ;
  Edit Code ; onglet Bindings → Add binding → KV namespace). Pas de refonte.
- **Pour plus tard** : les limites gratuites de Cloudflare valent pour TOUT le compte (toutes les boutiques
  ensemble : 100 000 lectures, 1 000 écritures, 1 000 listes par jour). Avec une consultation par minute et
  par patron, cela tient environ 70 boutiques. **À 50 boutiques, revoir le relais** (alertes poussées par
  Firebase, consultations plus espacées).

## Ordre décidé par le propriétaire (22/11, après le rapport « pendant l'attente »)
1. 0.31.0 (voix) — priorité absolue.
2. PRIORITÉ 1 : produits et prix après l'installation (Gestion, patron seul ; prix au journal avec ancien et
   nouveau prix ; masquer sans effacer l'historique ; image, unités, prix d'achat, stock de départ, seuil).
3. PRIORITÉ 2 : alléger les données (objectif < 1 Ko par vente stockée, < 5 Mo pour un nouvel appareil
   sur une boutique d'un an), sans casser la chaîne du journal ni la synchronisation.
4. 0.32 (réponses à l'audit), puis correction du relais Cloudflare.
Travail hors 0.31.0 sur la branche `claude/suite-apres-031` (liste : `docs/reste-a-faire.md` sur cette
branche).
- 22/11 à 8 h 13 (quota remis à zéro) : **48/50 phrases** (gemini-3.1-flash-tts-preview, Sulafat, 206 s,
  622 Ko). Restent 049 et 050. Vérification des 48 : même voix, volume régulier (−16 à −20 dB) ; **020** touche
  0 dB (risque de saturation) et **037** a une pause de 1,5 s au milieu de la phrase → seront refaites. Script :
  pauses de plus de 0,6 s dans une phrase ramenées à 0,35 s, volume plafonné, option « refaire » (action 6).
  Relance programmée le 23/11 à 8 h 12 (020, 037, 049, 050 : un seul lot).
- **22/11, 8 h 24 — INCIDENT, publication bloquée** : la fabrication (action 2) échoue à « Préparer la clé de
  signature » : `base64: error: invalid input`. Le contenu du secret `ZP_CLE_SIGNATURE` n'est plus la clé
  chiffrée (il l'était encore à 3 h 42, même workflow). Hypothèse : remplacé par erreur lors du changement de la
  clé Gemini. Claude ne modifie aucun secret : au propriétaire de remettre la valeur. Copie de secours chiffrée
  dans le coffre privé `zero-perte-coffre`, dossier `cle-signature/`. Sans la bonne clé, AUCUNE mise à jour ne
  peut être installée sur les téléphones des clients (Android exige la même signature).

### Version 0.31.0 — publiée le 22/11
- Clé de signature remise par l'action 7 (lancée par le propriétaire) : copie de secours du coffre, empreinte
  SHA-1 `49:27:0C:A9:FE:00:2B:55:14:08:5A:9E:AE:50:10:63:C9:CC:B1:A3` vérifiée avant l'écriture ; ZP_CLE_VOIX
  acceptée par Google, ZP_CLE_LICENCES conforme, mot de passe de signature valide (aucun avertissement).
- Décision du propriétaire : publier avec **48 phrases sur 50** ; 049 et 050 dites par la voix de l'appareil ;
  020, 037, 049, 050 refaites le 23/11 → **0.31.1**.
- Contrôles : 437 tests, visite entière à vitesse réelle sur 4 tailles (aucun bouton caché), fabrication
  signée « officiel » sur la branche : APK universel **17,7 Mo**, ZIP Windows **13,3 Mo**.

### Version 0.32.0 — mise en service (22/11)
Contenu : Produits et prix (Gestion, patron seul : ajouter, modifier, changer un prix avec l'ancien prix au
journal, masquer ; prix d'achat, stock de départ, seuil de stock bas, emballages) ; message « Nouvelle version
disponible » ; schéma 6 (stock courant tenu par la base, index, requêtes par période, contenu des opérations
rangé compressé) ; guides de mise en service (`docs/mise-en-service/`, dont `essai-avant-premier-client.md` et
`ce-qu-il-faut-dire-au-client.md`).
Vérifications A3 : (1) mise à jour sans perte depuis 0.29.0, 0.30.0 et 0.31.0 — bases fabriquées par le VRAI
code de chaque version (`test/fixtures/mise_a_jour`), mêmes stocks, crédits, ventes, reçus, chaîne intacte ;
(2) code réel de l'action 4 (`c-20261122-43536d`, « TEST mise en service 0.32 - ne pas utiliser ») : « Code
accepté par l'application : licence, 2 appareil(s) », jeton ZP_JETON_CODES, registre mis à jour ; (3) journée
complète (`test/ecrans/journee_complete_test.dart`) ; (4) droits du vendeur (test dédié, téléphone et PC) ;
(5) sauvegarde et restauration après mise à jour ; (6) synchronisation vers un autre appareil (même format
pour le PC) ; (7) visite d'Afi à vitesse réelle sur 4 tailles ; (8) relais et Firebase non branchés : rien
n'est affiché (relais activé seulement avec son adresse, notifications sans configuration = « non » silencieux).
Corrigés pendant les vérifications : fermetures de caisse lues avec l'ancien format (stockage compressé),
libellé du seuil de stock bas coupé. 458 tests.
- **Publiée** le 22/11 : Release `v0.32.0-n94`, APK universel 17,7 Mo, signature SHA-1 vérifiée sur le fichier
  publié (49:27:0C:…:B1:A3). Rapport A6 envoyé.

### Version 0.33.0 — partie B1 (alléger les données) et B3 (relais)
- **Synchronisation compressée** : fichiers `ops-….json.gz` seulement quand TOUS les appareils inscrits
  annoncent `format_sync` 2 (nouveau champ du fichier `appareil-….json`, écrit par la 0.33). Tant qu'un appareil
  plus ancien est inscrit : fichiers en clair, et chaque appareil récent remet en clair ses propres `.gz`.
  Fichier abîmé (compressé ou non) : refusé avec un message, rien n'est écrit.
- **Vérification de la chaîne** à l'arrivée seulement depuis la dernière opération connue (avant : tout
  l'historique à chaque synchronisation).
- **Point de départ** (`point-de-depart.json.gz`, refait au plus une fois par semaine, seulement quand tous les
  appareils le comprennent) : TOUT l'historique, sans résumé ni perte ; les numéros, empreintes et identifiants
  répétés ne sont pas écrits mais recalculés, puis la chaîne recalculée doit retomber sur la dernière empreinte
  de chaque téléphone (sinon refus). Un nouvel appareil lit ce fichier puis seulement les fichiers plus récents.
- **Mesures, boutique d'un an (73 936 opérations)** : première synchronisation d'un nouvel appareil
  **73,6 Mo → 3,1 Mo** (objectif : moins de 5 Mo) ; fichiers de synchronisation 73,6 Mo → 10,4 Mo, soit
  **147 octets par vente** envoyés (objectif : moins de 1 Ko) ; fabriquer le point de départ 3 s, le relire et
  tout vérifier 4,7 s (machine de test).
- **Base sur l'appareil** : 1 317 octets par vente (0.31 : environ 1,7 Ko). Essai sur une copie : reconstruire
  `mouvements_stock` et `ventes` « sans rowid » donnerait 79,1 Mo, soit 1,08 Ko par vente (1,6 s). Passer sous
  1 Ko demanderait de changer la façon dont l'historique est rangé. **Décision prise (la plus simple) : pas de
  reconstruction des tables chez les clients dans cette version** ; question posée au propriétaire dans le
  rapport, avec ma recommandation.
- **Cas noté** : un appareil installé avec une ANCIENNE version (0.32 ou avant) après le passage aux fichiers
  compressés ne lit pas les `.gz` ; dès qu'il s'inscrit, les appareils récents remettent leurs fichiers en clair
  à leur synchronisation suivante, puis il reçoit tout. Conseil : toujours installer la dernière version.
- **B3, relais** (`relais/worker.js`) : case « dernière alerte » écrite à chaque alerte ; une consultation sans
  nouveauté = 1 lecture et aucune liste ; au-delà de 100 alertes, les pages suivantes sont lues (la plus
  récente n'est jamais perdue). Partie B de `docs/etapes-proprietaire.md` refaite avec les menus de novembre
  2026 (Workers KV → Create instance ; Workers & Pages → Create application → Start with Hello World! ; Edit
  Code ; Bindings → Add binding → KV namespace) + rappel : limites gratuites pour tout le compte, **revoir le
  relais à 50 boutiques**. Le relais n'est pas encore déployé (Cloudflare : à faire par le propriétaire).
- Tests : 463 (dont 6 nouveaux sur la synchronisation et le point de départ, et 2 sur le relais).
- **Publiée** le 22/11 : Release `v0.33.0-n96`, APK universel 17,7 Mo, signature vérifiée. Rapport court envoyé
  (question (a)/(b) : base sous 1 Ko par vente — recommandation (a), garder ainsi).

### Version 0.34.0 — partie B2 (réponses à l'audit)
- **Chiffres** : « Tableau » et « Rapports » réunis dans une page « Chiffres », 2 onglets : **Résumé** (l'ancien
  Tableau) et **À envoyer** (l'ancien Rapports : jour par jour, image, Excel). Menu, accueil (carte
  « Aujourd'hui ») et visite d'Afi pointent vers « Chiffres » (la phrase 039 « Voici le tableau du patron »
  reste juste).
- **Résumé du soir** : quand un VENDEUR ferme la caisse, le patron voit à l'ouverture de son application (ou
  après une synchronisation) une fenêtre : ventes et bénéfice de ce jour-là, dépenses, écart de caisse de la
  journée, stock bas ; une seule fois (réglage local `resume_soir.vu`), seulement si la fermeture a moins de
  36 h. Bouton **Envoyer sur WhatsApp** (WhatsApp choisit le destinataire ; RIEN n'est envoyé seul). Si le
  relais est branché, le résumé part aussi en notification (type `resume_soir`, titre « Zéro Perte : résumé du
  soir » dans le relais) sans bandeau rouge ni voix. Le patron qui ferme lui-même ne reçoit pas de résumé.
- **Commander** : Chiffres → Stock bas → **Commander sur WhatsApp** → choisir un fournisseur enregistré (avec
  numéro) ou « Choisir dans WhatsApp » ; le message liste les produits en stock bas (« - Sucre : »), le patron
  ajoute les quantités. *Décision prise (la plus simple)* : pas de quantité proposée ni de lien produit →
  fournisseur ; à revoir si le propriétaire le souhaite.
- **Crédits en retard** : client qui doit encore et n'a rien remboursé depuis **14 jours** (ou, s'il n'a jamais
  remboursé, depuis son premier crédit). Bandeau rouge dans Clients (patron seul) → page « Crédits en retard » →
  **Rappeler** (un toucher) ouvre WhatsApp avec le rappel déjà écrit ; coche verte ensuite. *Décision prise (la
  plus simple)* : 14 jours, sans date d'échéance par client.
- Code : `lib/ecrans/patron/chiffres.dart`, `resume_soir.dart`, `commande.dart`, `lib/ecrans/credit/retards.dart`,
  `lib/domaine/messages_whatsapp.dart`, `lib/domaine/dates.dart` (dates en français, utilisées aussi par l'état).
- Tests : `test/ecrans/partie_b2_test.dart` (crédits en retard, Commander, résumé du soir et Chiffres sur
  6 tailles), synchronisation : résumé du soir d'un appareil à l'autre. Captures 4 tailles :
  `test_captures/partie_b2_captures_test.dart`. Guides de mise en service mis à jour (Chiffres, résumé du soir,
  Commander, crédits en retard).

- **Publiée** le 22/11 : Release `v0.34.0-n97`, APK 18,6 Mo, signature vérifiée (SHA-1
  49:27:0C:A9:FE:00:2B:55:14:08:5A:9E:AE:50:10:63:C9:CC:B1:A3).
- **Décisions du propriétaire (22/11)** : base sur le téléphone gardée telle quelle (choix (a)) ; 14 jours pour
  un crédit en retard et commande sans quantités : **validés**. Le propriétaire commence l'essai sur 2 vrais
  téléphones (`docs/mise-en-service/essai-avant-premier-client.md`).

### Relais Cloudflare branché (22/11)
- Le propriétaire a fait la partie B : espace KV `ALERTES`, Worker `zero-perte-relais`, liaison KV, variable
  `ZP_RELAIS_URL` = `https://zero-perte-relais.academyjoseph71.workers.dev`.
- Vérifié sans rien écrire dans le KV (requêtes GET seulement) : `/` → 404, `/alertes` sans jeton → 401,
  `/alertes` avec un jeton d'essai → 200 `{"alertes":[]}` (la liaison KV fonctionne), PUT → 405.
- Fabrication relancée sur `main` → Release **`v0.34.0-n98`** (versionCode 98, donc les téléphones en 0.34.0-n97
  voient « Nouvelle version disponible »). APK 18,6 Mo, signature vérifiée (SHA-1 49:27:0C:…:B1:A3), adresse du
  relais présente dans l'APK (arm64 et armv7). Commit `fe4c807` (aucun changement de code).
- Prochaine étape du propriétaire : partie F (Firebase), puis essai B5/F4 sur 2 vrais téléphones.

### Firebase branché (22/11)
- Le propriétaire a fait la partie F : Firebase sur le projet `zero-perte-515421` (Spark, sans Analytics),
  application `tg.zeroperte.app`, 4 variables `ZP_FIREBASE_*` (clé = « Android key (auto created by
  Firebase) »), secret Cloudflare `FCM_COMPTE`, fichier de clé effacé du téléphone.
- Documents des 3 commits précédents fusionnés sur `main` (avance rapide, `[skip ci]`).
- Fabrication relancée sur `main` → Release **`v0.34.0-n101`** (APK 18,6 Mo). Signature vérifiée (SHA-1
  49:27:0C:…:B1:A3). Dans l'APK : adresse du relais, ID du projet, ID d'application `1:328…:android:…`,
  une clé `AIza…` au bon format, ID de l'expéditeur = le numéro contenu dans l'ID d'application. Aucune valeur
  vide. ZIP Windows publié à part par son propre travail.
- **Non vérifiable d'ici** : que le relais obtient un jeton Google avec `FCM_COMPTE`. Le relais n'a pas de page
  de contrôle et cache les erreurs d'envoi ; un POST d'essai écrirait dans le KV sans rien prouver. Preuve
  prévue : l'essai F4 sur 2 vrais téléphones. Si la notification n'arrive pas, ajouter au relais une page
  de contrôle en lecture seule (le propriétaire recolle `worker.js`).

### Version 0.35.0 — ajout d'un vendeur par QR code (22/11)
Conception validée par le propriétaire (questions A taille et B secret réglées avant le code) :
`docs/conception-ajout-vendeur.md`.
- **Patron** : bouton **Ajouter mon vendeur** (accueil s'il reste de la place dans la licence, Gestion,
  menu de gauche sur grand écran) → prénom → accord Google (un toucher) → QR code 10 minutes, une fois.
  **Pas d'appareil photo ?** → code de 8 chiffres + « OUI » du patron. **Mes appareils** (Gestion) :
  Retirer, Couper tous les vendeurs.
- **Vendeur** : premier écran → **Je suis vendeur** → scanner (Google code scanner,
  `play-services-code-scanner` 16.1.0, aucune autorisation d'appareil photo) → boutique + code à 4 chiffres.
  Ancien parcours sous **Autres façons**.
- **Relais** (`relais/worker.js`) : `/google/id`, `/google/echange`, `/google/acces` (liste noire),
  `/google/retirer`, `/google/couper`, `/boite/<id>` (10 min, lecture unique), `/demande/<id>`. Code secret
  de l'identifiant Web seulement en secret Cloudflare (`GOOGLE_WEB_ID`, `GOOGLE_WEB_SECRET`). Tests du relais
  ajoutés à la fabrication (`node relais/worker.test.mjs`).
- **Synchro** : `retrait-<id>.json` (licence libérée, opérations après le retrait refusées), invitation et
  empreinte du jeton dans `appareil-<id>.json`, une seule entrée par invitation.
- **Choix faits en codant** (à signaler) : (1) un téléphone retiré est **bloqué**, pas effacé (la base
  interdit tout effacement de l'historique) ; (2) licence pleine : refaire le QR d'un vendeur déjà dans la
  liste reste permis (même téléphone, après un accès coupé) ; un autre téléphone est refusé à son arrivée ;
  (3) « Couper tous » retire aussi tous les téléphones ajoutés par QR code.
- Code : `lib/synchro/invitation.dart`, `lib/ecrans/vendeur_qr.dart`, `etat_application.dart` (section
  « Ajout d'un vendeur »), `synchro.dart`, `services/google.dart`, `MainActivity.kt`.
- Tests : `test/ecrans/ajout_vendeur_test.dart` (19 : chiffrement, 10 minutes, une fois, licence, retrait,
  opérations après retrait, sans réseau, code de secours, Couper tous, accès coupé, écrans) ; relais : tests
  des nouvelles routes. Captures 4 tailles : `test_captures/ajout_vendeur_captures_test.dart` (48 images).
- Guides mis à jour : agents (3 bis), aide-mémoire du patron ; étapes du propriétaire : partie **I**.
- **Jamais essayé sur un vrai téléphone** : accord Google (`serverAuthCode`), lecteur de QR de Google.
- **Publiée** le 22/11 : Release **`v0.35.0-n104`**. Signature vérifiée (SHA-1 49:27:0C:…:B1:A3). APK
  universel **18,84 Mo** (0.34 : 18,65 Mo → **+0,19 Mo** pour le lecteur de QR et le module `qr`) ; arm64
  10,55 Mo ; armv7 10,05 Mo. Aucun code secret Google (`GOCSPX…`) dans l'APK. Tests : 498 (Flutter) + relais.
- Le relais en ligne est encore l'ancien (`/google/id` → 404) : partie **I** à faire par le propriétaire.

### 23/11 — relais vérifié, action « 8 - Mettre à jour le relais »
- Partie I faite par le propriétaire (identifiant « Application Web » sans adresse, secrets Cloudflare
  `GOOGLE_WEB_ID` et `GOOGLE_WEB_SECRET`, nouveau `worker.js`, version 22580f67). Vérifié sans rien écrire :
  `/google/id` → 200 (ID présent), boîte au hasard → 404 / `present:false`, demande pour un code inconnu →
  404 (rien écrit), échange sans jeton → 401, accès avec un faux jeton → 403 « refusé par Google » (Google
  accepte donc l'ID et le code secret : sinon « invalid_client » → 502), alertes sans jeton → 401.
- Nouvelle action **« 8 - Mettre à jour le relais »** (`.github/workflows/mettre-a-jour-relais.yml`) :
  à la main ou à chaque changement de `relais/worker.js` sur `main` ; tests du relais, KV retrouvé par son
  nom, `wrangler@4.158.0 deploy` (secrets du Worker gardés, `keep_vars`), vérification en ligne, retour
  automatique à la version précédente si elle échoue. Jeton `ZP_JETON_CLOUDFLARE` (Workers Scripts : Edit,
  Workers KV Storage : Read) + variable `ZP_CLOUDFLARE_COMPTE` : partie **J** des étapes du propriétaire.
  Essai à blanc de wrangler (configuration et paquet de 12,8 Ko) : OK.
- Tâche programmée à 8 h 12 (Lomé) dans cette session : voix 020, 037, 049, 050, puis la 0.35.1.

### Version 0.35.1 — voix d'Afi complète (23/11)
- Tâche de 8 h 12 : action 6 lancée sur `main` (mode voix, phrases 020, 037, 049, 050, sans sons de test),
  réussie → branche `voix-demonstration` « Voix complète : 50/50 ». Vérifié : 4 vrais MP3, durées en accord
  avec le texte (020 : 1,7 s ; 037 : 4,2 s ; 049 : 5,8 s ; 050 : 5,1 s). Dossier `assets/demo/voix` repris
  de cette branche (50 phrases + `bouches.json`). Tests de la démonstration : OK.
- « Ce qu'il faut dire au client » : la limite « 2 dernières phrases par la voix du téléphone » est retirée.
- **Publiée** le 23/11 : Release **`v0.35.1-n107`**. Signature vérifiée (SHA-1 49:27:0C:…:B1:A3), 50 voix dans
  l'APK (050 identique au fichier de l'action 6), APK universel 18,86 Mo.

### Version 0.35.2 — lecteur de QR code réparé (23/11)
- **Essai réel (Pixel 6, 0.35.1)** : « Scanner le QR code » → message rouge tout de suite, l'appareil photo ne
  s'ouvre jamais.
- **Cause trouvée dans le code** : le lecteur de Google est un MODULE des Services Google Play téléchargé à la
  demande. `MainActivity.scannerQr` appelait `startScan()` sans jamais demander ni attendre ce module ; le
  premier appel échoue alors (MlKitException « UNAVAILABLE » / « CODE_SCANNER_UNAVAILABLE ») et
  `scannerQrAndroid` transformait TOUTE erreur en « ne marche pas sur ce téléphone », sans garder le code.
  (Le code exact n'était pas affiché : il le sera désormais, ce qui confirmera la cause sur le Pixel 6.)
- **Corrections** : `lecteurPret` (`ModuleInstallClient.areModulesAvailable`) et `lecteurPreparer`
  (`installModules`, demande urgente, réponse à la fin de l'installation) dans `MainActivity.kt` ;
  `play-services-base` 18.5.0 ; méta-donnée `com.google.mlkit.vision.DEPENDENCIES = barcode_ui` (Play Store) ;
  module demandé dès le premier lancement (étape Bienvenue) et à l'ouverture de « Je suis vendeur » (bouton
  « Préparation du lecteur… » avec une roue) ; `scannerAvecReessai` (préparation puis réessai toutes les 3 s,
  jusqu'à 60 s) ; fermeture du lecteur (annulé, code 201) = retour sans erreur ; message selon la cause
  (Internet, place, Services Google Play, appareil photo refusé, délai) + code exact en petit
  (« Code : 14 / UNAVAILABLE (mlkit) ») ; code de secours : plus de compteur « 0/9 », tiret ou espace acceptés.
  Noms et valeurs des codes vérifiés dans les bibliothèques de Google (`MlKitException` 18.11.0,
  `CommonStatusCodes`, `ModuleInstallStatusCodes`, `ModuleInstallStatusUpdate.InstallState`).
- Code : `lib/services/lecteur_qr.dart` (nouveau), `vendeur_qr.dart`, `main.dart`, `MainActivity.kt`.
  Tests : `test/ecrans/lecteur_qr_test.dart` (14 : réessai, délai, vraie panne, annulation, messages, codes,
  écran). Ancien `scannerQrAndroid` et `ErreurScanner` supprimés.
- Action « test minimal (temporaire) » : le fichier n'existe plus dans aucune branche ; elle reste dans la
  liste à cause de son seul passage (21/11), à supprimer par le propriétaire (pas d'outil pour le faire ici).
- **Publiée** le 23/11 : Release **`v0.35.2-n109`**. Signature vérifiée (SHA-1 49:27:0C:…:B1:A3), 50 voix,
  méta-donnée `barcode_ui` présente dans l'APK, APK universel 18,88 Mo. Tests : 512 (Flutter) + relais.

### Version 0.36.0 — refonte « commerçant » (chantier de nuit, 23-24/11)
Plan et état des lieux : `docs/refonte-commercant.md`. Argumentaire : `docs/mise-en-service/argumentaire-recruteurs.md`.
- **Lot 1 — démarrage en 3 étapes, sans inventaire** : bienvenue → vérification → activation (inchangée) →
  1. nom ; 2. « Vous vendez : détail / gros / les deux » + « Qui vend : moi / un vendeur / plusieurs » (nouvelle
  étape `profil`, réglages `vente` et `qui_vend` dans la configuration, synchronisés, ignorés par les anciennes
  versions) ; 3. code du patron → « Vous pouvez vendre ! ». Types, contact, couleur, reçu, produits connus :
  Gestion → **Ma boutique** (mêmes écrans, mode « réglage »). **Nouveau produit** pendant la vente (nom + prix,
  carton facultatif) ; un vendeur peut le faire, le patron reçoit une alerte. Stock **« pas encore compté »**
  (ni reçu ni compté) : pas de chiffre, aucune alerte de stock. **Compter mon stock** : 5 produits à la fois,
  les plus vendus (30 jours) puis les plus chers, barre de progression ; le **premier comptage** d'un produit
  n'est pas un écart (ligne d'inventaire `premier`). Carte **« À faire quand vous avez le temps »** (compter,
  vendeur, Google, prix d'achat, numéro sur les reçus). « Ajouter mon vendeur » caché si « Moi ».
- **Lot 2 — gros et détail** : « Emballages » → **Vente en gros** (nom libre, nombre d'unités, prix de gros,
  **prix revendeur** facultatif = un conditionnement « … (revendeur) » de même contenance : aucune nouvelle
  donnée) ; Vendre : gros boutons **Détail / Gros / Gros revendeur** ; stock **« 3 cartons de 24 et 5 boîtes »**
  (liste, arrivage) ; arrivage en cartons ; unités de gros (carton, sac, casier, bidon) pour qui vend seulement
  en gros.
- **Lot 3 — les mots** (avant → après) : Clients → **Ce qu'on me doit** ; Fournisseurs → **Ce que je dois** ;
  Chiffres → **Mon bénéfice** ; Arrivages → **Arrivage** ; Appareils et Drive → **Compte Google** ; Emballages →
  **Vente en gros** ; Bénéfice estimé → **Bénéfice** ; Ventes du jour (accueil) → **Vendu aujourd'hui** ;
  Crédits clients (tableau) → **Ce qu'on me doit** ; Mixx (T-Money) → **Mixx by Yas** ; Prix de vente → **Prix au
  détail** ; « Ajouter un emballage » → **Ajouter une vente en gros** ; « Le patron doit d'abord ajouter ses
  produits » → **« Ajoutez celui que vous vendez maintenant : son nom et son prix suffisent »** ; « Votre boutique
  est prête » → **« Vous pouvez vendre ! »**.
- **Lot 4 — valeur visible** : accueil du patron (téléphone et grand écran) : **Vendu aujourd'hui**,
  **Bénéfice** (ou « Ajoutez le prix d'achat »), **Caisse : juste / il manque … / ouverte** (espèces ; un manque
  du jour reste affiché si la caisse est rouverte), ventes **par vendeur** s'il y en a plusieurs. Fermeture :
  **Envoyer sur WhatsApp** (texte ; sans l'écart pour le vendeur).
- **Démonstration retirée de l'application** (demande du propriétaire pendant la nuit : « ça sature, les gens ne
  comprennent pas » ; une vidéo de l'écran la remplace) : plus aucun bouton (ni « Voir un exemple », ni
  « Voir une démonstration » à l'activation). Le code de la démo, la visite d'Afi et les 50 voix restent dans le
  dépôt et l'APK, sans accès (décision prudente de nuit : les supprimer touche beaucoup de fichiers ; à faire
  dans une prochaine version si le propriétaire le confirme : APK plus léger d'environ 1 Mo). La boutique
  d'exemple a quand même été enrichie (gros, vendeur, manque de caisse, crédit) et reste testée.
- **Lot 5** : crédit déjà complet (renommé) ; paiements Espèces / Flooz / Mixx by Yas / Crédit ; **réserve
  (« magasin ») non faite** : plan dans `docs/refonte-commercant.md`.
- **Lot 6** : `argumentaire-recruteurs.md` ; guides agents, aide-mémoire, « ce qu'il faut dire » mis à jour.
- **Données** : aucun changement de schéma. Test de mise à jour sur une base fabriquée par le VRAI code de la
  0.35.2 (`test/fixtures/mise_a_jour/v0.35.2.db`, généré par `test_perf/fabriquer_base_0352_test.dart`) : mêmes
  stocks, ventes, crédits, vendeurs, chaîne ; les anciens emballages sont la vente en gros ; pas de démarrage.
- Tests : `test/ecrans/refonte_036_test.dart` (11) ; suite complète : 523 tests, tous verts ; captures 4 tailles :
  `test_captures/refonte_036_captures_test.dart` (56 images).
