# Zéro Perte — Plan de la version 1 (mis à jour, mission 3)

*21 novembre 2026. Remplace les versions précédentes et le découpage de `analyse.md` (partie 5).*

**Ordre décidé :** A (fondations) → B (boutique sur un seul téléphone) → C1 (crédit client) → D (patron à distance) → C2 à C4 (inventaires, crédit fournisseur) → E (mise en service).

**Architecture :** le Drive Google de chaque boutique + un relais Cloudflare gratuit pour les alertes graves + **Releases GitHub** pour les mises à jour (dépôt public depuis l'étape A1). Le détail est dans `decision-serveur.md`.

**Coût pour le propriétaire : 0 F.**

**Règle :** chaque étape donne un APK installable. On ne passe à la suivante qu'après validation par le propriétaire.

---

## Bloc A — Fondations

| # | Étape | Résultat visible |
|---|---|---|
| A1 | Projet Flutter + GitHub Actions qui fabrique l'**APK universel** (32 + 64 bits, pour WhatsApp) **et** les **APK par processeur** (mises à jour), tous avec le **même versionCode**, et les publie dans une **Release GitHub** (lien fixe `latest/download`). Création de la **clé de signature**, stockée **uniquement dans les secrets GitHub**, avec une copie de secours chiffrée dans le dépôt **privé** `zero-perte-coffre`. | Une application « Zéro Perte » s'installe ✅ |
| A2 | **Base locale SQLite** « on ajoute, on ne modifie jamais » : journal `operations` (identifiant unique, auteur, heure du téléphone, téléphone d'origine, **numéro d'ordre par téléphone**, **chaîne d'empreintes SHA-256**, place pour la **signature** de l'étape D2) ; **déclencheurs SQL qui interdisent modification et effacement** ; montants en **F entiers**, quantités en **millièmes d'unité de base** ; conditionnements (sac → bol, facteur + prix propre), **vente au montant**, **emballages consignés**, **préfixe de reçu par téléphone**, caisse par moyen de paiement (fonds, dépenses, retraits du patron, consignes). Compatible avec le SQLite ancien d'Android 8. | 49 tests automatiques ✅ |
| A3 | **Style visuel** : police **Atkinson Hyperlegible** (conçue pour les personnes qui lisent mal), marque **bleu nuit** (le vert reste réservé à l'argent qui entre), fond crème ; **écran d'accueil vendeur** : Vendre (vert, énorme), Crédit (ambre), Dépense (rouge), Fermer la caisse (bleu nuit) ; vérifié sur 4 tailles d'écran (4", 5", 6,5", tablette) et avec le texte agrandi ×1,5. Version **0.2.0**. | Écran d'accueil ✅ |
| A4 | **Mise à jour intégrée** : l'application lit `version.json`, télécharge l'APK de son processeur, vérifie l'empreinte, puis affiche « Installer » ; nouveautés en français simple dans `version.json` | Mise à jour en un geste |
| A5 | ~~Cloudflare Pages~~ : **remplacé par les Releases GitHub, déjà fait en A1** | — |
| A6 | **Démarches (sans code, à lancer tôt)** : projet Google Cloud **sans facturation**, écran de consentement, page de confidentialité (**GitHub Pages**, gratuit pour un dépôt public), demande de vérification simple ; projet Firebase (offre gratuite) pour les notifications ; **compte Cloudflare** (relais d'alertes, étape D8) | Dossier Google en cours de validation |

## Bloc B — Boutique sur un seul téléphone (hors ligne)

| # | Étape |
|---|---|
| B1 | **Assistant d'installation, partie 1** (`decision-serveur.md` §4.0, étapes 1, 5, 6 à 12) : vérification du téléphone (**refus clair si pas de services Google**), voix, bouton « J'ai besoin d'aide », reprise après interruption |
| B2 | **Code d'activation signé** : vérification hors ligne, activation par lien WhatsApp ou QR code, **licence 2 téléphones** ; bouton GitHub « Générer un code » (licence ou **+1 téléphone**), saisies masquées dans le journal public ; code et **registre des clients rangés dans le coffre privé** |
| B3 | **Personnalisation** : type de boutique, nom, logo, téléphone, adresse, couleur, en-tête du reçu, PIN du patron, **raccourci d'écran d'accueil** au nom de la boutique |
| B4 | **Catalogues préremplis** selon `categories.md` : sélection « Je vends ça », prix, unités et conditionnements, **ouverture d'un sac ou d'un carton**, **vente au montant** (« donne pour 100 F »), **emballages consignés** (casiers, bouteilles, gaz) |
| B5 | **Arrivages** (patron seulement) : entrée de stock, prix d'achat |
| B6 | **Vendre** : photos, + et −, total géant lu à voix haute, montant reçu, **monnaie à rendre**, espèces / Flooz / Mixx (avec référence) |
| B7 | **Vendeur** : PIN, auteur et heure sur chaque action, blocage |
| B8 | **Annulation avec motif**, retour client, **perte déclarée** |
| B9 | **Fonds de caisse**, **dépenses**, **retrait du patron** |
| B10 | **Fermeture de caisse en comptage aveugle** (espèces, Flooz et Mixx séparés), écart affiché |
| B11 | **Reçu numéroté sans trou avec préfixe par téléphone**, aux couleurs de la boutique, partagé sur WhatsApp en un geste |
| B12 | **Tableau du patron** : jour, semaine et mois, bénéfice estimé, stock bas |
| B13 | **Export de sauvegarde** manuel (fichier chiffré) + sauvegarde automatique Android en bonus |

➡️ **Pilote 1** : 2 ou 3 boutiques parmi les clients qui ont déjà payé, à Lomé, installées sur place.

## Bloc C1 — Crédit client (promesse publicitaire)

| # | Étape |
|---|---|
| C1 | Fiche client (nom, téléphone, photo), **plafond**, vente à crédit, **remboursement partiel**, reçu de crédit envoyé au client sur WhatsApp, bouton « Rappeler » |

## Bloc D — Patron à distance (promesse « tu voyages tranquille »)

| # | Étape |
|---|---|
| D1 | **Assistant d'installation, partie 2** (§4.0, étapes 2 à 4) : création guidée du compte Google de la boutique **avec le numéro du patron** (§2.5), validation en deux étapes, codes de secours, connexion (autorisation `drive.appdata` seulement) ; la licence est liée à ce compte |
| D2 | **Envoi des journaux** vers le Drive : paquets compressés, **signés et chaînés**, un fichier par téléphone, envoi après chaque vente dès qu'il y a du réseau, reprise après une coupure |
| D3 | **Relève** des journaux des autres téléphones : en tâche de fond toutes les 15 à 30 min + à chaque ouverture ; voyant vert / orange / rouge ; **guide batterie selon la marque** (§4.0, étape 13) |
| D4 | **Liaison du téléphone du vendeur** (QR code + compte de la boutique ajouté par le patron) ; `telephones.json` ; **refus d'un 3e téléphone** sans code d'extension ; **remplacer un téléphone** |
| D5 | **Vue patron à distance** : ventes, caisse, stock et crédits, à jour à la dernière relève |
| D6 | **Protection contre l'effacement (risque a, §2.4)** : copie locale permanente chez le patron, **contrôle des numéros de suite**, **inventaire du Drive** et **re-dépôt automatique** s'il a été vidé, **signal de vie** du vendeur, détection du compte retiré, de la réinstallation et de l'horloge faussée |
| D7 | **Alertes locales** après chaque relève (annulation, écart de caisse, stock bas, vendeur muet…) + **résumé du soir** (notification + partage WhatsApp) |
| D8 | **Relais Cloudflare pour les alertes graves instantanées (validé)** : Worker gratuit + Firebase Cloud Messaging, jeton par téléphone, limite par boutique, messages chiffrés ; il ne dépend pas du compte Google |
| D9 | **Restauration complète** sur un nouveau téléphone depuis le Drive |
| D10 | **Assistant, partie 3** (§4.0, étapes 14 et 15) : ajout du téléphone vendeur et **test final automatique** |
| D11 | **SMS de secours** (option **désactivée par défaut**, payée par la boutique) : résumé du soir et alertes graves sans Internet |

➡️ **Pilote 2** : patron réellement absent quelques jours + **une installation entièrement à distance** (hors de Lomé) avec la vidéo. On mesure le délai réel, le volume de données et les blocages de l'assistant.

## Blocs C2 à C4 — Inventaires et fournisseurs

| # | Étape |
|---|---|
| C2 | **Inventaire complet en comptage aveugle** : écart **en francs**, tolérance pour les produits vendus au bol, au tas ou au montant |
| C3 | **Inventaire tournant quotidien** : 3 à 5 produits au hasard, priorité aux produits chers et rapides ; suivi des écarts par vendeur |
| C4 | **Crédit fournisseur** (côté patron) |

## Bloc E — Mise en service

| # | Étape |
|---|---|
| E1 | **Liste noire de licences** dans `version.json` signé ; **codes d'extension « +1 téléphone »** |
| E2 | **Catalogues mis à jour à distance** depuis les Releases GitHub, sans nouvel APK |
| E3 | **Kit d'installation** : vidéo (installer l'APK, créer le compte, utiliser l'application), **fiche d'installation** et **enveloppe du patron** imprimables, procédure de création du compte (§2.5) pour les agents |
| E4 | Déploiement chez les plus de 20 clients, puis diffusion large |

## Plus tard (V1.5 / V2)

Voix en éwé, mina et kabiyè ; code-barres ; impression Bluetooth ; plusieurs boutiques par patron ; Play Store ; catégories « services » avancées (restauration avec stock d'ingrédients, pharmacie avec lots et dates de péremption).

---

## Ce qui a changé à l'étape A1 (dépôt devenu public)

- **Hébergement des APK** : **Releases GitHub** (lien fixe `latest/download`, 2 Gio par fichier) au lieu de Cloudflare Pages. Plus de compte ni de clé d'accès supplémentaires. Cloudflare reste prévu pour le **relais d'alertes** (D8).
- **Clé de signature** : uniquement dans les **secrets GitHub**, jamais dans le dépôt, même chiffrée. La copie de secours est dans le dépôt **privé** `zero-perte-coffre`, puis dans le Google Drive du propriétaire.
- **Registre des clients et codes d'activation** : dans le **coffre privé**, jamais dans le dépôt public.
- **APK universel** (`ZeroPerte.apk`) pour WhatsApp ; APK par processeur pour les mises à jour ; même `versionCode` pour les trois.

## Ce qui a changé depuis la mission 2

- **Hébergement des APK** : Cloudflare Pages au lieu d'un dépôt GitHub public (refusé). Il passe en **A2**.
- **Relais Cloudflare d'alertes graves** : validé. Ce n'est plus une option (**D8**).
- **SMS de secours** : option désactivée par défaut (**D11**).
- **Licence** : 2 téléphones + extension vendue (**B2, D4, E1**).
- **Assistant d'installation guidé** pour l'installation à distance, découpé en 3 parties (**B1, D1, D10**).
- **Risque (a)**, effacement du Drive ou retrait du compte : traité en **D6** (détails dans `decision-serveur.md` §2.4).
- **Risque (b)**, limite de comptes par numéro : procédure écrite (`decision-serveur.md` §2.5), intégrée à l'assistant (**D1**) et au kit des agents (**E3**).
- **Huawei sans services Google** : non pris en charge. Le refus est détecté et clairement affiché en **B1**.
- **Catalogues** : toutes les catégories de `categories.md`, avec la **vente au montant** et les **emballages consignés** (**B4**).
