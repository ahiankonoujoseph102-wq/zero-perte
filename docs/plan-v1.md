# Zéro Perte — Plan de la version 1 (mis à jour, mission 2)

*21 novembre 2026. Remplace le découpage de `analyse.md` (partie 5).*

**Ordre décidé :** A (fondations) → B (boutique sur un seul téléphone) → C1 (crédit client) → D (patron à distance) → C2 à C4 (inventaires, crédit fournisseur) → E (mise en service).

**Architecture :** sans serveur à nous, avec le Drive Google de chaque boutique (voir `decision-serveur.md`).

**Règle :** chaque étape donne un APK installable. On ne passe à la suivante qu'après validation par le propriétaire.

---

## Bloc A — Fondations

| # | Étape | Résultat visible |
|---|---|---|
| A1 | Projet Flutter + GitHub Actions qui fabrique un **APK signé**. Création de la **clé de signature** avec sa copie de secours. | Une application « Zéro Perte » s'installe |
| A2 | **Dépôt public de téléchargement** (`zero-perte-telechargement`) : publication automatique de l'APK + `version.json` | Un lien fixe « dernière version » |
| A3 | **Mise à jour intégrée** : « Nouvelle version disponible — Installer » (placée ici parce que plus de 20 clients recevront des versions de test) | Mise à jour en un geste |
| A4 | Base locale « on ajoute, on ne modifie jamais » : montants entiers, identifiants uniques, téléphone d'origine, **heure du téléphone + contrôle de l'horloge** | Tests automatiques |
| A5 | Style visuel : gros boutons, vert = entre, rouge = sort, chiffres géants, `12 500 F`, **thème de couleur variable** (pour la personnalisation) | Écran d'accueil de démonstration |
| A6 | **Démarches Google (sans code, à lancer tôt car elles prennent du temps)** : projet Google Cloud **sans facturation**, écran de consentement, page de confidentialité sur GitHub Pages, demande de vérification simple | Dossier Google en cours de validation |

## Bloc B — Boutique sur un seul téléphone (hors ligne)

| # | Étape |
|---|---|
| B1 | **Code d'activation signé** : vérification hors ligne, activation par lien WhatsApp ou QR code ; bouton GitHub « Générer un code » + registre des clients |
| B2 | **Assistant de personnalisation** (écrans 1, 3 à 8 de `decision-serveur.md` §4) : type de boutique, nom, logo, téléphone, adresse, couleur, en-tête du reçu, PIN du patron ; **raccourci d'écran d'accueil** au nom de la boutique |
| B3 | **Catalogues préremplis** par type (intégrés à l'APK) : sélection « Je vends ça », prix, unités et conditionnements (sac → bol, casier → bouteille), **ouverture d'un sac** |
| B4 | **Arrivages** (patron seulement) : entrée de stock, prix d'achat |
| B5 | **Vendre** : photos, + et −, total géant lu à voix haute, montant reçu, **monnaie à rendre**, espèces / Flooz / Mixx (avec référence) |
| B6 | **Vendeurs** : PIN, auteur et heure sur chaque action, blocage |
| B7 | **Annulation avec motif**, retour client, **perte déclarée** |
| B8 | **Fonds de caisse**, **dépenses**, **retrait du patron** |
| B9 | **Fermeture de caisse en comptage aveugle** (espèces, Flooz et Mixx séparés), écart affiché |
| B10 | **Reçu numéroté sans trou avec préfixe par téléphone**, aux couleurs de la boutique, partagé sur WhatsApp en un geste |
| B11 | **Tableau du patron** : jour, semaine et mois, bénéfice estimé, stock bas |
| B12 | **Export de sauvegarde** manuel (fichier chiffré à envoyer sur WhatsApp) + sauvegarde automatique Android en bonus |

➡️ **Pilote 1** : 2 ou 3 boutiques parmi les clients qui ont déjà payé.

## Bloc C1 — Crédit client (promesse publicitaire)

| # | Étape |
|---|---|
| C1 | Fiche client (nom, téléphone, photo), **plafond**, vente à crédit, **remboursement partiel**, reçu de crédit envoyé au client sur WhatsApp, bouton « Rappeler » (message prêt à envoyer) |

## Bloc D — Patron à distance (promesse « tu voyages tranquille »)

| # | Étape |
|---|---|
| D1 | **Connexion au compte Google de la boutique** (permission `drive.appdata` seulement) ; la licence est liée à ce compte |
| D2 | **Envoi des journaux** vers le dossier caché du Drive : paquets compressés, un fichier par téléphone, reprise automatique après une coupure |
| D3 | **Relève des journaux des autres téléphones** : en tâche de fond toutes les 15 à 30 min + à chaque ouverture ; voyant vert / orange / rouge ; guide « désactiver l'économie de batterie » |
| D4 | **Liaison d'un deuxième téléphone** (vendeur) au même compte, avec un **nouveau préfixe de reçu** |
| D5 | **Vue patron à distance** : ventes, caisse, stock et crédits de la boutique, à jour à la dernière relève |
| D6 | **Alertes locales** après chaque relève : annulation, écart de caisse, stock bas, **téléphone vendeur muet depuis X heures**, PIN patron utilisé en boutique, heure du téléphone faussée ; **résumé du soir** (notification + partage WhatsApp) |
| D7 | **Restauration complète** sur un nouveau téléphone depuis le Drive ; détection et réparation si le Drive a été vidé |
| D8 | *(Option gratuite, après accord)* **Alertes urgentes instantanées** via le relais Cloudflare gratuit + Firebase Cloud Messaging |
| D9 | *(Option, après accord)* **SMS de secours** sans Internet (résumé du soir, alerte grave), payé par la boutique |

➡️ **Pilote 2** : patron réellement absent pendant quelques jours. On mesure le délai réel et le volume de données par boutique.

## Blocs C2 à C4 — Inventaires et fournisseurs

| # | Étape |
|---|---|
| C2 | **Inventaire complet en comptage aveugle** : écart **en francs**, tolérance pour les produits vendus au bol ou au tas |
| C3 | **Inventaire tournant quotidien** : 3 à 5 produits au hasard, priorité aux produits chers et rapides ; suivi des écarts par vendeur |
| C4 | **Crédit fournisseur** (côté patron) |

## Bloc E — Mise en service

| # | Étape |
|---|---|
| E1 | **Liste noire de licences** dans `version.json` ; contrôle du nombre de téléphones par licence |
| E2 | **Catalogues mis à jour à distance** (téléchargés depuis le dépôt public, sans nouvel APK) |
| E3 | **Guide d'installation** en images et en vocal : sources inconnues, création du compte Google de la boutique, économie de batterie |
| E4 | Déploiement chez les plus de 20 clients, puis diffusion large |

## Plus tard (V1.5 / V2)

Voix en éwé, mina et kabiyè ; code-barres ; impression Bluetooth ; plusieurs boutiques par patron ; Play Store.

---

## Ce qui a changé par rapport à `analyse.md`

- **Supabase est abandonné** au profit du Drive de chaque boutique (contrainte des 0 F).
- **Les vendeurs n'ont plus de compte à eux** : tous les téléphones de la boutique utilisent le **compte Google de la boutique**, et chaque personne s'identifie par son PIN.
- **La licence devient « à vie »**, signée et vérifiée hors ligne (au lieu d'un abonnement suspendable).
- **La mise à jour intégrée et le dépôt public passent dans le bloc A** (au lieu de E), car des clients payants recevront les versions de test.
- **La personnalisation et les catalogues** entrent dans le bloc B (B2, B3).
