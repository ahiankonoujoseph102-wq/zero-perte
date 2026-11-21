# Zéro Perte

Application Android de gestion pour les boutiques et commerçants du Togo
(identifiant `tg.zeroperte.app`, Android 8 minimum, Flutter).

## Documents
- `docs/analyse.md` — analyse de départ et critique du plan
- `docs/decision-serveur.md` — architecture à 0 F (Drive de chaque boutique, Cloudflare)
- `docs/plan-v1.md` — ordre des étapes de la version 1
- `docs/categories.md` — types de boutiques et unités de vente
- `docs/cle-de-signature.md` — clé de signature : création, sauvegarde, récupération

## Fabrication des APK (GitHub Actions)
- **« 2 - Fabriquer l'APK »** : à chaque modification. Il produit :
  - l'**APK universel** (32 et 64 bits) pour la **première installation par WhatsApp** ;
  - les **APK par processeur** (arm64, armv7) pour les **mises à jour automatiques**.
  Sur la branche `main`, les APK sont publiés dans une « Release » GitHub, téléchargeable depuis un téléphone.
- **« 1 - Créer la clé de signature (une seule fois) »** : crée la clé officielle, chiffrée.
  Tant qu'elle n'existe pas, les APK sont des **versions d'essai** (bandeau rouge) à ne pas distribuer.
