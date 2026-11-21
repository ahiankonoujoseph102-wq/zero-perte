# Zéro Perte

Application Android de gestion pour les boutiques et commerçants du Togo
(identifiant `tg.zeroperte.app`, Android 8 minimum, Flutter).

## Documents
- `docs/analyse.md` — analyse de départ et critique du plan
- `docs/decision-serveur.md` — architecture à 0 F (Drive de chaque boutique, Cloudflare)
- `docs/plan-v1.md` — ordre des étapes de la version 1
- `docs/categories.md` — types de boutiques et unités de vente
- `docs/cle-de-signature.md` — clé de signature : création, sauvegarde, récupération

## Télécharger l'application
- **Dernière version officielle** (à envoyer par WhatsApp) :
  https://github.com/ahiankonoujoseph102-wq/zero-perte/releases/latest/download/ZeroPerte.apk
- Toutes les versions : https://github.com/ahiankonoujoseph102-wq/zero-perte/releases

## Fabrication des APK (GitHub Actions)
- **« 2 - Fabriquer l'APK »** : à chaque modification. Il produit :
  - `ZeroPerte.apk`, l'**APK universel** (32 et 64 bits), pour la **première installation par WhatsApp** ;
  - `ZeroPerte-arm64.apk` et `ZeroPerte-armv7.apk`, pour les **mises à jour automatiques** ;
  - `version.json`, lu par l'application.

  Sur `main`, tout est publié dans une **Release GitHub**.
- **« 1 - Créer la clé de signature (une seule fois) »** : crée la clé officielle. Elle est rangée **uniquement dans les secrets GitHub**, jamais dans ce dépôt public. Voir `docs/cle-de-signature.md`.
  Tant qu'elle n'existe pas, les APK sont des **versions d'essai** (bandeau rouge, « pré-versions ») à ne pas distribuer.

## Sécurité (dépôt public)
Aucun secret n'est enregistré dans ce dépôt : ni clé, ni mot de passe, ni données de clients.
Les secrets sont dans les « secrets » GitHub ou dans le dépôt privé du propriétaire.
