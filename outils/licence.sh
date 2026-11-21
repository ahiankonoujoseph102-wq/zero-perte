#!/usr/bin/env bash
# Licences Zéro Perte (signature Ed25519 avec OpenSSL 3).
#
#   licence.sh creer-cle <dossier>
#       Crée une paire de clés : <dossier>/cle_privee.pem (SECRÈTE, droits 600)
#       et <dossier>/cle_publique.txt (32 octets en base64 : à mettre dans l'application).
#   licence.sh signer <cle_privee.pem> <fichier_charge.json>
#       Affiche le code d'activation « ZP1.<charge>.<signature> » (base64url, sans « = »).
#
# Le dépôt est PUBLIC : ce script refuse d'écrire une clé privée dans le dépôt.
set -euo pipefail

b64url() { base64 -w0 | tr '+/' '-_' | tr -d '='; }

DEPOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
hors_depot() {
  case "$(realpath -m "$1")" in
    "$(realpath -m "$DEPOT")"/*) echo "::error::Refus : une clé privée ne doit jamais être écrite dans le dépôt." >&2; exit 1 ;;
  esac
}

case "${1:-}" in
  creer-cle)
    DOSSIER="${2:?dossier manquant}"
    hors_depot "$DOSSIER/cle_privee.pem"
    mkdir -p "$DOSSIER"
    umask 077
    openssl genpkey -algorithm ed25519 -out "$DOSSIER/cle_privee.pem" 2>/dev/null
    openssl pkey -in "$DOSSIER/cle_privee.pem" -pubout -outform DER 2>/dev/null \
      | tail -c 32 | base64 -w0 > "$DOSSIER/cle_publique.txt"
    ;;
  signer)
    CLE="${2:?clé privée manquante}"
    CHARGE="${3:?charge manquante}"
    SIG="$(mktemp)"
    trap 'rm -f "$SIG"' EXIT
    openssl pkeyutl -sign -inkey "$CLE" -rawin -in "$CHARGE" -out "$SIG" 2>/dev/null
    printf 'ZP1.%s.%s\n' "$(b64url < "$CHARGE")" "$(b64url < "$SIG")"
    ;;
  *)
    echo "Usage : $0 creer-cle <dossier> | signer <cle_privee.pem> <charge.json>" >&2
    exit 2
    ;;
esac
