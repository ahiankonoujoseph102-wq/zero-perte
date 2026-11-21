#!/usr/bin/env bash
# Crée la clé de signature de Zéro Perte et produit un fichier CHIFFRÉ, hors du dépôt.
#
# Utilisé par le workflow « 1 - Créer la clé de signature » (puis le fichier chiffré est
# rangé dans les secrets GitHub et dans le dépôt privé « coffre » du propriétaire) et par
# la fabrication d'essai (clé jetable). Ne jamais lancer ce script avec un vrai mot de
# passe tapé dans un terminal partagé ou une conversation.
# Le dépôt est PUBLIC : ce script refuse d'écrire dans le dépôt, même un fichier chiffré.
#
# Entrées (variables d'environnement) :
#   ZP_SIGNATURE_MOT_DE_PASSE  mot de passe choisi par le propriétaire (secret GitHub)
# Argument :
#   $1  chemin du fichier chiffré à créer, HORS du dépôt (ex. $RUNNER_TEMP/zp/cle.chiffre)
#
# La clé en clair n'existe que dans un dossier temporaire privé, effacé à la fin.
# Rien de secret n'est affiché : seules les empreintes publiques du certificat le sont.
set -euo pipefail

SORTIE="${1:?Indiquez le fichier chiffré à créer}"
ALIAS="zeroperte"
ITERATIONS=600000

if [ -z "${ZP_SIGNATURE_MOT_DE_PASSE:-}" ]; then
  echo "::error::Le secret ZP_SIGNATURE_MOT_DE_PASSE n'existe pas. Créez-le d'abord (voir les instructions)."
  exit 1
fi
if [ "${#ZP_SIGNATURE_MOT_DE_PASSE}" -lt 16 ]; then
  echo "::error::Le mot de passe est trop court : il faut au moins 16 caractères. Remplacez le secret ZP_SIGNATURE_MOT_DE_PASSE."
  exit 1
fi
DEPOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
case "$(realpath -m "$SORTIE")" in
  "$(realpath -m "$DEPOT")"/*)
    echo "::error::Refus : le dépôt est public, la clé (même chiffrée) ne doit jamais y être écrite."
    exit 1 ;;
esac
if [ -e "$SORTIE" ]; then
  echo "::error::Une clé existe déjà ($SORTIE). Par sécurité, elle ne sera JAMAIS remplacée automatiquement."
  exit 1
fi

TMP="$(mktemp -d)"
chmod 700 "$TMP"
trap 'find "$TMP" -type f -exec shred -u {} + 2>/dev/null || true; rm -rf "$TMP"' EXIT

# 1. Génération de la clé (RSA 4096, valable 100 ans). Le mot de passe est lu depuis
#    l'environnement (-storepass:env), il n'apparaît donc jamais dans la ligne de commande.
keytool -genkeypair -noprompt \
  -storetype PKCS12 \
  -keystore "$TMP/cle.p12" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 36500 \
  -dname "CN=Zero Perte, O=Zero Perte, C=TG" \
  -storepass:env ZP_SIGNATURE_MOT_DE_PASSE \
  -keypass:env ZP_SIGNATURE_MOT_DE_PASSE >/dev/null 2>&1

# 2. Chiffrement AES-256 avec une clé dérivée du mot de passe (PBKDF2, 600 000 tours).
mkdir -p "$(dirname "$SORTIE")"
openssl enc -aes-256-cbc -pbkdf2 -iter "$ITERATIONS" -salt \
  -pass env:ZP_SIGNATURE_MOT_DE_PASSE \
  -in "$TMP/cle.p12" -out "$SORTIE"

# 3. Vérification : on déchiffre la copie et on vérifie qu'elle est identique et lisible.
openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITERATIONS" \
  -pass env:ZP_SIGNATURE_MOT_DE_PASSE \
  -in "$SORTIE" -out "$TMP/verif.p12"
cmp -s "$TMP/cle.p12" "$TMP/verif.p12" || { echo "::error::La vérification du chiffrement a échoué."; rm -f "$SORTIE"; exit 1; }
keytool -list -keystore "$TMP/verif.p12" -storetype PKCS12 \
  -storepass:env ZP_SIGNATURE_MOT_DE_PASSE -alias "$ALIAS" >/dev/null

# 4. Empreintes PUBLIQUES du certificat (utiles plus tard pour Google Cloud). Rien de secret.
echo "Clé créée et chiffrée (fichier temporaire hors du dépôt)."
keytool -list -v -keystore "$TMP/verif.p12" -storetype PKCS12 \
  -storepass:env ZP_SIGNATURE_MOT_DE_PASSE -alias "$ALIAS" 2>/dev/null \
  | grep -E "SHA1:|SHA256:" | sed 's/^[[:space:]]*/Empreinte publique /'
