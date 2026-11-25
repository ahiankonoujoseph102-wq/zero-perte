# Licences des éléments tiers

## Voix de la démonstration (retirée de l'application en 0.37.0)

Depuis la version 0.37.0, l'application **ne contient plus** de démonstration ni de voix générée par
intelligence artificielle (décision du propriétaire, 24 novembre 2026). L'action GitHub « 6 - Fabriquer la voix
de la démonstration » est gardée telle quelle : si elle est relancée, elle range ses fichiers dans
`assets/demo/voix/`, qui n'est **plus** mis dans l'application (pubspec.yaml ne le déclare plus). Les conditions
des services qu'elle utilise (Google Gemini API, OpenAI `gpt-4o-mini-tts` en secours) restent décrites dans
l'historique de ce fichier (version 0.36.0). Le bouton « Écouter » de l'installation utilise la voix de
synthèse de l'appareil (Android ou Windows), sans service extérieur.

## Lecteur de QR code de secours (0.37.1)

- **ZXing Android Embedded** (JourneyApps) et **ZXing core** — licence Apache 2.0. Utilisé seulement si le lecteur
  de QR code des Services Google Play ne peut pas s'ouvrir. Il utilise l'appareil photo (autorisation demandée
  au moment du scan).

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
