# Ajout d'un vendeur par QR code — conception (version 0.35)

Validée par le propriétaire le 22 novembre 2026.

## Parcours
- **Patron** : accueil (ou Gestion) → **Ajouter mon vendeur** → prénom → accord Google (un toucher
  « Continuer », compte de la boutique déjà sur son téléphone) → **QR code** (10 minutes, une seule fois).
  Le bouton de l'accueil n'apparaît que s'il reste de la place dans la licence ; Gestion l'a toujours.
- **Vendeur** : premier écran → **Je suis vendeur** → **Scanner le QR code** (lecteur de Google Play
  services, aucune autorisation d'appareil photo) → la boutique arrive → son **code à 4 chiffres** s'affiche.
  Aucun compte Google ni mot de passe sur son téléphone.
- **Code de secours** (8 chiffres), caché derrière « Pas d'appareil photo ? » : le vendeur tape le code, le
  patron voit « Un téléphone veut entrer : <modèle> » et répond **OUI** ou **NON**.
- **Mes appareils** (Gestion) : liste, **Retirer**, **Couper tous les vendeurs**.
- L'ancien parcours (compte Google, fichier de sauvegarde) reste sous **Autres façons**.

## Fonctionnement
1. Le téléphone du patron demande à Google un **code d'échange** (`serverAuthCode`, un seul usage, quelques
   minutes) pour l'identifiant « Application Web », autorisation `drive.appdata` seulement.
2. Le relais (`/google/echange`) l'échange contre un **jeton de longue durée** avec le code secret
   `GOOGLE_WEB_SECRET`, qui n'existe que dans Cloudflare. Le relais n'enregistre pas le jeton.
3. Le patron crée le vendeur (code tiré au hasard), synchronise, puis range dans un **paquet chiffré**
   (AES-256-GCM) : jeton long, jeton du relais, compte, vendeur et son code, identifiant d'invitation.
4. QR code = `ZP1` + boîte (16 octets au hasard) + clé (32 octets). Le paquet est déposé sur le relais
   (`PUT /boite/<id>`) ; le relais le garde 10 minutes au plus et l'efface à la **première lecture**.
5. Le vendeur prend le paquet, l'ouvre, se relie au Drive (accès d'une heure demandé à `/google/acces`),
   récupère la boutique et s'inscrit avec l'identifiant d'invitation et l'**empreinte** SHA-256 de son jeton.
6. Code de secours : boîte = SHA-256 du code ; le vendeur envoie une clé publique X25519 (`POST /demande`,
   refusé si le patron n'attend pas ce code) ; après le OUI, le patron chiffre le paquet pour CETTE clé.

## Sécurité
- Aucun secret dans l'APK, dans le QR code ni sur le relais en clair. Mot de passe jamais demandé.
- **Une seule fois** : effacement à la lecture (relais) + contrôle dans le Drive (un seul appareil par
  identifiant d'invitation).
- **10 minutes** : heure de fin gardée par le relais, contrôlée à chaque lecture.
- **Licence** : contrôlée par le patron avant l'accord Google, puis à l'inscription du vendeur. Les appareils
  retirés ne comptent plus. Exception : refaire le QR code d'un vendeur dont le téléphone est déjà dans la
  liste (même téléphone ; un autre téléphone est refusé à son arrivée).
- **Retirer** : empreinte du jeton mise sur liste noire du relais (plus d'accès au plus tard ~1 h 10 :
  accès d'une heure déjà donné + mémoire de 10 minutes), fichier `retrait-<id>.json` dans le Drive (licence
  libérée ; opérations faites après le retrait refusées par tous les appareils) ; le téléphone retiré est
  **bloqué** (l'historique local n'est pas effacé : la base l'interdit ; désinstaller pour le réutiliser).
- **Couper tous** : nouvel accord Google → annulation chez Google (tous les jetons longs) + retrait de tous
  les téléphones ajoutés par QR code. Leurs ventes non envoyées sont perdues (dit dans la confirmation).
- **Accès coupé par Google** (autorisation annulée ailleurs, 6 mois sans usage) : le vendeur continue de
  vendre, bandeau « refaire un QR code » ; le nouveau QR garde le même téléphone et ses ventes.
- **Sans réseau** : le vendeur vend toujours ; ses ventes partent à la synchronisation suivante.

## Coût (offre gratuite Cloudflare)
Par ajout : 1 à 4 écritures KV ; accès Drive : environ 24 demandes par jour et par téléphone vendeur ;
liste noire lue au plus toutes les 10 minutes par appareil (mémoire Cloudflare).

## Réglages du propriétaire
`docs/etapes-proprietaire.md`, partie I : identifiant « Application Web » sans adresse, secrets Cloudflare
`GOOGLE_WEB_ID` et `GOOGLE_WEB_SECRET`, nouveau `relais/worker.js`.
