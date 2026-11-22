# Licences des éléments tiers

## Voix de la démonstration guidée (voix générée par intelligence artificielle)

La voix d'Afi (fichiers `assets/demo/voix/*.mp3`) est fabriquée **une seule fois** par l'action
« 6 - Fabriquer la voix de la démonstration », avec un service d'intelligence artificielle :

| Service | Utilisation | Conditions (vérifiées le 21 novembre 2026) |
|---|---|---|
| **Google Gemini API** (synthèse vocale), premier choix | clé `ZP_CLE_VOIX` | *Gemini API Additional Terms of Service* : Google ne revendique pas la propriété du contenu original généré ; l'utilisateur est responsable de l'usage du contenu et doit respecter la loi et la *Generative AI Prohibited Use Policy* (pas de contenu trompeur présenté comme humain). Usage commercial permis. Avec un compte de facturation actif (« Paid Services »), Google n'utilise pas les textes envoyés pour améliorer ses produits ; en gratuit, ils peuvent l'être (ici le texte est public : `docs/demo/texte-voix.md`). |
| **OpenAI** (`gpt-4o-mini-tts`), secours | clé `ZP_CLE_VOIX_SECOURS` (ou `ZP_CLE_VOIX` commençant par `sk-`) | *Service Terms* / *Usage Policies* : le client possède les sorties ; il **doit indiquer clairement aux utilisateurs que la voix est générée par IA**. Usage commercial permis. |

**Mention affichée** : dès que les fichiers de voix sont présents, la démonstration affiche sous les sous-titres
« Voix générée par intelligence artificielle » (exigée par OpenAI, conforme aux règles de Google). La voix est
celle d'une voix prédéfinie du service, **pas** le clone d'une personne réelle ; le personnage d'Afi est un dessin
original de l'application. Le service utilisé, le modèle, la voix et la date sont écrits dans
`assets/demo/voix/bouches.json`.

Sans ces fichiers, la démonstration utilise la voix de synthèse installée sur l'appareil (Android ou Windows).

## Police

- **Atkinson Hyperlegible** (Braille Institute of America) — SIL Open Font License 1.1.

## Bibliothèques Flutter / Dart principales

- Flutter et le SDK Dart — licence BSD 3 clauses (Google).
- `sqflite`, `sqflite_common_ffi`, `path_provider`, `path`, `url_launcher`, `image_picker`, `file_selector`,
  `package_info_plus`, `google_sign_in`, `flutter_tts`, `crypto`, `cryptography`, `qr`, `msix` — licences BSD ou MIT
  (voir pub.dev pour chaque paquet).
- SQLite — domaine public.
- `com.google.firebase:firebase-messaging` (Android) — Apache 2.0.
- `com.google.android.gms:play-services-code-scanner` (Android, lecteur de QR code) — conditions du SDK
  Android / Google Play services.
