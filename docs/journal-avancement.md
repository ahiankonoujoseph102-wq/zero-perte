# Zéro Perte — Journal d'avancement

Ce fichier permet à une **nouvelle session** de reprendre exactement où le travail s'est arrêté.
Il est mis à jour **à la fin de chaque étape**.

---

## 1. Où en est-on ? (à lire en premier)

| | |
|---|---|
| **Dernière étape terminée** | **B6** — Vendre |
| **Version publiée** | 0.7.0 (voir les Releases GitHub) |
| **Prochaine étape** | **B7** — Vendeurs, connexion par code |
| **Méthode** | Enchaîner les étapes de `docs/plan-v1.md` sans validation intermédiaire : B1→B13, puis C1, D, C2→C4, E. Rapport au chef de projet **à la fin de chaque bloc**, ou si une décision appartient au propriétaire, ou si on est bloqué. |
| **Ordre des blocs** | A ✅ → **B (en cours)** → C1 → D → C2–C4 → E |

### Décisions en attente du propriétaire (à poser dans le rapport de fin de bloc B)

| # | Question | Choix provisoire (facile à changer) |
|---|---|---|
| Q1 | Que peut faire une boutique **avant** d'avoir collé son code d'activation ? (a) rien : l'installation s'arrête à l'étape « Code d'activation » ; (b) une démonstration avec des produits fictifs ; (c) un essai de quelques jours | **(a) bloquée** (le plus simple, empêche le piratage). Pour changer : `EtapeAssistant.activation` dans `lib/app/etat_application.dart` |
| Q2 | **Clé des licences** : le workflow « 3 - Créer la clé des licences » doit tourner **avant le 28 novembre** (expiration de `ZP_JETON_COFFRE`). Le propriétaire le lance-t-il, ou autorise-t-il Claude à le lancer ? | Pas encore lancé : `assets/licence/cle_publique.txt` = « ABSENTE » → l'application affiche « ne peut pas encore vérifier les codes » |
| Q3 | **Jeton longue durée `ZP_JETON_CODES`** (1 an, écriture du coffre seulement) pour générer des codes après le 28 novembre ? | Sans lui, le workflow 4 utilise `ZP_JETON_COFFRE` (jusqu'au 28 novembre seulement) |
| Q5 | **Facteurs « à vérifier » du catalogue** (ex. 1 sac de maïs de 100 kg = 40 bols, 1 casier = 12 grandes bouteilles) : les agents peuvent-ils les confirmer sur le terrain ? | Affichés « à vérifier » au patron, qui peut les corriger |
| Q4 | **Texte du message d'activation** envoyé au patron (workflow 4, fichier dans le coffre) : à valider | « Bonjour, Voici le code d'activation Zéro Perte de votre boutique « NOM » (2 téléphones) : CODE. Pour l'activer : appuyez longtemps sur ce message, choisissez « Copier », puis ouvrez Zéro Perte et touchez « Coller le code ». Ce code est personnel : ne le donnez à personne. » |

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
