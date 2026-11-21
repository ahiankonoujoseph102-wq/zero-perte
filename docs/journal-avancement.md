# Zéro Perte — Journal d'avancement

Ce fichier permet à une **nouvelle session** de reprendre exactement où le travail s'est arrêté.
Il est mis à jour **à la fin de chaque étape**.

---

## 1. Où en est-on ? (à lire en premier)

| | |
|---|---|
| **Dernière étape terminée** | **B13** — Sauvegarde chiffrée → **bloc B terminé** |
| **Version publiée** | 0.25.0 (Android et Windows, voir les Releases GitHub) |
| **Dernière étape terminée (bis)** | **C1** — Crédit client |
| **Prochaine étape** | Rapport de fin de bloc C1, puis bloc **D** (synchronisation) |
| **Méthode** | Enchaîner les étapes de `docs/plan-v1.md` sans validation intermédiaire : B1→B13, puis C1, D, C2→C4, E. Rapport au chef de projet **à la fin de chaque bloc**, ou si une décision appartient au propriétaire, ou si on est bloqué. |
| **Ordre des blocs** | A ✅ → B ✅ → C1 ✅ → **D** → C2–C4 → E |
| **Pour tout choix non décidé** | Prendre l'option la plus simple et la lister dans le rapport de fin de bloc C1 avec une recommandation. |

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
