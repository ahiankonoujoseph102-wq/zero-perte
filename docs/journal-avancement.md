# Zéro Perte — Journal d'avancement

Ce fichier permet à une **nouvelle session** de reprendre exactement où le travail s'est arrêté.
Il est mis à jour **à la fin de chaque étape**.

---

## 1. Où en est-on ? (à lire en premier)

| | |
|---|---|
| **Dernière étape terminée** | **B1** — Assistant d'installation (partie 1) |
| **Version publiée** | 0.3.0 (voir les Releases GitHub) |
| **Prochaine étape** | **B2** — Code d'activation signé |
| **Méthode** | Enchaîner les étapes de `docs/plan-v1.md` sans validation intermédiaire : B1→B13, puis C1, D, C2→C4, E. Rapport au chef de projet **à la fin de chaque bloc**, ou si une décision appartient au propriétaire, ou si on est bloqué. |
| **Ordre des blocs** | A ✅ → **B (en cours)** → C1 → D → C2–C4 → E |

### Décisions en attente du propriétaire (à poser dans le rapport de fin de bloc B)

| # | Question | Choix provisoire (facile à changer) |
|---|---|---|
| Q1 | Que peut faire une boutique **avant** d'avoir saisi son code d'activation ? | *(à définir en B2)* |
| Q2 | Génération des codes d'activation : jeton longue durée pour écrire dans le coffre privé (le jeton actuel `ZP_JETON_COFFRE` expire le 28 novembre) | *(à définir en B2)* |

---

## 2. Comment reprendre le travail (environnement)

- **Dépôt** : `ahiankonoujoseph102-wq/zero-perte` (public). Travail sur `main` (décision du propriétaire), la branche `claude/pensive-einstein-jfps3a` est tenue au même niveau.
- **Flutter 3.47.9** (stable), Java 17. Dans une session cloud vierge : télécharger Flutter dans `/opt/sdk/flutter` et le SDK Android (`cmdline-tools`, `platforms;android-36`, `build-tools;36.0.0`) dans `/opt/sdk/android`.
- **Tests** : `flutter analyze` puis `flutter test` (tests dans `test/`, les outils communs dans `test/support/outils.dart`).
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
