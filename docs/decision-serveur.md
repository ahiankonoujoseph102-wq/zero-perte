# Zéro Perte — Décision serveur : une architecture à 0 F pour le propriétaire

*Mission 2, 21 novembre 2026. Aucun code n'a été écrit.*

**Contrainte non négociable :** le commerçant paie une seule fois. Le propriétaire ne paie **aucun** serveur, ni aujourd'hui ni avec des milliers de boutiques. Le patron doit quand même pouvoir suivre sa boutique à distance.

---

## 0. La recommandation en bref

> **Chaque boutique utilise son propre espace Google Drive gratuit, dans le dossier caché réservé à l'application (« appDataFolder »), via un compte Google dédié à la boutique.** Le téléphone du vendeur et celui du patron se connectent au même compte. Chacun y dépose son journal d'opérations et lit celui de l'autre.
>
> - **Coût pour le propriétaire : 0 F.** Le stockage appartient au compte de la boutique (15 Go gratuits). La consommation augmente avec le nombre de boutiques, mais elle est **répartie sur leurs comptes**, pas sur le nôtre.
> - Ce même Drive sert de **sauvegarde** : un téléphone perdu se restaure en se connectant au compte.
> - Le **code d'activation est signé** et vérifié sans Internet. Les **mises à jour** sont publiées dans un **dépôt GitHub public qui ne contient que les APK** (le code reste privé).
> - **Option gratuite, plus tard :** un petit relais Cloudflare (offre gratuite) pour les **alertes urgentes instantanées** (notification « push »). Le petit volume de messages tient dans l'offre gratuite jusqu'à plusieurs milliers de boutiques.

Il n'y a aucune base de données centrale à nous, aucune carte bancaire enregistrée, et donc **aucune facture possible**. Si un quota gratuit est dépassé, le service ralentit ou refuse les requêtes, mais rien n'est facturé.

---

## 1. Étude des architectures à coût zéro

### Hypothèses de calcul (identiques pour toutes les options)

| Paramètre | Valeur retenue |
|---|---|
| Opérations par boutique et par jour | **300** (ventes, paiements, dépenses, mouvements de stock…) |
| Taille d'une opération | ~**200 octets** (JSON), soit environ 50 octets une fois compressée par paquets |
| Volume brut par boutique | 300 × 200 o = **60 Ko/jour**, soit environ 22 Mo par an |
| Volume compressé | environ **15 Ko/jour** |
| Téléphones par boutique | **2** (vendeur + patron) |
| Ouverture | 12 h par jour |
| Envoi « une opération = une écriture » | 300 écritures par jour |
| Envoi « par paquets » (toutes les 15 min quand il y a du réseau) | ~**30 paquets par jour** |
| Relève par le téléphone du patron | toutes les 15 à 30 min, soit ~**30 à 48 fois par jour** |

### 1.a) Google Drive de la boutique (dossier de l'application)

**Autorisation Google nécessaire (vérifié).**
- On utilise uniquement la permission `drive.appdata` (« dossier de données de l'application »). Google la classe **« Recommandée » et « Non sensible »**.
- L'application ne voit **que ses propres fichiers**. Elle ne voit ni les photos ni les documents de l'utilisateur, et ces fichiers sont invisibles dans l'appli Drive.
- Les permissions **sensibles** imposent une vérification, et les permissions **restreintes** (par exemple l'accès complet au Drive) imposent un **audit de sécurité payant**. Ce n'est **pas notre cas**.
- La limite de **100 utilisateurs pour une application non vérifiée** ne concerne que les permissions sensibles ou restreintes. **Elle ne s'applique pas à `drive.appdata`.**
- Il reste une **vérification simple et gratuite** de l'écran de consentement (nom, logo, page de politique de confidentialité, domaine prouvé dans Google Search Console). Je proposerai une page gratuite hébergée sur GitHub Pages. **Point à confirmer lors de l'étape A** : que Google accepte une adresse `*.github.io` comme domaine autorisé. Sinon, il faut un nom de domaine (environ 6 000 F par an), seul coût éventuel à prévoir.

**Fonctionnement avec deux téléphones : point clé.**
- Le dossier de l'application est **propre à un compte Google**. **Il ne peut pas être partagé avec un autre compte.**
- Le vendeur et le patron doivent donc être connectés **au même compte Google** dans l'application.
- **Solution : un compte Google dédié à la boutique** (par exemple `boutique.mama.ama@gmail.com`), créé à l'installation, avec **le numéro du patron comme numéro de récupération**.
- On évite le compte Gmail personnel du patron, que le vendeur pourrait alors consulter sur son téléphone.
- **Organisation des fichiers :** chaque téléphone écrit **uniquement ses propres fichiers** (`journal-<téléphone>-<date>-<n°>`) et lit ceux des autres. Comme chaque fichier n'a qu'un seul auteur et que les opérations ne sont jamais modifiées, **il n'y a aucun conflit**.
- Les décisions du patron (prix, produits, employés) sont dans son propre journal. Le vendeur les applique en le lisant.

**Délai de synchronisation.**
- **L'envoi** est immédiat dès qu'il y a du réseau (quelques secondes). Le téléphone envoie un paquet après chaque vente ou toutes les 5 à 15 minutes.
- **La réception** n'est pas instantanée. Drive ne prévient pas les téléphones des changements, car ce système d'avertissement exige un serveur web à nous. Le téléphone du patron doit donc **relever lui-même**, en tâche de fond (au minimum toutes les **15 minutes**, imposé par Android), et **à chaque ouverture de l'application** (relève immédiate).
- **Délai réel attendu : 0 à 30 minutes** si les deux téléphones ont du réseau. C'est plus long sur certains téléphones (Tecno, Infinix, Itel) qui coupent les tâches de fond pour économiser la batterie. Il faudra guider le patron pour désactiver l'économie de batterie pour Zéro Perte.

**Limites d'utilisation de l'API (vérifié, avec une incertitude).**
- Les anciennes limites sont d'environ **12 000 requêtes par minute et par projet**. Google passe à un modèle en « unités de quota » pour les projets créés **après le 1er mai 2026**, ce qui sera notre cas. La documentation donne environ **1 000 000 d'unités par minute et par projet**, 325 000 par minute et par utilisateur, et un seuil quotidien d'environ 400 millions d'unités par projet. Une lecture de liste coûte environ 100 unités et une lecture simple environ 5 unités.
- Google annonce que **le dépassement sera facturé plus tard en 2026**, mais **seulement aux projets qui ont activé la facturation**, avec 90 jours de préavis. **Nous n'activerons jamais la facturation.** Au pire, les requêtes en trop sont **refusées** et l'application réessaie plus tard. Elles ne sont jamais facturées.

**Calcul pour une boutique** (hypothèse prudente : 100 unités par requête) :
- par téléphone : 30 envois + 48 relèves = 78 requêtes × 100 = **7 800 unités/jour**, soit ~**15 600 unités/jour par boutique** ;
- stockage : 22 Mo par an dans les **15 Go gratuits du compte de la boutique**, soit plus de 50 ans de données.

| Nombre de boutiques | Unités par jour (projet) | Seuil ~400 M/jour | Pointe par minute (×3 la moyenne) | Seuil 1 M/min | Verdict |
|---|---|---|---|---|---|
| 20 | 0,3 M | ✅ 0,08 % | ~1 300 | ✅ | Large |
| 200 | 3,1 M | ✅ 0,8 % | ~13 000 | ✅ | Large |
| 2 000 | 31 M | ✅ 8 % | ~130 000 | ✅ 13 % | Large |
| 20 000 | 312 M | ⚠️ 78 % | ~1,3 M | ❌ en pointe | Il faut espacer les relèves (30 min, heures d'ouverture seulement) : environ ÷2 |

➡️ **Drive tient jusqu'à environ 10 000 à 20 000 boutiques sans rien changer.** Au-delà, on espace les relèves ou on crée un second projet Google pour une nouvelle série de boutiques. C'est **de loin l'option qui va le plus loin à 0 F**, parce que le stockage et la plupart des quotas sont ceux de chaque boutique, pas les nôtres.

### 1.b) Un serveur gratuit partagé

Le principe est commun : toutes les boutiques utilisent **notre** projet gratuit. Les limites sont donc **partagées entre toutes les boutiques**.

#### Firebase (offre Spark) — Firestore

Limites vérifiées : **20 000 écritures/jour, 50 000 lectures/jour, 20 000 suppressions/jour, 1 Gio stocké, 10 Gio téléchargés/mois**, pour **tout le projet**. Le projet ne peut pas générer de facture : il s'arrête quand le quota est atteint.

| | 20 boutiques | 200 boutiques | 2 000 boutiques |
|---|---|---|---|
| Écritures, 1 par opération (300 × N) | 6 000 ✅ | 60 000 ❌ (×3) | 600 000 ❌ (×30) |
| Écritures par paquets (30 × N) | 600 ✅ | 6 000 ✅ | 60 000 ❌ (×3) |
| Lectures par paquets (patron 30 + vendeur 10 = 40 × N) | 800 ✅ | 8 000 ✅ | 80 000 ❌ (×1,6) |
| Stockage permanent (22 Mo/an × N) | 440 Mo/an ✅ (plein en ~2 ans) | 4,4 Go/an ❌ (plein en ~3 mois) | 44 Go/an ❌ (plein en ~8 jours) |

➡️ Firestore convient pour environ **200 boutiques en mode relais** (les données sont effacées après livraison), et **pas pour 2 000**.

#### Firebase — Realtime Database

Limite bloquante : **100 connexions simultanées au maximum** (impossible d'augmenter en Spark). Le reste est confortable (1 Go stocké, 10 Go téléchargés par mois). Avec 2 000 boutiques et 4 000 téléphones, des refus de connexion sont certains aux heures de pointe. Et **si une limite mensuelle est dépassée, l'application est coupée**. ❌

#### Supabase (offre gratuite)

Limites vérifiées : **base de 500 Mo** (au-delà, elle passe en lecture seule), **5 Go de sortie de données par mois**, **requêtes API illimitées**, 2 projets. Le projet est mis en pause après 7 jours sans activité, ce qui n'arrive pas avec des boutiques actives. Pas de sauvegarde quotidienne.

| | 20 boutiques | 200 boutiques | 2 000 boutiques |
|---|---|---|---|
| Stockage permanent (22 Mo/an × N) | 440 Mo/an ⚠️ (plein en ~13 mois) | ❌ plein en ~6 semaines | ❌ plein en ~4 jours |
| Stockage en relais (7 jours, compressé : 15 Ko × 7 × N) | 2 Mo ✅ | 21 Mo ✅ | 210 Mo ✅ |
| Sortie de données (15 Ko de données + 96 relèves × ~1 Ko = ~111 Ko/jour/boutique, × 30 jours × N) | 67 Mo/mois ✅ | 670 Mo/mois ✅ | **6,7 Go/mois ❌** (limite 5 Go) |
| Idem avec 48 relèves par jour | — | — | ~3,8 Go ⚠️ juste |

➡️ Supabase tient environ **1 000 à 1 500 boutiques en mode relais**, et **pas 2 000 confortablement**.

#### Cloudflare Workers + D1 (offre gratuite)

Limites vérifiées : **100 000 requêtes/jour**, 10 ms de calcul par requête. D1 : **100 000 lignes écrites/jour**, 5 millions de lignes lues/jour, 5 Go au total (500 Mo par base). Le dépassement produit des **erreurs, jamais de facture**, et aucune carte bancaire n'est demandée.

| | 20 boutiques | 200 boutiques | 2 000 boutiques |
|---|---|---|---|
| Requêtes (vendeur 30 envois + patron 30 relèves + vendeur 10 relèves = 70 × N) | 1 400 ✅ | 14 000 ✅ | 140 000 ❌ (×1,4) |
| Lignes écrites (30 paquets + 30 effacements = 60 × N) | 1 200 ✅ | 12 000 ✅ | 120 000 ❌ (×1,2) |
| Stockage relais 7 jours | ✅ | ✅ | ✅ |

➡️ Cette solution tient environ **1 400 boutiques**. **Son vrai atout** : elle peut envoyer des **notifications instantanées** au patron (via Firebase Cloud Messaging, gratuit). Je la garde donc **seulement pour les alertes urgentes**, un petit volume : 5 alertes/jour × 2 000 boutiques = 10 000 requêtes ✅ (10 % du quota).

### 1.c) Autres solutions à coût zéro étudiées

| Solution | Verdict |
|---|---|
| **Sauvegarde automatique Android** (vers le Drive de l'utilisateur) | Gratuite, mais limitée à **25 Mo**, au plus **une fois par 24 h**, souvent **seulement en Wi-Fi**, restaurée seulement à l'installation, sans contrôle de notre part. **Bonus utile, pas une solution.** |
| **SMS automatique du téléphone vendeur vers le patron** | Fonctionne **sans Internet**. C'est la boutique qui paie le SMS (quelques dizaines de francs), pas vous. L'APK installé hors Play Store a le droit d'envoyer des SMS (le Play Store l'interdit sauf exception). **Bonne option de secours** pour le résumé du soir et les alertes graves. |
| **Partage de fichier par WhatsApp** (export chiffré du journal) | Toujours possible à la main, mais pas automatique. C'est une **solution de secours** pour la restauration. |
| **Service de notification public gratuit (ntfy.sh)** | Gratuit, mais public. Il faudrait chiffrer les messages, et le service dépend d'un bénévole. **Non retenu.** |
| **Un compte Supabase ou Firebase créé par chaque patron** | Techniquement à 0 F pour vous, mais **impossible à mettre en place** par des commerçants peu lettrés. **Non retenu.** |
| **Ouvrir plusieurs comptes gratuits pour multiplier les quotas** | **Contraire aux conditions d'utilisation** des fournisseurs : risque de fermeture brutale de tout. **Interdit.** |
| **Transfert direct entre téléphones** (Wi-Fi Direct, Bluetooth, QR code) | Gratuit et sans Internet, mais il faut que les téléphones soient **côte à côte**. Pas de suivi à distance. Peut servir de **secours en boutique**. |

### 1.d) Tableau de synthèse

| Option | Coût pour vous | 20 boutiques | 200 | 2 000 | 20 000 | Délai patron | Remarque |
|---|---|---|---|---|---|---|---|
| **Drive de la boutique** ⭐ | **0 F** | ✅ | ✅ | ✅ | ⚠️ en réglant les relèves | 0–30 min | La consommation se répartit sur les comptes des boutiques |
| Firestore (Spark) | 0 F | ✅ | ✅ relais | ❌ | ❌ | quelques secondes | Quotas partagés |
| Supabase gratuit | 0 F | ✅ | ✅ relais | ⚠️/❌ | ❌ | quelques secondes | Sortie de données limitée |
| Cloudflare gratuit | 0 F | ✅ | ✅ | ⚠️ | ❌ | **instantané (push)** | Gardé pour les alertes seulement |
| Realtime Database | 0 F | ✅ | ⚠️ | ❌ | ❌ | instantané | 100 connexions au maximum |

---

## 2. Sans serveur à nous : activation, mises à jour, restauration

### 2.1 Code d'activation signé, vérifiable sans Internet

**Principe (signature numérique Ed25519) :**
- Vous détenez une **clé privée secrète**. L'application contient la **clé publique** correspondante.
- Un code d'activation contient : identifiant de la boutique, **empreinte du compte Google de la boutique**, date, type de licence (« à vie »), nombre de téléphones autorisés. Ces informations sont **signées** avec la clé privée.
- L'application vérifie la signature **sans Internet**. Un code modifié ou inventé est rejeté.
- Comme le code est **lié au compte Google de la boutique**, le copier dans une autre boutique ne sert à rien.

**Fabriquer les codes sans ordinateur :**
- Un **bouton dans GitHub** (une tâche GitHub Actions lancée à la main depuis l'application GitHub du téléphone). Vous saisissez le nom de la boutique et son adresse Gmail, et vous recevez **un lien et un QR code** à envoyer par WhatsApp.
- La clé privée est conservée dans les **secrets GitHub**, avec **une copie de secours hors ligne** (papier + coffre). Ce n'est pas la même clé que celle qui signe l'APK.
- Chaque code émis est noté automatiquement dans un **registre des clients** du dépôt privé. Ce registre devient votre fichier clients.

**Format :**
- Une signature fait 64 octets, soit environ 100 caractères. C'est **trop long à taper**.
- Le code est donc transmis par **lien WhatsApp** (un toucher ouvre l'application et l'active) ou par **QR code** à scanner.

**Révocation :** une licence hors ligne ne peut pas être annulée à distance. On publie quand même une **liste noire** (boutiques fraudeuses ou codes volés) dans le fichier de version public (voir 2.2). L'application la lit quand elle vérifie les mises à jour.

> **Franchise :** une personne très compétente peut toujours modifier un APK pour contourner la vérification. Aucune protection sans serveur n'empêche cela. Pour vos clients, le risque est faible.

### 2.2 Mises à jour de l'application

**Le problème :** les fichiers d'un dépôt GitHub **privé**, y compris les « Releases », ne sont pas téléchargeables sans connexion à GitHub.

**Solution recommandée : un deuxième dépôt GitHub public, par exemple `zero-perte-telechargement`, qui ne contient AUCUN code.** Il contient seulement :
- les **APK signés** (dans ses « Releases ») ;
- un fichier **`version.json`** : numéro de la dernière version, lien de l'APK, nouveautés en français simple, liste noire de licences ;
- les **catalogues de produits** par type de boutique (voir la partie 4) ;
- la **page de politique de confidentialité** (GitHub Pages), utile pour la vérification Google.

**Fonctionnement :**
1. Le code reste dans le dépôt **privé**. GitHub Actions y fabrique l'APK signé.
2. La même tâche **publie** l'APK et met à jour `version.json` dans le dépôt public, avec une clé d'accès limitée à ce seul dépôt.
3. À chaque ouverture avec du réseau, l'application lit `version.json`. Si une nouvelle version existe : **« Nouvelle version disponible — Installer »**.
4. Android n'accepte la mise à jour que si elle est **signée avec la même clé** que la version installée. Un faux APK ne peut donc pas remplacer le vrai.

C'est gratuit : GitHub ne fait pas payer le téléchargement des Releases publiques. L'APK public ne pose pas de problème, car sans code d'activation l'application ne fonctionne pas.

### 2.3 Restauration après perte du téléphone

| Cas | Solution |
|---|---|
| **Téléphone du vendeur perdu ou cassé** | Rien n'est perdu : ses opérations envoyées sont dans le Drive **et** sur le téléphone du patron. On installe l'APK sur un nouveau téléphone, on se connecte au compte de la boutique, et le téléphone reçoit un **nouveau préfixe de reçu**. |
| **Téléphone du patron perdu** | Nouveau téléphone, installation de l'APK, connexion au compte Google de la boutique. L'application retrouve **tout** dans le Drive : journaux, réglages, personnalisation, licence. |
| **Les deux téléphones perdus** | Même chose : le Drive contient tout ce qui a été envoyé. On perd seulement les opérations jamais envoyées. |
| **Mot de passe du compte Google oublié** | Récupération Google classique par le **numéro du patron** (d'où l'importance de le mettre à l'installation). |
| **Le vendeur efface les données cachées du Drive** (c'est possible depuis le site Drive) | Chaque téléphone garde **une copie complète** de tous les journaux. Le téléphone du patron détecte le trou et **renvoie tout**. Une alerte est envoyée au patron. |
| **Le vendeur retire l'accès de l'application au compte** | La synchronisation s'arrête. Alerte « le téléphone vendeur n'a rien envoyé depuis X heures ». |
| **Secours supplémentaire** | Sauvegarde automatique Android (bonus) + bouton « Exporter une sauvegarde » (fichier chiffré à s'envoyer sur WhatsApp). |

---

## 3. Ce qu'on perd par rapport à un serveur payant

### Ce qui reste possible, mais moins bien

| Fonction | Avec un serveur payant | À 0 F (Drive) |
|---|---|---|
| Délai pour que le patron voie une vente | quelques secondes | **0 à 30 minutes** (instantané pour les alertes si on ajoute le relais Cloudflare gratuit) |
| Notifications | instantanées et fiables | **locales**, après chaque relève, et retardées par les téléphones qui tuent les tâches de fond |
| Installation | un numéro de téléphone suffit | il faut **un compte Google pour la boutique**, plus long à l'installation |
| Révocation d'une licence | immédiate | seulement quand l'application va sur Internet (liste noire) |
| Téléphones compatibles | tous | seulement ceux qui ont les **services Google**. Les Huawei récents n'en ont pas. |

### Ce qui est impossible à 0 F

1. **Une vue d'ensemble pour vous** : combien de boutiques utilisent vraiment l'application, leurs chiffres, les erreurs. Vous ne voyez **rien** des boutiques, car les données sont chez elles. C'est bon pour la confidentialité, mauvais pour le suivi commercial.
2. **Une assistance à distance sur les données** : vous ne pouvez pas corriger une erreur dans les données d'un client sans son téléphone ou sans qu'il vous envoie un export.
3. **La confirmation automatique des paiements Mobile Money** : les agrégateurs envoient la confirmation à un serveur web. De plus, ils prélèvent une commission.
4. **L'envoi automatique de messages WhatsApp** (résumé du soir, rappel de crédit sans toucher l'écran) : l'API WhatsApp Business est payante. Le partage reste **manuel, en un geste**.
5. **Une garantie « gratuit pour toujours »** : aucun fournisseur (Google, Cloudflare…) ne s'y engage. Google a déjà annoncé un nouveau modèle de quotas pour 2026. Le risque est **réduit**, parce que la charge est répartie sur les comptes des boutiques, mais **pas nul**.
6. **Les statistiques multi-boutiques côté serveur** (un patron avec plusieurs boutiques, prévu en V2) : elles restent faisables sur le téléphone du patron en lisant plusieurs comptes, mais c'est plus lourd.

### Petits coûts possibles à surveiller (pas des abonnements)

- **Nom de domaine** : environ 6 000 F par an, seulement si Google refuse l'adresse GitHub Pages pour la vérification de l'écran de consentement.
- **Play Store** : 25 $ une seule fois, si un jour vous publiez sur le Play Store (pas prévu en V1).
- **GitHub Actions** pour le dépôt privé : 2 000 minutes gratuites par mois, soit environ 200 fabrications d'APK. Largement suffisant.

---

## 4. La personnalisation automatique

### 4.1 L'assistant d'inscription (8 écrans, un geste par écran, voix pour guider)

| # | Écran | Détail |
|---|---|---|
| 1 | **Langue et voix** | Français pour l'instant (voix pré-enregistrées en éwé, mina et kabiyè plus tard). Un haut-parleur sur chaque écran relit la consigne. |
| 2 | **Activation** | Toucher le lien WhatsApp ou scanner le QR code reçu, puis connexion au compte Google de la boutique. |
| 3 | **Type de boutique** | Grandes images : alimentation générale, boissons et buvette, quincaillerie, céréales et vivriers, cosmétiques, pièces détachées, téléphonie et accessoires, divers. Plusieurs choix possibles. |
| 4 | **Nom de la boutique + logo ou photo** | Nom tapé ou **dicté** (reconnaissance vocale d'Android). Photo prise avec l'appareil photo et recadrée en rond. Sans photo, l'application génère un **logo avec les initiales** dans la couleur choisie. |
| 5 | **Téléphone et adresse** | Numéro du patron (à afficher sur les reçus), ville choisie dans une liste, quartier en texte libre ou dicté, repère (« en face de la pharmacie… »). |
| 6 | **Couleur** | 8 pastilles de couleur, avec un **aperçu en direct** de l'écran d'accueil. Le **vert et le rouge restent réservés** à « argent qui entre » et « argent qui sort », quelle que soit la couleur choisie. |
| 7 | **Mes produits** | Le catalogue du type choisi s'affiche en **grille de photos**. Le patron touche « Je vends ça » sur chaque produit, puis entre **le prix** (ou plus tard : un produit sans prix ne peut pas être vendu). Les unités sont déjà réglées (sac → bol, casier → bouteille…) et modifiables. |
| 8 | **Le reçu et les codes PIN** | **Aperçu du reçu** avec l'en-tête (logo, nom, téléphone, adresse) et un message de bas de page (« Merci, à bientôt ! », modifiable). Ensuite : PIN du patron, puis ajout des vendeurs. |

### 4.2 Ce que la personnalisation change

- **Dans l'application** : nom et logo de la boutique en haut de chaque écran, couleur de la boutique, écran de démarrage avec son logo.
- **Reçus et messages WhatsApp** : en-tête et signature de la boutique.
- **Raccourci sur l'écran d'accueil du téléphone** : Android permet de créer un **raccourci avec le logo et le nom de la boutique** (« Boutique Mama Ama »). Le commerçant voit son nom à lui sur son téléphone.
- **Limite honnête** : l'**icône principale** de l'application et son nom dans la liste des applications restent « Zéro Perte ». On ne peut pas les changer sans fabriquer un APK par boutique, ce qui contredirait la décision « une seule application ».
- La personnalisation est enregistrée **dans le Drive de la boutique**. Elle revient donc automatiquement sur un nouveau téléphone.

### 4.3 Les catalogues préremplis

- Un **fichier par type de boutique** : produits, noms courants (y compris les noms locaux), unités et conversions, catégorie et image.
- Une copie est **intégrée à l'APK** (fonctionne sans Internet). Une version à jour est publiée dans le **dépôt public** : on peut enrichir les catalogues **sans nouvel APK**.
- **Images** : illustrations simples et libres de droits, ou photos prises par votre équipe dans de vraies boutiques. On évite les logos de marques. Le patron peut remplacer chaque image par **sa propre photo**.
- **Prix** : **non préremplis**, car ils varient trop d'un quartier à l'autre. C'est le patron qui les fixe. On pourra plus tard proposer un « prix courant indicatif ».
- **Contenu** : il nous faut **vos listes réelles** (30 à 80 produits par type), voir les questions.

---

## 5. Architecture retenue (schéma)

```
 Téléphone VENDEUR                    Google Drive de la BOUTIQUE                 Téléphone PATRON
 (base locale complète)               (dossier caché de l'application)            (base locale complète)
 ┌─────────────────────┐   envoi     ┌────────────────────────────────┐  relève    ┌─────────────────────┐
 │ ventes, caisse,     │ ──────────▶ │ journal-vendeur-A-*.json.gz     │ ─────────▶ │ tableau de bord,    │
 │ dépenses, stock     │             │ journal-patron-P-*.json.gz      │ ◀───────── │ alertes locales,    │
 │ (on ajoute, on ne   │ ◀────────── │ reglages.json, licence, photos  │   envoi    │ prix, arrivages     │
 │  modifie jamais)    │   relève    └────────────────────────────────┘            └─────────────────────┘
 └─────────┬───────────┘                                                                   ▲
           │ (option D7) alerte urgente : quelques octets                                  │ notification
           └──────────▶ relais Cloudflare gratuit ──▶ Firebase Cloud Messaging (gratuit) ─┘ instantanée
           (option D8) SMS de secours sans Internet, payé par la boutique ─────────────────▶ patron

 Dépôt GitHub PRIVÉ (code)  ──GitHub Actions──▶  Dépôt GitHub PUBLIC (APK, version.json, catalogues, liste noire)
```

---

## 6. Sources vérifiées

- Permissions Google Drive (`drive.appdata` recommandée et non sensible) : [Choose Google Drive API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- Applications non vérifiées et limite de 100 utilisateurs (permissions sensibles ou restreintes seulement) : [Unverified apps](https://support.google.com/cloud/answer/7454865)
- Vérification des applications : [FAQ vérification OAuth](https://support.google.com/cloud/answer/13463817)
- Limites de l'API Drive : [Usage limits](https://developers.google.com/workspace/drive/api/guides/limits)
- Nouveau modèle de quotas Google Workspace (2026) : [Google Workspace API tiering model](https://developers.google.com/workspace/tools-safety)
- Sauvegarde automatique Android (25 Mo, 24 h) : [Back up user data with Auto Backup](https://developer.android.com/identity/data/autobackup)
- Firebase, offre gratuite : [Firebase pricing](https://firebase.google.com/pricing), [Realtime Database limits](https://firebase.google.com/docs/database/usage/limits)
- Supabase, offre gratuite : [Pricing](https://supabase.com/pricing), [Project pausing](https://supabase.com/docs/guides/platform/free-project-pausing), [Egress](https://www.supabase.com/docs/guides/platform/manage-your-usage/egress)
- Cloudflare : [Workers pricing](https://developers.cloudflare.com/workers/about/pricing), [D1 limits](https://developers.cloudflare.com/d1/platform/limits), [D1 : application des limites gratuites (sept. 2026)](https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/)

*Certaines limites diffèrent d'une page à l'autre chez Google et Cloudflare : elles seront revérifiées au moment de coder les étapes concernées. Les calculs ci-dessus sont des estimations prudentes, à confirmer pendant le pilote en mesurant le volume réel par boutique.*
