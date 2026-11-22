# Ce que vous devez faire vous-même, dans l'ordre

Tout le reste est prêt dans l'application.

Le guide détaillé, avec chaque bouton, est `docs/etapes-proprietaire.md` (sur GitHub : dépôt zero-perte → dossier `docs`).

Rien de ceci n'est un secret, **sauf** le fichier `.json` de Firebase (étape 2c). Ne l'envoyez à personne, même pas à moi.

## 1. Cloudflare — alertes graves en moins d'une minute — ✅ FAIT (22 novembre 2026)

✅ Relais `https://zero-perte-relais.academyjoseph71.workers.dev` en service, vérifié. Reste seulement l'essai 7 ci-dessous sur 2 vrais téléphones.

Guide : partie **B**. Les menus sont ceux de novembre 2026, en anglais.

1. **Créer le compte** : https://dash.cloudflare.com/sign-up → compte gratuit → confirmer l'adresse e-mail.
2. **Créer l'espace de stockage** : **Storage & databases** → **Workers KV** → **Create instance** → nom `ALERTES`.
3. **Créer le relais** :
   - **Compute (Workers)** → **Workers & Pages** → **Create application** → **Start with Hello World!** → nom `zero-perte-relais` → **Deploy**.
   - **Edit Code** → effacer le code → coller le fichier https://github.com/ahiankonoujoseph102-wq/zero-perte/blob/main/relais/worker.js (bouton « Copy raw file ») → **Deploy**.
4. **Relier le stockage** : onglet **Bindings** → **Add binding** → **KV namespace** → « Variable name » `ALERTES`, espace `ALERTES` → **Add Binding**.
5. **Donner l'adresse à GitHub** :
   - noter l'adresse `https://zero-perte-relais.….workers.dev` (onglet **Settings** → **Domains & Routes**) ;
   - GitHub → **Settings** → **Secrets and variables** → **Actions** → **Variables** → **New repository variable** → nom `ZP_RELAIS_URL`, valeur = l'adresse, sans « / » à la fin.
   - Lien direct : https://github.com/ahiankonoujoseph102-wq/zero-perte/settings/variables/actions
6. **Relancer la fabrication** : https://github.com/ahiankonoujoseph102-wq/zero-perte/actions/workflows/fabriquer-apk.yml → **Run workflow** → branche `main`. Cela publie une nouvelle version avec le relais branché.
7. **Vérifier** : un vendeur ferme la caisse avec 2 000 F de moins → dans la minute, bandeau rouge chez le patron (application ouverte).

## 2. Firebase — notifications même application fermée — ✅ FAIT (22 novembre 2026)

✅ Version `v0.34.0-n101` avec Firebase et le relais. Reste seulement l'essai 5 ci-dessous sur 2 vrais téléphones.

Guide : partie **F**. À faire **après** Cloudflare : le relais envoie les notifications.

1. https://console.firebase.google.com → **Ajouter un projet** → choisir le projet **Zero Perte** existant → sans Google Analytics.
2. **Ajouter l'application Android** :
   - a. nom du package `tg.zeroperte.app` → **Enregistrer** (ne pas télécharger `google-services.json`) ;
   - b. noter 4 valeurs : ID d'application, Clé API Web, ID du projet, ID de l'expéditeur (onglet Cloud Messaging). Les mettre en **Variables** GitHub : `ZP_FIREBASE_APPLI`, `ZP_FIREBASE_CLE`, `ZP_FIREBASE_PROJET`, `ZP_FIREBASE_EXPEDITEUR` (même lien qu'en 1.5) ;
   - c. **Paramètres du projet** → **Comptes de service** → **Générer une nouvelle clé privée** → fichier `.json`. **SECRET.**
3. **Donner la clé au relais** : Cloudflare → `zero-perte-relais` → **Settings** → **Variables and Secrets** → **+ Add** → Type **Secret**, nom `FCM_COMPTE`, valeur = tout le contenu du fichier `.json` → **Deploy**. Effacez ensuite le fichier de votre téléphone.
4. **Relancer la fabrication** (même lien qu'en 1.6). Sur le téléphone du patron : ouvrir l'application en patron → **Autoriser les notifications**.
5. **Vérifier**, application du patron fermée :
   - caisse fermée avec 2 000 F de moins → notification « Zéro Perte : alerte » ;
   - puis une deuxième notification, « Zéro Perte : résumé du soir ».

## 3. Microsoft Store — supprime le message « Windows a protégé votre ordinateur » (facultatif, gratuit)
Guide : partie **E**. Il faut un **PC**. La vérification de Microsoft prend 1 à 3 jours.

1. https://storedeveloper.microsoft.com → **Get started** → compte Microsoft → type **Individual developer** → vérification d'identité.
2. **Réserver le nom** : https://partner.microsoft.com/dashboard → **Apps and games** → **New product** → **MSIX or PWA app** → nom `Zéro Perte` → **Reserve**.
3. **Product management** → **Product identity** → noter 3 valeurs et les mettre en **Variables** GitHub :
   - `ZP_MSIX_IDENTITE`
   - `ZP_MSIX_EDITEUR`
   - `ZP_MSIX_EDITEUR_NOM`
4. **Relancer la fabrication** (lien 1.6), puis télécharger l'artefact `ZeroPerte-Store-…` (en bas de la page de la fabrication) → `ZeroPerte-Store.msix`.
5. Partner Center → **Start your submission** :
   - gratuit ;
   - catégorie **Business** ;
   - âges : « non » partout ;
   - déposer le `.msix` ;
   - une description et des captures (je les fournis sur demande) → **Submit to the Store**.

## Aussi à faire (rappel)
- **Essai A5** : connecter le compte Google de la boutique sur un vrai téléphone puis sur le PC (partie A5).
- **Valider les guides** de mise en service (`docs/mise-en-service/`) et faire l'**essai avant le premier client** (`essai-avant-premier-client.md`).
- **Répondre à la question (a)/(b)** du rapport 0.33.0 : taille de la base sur l'appareil. Je recommande (a).
- **Plus tard** : à **50 boutiques**, me demander de revoir le relais (limites gratuites de Cloudflare pour tout le compte).
