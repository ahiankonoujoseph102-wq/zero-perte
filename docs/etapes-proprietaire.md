# Étapes à faire par le propriétaire (depuis un téléphone)

*Tout est faisable dans le navigateur du téléphone (Chrome), en mode « Version pour ordinateur » quand
c'est indiqué. Aucune de ces étapes ne demande d'écrire un mot de passe ou une clé dans une conversation.
**Ne donnez jamais vos mots de passe ni vos codes à personne, pas même à Claude ou au chef de projet.***

Le code de l'application est déjà prêt : ces étapes « branchent » les comptes gratuits.

---

## A. Google Cloud — pour que les téléphones s'échangent les ventes par Google Drive

Ce qu'on crée : un « projet » Google Cloud **gratuit**, avec la seule autorisation `drive.appdata`
(classée « non sensible » par Google : pas de vérification payante, pas de limite de 100 utilisateurs).

### A1. Créer le projet
1. Ouvrez **console.cloud.google.com** avec **votre** compte Google (celui du propriétaire, pas celui d'une boutique).
2. Acceptez les conditions si c'est la première fois.
3. En haut, touchez le sélecteur de projet → **Nouveau projet**.
4. Nom du projet : `Zero Perte` → **Créer**. Attendez la notification, puis sélectionnez ce projet.

### A2. Activer l'API Google Drive
1. Menu ☰ → **API et services** → **Bibliothèque**.
2. Cherchez **Google Drive API** → touchez-la → **Activer**.

### A3. Écran de consentement (ce que voit la boutique quand elle se connecte)
1. Menu ☰ → **API et services** → **Écran de consentement OAuth** (ou « Google Auth Platform » → **Présentation** → **Commencer**).
2. Nom de l'application : `Zéro Perte`. Adresse d'assistance : votre adresse e-mail.
3. Type d'audience : **Externe** → Suivant.
4. Coordonnées du développeur : votre adresse e-mail → Suivant → acceptez → **Créer**.
5. Partie **Accès aux données** (ou « Champs d'application ») → **Ajouter ou supprimer des champs d'application** →
   cherchez et cochez **`.../auth/drive.appdata`** (« Afficher, créer et supprimer ses propres données de
   configuration dans votre Google Drive ») → **Mettre à jour** → **Enregistrer**.
6. Partie **Audience** → **Publier l'application** → **Confirmer** (état « En production »). Comme l'autorisation
   n'est pas sensible, il n'y a **pas** de vérification à demander.

### A4. Identifiant Android (relie le projet à l'application signée)
1. Ouvrez la dernière fabrication sur GitHub : dépôt **zero-perte** → **Actions** → « 2 - Fabriquer l'APK » →
   la dernière exécution verte sur **main** → en bas, le **résumé**. Copiez la ligne **SHA-1** (une suite de
   paires de chiffres et lettres séparées par « : »). *Cette empreinte est publique : ce n'est pas un secret.*
2. Dans Google Cloud : Menu ☰ → **API et services** → **Identifiants** → **Créer des identifiants** →
   **ID client OAuth**.
3. Type d'application : **Android**.
4. Nom : `Zéro Perte Android`. Nom du package : **`tg.zeroperte.app`**.
5. Empreinte du certificat SHA-1 : collez la ligne copiée à l'étape 1 → **Créer**.
6. Rien à recopier ailleurs : l'application Android trouve toute seule cet identifiant grâce au nom du
   package et à l'empreinte.

### A5. Vérifier
1. Installez la dernière version de l'application sur un téléphone.
2. Espace patron → **Appareils et Drive** → **Connecter le compte Google** → choisissez le compte Google
   **de la boutique** → acceptez.
3. L'écran affiche l'adresse du compte et « Dernière fois : le … ». Si un message d'erreur « 10 » ou
   « DEVELOPER_ERROR » apparaît, l'empreinte SHA-1 ou le nom du package de l'étape A4 est faux.

### A6. (Plus tard) Identifiant pour la version PC Windows
La version Windows se connecte autrement (navigateur). Quand vous voudrez la synchronisation sur PC :
**Identifiants** → **Créer des identifiants** → **ID client OAuth** → type **Application de bureau** →
nom `Zéro Perte PC` → **Créer**. Envoyez-moi seulement **l'ID client** (il se termine par
`.apps.googleusercontent.com` ; ce n'est pas un secret). **N'envoyez pas** le « Code secret du client » :
je vous expliquerai comment le ranger dans les secrets GitHub.

---

## B. Cloudflare — relais gratuit pour les alertes graves

Ce qu'on crée : un petit programme gratuit (« Worker ») qui transmet au patron, en moins d'une minute, les
alertes graves : caisse fermée avec 1 000 F ou plus de manque, vente de 5 000 F ou plus annulée, 5 codes faux.
Le programme est déjà écrit : `relais/worker.js` dans le dépôt.

### B1. Compte
1. Ouvrez **dash.cloudflare.com/sign-up** → créez un compte gratuit avec votre adresse e-mail.
2. Confirmez l'adresse avec le lien reçu par e-mail.

### B2. Espace de stockage des alertes
1. Menu → **Stockage et bases de données** → **KV** (ou « Workers KV ») → **Créer** (« Create a namespace »).
2. Nom : `ALERTES` → **Ajouter**.

### B3. Le relais
1. Menu → **Workers et Pages** → **Créer** → **Créer un Worker** (« Hello World ») → nom :
   `zero-perte-relais` → **Déployer**.
2. **Modifier le code** : effacez tout le code affiché, puis copiez-collez le contenu du fichier
   `relais/worker.js` (sur GitHub : dépôt zero-perte → dossier `relais` → `worker.js` → bouton « Copier »).
   → **Déployer**.
3. Retour au Worker → **Paramètres** → **Liaisons** (« Bindings ») → **Ajouter** → **Espace de noms KV** →
   nom de la variable : **`ALERTES`** (en majuscules) → espace : `ALERTES` → **Enregistrer**.
4. Notez l'adresse du Worker, du type `https://zero-perte-relais.<votre-nom>.workers.dev`.
   *Ce n'est pas un secret.*

### B4. Donner l'adresse à la fabrication de l'application
1. GitHub → dépôt **zero-perte** → **Settings** → **Secrets and variables** → **Actions** → onglet
   **Variables** → **New repository variable**.
2. Nom : **`ZP_RELAIS_URL`** ; valeur : l'adresse notée en B3.4 (sans « / » à la fin) → **Add variable**.
3. Relancez « 2 - Fabriquer l'APK » (Actions → le workflow → **Run workflow** → branche `main`).

### B5. Vérifier
Sur le téléphone d'un **vendeur** : ouvrir la caisse avec 5 000 F puis la fermer en comptant 3 000 F.
Dans la minute, le téléphone du **patron** (application ouverte, connecté en patron) affiche un bandeau
rouge « Caisse fermée par … : il manque 2 000 F » et le dit à voix haute.

*Limite actuelle :* l'alerte arrive quand l'application du patron est **ouverte**. Pour la recevoir
application fermée (notification Android), il faudra plus tard un projet Firebase gratuit (je vous
donnerai les étapes) ; ce n'est pas nécessaire pour le pilote.

---

## C. Jeton `ZP_JETON_CODES` (après le 28 novembre)

Déjà décrit dans le rapport de fin de bloc C1 : jeton « Fine-grained », durée 1 an, accès au seul dépôt
**zero-perte-coffre**, autorisation **Contents : Read and write**, enregistré comme secret
**ZP_JETON_CODES** du dépôt zero-perte. L'action « 4 » l'utilise automatiquement.
