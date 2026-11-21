#!/usr/bin/env bash
# Déchiffre la clé de signature dans un dossier temporaire, pour la fabrication de l'APK.
#
# Entrées (variables d'environnement) :
#   ZP_SIGNATURE_MOT_DE_PASSE  mot de passe (secret GitHub)
# Arguments :
#   $1  fichier chiffré (ex. signature/cle-signature.p12.chiffre)
#   $2  fichier en clair à créer, dans un dossier temporaire (jamais dans le dépôt)
set -euo pipefail

ENTREE="${1:?Fichier chiffré manquant}"
SORTIE="${2:?Fichier de sortie manquant}"

DEPOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
case "$(realpath -m "$SORTIE")" in
  "$(realpath -m "$DEPOT")"/*)
    echo "::error::Refus : la clé en clair ne doit jamais être écrite dans le dépôt."
    exit 1 ;;
esac

umask 077
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
  -pass env:ZP_SIGNATURE_MOT_DE_PASSE \
  -in "$ENTREE" -out "$SORTIE" 2>/dev/null || {
  rm -f "$SORTIE"
  echo "::error::Impossible de déchiffrer la clé : le secret ZP_SIGNATURE_MOT_DE_PASSE ne correspond pas à la clé enregistrée."
  exit 1
}
keytool -list -keystore "$SORTIE" -storetype PKCS12 \
  -storepass:env ZP_SIGNATURE_MOT_DE_PASSE -alias zeroperte >/dev/null 2>&1 || {
  rm -f "$SORTIE"
  echo "::error::La clé déchiffrée est illisible."
  exit 1
}
echo "Clé de signature prête (dossier temporaire)."
