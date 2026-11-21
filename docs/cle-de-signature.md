# Zéro Perte — La clé de signature

*Étape A1, mise à jour le 21 novembre 2026 : le dépôt est désormais **public**.*

## À quoi elle sert

Android n'accepte une mise à jour que si elle est **signée avec la même clé** que la version déjà installée.

> **Perdre cette clé = ne plus jamais pouvoir mettre à jour l'application chez les clients.** Ils devraient tout désinstaller et perdre leurs données locales.

## Les règles

1. **La clé n'est JAMAIS enregistrée dans le dépôt, même chiffrée**, puisque tout le monde peut lire un dépôt public. Les scripts refusent d'ailleurs d'y écrire.
2. **Personne ne voit jamais la clé en clair** : ni le propriétaire, ni le chef de projet, ni Claude. Elle n'existe en clair que quelques minutes, dans un dossier temporaire de la machine GitHub, effacé ensuite.
3. **Le mot de passe n'est jamais envoyé à personne** (WhatsApp, Claude, chef de projet, e-mail…). Le propriétaire le tape **seulement** dans les « secrets » de GitHub, et le garde **sur 2 papiers**.
4. **Les journaux des workflows sont publics** : aucune valeur secrète n'y est affichée. GitHub masque les secrets, les autres valeurs sensibles sont masquées par le workflow, et aucune commande n'affiche son contenu.
5. Le workflow de création **refuse de remplacer** une clé existante.

## Où sont les morceaux

| Morceau | Où | Qui peut le voir | Suffit seul ? |
|---|---|---|---|
| Clé **chiffrée** (pour fabriquer) | Secret GitHub `ZP_CLE_SIGNATURE` | Personne (illisible, même par le propriétaire) | ❌ |
| Clé **chiffrée** (copie de secours) | Dépôt **privé** `zero-perte-coffre` + Google Drive du propriétaire | Le propriétaire seul | ❌ |
| Mot de passe | Secret GitHub `ZP_SIGNATURE_MOT_DE_PASSE` (illisible) + **2 papiers** | Le propriétaire seul | ❌ |

Il faut **la clé chiffrée ET le mot de passe** pour signer. Un voleur qui trouverait un seul des deux ne pourrait rien faire.

## Pourquoi un dépôt privé « coffre » ?

Dans un dépôt public, les fichiers joints aux fabrications (les « artefacts ») sont **téléchargeables par n'importe quel compte GitHub**. Ils ne sont donc pas « visibles seulement par le propriétaire ».

Un dépôt **privé** ne contenant que la copie chiffrée est vraiment personnel. Il ne coûte rien, car on n'y lance aucune fabrication. Depuis ce coffre, le propriétaire range aussi une copie dans son Google Drive.

## Le jeton temporaire `ZP_JETON_COFFRE`

Le jeton automatique d'un workflow (`GITHUB_TOKEN`) **ne peut pas écrire de secret** : c'est une protection de GitHub. Pour ranger la clé dans les secrets, le propriétaire crée donc **une seule fois** un jeton :
- **limité** : seulement les dépôts `zero-perte` (permission « Secrets ») et `zero-perte-coffre` (permission « Contents ») ;
- **valable 7 jours** ;
- **supprimé** dès que la clé est créée.

## Comment ça marche

| Étape | Qui | Quoi |
|---|---|---|
| 1 | Propriétaire | Crée le secret `ZP_SIGNATURE_MOT_DE_PASSE` (au moins 16 caractères, écrit sur 2 papiers). |
| 2 | Propriétaire | Crée le dépôt privé `zero-perte-coffre`. |
| 3 | Propriétaire | Crée le jeton limité, puis le secret `ZP_JETON_COFFRE`. |
| 4 | Propriétaire | Lance le workflow **« 1 - Créer la clé de signature (une seule fois) »** en écrivant `OUI`. |
| 5 | GitHub Actions | Vérifie que le coffre est **privé**, crée la clé (RSA 4096 bits, valable 100 ans) dans un dossier temporaire et la **chiffre** (AES-256, PBKDF2, 600 000 tours). Il range la copie de secours dans le coffre, puis la clé chiffrée dans le secret `ZP_CLE_SIGNATURE`, efface tout et relance la fabrication. |
| 6 | Propriétaire | Télécharge la copie depuis le coffre vers son **Google Drive**, puis **supprime le jeton**. |
| Ensuite | GitHub Actions | À chaque fabrication : déchiffre la clé dans un dossier temporaire hors du dépôt, signe les APK, puis l'**efface**. |

## Si quelque chose arrive

| Situation | Que faire |
|---|---|
| Le secret `ZP_CLE_SIGNATURE` a été effacé | Copier le contenu de la copie de secours du coffre dans un nouveau secret `ZP_CLE_SIGNATURE`. Le contenu est déjà en texte (base64), une procédure guidée sera fournie. |
| Le secret du mot de passe a été effacé | Le recréer avec le **mot de passe du papier**. |
| Le compte ou le dépôt GitHub est perdu | Nouveau dépôt avec le code, puis recréer les deux secrets à partir de la copie Google Drive et du papier. |
| Papier perdu, secret toujours là | La fabrication continue. Faire changer le mot de passe par une procédure de rechiffrement (à demander), **sans jamais afficher la clé**. |
| Papier **et** secret du mot de passe perdus | ❌ Clé **perdue définitivement**. D'où les **2 copies papier** dans 2 endroits différents. |
