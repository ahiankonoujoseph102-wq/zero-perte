# Étapes à faire par le propriétaire (depuis un téléphone)

*Tout est faisable dans le navigateur du téléphone (Chrome), en mode « Version pour ordinateur » quand
c'est indiqué. Aucune de ces étapes ne demande d'écrire un mot de passe ou une clé dans une conversation.
**Ne donnez jamais vos mots de passe ni vos codes à personne, pas même à Claude ou au chef de projet.***

Le code de l'application est déjà prêt : ces étapes « branchent » les comptes gratuits.

---

## A. Google Cloud — pour que les téléphones s'échangent les ventes par Google Drive

✅ **A1 à A4 et A6 faits par le propriétaire (21 novembre 2026)** : projet « Zero Perte »
(ID `zero-perte-515421`), API Google Drive activée ; écran de consentement externe **en production**, seule
autorisation `drive.appdata`, sans logo, avec les 3 pages publiques et le domaine
`ahiankonoujoseph102-wq.github.io` ; identifiant Android (package `tg.zeroperte.app`, SHA-1
`49:27:0C:A9:FE:00:2B:55:14:08:5A:9E:AE:50:10:63:C9:CC:B1:A3`) ; identifiant PC (`ZP_GOOGLE_PC_ID` et
`ZP_GOOGLE_PC_SECRET` dans GitHub — la fabrication Windows vérifie qu'ils sont bien dans l'application, sans
les afficher). **Reste : A5, l'essai sur un vrai téléphone.**

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

### A6. Identifiant pour la version PC Windows (synchronisation sur PC)
Le code est prêt : la connexion se fait par le navigateur du PC.
1. Google Cloud → **API et services** → **Identifiants** → **Créer des identifiants** → **ID client OAuth** →
   type **Application de bureau** → nom `Zéro Perte PC` → **Créer**.
2. Une fenêtre montre **l'ID client** (se termine par `.apps.googleusercontent.com`) et le **Code secret du client**.
3. GitHub → dépôt **zero-perte** → **Settings** → **Secrets and variables** → **Actions** :
   - onglet **Variables** → **New repository variable** → nom **`ZP_GOOGLE_PC_ID`**, valeur : l'ID client ;
   - onglet **Secrets** → **New repository secret** → nom **`ZP_GOOGLE_PC_SECRET`**, valeur : le code secret.
   Collez-les **vous-même dans GitHub** : ne les envoyez à personne (même pas à Claude).
4. Relancez « 2 - Fabriquer l'APK » : la nouvelle version Windows aura le bouton « Connecter le compte Google »
   dans « Appareils et Drive ».

---

## B. Cloudflare — relais gratuit pour les alertes graves

Ce qu'on crée : un petit programme gratuit (« Worker ») qui transmet au patron, en moins d'une minute, les
alertes graves : caisse fermée avec 1 000 F ou plus de manque, vente de 5 000 F ou plus annulée, 5 codes faux.
Le programme est déjà écrit : `relais/worker.js` dans le dépôt.

### B1. Compte
1. Ouvrez **dash.cloudflare.com/sign-up** → créez un compte gratuit avec votre adresse e-mail.
2. Confirmez l'adresse avec le lien reçu par e-mail.

### B2. Espace de stockage des alertes
*(Noms des menus vérifiés en novembre 2026 ; Cloudflare est en anglais.)*
1. Menu de gauche → **Storage & databases** → **Workers KV** → bouton **Create instance**.
2. Nom (« Namespace name ») : `ALERTES` → **Create**.

### B3. Le relais
1. Menu de gauche → **Compute (Workers)** → **Workers & Pages** → **Create application** →
   **Start with Hello World!** → nom (« Worker name ») : `zero-perte-relais` → **Deploy**.
2. Sur la page qui s'affiche → **Edit Code** : effacez tout le code affiché, puis copiez-collez le contenu du
   fichier `relais/worker.js` (sur GitHub : dépôt zero-perte → dossier `relais` → `worker.js` → bouton
   « Copy raw file »). → bouton **Deploy** (en haut à droite).
   *Sur téléphone :* l'éditeur est petit mais fonctionne ; tournez le téléphone à l'horizontale.
3. Retour au Worker → onglet **Bindings** → **Add binding** → **KV namespace** → **Add Binding** →
   « Variable name » : **`ALERTES`** (en majuscules) → « KV namespace » : `ALERTES` → **Add Binding**
   (le Worker est redéployé tout seul).
4. Notez l'adresse du Worker (onglet **Settings** → **Domains & Routes**, ligne `workers.dev`), du type
   `https://zero-perte-relais.<votre-nom>.workers.dev`. *Ce n'est pas un secret.*

**Mise à jour du relais** (quand le fichier `relais/worker.js` change, par exemple la version de
novembre 2026 qui économise les lectures) : refaites seulement B3.2 (Edit Code → coller → Deploy).

**À savoir :** les limites gratuites de Cloudflare valent pour TOUT le compte (toutes les boutiques
ensemble : 100 000 lectures, 1 000 écritures et 1 000 listes par jour). Avec la case « dernière alerte »,
une consultation sans nouveauté coûte 1 lecture et aucune liste : cela tient environ 70 boutiques
(une consultation par minute et par patron). **À 50 boutiques, il faudra revoir le relais.**

### B4. Donner l'adresse à la fabrication de l'application
1. GitHub → dépôt **zero-perte** → **Settings** → **Secrets and variables** → **Actions** → onglet
   **Variables** → **New repository variable**.
2. Nom : **`ZP_RELAIS_URL`** ; valeur : l'adresse notée en B3.4 (sans « / » à la fin) → **Add variable**.
3. Relancez « 2 - Fabriquer l'APK » (Actions → le workflow → **Run workflow** → branche `main`).

### B5. Vérifier
Sur le téléphone d'un **vendeur** : ouvrir la caisse avec 5 000 F puis la fermer en comptant 3 000 F.
Dans la minute, le téléphone du **patron** (application ouverte, connecté en patron) affiche un bandeau
rouge « Caisse fermée par … : il manque 2 000 F » et le dit à voix haute.

*Application fermée :* pour recevoir l'alerte en notification même quand l'application du patron est fermée, faites aussi la partie **F (Firebase)**.

---

## C. Jeton `ZP_JETON_CODES` — ✅ FAIT (21 novembre 2026)

✅ **Fait par le propriétaire** : secret `ZP_JETON_CODES` créé (accès au seul dépôt `zero-perte-coffre`,
Contents en lecture et écriture, sans date d'expiration). L'action « 4 - Générer un code d'activation » l'utilise
et l'écrit dans son résumé (« Jeton utilisé : ZP_JETON_CODES ») ; elle vérifie aussi chaque code avec le même
programme que l'application. Rien d'autre à faire. *(Conseil : comme il n'expire pas, si un jour il est
divulgué, supprimez-le dans GitHub → Settings → Developer settings → Fine-grained tokens et recréez-en un.)*

Étapes suivies (pour mémoire) :

1. GitHub (connecté avec votre compte) → photo en haut à droite → **Settings** → tout en bas **Developer
   settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. Nom : `ZP_JETON_CODES`. Expiration : **1 an** (« Custom », date dans un an).
3. Repository access : **Only select repositories** → **zero-perte-coffre** (et rien d'autre).
4. Permissions → Repository permissions : **Contents : Read and write**. (« Metadata : Read-only » se coche
   tout seul.) Ne cochez rien d'autre.
5. **Generate token**. Le jeton s'affiche une seule fois : ne le copiez nulle part ailleurs qu'à l'étape 6,
   ne l'envoyez à personne.
6. Dépôt **zero-perte** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret** →
   nom **`ZP_JETON_CODES`**, valeur : collez le jeton → **Add secret**.
7. L'action « 4 - Générer un code d'activation » l'utilise automatiquement (sans rien changer).

---

## D. Windows : premier lancement (« Windows a protégé votre ordinateur »)

L'application PC n'est pas encore signée : Windows l'indique à la première ouverture. C'est normal pour le pilote.
1. Téléchargez `ZeroPerte-Windows.zip` (lien : `…/releases/latest/download/ZeroPerte-Windows.zip`).
2. Clic droit sur le fichier → **Extraire tout…** → **Extraire** (par exemple dans `Documents\Zero Perte`).
3. Ouvrez le dossier extrait → double-cliquez **ZeroPerte.exe**.
4. Une fenêtre bleue s'affiche : « Windows a protégé votre ordinateur ». Cliquez sur **Informations
   complémentaires** (petit lien sous le texte).
5. Un bouton **Exécuter quand même** apparaît → cliquez dessus. Windows ne le redemandera plus pour ce fichier.
6. (Conseillé) Clic droit sur `ZeroPerte.exe` → **Afficher d'autres options** → **Envoyer vers** → **Bureau (créer
   un raccourci)**.

Si l'antivirus bloque le fichier : choisissez **Autoriser** / **Restaurer** dans sa fenêtre (c'est la même
application que sur la page GitHub officielle).

---

## E. (Plus tard) Microsoft Store — supprime le message de Windows, gratuitement

Le Store signe l'application lui-même : plus de message « Windows a protégé votre ordinateur ».
Chaque fabrication prépare déjà le paquet **`ZeroPerte-Store.msix`** (GitHub → Actions → la fabrication → en bas,
**Artifacts** → `ZeroPerte-Store-…`).

### E1. Compte développeur (gratuit pour une personne)
1. Sur un PC, ouvrez **storedeveloper.microsoft.com** → **Get started** / **Commencer** → compte Microsoft
   (créez-en un avec votre adresse e-mail si besoin).
2. Type : **Individual developer** (développeur individuel). Suivez la vérification d'identité demandée.

### E2. Réserver le nom
1. **partner.microsoft.com/dashboard** → **Apps and games** → **New product** → **MSIX or PWA app**.
2. Nom : `Zéro Perte` (ou `Zero Perte Caisse` si le nom est pris) → **Reserve**.
3. Menu de l'application → **Product management** → **Product identity**. Notez trois valeurs (elles ne
   sont pas secrètes) :
   - **Package/Identity/Name** (ex. `12345Exemple.ZeroPerte`) ;
   - **Package/Identity/Publisher** (commence par `CN=`) ;
   - **Package/Properties/PublisherDisplayName**.

### E3. Les donner à la fabrication
GitHub → dépôt **zero-perte** → **Settings** → **Secrets and variables** → **Actions** → onglet **Variables** :
- **`ZP_MSIX_IDENTITE`** = Package/Identity/Name ;
- **`ZP_MSIX_EDITEUR`** = Package/Identity/Publisher ;
- **`ZP_MSIX_EDITEUR_NOM`** = PublisherDisplayName.
Relancez « 2 - Fabriquer l'APK ».

### E4. Envoyer au Store
1. Téléchargez l'artefact `ZeroPerte-Store-…` de la dernière fabrication → décompressez → `ZeroPerte-Store.msix`.
2. Partner Center → votre application → **Start your submission** :
   - **Pricing and availability** : Gratuit (le paiement se fait par la licence Zéro Perte) ;
   - **Properties** : catégorie **Business** ;
   - **Age ratings** : questionnaire (réponses « non » partout) ;
   - **Packages** : déposez `ZeroPerte-Store.msix` ;
   - **Store listings** : description, au moins une capture d'écran (je vous les fournis).
3. **Submit to the Store**. La vérification de Microsoft prend en général 1 à 3 jours.

---

## F. Firebase — alertes graves même quand l'application du patron est fermée

Gratuit. Le code est prêt (téléphone et relais) ; il manque seulement le compte.

### F1. Projet Firebase
1. **console.firebase.google.com** (même compte Google que pour Google Cloud) → **Ajouter un projet** →
   choisissez le projet **Zero Perte** existant (celui de la partie A) → désactivez Google Analytics → **Continuer**.

### F2. Application Android
1. Page du projet → icône **Android** (« Ajouter une application ») → nom du package **`tg.zeroperte.app`** →
   **Enregistrer l'application**.
2. **Ne téléchargez pas** `google-services.json` (pas nécessaire) → **Suivant** jusqu'à la fin.
3. ⚙️ **Paramètres du projet** → onglet **Général** → section « Vos applications » → l'application Android. Notez :
   - **ID d'application** (ex. `1:1234567890:android:abcdef…`) ;
   - **Clé API Web** (en haut, « Clé API Web ») ;
   - **ID du projet** ;
   - onglet **Cloud Messaging** → **ID de l'expéditeur**.
   *Ces quatre valeurs ne sont pas des secrets.*
4. GitHub → **Settings** → **Secrets and variables** → **Actions** → **Variables** :
   `ZP_FIREBASE_APPLI` (ID d'application), `ZP_FIREBASE_CLE` (Clé API Web), `ZP_FIREBASE_PROJET` (ID du projet),
   `ZP_FIREBASE_EXPEDITEUR` (ID de l'expéditeur).

### F3. Autoriser le relais à envoyer les notifications
1. Firebase → ⚙️ **Paramètres du projet** → **Comptes de service** → **Générer une nouvelle clé privée** → un fichier
   `.json` se télécharge. **C'est un secret : ne l'envoyez à personne.**
2. Cloudflare → **Workers et Pages** → `zero-perte-relais` → **Paramètres** → **Variables et secrets** →
   **Ajouter** → type **Secret** → nom **`FCM_COMPTE`** → valeur : ouvrez le fichier `.json` (avec l'application
   « Fichiers » du téléphone, « Ouvrir avec » un éditeur de texte), copiez **tout** son contenu et collez-le →
   **Déployer**.
3. Effacez ensuite le fichier `.json` de votre téléphone.
4. Relancez « 2 - Fabriquer l'APK ». Sur le téléphone du **patron**, ouvrez l'application une fois connecté en
   patron : Android demande « Autoriser les notifications ? » → **Autoriser**.

### F4. Vérifier
Application du patron **fermée** ; sur le téléphone d'un vendeur, fermez la caisse avec 2 000 F de moins :
une notification « Zéro Perte : alerte — Caisse fermée par … : il manque 2 000 F » arrive en quelques secondes.

---

## G. Pages publiques pour Google (accueil, confidentialité, conditions)

Les 3 pages sont prêtes dans le dépôt (`docs/site/`) et se publient avec l'action « 5 - Publier le site ».
✅ **Fait** : GitHub Pages autorisé (source « GitHub Actions ») et pages en ligne depuis le 21 novembre 2026.

### G1. Activer GitHub Pages (une seule fois)
1. Dans Chrome, ouvrez : **github.com/ahiankonoujoseph102-wq/zero-perte/settings/pages**
   (si la page est trop petite : menu ⋮ → cochez **Version pour ordinateur**).
2. Partie **Build and deployment** → **Source** → choisissez **GitHub Actions** (pas « Deploy from a branch »).
   Il n'y a rien d'autre à remplir ni à enregistrer.

### G2. Publier
1. Dépôt **zero-perte** → **Actions** → à gauche **« 5 - Publier le site (pages publiques) »** →
   **Run workflow** → branche **main** → **Run workflow**. (Ou dites à Claude de la lancer.)
2. Attendez la coche verte (moins d'une minute). Ensuite, chaque changement de `docs/site/` sur `main` est
   publié tout seul.

### G3. Les adresses à donner à Google
- Page d'accueil : **https://ahiankonoujoseph102-wq.github.io/zero-perte/**
- Règles de confidentialité : **https://ahiankonoujoseph102-wq.github.io/zero-perte/confidentialite.html**
- Conditions d'utilisation : **https://ahiankonoujoseph102-wq.github.io/zero-perte/conditions.html**
- Domaine autorisé : **ahiankonoujoseph102-wq.github.io**

Dans Google Cloud : Menu ☰ → **Google Auth Platform** → **Personnalisation de la marque** (« Branding ») →
remplissez les 3 liens, puis **Domaines autorisés** → **Ajouter un domaine** → `ahiankonoujoseph102-wq.github.io`
→ **Enregistrer**. Si Google demande de prouver que le domaine est à vous (Search Console), dites-le à Claude :
la preuve se fait en ajoutant un petit fichier aux pages.

---

## H. Voix d'Afi pour la démonstration guidée (une seule fois)

La démonstration marche déjà avec la voix de synthèse du téléphone. Ces étapes donnent à Afi une voix
d'intelligence artificielle plus naturelle, fabriquée **une seule fois** par l'action
« 6 - Fabriquer la voix de la démonstration » (texte : `docs/demo/texte-voix.md`).
**Ne collez jamais la clé dans une conversation (ni avec Claude, ni avec le chef de projet).**

### H1. Créer la clé Gemini (gratuit pour commencer)
1. Dans Chrome, ouvrez **aistudio.google.com** avec **votre** compte Google (celui du projet « Zero Perte »).
   Acceptez les conditions si c'est la première fois.
2. Menu (☰) → **Get API key** (« Obtenir une clé API ») → **Créer une clé API** (« Create API key »).
3. Choisissez le projet **Zero Perte** (`zero-perte-515421`) → **Créer**.
4. La clé s'affiche (elle commence par `AIza`). Touchez **Copier**.

### H2. La ranger dans GitHub
1. Ouvrez **github.com/ahiankonoujoseph102-wq/zero-perte/settings/secrets/actions**
   (menu ⋮ → **Version pour ordinateur** si la page est trop petite).
2. **New repository secret** → nom : **`ZP_CLE_VOIX`** → valeur : collez la clé → **Add secret**.
3. Copiez ensuite n'importe quel autre texte, pour que la clé ne reste pas dans le presse-papiers.

### H3. Écouter 3 voix et choisir
1. Dépôt **zero-perte** → **Actions** → à gauche **« 6 - Fabriquer la voix de la démonstration »** →
   **Run workflow** → mode **extraits**, essai **non** → **Run workflow**. (Ou dites à Claude de la lancer.)
2. Quelques minutes plus tard, écoutez sur le téléphone :
   **https://ahiankonoujoseph102-wq.github.io/zero-perte/voix/** (Voix 1, 2 et 3, même phrase d'accueil).
3. Dites à Claude la voix choisie (1, 2 ou 3).

### H4. Fabriquer la voix de toute la démonstration
1. Claude règle la voix choisie, puis lance l'action « 6 » en mode **voix** (ou vous : mode **voix**, essai **non**).
2. Attendez la coche verte (quelques minutes). La voix est poussée sur la branche `voix-demonstration`.
3. Dites à Claude **« la voix est prête »** : il l'écoute (durées, taille), la teste dans l'application, puis
   publie la nouvelle version.

**Si l'action échoue avec « HTTP 429 » (quota)** : la synthèse vocale gratuite est limitée par jour. Soit
relancez le lendemain, soit activez la facturation : Google Cloud → projet Zero Perte → **Facturation** →
associer un moyen de paiement (la fabrication complète coûte quelques centimes). Avec la facturation active,
Google n'utilise pas vos textes pour améliorer ses produits.

**Réglages facultatifs** (GitHub → Settings → Secrets and variables → Actions → onglet **Variables**) :
`ZP_VOIX_NOM` (nom d'une autre voix Gemini, par défaut `Sulafat`, voix féminine chaleureuse) et
`ZP_VOIX_MODELE` (autre modèle de synthèse vocale).

**Secours OpenAI (facultatif)** : si vous avez un compte OpenAI, créez une clé sur
**platform.openai.com/api-keys** et rangez-la comme secret **`ZP_CLE_VOIX_SECOURS`** : elle sert seulement si
Gemini échoue.
