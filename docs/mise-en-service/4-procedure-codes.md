# Codes d'activation — fabrication et envoi

Un code = une boutique (**licence**, 2 appareils par défaut) ou des appareils en plus (**extension**).
Le code est **signé** : impossible à inventer ou à modifier. Il n'expire pas.

## Fabriquer un code (depuis le téléphone, 2 minutes)
1. GitHub → dépôt **zero-perte** → **Actions** → **« 4 - Générer un code d'activation »** → **Run workflow**.
2. Remplir :
   - **Nom de la boutique** : exactement celui que le patron verra (ex. « Boutique Mama Ama »).
   - **type** : `licence` (nouvelle boutique) ou `extension` (appareil en plus).
   - **Nombre d'appareils** : téléphones + tablettes + PC (2 pour une licence, 1 pour une extension).
   - **boutique_id** : seulement pour une extension (identifiant `bq-…` lu dans le registre).
3. **Run workflow**, attendre la coche verte (1 à 2 minutes). Le journal de l'action ne montre ni le nom
   ni le code (c'est voulu).

## Récupérer et envoyer
1. Dépôt **privé** `zero-perte-coffre` → dossier `codes/` → le fichier du jour : il contient le **message
   prêt** (bonjour, le code, comment l'activer).
2. Copier tout le message → WhatsApp du patron → **Envoyer**.
3. Le **registre** `registre-clients.csv` (même coffre) garde une ligne par code : date, boutique, type,
   appareils, identifiant. Ne jamais le partager.

## Règles
- Un code par boutique. Ne pas réutiliser un code pour une autre boutique.
- Code perdu par le patron : renvoyer **le même message** (il est dans `codes/`).
- Si l'action échoue avec « clé des licences » ou « coffre inaccessible » : prévenir le propriétaire
  (secrets `ZP_CLE_LICENCES` / `ZP_JETON_CODES`, parties C du guide du propriétaire). **Ne jamais copier
  une clé dans une conversation.**
