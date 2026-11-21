# Zéro Perte — La clé de signature

*Étape A1, 21 novembre 2026.*

## À quoi elle sert

Android n'accepte une mise à jour que si elle est **signée avec la même clé** que la version déjà installée.

> **Perdre cette clé = ne plus jamais pouvoir mettre à jour l'application chez les clients.** Ils devraient tout désinstaller et perdre leurs données locales.

## Les règles

1. **Personne ne voit jamais la clé en clair** : ni le propriétaire, ni le chef de projet, ni Claude. Elle n'apparaît ni dans le dépôt ni dans les journaux.
2. **Le mot de passe n'est jamais écrit dans une conversation** (WhatsApp, Claude, e-mail…). Le propriétaire le tape **seulement** dans les « secrets » de GitHub, et le garde **sur papier**.
3. La clé n'existe **qu'en version chiffrée** :
   - dans le dépôt : `signature/cle-signature.p12.chiffre` ;
   - dans le Google Drive du propriétaire (copie de secours).
4. Le workflow de création **refuse de remplacer** une clé existante.

## Comment ça marche

| Étape | Qui | Quoi |
|---|---|---|
| 1 | Propriétaire | Choisit un mot de passe d'**au moins 16 caractères**, l'écrit **sur papier (2 copies)** et le tape dans le secret GitHub `ZP_SIGNATURE_MOT_DE_PASSE`. |
| 2 | Propriétaire | Lance le workflow **« 1 - Créer la clé de signature (une seule fois) »** en écrivant `OUI`. |
| 3 | GitHub Actions | Crée la clé (RSA 4096 bits, valable 100 ans) dans un dossier temporaire, la **chiffre** (AES-256, clé dérivée du mot de passe par PBKDF2 avec 600 000 tours), vérifie le chiffrement, enregistre **seulement le fichier chiffré** dans le dépôt, puis efface le dossier temporaire. |
| 4 | GitHub Actions | Met à disposition une **copie de secours chiffrée** à télécharger, puis relance la fabrication de l'APK officiel. |
| 5 | Propriétaire | Télécharge la copie de secours et la range dans son **Google Drive**. |
| Ensuite | GitHub Actions | À chaque fabrication : déchiffre la clé dans un dossier temporaire **hors du dépôt**, signe les APK, puis l'**efface**. |

## Où sont les morceaux (pour retrouver la clé)

| Morceau | Où | Suffit seul ? |
|---|---|---|
| Fichier chiffré | Dépôt GitHub + Google Drive du propriétaire | ❌ Inutilisable sans le mot de passe |
| Mot de passe | Secret GitHub (impossible à relire) + **papier du propriétaire** | ❌ Inutile sans le fichier |

Un voleur qui trouverait l'un des deux morceaux **ne pourrait rien faire**. Il faut les deux.

## Si quelque chose arrive

| Situation | Que faire |
|---|---|
| Le secret GitHub a été effacé par erreur | Recréer le secret `ZP_SIGNATURE_MOT_DE_PASSE` avec le **mot de passe du papier**. |
| Le dépôt GitHub est perdu | Créer un nouveau dépôt avec le code, y remettre le fichier chiffré de Google Drive dans `signature/`, puis recréer le secret avec le mot de passe du papier. |
| Le papier est perdu, mais le secret GitHub existe toujours | La fabrication continue de marcher. Il faut tout de même **écrire un nouveau papier**, mais on ne peut pas relire le secret. Il faut donc faire changer le mot de passe par une procédure de rechiffrement (à demander au développeur), **sans jamais afficher la clé**. |
| Papier **et** secret perdus | ❌ La clé est **perdue définitivement**. C'est pourquoi il faut **2 copies papier**, rangées dans 2 endroits différents. |
