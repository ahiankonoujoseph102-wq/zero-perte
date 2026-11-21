# Zéro Perte — Décision serveur : une architecture à 0 F pour le propriétaire

*Mission 2, 21 novembre 2026, mise à jour en mission 3. Aucun code n'a été écrit.*

## ✅ Décisions validées (mission 3)

| Sujet | Décision |
|---|---|
| Synchronisation et sauvegarde | **Drive de chaque boutique** (dossier caché de l'application, autorisation `drive.appdata`) : **validé** |
| Compte Google de la boutique | Créé **à l'installation** par le propriétaire ou ses agents, **avec le patron et SON numéro de téléphone** (procédure au §2.5) |
| Alertes instantanées | **OUI**, pour les cas graves, via le relais Cloudflare gratuit + Firebase Cloud Messaging (§2.6) |
| Hébergement des APK | **PAS de dépôt GitHub public.** Solution retenue : **Cloudflare Pages** (§2.2) |
| Licence | Paiement unique, **2 téléphones** (patron + 1 vendeur), mises à jour gratuites à vie, **téléphone supplémentaire vendu en option** (§2.1) |
| SMS de secours | **OUI, en option, désactivé par défaut**, payé par la boutique |
| Huawei sans services Google | **Non pris en charge en V1.** L'application le détecte et l'affiche clairement. |
| Installation | **Sur place à Lomé** ; **à distance ailleurs** (APK + vidéo). Il faut donc un **assistant d'installation utilisable seul** (§4.0). |
| Risques à traiter | (a) Vendeur qui efface le Drive ou retire le compte : **§2.4** ; (b) limite de comptes par numéro : **§2.5** |

**Contrainte non négociable :** le commerçant paie une seule fois. Le propriétaire ne paie **aucun** serveur, ni aujourd'hui ni avec des milliers de boutiques. Le patron doit quand même pouvoir suivre sa boutique à distance.

---

## 0. La recommandation en bref

> **Chaque boutique utilise son propre espace Google Drive gratuit, dans le dossier caché réservé à l'application (« appDataFolder »), via un compte Google dédié à la boutique.** Le téléphone du vendeur et celui du patron se connectent au même compte. Chacun y dépose son journal d'opérations et lit celui de l'autre.
>
> - **Coût pour le propriétaire : 0 F.** Le stockage appartient au compte de la boutique (15 Go gratuits). La consommation augmente avec le nombre de boutiques, mais elle est **répartie sur leurs comptes**, pas sur le nôtre.
> - Ce même Drive sert de **sauvegarde** : un téléphone perdu se restaure en se connectant au compte.
> - Le **code d'activation est signé** et vérifié sans Internet. Les **mises à jour** sont publiées sur **Cloudflare Pages** (gratuit, sans carte bancaire), à une adresse fixe, par GitHub Actions. Le dépôt de code reste privé.
> - **Relais Cloudflare gratuit** pour les **alertes graves instantanées** (notification « push »). Le petit volume de messages tient dans l'offre gratuite jusqu'à plusieurs milliers de boutiques.

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
- Un code d'activation contient : identifiant de la boutique, **empreinte du compte Google de la boutique**, date, licence « à vie », **nombre de téléphones autorisés (2 par défaut)**. Ces informations sont **signées** avec la clé privée.
- L'application vérifie la signature **sans Internet**. Un code modifié ou inventé est rejeté.
- Comme le code est **lié au compte Google de la boutique**, le copier dans une autre boutique ne sert à rien.

**Deux téléphones par licence, et le téléphone supplémentaire :**
- Chaque téléphone relié à la boutique s'inscrit dans un fichier `telephones.json` du Drive de la boutique : identifiant, rôle, préfixe de reçu, date.
- Un **3e téléphone est refusé**, avec ce message : « Votre licence couvre 2 téléphones. Pour en ajouter un, contactez Zéro Perte. »
- **Téléphone supplémentaire vendu** : vous générez un **code d'extension** signé (« +1 téléphone » pour cette boutique). Il s'ajoute à la licence existante.
- **Remplacement d'un téléphone** (perdu ou cassé) : toujours **gratuit**. Le patron, avec son PIN, choisit « Remplacer le téléphone du vendeur ». L'ancien est **désactivé** (il ne peut plus rien envoyer) et le patron est alerté si l'ancien tente encore de se connecter.

**Fabriquer les codes sans ordinateur :**
- Un **bouton dans GitHub** (tâche GitHub Actions lancée à la main depuis l'application GitHub du téléphone). Vous saisissez : nom de la boutique, adresse Gmail de la boutique, type (« licence » ou « +1 téléphone »).
- Vous recevez **un lien et un QR code** à envoyer par WhatsApp.
- La clé privée est dans les **secrets GitHub**, avec **une copie de secours hors ligne**. Ce n'est pas la même clé que celle qui signe l'APK.
- Chaque code émis est noté automatiquement dans un **registre des clients** du dépôt privé : votre fichier clients.

**Format :** une signature fait environ 100 caractères, ce qui est trop long à taper. Le code est donc transmis par **lien WhatsApp** (un toucher ouvre l'application et l'active) ou par **QR code**.

**Révocation :** une **liste noire** (codes volés ou boutiques fraudeuses) est publiée dans le fichier de version **signé** (§2.2). L'application la lit à chaque vérification de mise à jour.

> **Franchise :** une personne très compétente peut toujours modifier un APK pour contourner la vérification. Aucune protection sans serveur n'empêche cela. Pour vos clients, le risque est faible.

### 2.2 Hébergement des mises à jour (sans dépôt public) — solution retenue : Cloudflare Pages

**Besoin :**
- un **lien fixe** pour l'APK et le fichier `version.json` ;
- une **mise à jour automatique** depuis GitHub Actions (dépôt privé) ;
- **gratuit**, **sans carte bancaire** si possible ;
- des fichiers d'environ 10 Mo.

**Comparaison (vérifiée en novembre 2026) :**

| Option | Taille max. d'un fichier | Bande passante gratuite | Carte bancaire | Mise à jour depuis GitHub Actions | Lien fixe | Verdict |
|---|---|---|---|---|---|---|
| **Cloudflare Pages** (envoi direct) | **25 Mio** | Fichiers statiques **illimités** (selon une source secondaire, à confirmer) | **Non** | Oui : commande `wrangler pages deploy` + clé d'accès Cloudflare dans les secrets GitHub | Oui : `https://<nom>.pages.dev/...` | ⭐ **Retenu** |
| Cloudflare R2 (stockage) | Très grande | 10 Go stockés, sortie gratuite | **Contradictoire** : Cloudflare dit « sans carte », un guide dit qu'un moyen de paiement est demandé à la création | Oui | Oui | En réserve |
| Google Drive du propriétaire | Très grande (avertissement antivirus au-delà d'environ 100 Mo seulement) | Quota de téléchargement **non publié** : un fichier très téléchargé peut être bloqué temporairement (« quota dépassé ») | Non | Possible, mais il faut garder dans GitHub une autorisation permanente de votre compte Google | Oui, si on remplace le fichier en gardant son identifiant | **Secours seulement** : quota flou, et Google peut bloquer le partage d'un APK |
| Firebase App Distribution | — | — | Non | Oui | **Non** : il faut **inviter chaque testeur par e-mail** (500 maximum par projet) ; les versions sont **supprimées après 150 jours** | ❌ Fait pour les tests, pas pour des clients |
| Firebase Hosting (offre Spark) | 2 Go | 10 Go/mois | Non | Oui | Oui | ❌ **Les fichiers .apk sont interdits** sur l'offre gratuite (vérifié) |
| Netlify (offre gratuite) | Non vérifiée | 300 crédits/mois, soit environ **15 Go/mois** ; site coupé jusqu'au mois suivant si dépassé | Non | Oui | Oui | ❌ Trop juste : 2 000 boutiques × 2 téléphones × 10 Mo = 40 Go par mise à jour |
| Dépôt GitHub privé (Releases) | 2 Go | — | Non | Oui | **Non** : téléchargement impossible sans être connecté à GitHub | ❌ |
| Dépôt GitHub public | 2 Go | Large | Non | Oui | Oui | ❌ Refusé par le propriétaire |

**Fonctionnement retenu :**
1. GitHub Actions (dépôt privé) fabrique l'APK signé, **découpé par type de processeur** :
   - `arm64-v8a` pour les téléphones récents ;
   - `armeabi-v7a` pour les vieux ou très bas de gamme.
   
   Chacun fait environ 8 à 12 Mo, **bien sous la limite de 25 Mio**. Un APK « universel » (environ 20 à 25 Mo) frôlerait la limite : on ne le publie pas.
2. La même tâche publie sur Cloudflare Pages :
   - `zeroperte-maj.pages.dev/apk/zeroperte-arm64.apk` (le nom est à choisir) ;
   - `zeroperte-maj.pages.dev/apk/zeroperte-armv7.apk` ;
   - `zeroperte-maj.pages.dev/version.json` : numéro de version, nouveautés en français simple, empreinte de chaque APK et **liste noire de licences**. Ce fichier est **signé avec la clé de licence** : si quelqu'un piratait le compte Cloudflare, il ne pourrait ni fabriquer une fausse liste ni pointer vers un faux APK.
   - `zeroperte-maj.pages.dev/catalogues/*.json` : les catalogues de produits (voir `categories.md`).
3. L'application lit `version.json` à chaque ouverture avec du réseau, **télécharge le bon APK pour son processeur**, vérifie son empreinte, puis propose « Installer ».
4. Android n'accepte la mise à jour que si l'APK est **signé avec la même clé** : double protection.
5. **Première installation** : l'APK est toujours **envoyé par WhatsApp** avec la vidéo. Le lien Cloudflare peut aussi être donné.

**Limites honnêtes de Cloudflare Pages :**
- **25 Mio par fichier** : on surveille la taille de l'APK à chaque fabrication, et GitHub Actions échoue volontairement si un APK dépasse 22 Mo.
- **500 déploiements par mois** et **20 000 fichiers** par site : largement suffisant.
- Les fichiers sont **accessibles à quiconque connaît le lien**. Ce n'est pas grave, car l'APK ne marche pas sans code d'activation et le code reste privé. On ajoute une consigne pour que les moteurs de recherche n'indexent pas le site.
- La « bande passante illimitée » n'est confirmée que par une source secondaire, et Cloudflare peut changer son offre. Si c'était le cas, le **plan B** est Google Drive du propriétaire, et l'application connaît une **adresse de secours** inscrite dans `version.json`.
- Cloudflare fait évoluer Pages vers les « Workers static assets », qui ont la même limite de 25 Mio par fichier et sont aussi gratuits. La migration serait simple si nécessaire.
- **Même compte Cloudflare** que le relais d'alertes (§2.6) : **un seul compte à protéger**, avec une double authentification sur votre téléphone.

### 2.3 Restauration après perte du téléphone

| Cas | Solution |
|---|---|
| **Téléphone du vendeur perdu ou cassé** | Rien n'est perdu : ses opérations envoyées sont dans le Drive **et** sur le téléphone du patron. Le patron fait « Remplacer le téléphone du vendeur ». Le nouveau téléphone se connecte au compte de la boutique et reçoit un **nouveau préfixe de reçu**. |
| **Téléphone du patron perdu** | Nouveau téléphone, installation de l'APK, connexion au compte Google de la boutique (code reçu par SMS sur le numéro du patron, ou codes de secours de l'enveloppe, §2.5). L'application retrouve **tout** : journaux, réglages, personnalisation, licence. |
| **Les deux téléphones perdus** | Même chose. Seules les opérations jamais envoyées sont perdues. |
| **Mot de passe oublié** | Récupération Google par le **numéro du patron** ou par les **codes de secours** de l'enveloppe. |
| **Secours supplémentaire** | Bouton « Exporter une sauvegarde » (fichier chiffré à s'envoyer sur WhatsApp) + sauvegarde automatique Android (bonus). |

### 2.4 Risque (a) : le vendeur efface les données du Drive ou retire le compte

**Ce qu'un vendeur peut faire :**
1. effacer les **données cachées de l'application** depuis les réglages de Google Drive (drive.google.com → Paramètres → Gérer les applications) ;
2. **retirer le compte Google** de son téléphone, ou **retirer l'autorisation** donnée à Zéro Perte ;
3. **désinstaller** l'application ou **effacer ses données** sur le téléphone ;
4. **couper Internet** (mode avion) pour que rien ne parte ;
5. **changer l'heure** du téléphone.

**Règle de base : le téléphone du patron ne dépend jamais du Drive pour garder ses données.**
- Tout ce qu'il reçoit est **copié dans sa propre base**, et **jamais effacé** (modèle « on ajoute seulement »).
- Le Drive n'est qu'une **boîte aux lettres et une sauvegarde**. Le vider ne fait rien disparaître chez le patron.

**Comment l'application détecte chaque problème :**

| Mécanisme | Détail | Ce qu'il détecte |
|---|---|---|
| **Numéros de suite par téléphone** | Chaque opération porte le numéro suivant du téléphone qui l'a créée (A-1, A-2, A-3…). Le patron mémorise le dernier numéro reçu de chaque téléphone. | Toute **opération manquante** (trou dans la suite), toute **réinstallation** (la suite repart à 1) |
| **Chaîne d'empreintes** | Chaque paquet envoyé contient l'empreinte du paquet précédent du même téléphone, et il est **signé par ce téléphone** avec sa clé, créée à la liaison. | Tout paquet **supprimé, modifié ou inventé** |
| **Inventaire du Drive** | À chaque relève, le patron compare la liste des fichiers présents dans le Drive avec **sa propre liste** de ce qu'il a déjà reçu. | **Données effacées du Drive** |
| **Signal de vie** | Quand l'application vendeur est ouverte, elle dépose toutes les 15 min un petit fichier « je suis vivant » (heure, dernier numéro, nombre d'opérations en attente, niveau de batterie). | **Arrêt de synchronisation**, téléphone éteint, mode avion, compte retiré |
| **Erreur d'accès côté vendeur** | Si Google répond « compte absent » ou « autorisation retirée », l'application vendeur le sait immédiatement. | **Compte retiré**, **autorisation retirée** |
| **Contrôle de l'heure** | L'heure de chaque fichier selon Google Drive est comparée à l'heure annoncée par le téléphone. | **Horloge faussée** |

**Ce que fait l'application dans chaque cas :**

| Situation | Réaction automatique | Alerte au patron |
|---|---|---|
| Fichiers effacés du Drive | Le téléphone du patron **renvoie toute sa copie** dans le Drive. Le vendeur la récupère à la relève suivante. | 🔴 **Instantanée** (relais Cloudflare) : « Les données de la boutique ont été effacées du Drive. Elles ont été restaurées. » |
| Compte ou autorisation retirés sur le téléphone vendeur | L'application vendeur affiche un **écran rouge** (« Connexion à la boutique perdue, appelez le patron ») et **continue de vendre hors ligne** pour ne pas bloquer les clients. Tout est gardé localement. | 🔴 **Instantanée** : le relais Cloudflare **ne dépend pas du compte Google**, donc l'alerte part quand même dès qu'il y a Internet. **SMS** si l'option est activée. |
| Signal de vie absent depuis plus de X heures pendant les heures d'ouverture (X réglable, 2 h par défaut) | — | 🟠 Notification locale : « Le téléphone de [vendeur] n'a rien envoyé depuis 3 h. » 🔴 Instantanée si cela dure plus de 6 h. |
| Trou dans la suite des numéros | — | 🔴 « Des opérations du téléphone A ont disparu (n° 1 245 à 1 260). » |
| Réinstallation ou effacement de l'application vendeur | Pour reconnecter le téléphone, il faut le **PIN du patron**. Le téléphone garde le même préfixe, mais la suite reprend après le dernier numéro connu du patron. | 🔴 « L'application a été réinstallée sur le téléphone du vendeur, le [date] à [heure]. Opérations non envoyées perdues : n° … » |
| Horloge faussée | Les opérations sont marquées « heure douteuse ». | 🟠 « L'heure du téléphone vendeur a été modifiée. » |
| Opérations en attente depuis longtemps sur le téléphone vendeur | Le voyant passe à l'orange puis au rouge chez le vendeur. Le compte des opérations en attente est aussi dans le signal de vie. | 🟠 si plus de 50 opérations ou plus de 4 h en attente |

**Ce qui reste impossible à empêcher (franchement) :** un vendeur qui **efface l'application avant tout envoi** fait perdre les opérations non envoyées. On le **détecte** (réinstallation, trou dans les numéros, écart de caisse), mais on ne peut pas récupérer ce qui n'est jamais parti. C'est pourquoi l'envoi se fait **après chaque vente** dès qu'il y a du réseau.

**Protection supplémentaire :** grâce à la **validation en deux étapes** du compte (§2.5), le vendeur **ne peut pas ajouter le compte** sur un autre appareil ni changer le mot de passe sans le code reçu sur le téléphone du patron.

### 2.5 Risque (b) : procédure de création du compte Google de la boutique

**Pourquoi c'est important (vérifié) :**
- Google limite le nombre d'utilisations d'un même numéro pour la vérification. Le seuil n'est **pas publié**. Une étude universitaire relevait **au plus 2 par jour et environ 10 sur toute la vie du numéro**, et ce compteur ne se remet pas à zéro.
- Si un agent utilise son propre numéro, **il sera bloqué après quelques boutiques**.
- Google surveille aussi les **créations répétées depuis un même téléphone ou une même connexion Internet**.

**Règles absolues :**
1. **Toujours le numéro du patron**, jamais celui du propriétaire ou d'un agent, même « pour dépanner ».
2. **Créer le compte depuis le téléphone du patron**, avec **sa connexion Internet** (données mobiles), jamais depuis le téléphone ni le partage de connexion de l'agent.
3. **Un compte par boutique.** Si le patron a déjà un compte personnel, on en crée quand même un **nouveau** pour la boutique.
4. Si Google répond « Ce numéro ne peut pas être utilisé » : **on s'arrête**. On essaie l'**autre puce du patron** (Moov ou Yas) ou le numéro d'un **proche du patron** présent et d'accord. On note le cas dans la fiche.

**Avant de venir (à préparer) :**
- Le patron a son téléphone chargé, avec **sa puce active** qui reçoit les SMS et du **crédit Internet**.
- Le patron connaît sa **date de naissance**. **Il doit avoir 18 ans ou plus** dans le compte, sinon Google restreint le compte.
- L'agent apporte une **fiche d'installation** papier et une **enveloppe** (modèle fourni en étape E).

**Étapes (environ 10 minutes) :**

| # | Action | Détail |
|---|---|---|
| 1 | Sur le **téléphone du patron** : **Paramètres → Comptes (ou Utilisateurs et comptes) → Ajouter un compte → Google** | Si le patron est déjà connecté à son compte personnel, ce n'est pas grave : on ajoute un second compte. L'assistant Zéro Perte peut ouvrir cet écran directement (§4.0). |
| 2 | Toucher **« Créer un compte » → « Pour mon usage personnel »** | On évite l'option entreprise, qui propose des services payants. |
| 3 | **Prénom** : nom de la boutique (par ex. « Boutique Mama Ama ») ; **Nom** : « Zéro Perte » | Le nom est visible seulement par le patron. |
| 4 | **Date de naissance et genre du patron** | Date réelle, 18 ans ou plus. |
| 5 | **Adresse Gmail** : choisir `zp.<nom-boutique>.<ville>@gmail.com` (par ex. `zp.mamaama.lome@gmail.com`) | Si elle est prise, ajouter le quartier ou un chiffre. Écrire l'adresse sur la fiche. |
| 6 | **Mot de passe** : choisi **par le patron**, ou créé avec lui (au moins 10 caractères, facile à retenir pour lui) | Écrit **uniquement** sur la fiche secrète, glissée dans l'**enveloppe du patron**. **L'agent ne le garde pas** (sauf décision contraire du propriétaire, voir questions). |
| 7 | **Numéro de téléphone : celui du PATRON** (+228 …) | Google envoie un code par SMS **au téléphone du patron**. On saisit le code. |
| 8 | **Adresse e-mail de récupération** : l'e-mail personnel du patron s'il en a un, sinon passer | — |
| 9 | Accepter les conditions. Refuser les options non nécessaires (paiement, etc.). | — |
| 10 | **Activer la validation en deux étapes par SMS sur le numéro du patron** : myaccount.google.com → Sécurité → Validation en deux étapes | Empêche le vendeur d'utiliser le compte ailleurs ou de changer le mot de passe. |
| 11 | **Imprimer ou recopier les 10 codes de secours** (Sécurité → Codes de secours) | Dans l'**enveloppe du patron**. Ils servent si le patron perd sa puce. |
| 12 | **Vérifier** : le numéro de récupération est bien celui du patron (Sécurité → Numéro de téléphone de récupération) | — |
| 13 | Ouvrir **Zéro Perte** → « Se connecter avec le compte de la boutique » → choisir **ce** compte (pas le compte personnel) → accepter l'autorisation | L'application vérifie que ce n'est pas un compte déjà utilisé par une autre boutique. |
| 14 | Ajouter le **téléphone du vendeur** : sur ce téléphone, ajouter le **même compte** (le patron tape le mot de passe et reçoit le code de validation sur **son** téléphone), puis scanner dans Zéro Perte le QR code affiché par le patron | Le vendeur ne voit jamais le mot de passe. |
| 15 | Remplir la **fiche d'installation** : nom de la boutique, adresse Gmail, numéro du patron, date, agent, type de licence. **Pas le mot de passe.** | La fiche revient au propriétaire, pour le registre des clients. |

**À distance (hors de Lomé) :** l'assistant Zéro Perte guide le patron pas à pas, avec la voix et des captures d'écran, pour les étapes 1 à 14 (§4.0). Une vidéo montre la même chose. L'agent reste joignable par appel WhatsApp.

### 2.6 Alertes instantanées (relais Cloudflare) : validé

- **Rôle unique** : faire passer **des alertes graves**, jamais les données de la boutique.
- **Cas graves retenus** :
  - données effacées du Drive ;
  - compte retiré du téléphone vendeur ;
  - opérations disparues ;
  - réinstallation de l'application ;
  - écart de caisse au-delà du seuil du patron ;
  - annulation d'une vente importante ;
  - téléphone vendeur muet depuis plus de 6 h ;
  - PIN du patron utilisé dans la boutique alors que le patron est ailleurs.
- **Fonctionnement** : le téléphone vendeur envoie un **message court et chiffré** (code d'alerte + montant) au relais. Le relais le transmet via **Firebase Cloud Messaging** (gratuit) au téléphone du patron, qui le déchiffre et l'affiche.
- **Volume** : environ 5 alertes/jour × 2 000 boutiques = **10 000 requêtes/jour**, soit **10 %** des 100 000 gratuites. Il faut aussi compter l'inscription des téléphones, qui est rare.
- **Protection** : chaque téléphone a un **jeton** remis à l'activation. Le relais refuse les messages sans jeton valide et limite le nombre de messages par boutique, pour qu'un tricheur ne puisse pas épuiser le quota de tous.
- **Si le quota gratuit est épuisé** : les alertes arrivent quand même par la relève normale du Drive (0 à 30 min). Rien n'est perdu et rien n'est facturé.
- **SMS de secours** (option, **désactivé par défaut**, payé par la boutique) : pour le résumé du soir et les alertes graves **quand le téléphone vendeur n'a pas Internet**.

---

## 3. Ce qu'on perd par rapport à un serveur payant

### Ce qui reste possible, mais moins bien

| Fonction | Avec un serveur payant | À 0 F (Drive + relais Cloudflare) |
|---|---|---|
| Délai pour que le patron voie une vente | quelques secondes | **0 à 30 minutes** ; **alertes graves instantanées** grâce au relais Cloudflare gratuit |
| Notifications ordinaires (stock bas, résumé) | instantanées | **locales**, après chaque relève, et retardées par les téléphones qui coupent les tâches de fond |
| Installation | un numéro de téléphone suffit | il faut **un compte Google pour la boutique**, environ 10 minutes de plus (§2.5) |
| Révocation d'une licence | immédiate | seulement quand l'application va sur Internet (liste noire) |
| Téléphones compatibles | tous | seulement ceux qui ont les **services Google** (Huawei récents non pris en charge en V1 : **décision validée**) |

### Ce qui est impossible à 0 F

1. **Une vue d'ensemble pour vous** : combien de boutiques utilisent vraiment l'application, leurs chiffres, les erreurs. Vous ne voyez **rien** des boutiques, car les données sont chez elles. C'est bon pour la confidentialité, mauvais pour le suivi commercial. Le relais Cloudflare pourrait compter les téléphones actifs, sans aucune donnée commerciale, si vous le souhaitez.
2. **Une assistance à distance sur les données** : vous ne pouvez pas corriger une erreur dans les données d'un client sans son téléphone ou sans qu'il vous envoie un export.
3. **La confirmation automatique des paiements Mobile Money** : les agrégateurs envoient la confirmation à un serveur web. De plus, ils prélèvent une commission.
4. **L'envoi automatique de messages WhatsApp** : l'API WhatsApp Business est payante. Le partage reste **manuel, en un geste**.
5. **Une garantie « gratuit pour toujours »** : aucun fournisseur (Google, Cloudflare…) ne s'y engage. Le risque est **réduit**, parce que la charge est répartie sur les comptes des boutiques, mais **pas nul**.
6. **Les statistiques multi-boutiques côté serveur** (V2) : elles restent faisables sur le téléphone du patron, mais c'est plus lourd.

### Petits coûts possibles à surveiller (pas des abonnements)

- **Nom de domaine** : environ 6 000 F par an, seulement si Google refuse l'adresse gratuite pour la vérification de l'écran de consentement. La page de confidentialité peut aussi être hébergée sur **Cloudflare Pages** (`*.pages.dev`) : même question à vérifier à l'étape A6.
- **Play Store** : 25 $ une seule fois, si un jour vous publiez sur le Play Store (pas prévu en V1).
- **GitHub Actions** pour le dépôt privé : 2 000 minutes gratuites par mois, soit environ 200 fabrications d'APK. Largement suffisant.

---

## 4. Installation et personnalisation automatique

### 4.0 L'assistant d'installation guidé (utilisable seul, à distance)

À Lomé, l'agent installe sur place. Ailleurs, le patron reçoit **l'APK et une vidéo** par WhatsApp et doit pouvoir **tout faire seul**. Règles de l'assistant :
- **un seul geste par écran** ;
- une **voix** lit chaque consigne (bouton haut-parleur toujours visible) ;
- une **capture d'écran** montre ce que le patron doit voir sur son téléphone ;
- un **bouton « J'ai besoin d'aide »** sur chaque écran ouvre WhatsApp vers le numéro d'assistance avec un **code de diagnostic** (étape bloquée, modèle du téléphone, version Android), **sans aucune donnée de la boutique** ;
- on peut **reprendre où l'on s'est arrêté** si le téléphone s'éteint ou si l'appel coupe.

| # | Étape | Ce que fait l'application |
|---|---|---|
| 0 | *(Avant l'application, dans la vidéo)* Autoriser l'installation depuis WhatsApp (« sources inconnues ») et installer l'APK | — |
| 1 | **Vérification du téléphone** | Contrôle automatique : version d'Android, **services Google présents** (sinon message clair : « Ce téléphone n'est pas compatible »), place libre, voix française installée. Chaque point est affiché en vert ou en rouge, avec la solution. |
| 2 | **Créer le compte de la boutique** | L'application explique les règles (numéro du **patron**, 18 ans ou plus) puis **ouvre elle-même l'écran Android « Ajouter un compte Google »**. Une voix guide les étapes 2 à 12 du §2.5. Au retour, elle vérifie que le nouveau compte existe. |
| 3 | **Validation en deux étapes et codes de secours** | Ouvre la page Google correspondante, puis demande au patron de **photographier ou recopier ses codes de secours**. |
| 4 | **Se connecter à Zéro Perte avec ce compte** | Choix du compte, autorisation `drive.appdata` (l'écran Google explique que l'application ne voit que ses propres données). |
| 5 | **Activation** | Le patron touche le **lien d'activation** reçu sur WhatsApp, ou scanne le QR code. |
| 6 à 12 | **Personnalisation** (§4.1) | — |
| 13 | **Réglage batterie** | Guide **selon la marque** (Tecno, Infinix, Itel, Samsung, Xiaomi…) pour que Zéro Perte ne soit pas coupée en tâche de fond. L'application vérifie ensuite que le réglage est fait. |
| 14 | **Ajouter le téléphone du vendeur** | Le téléphone du patron affiche un QR code. Sur le téléphone du vendeur, l'assistant (mode « vendeur ») fait ajouter le compte de la boutique : le **patron** tape le mot de passe et reçoit le code sur **son** téléphone. Ensuite, le vendeur scanne le QR code. |
| 15 | **Test final** | « Faites une vente test de 100 F sur le téléphone du vendeur. » En moins d'une minute (relève forcée), la vente apparaît chez le patron, et une alerte test arrive par le relais. Tout est vert : l'installation est terminée. La vente test est annulée automatiquement, avec le motif « test ». |

### 4.1 La personnalisation (dans l'assistant, un geste par écran, avec la voix)

| # | Écran | Détail |
|---|---|---|
| 6 | **Langue et voix** | Français pour l'instant (voix pré-enregistrées en éwé, mina et kabiyè plus tard). |
| 7 | **Type de boutique** | Grandes images des **catégories de `categories.md`**. Plusieurs choix possibles (par ex. alimentation + boissons). |
| 8 | **Nom de la boutique + logo ou photo** | Nom tapé ou **dicté** (reconnaissance vocale d'Android). Photo prise avec l'appareil photo et recadrée en rond. Sans photo, un **logo avec les initiales** dans la couleur choisie. |
| 9 | **Téléphone et adresse** | Numéro du patron (pré-rempli), ville choisie dans une liste, quartier en texte libre ou dicté, repère (« en face de la pharmacie… »). |
| 10 | **Couleur** | 8 pastilles, avec un **aperçu en direct**. Le **vert et le rouge restent réservés** à l'argent qui entre et qui sort. |
| 11 | **Mes produits** | Le catalogue des types choisis s'affiche en **grille de photos**. Le patron touche « Je vends ça » sur chaque produit, puis entre **le prix** (ou plus tard). Les unités sont déjà réglées et modifiables. Il peut aussi passer cette étape et ajouter ses produits plus tard. |
| 12 | **Le reçu et les codes PIN** | **Aperçu du reçu** (logo, nom, téléphone, adresse, message de bas de page). Ensuite : PIN du patron, puis nom et PIN du vendeur. |

### 4.2 Ce que la personnalisation change

- **Dans l'application** : nom et logo de la boutique en haut de chaque écran, couleur de la boutique, écran de démarrage avec son logo.
- **Reçus et messages WhatsApp** : en-tête et signature de la boutique.
- **Raccourci sur l'écran d'accueil du téléphone** : un **raccourci avec le logo et le nom de la boutique** (« Boutique Mama Ama »).
- **Limite honnête** : l'**icône principale** de l'application et son nom dans la liste des applications restent « Zéro Perte ». Les changer exigerait un APK par boutique, ce qui contredit la décision « une seule application ».
- La personnalisation est enregistrée **dans le Drive de la boutique**. Elle revient donc automatiquement sur un nouveau téléphone.

### 4.3 Les catalogues préremplis

- La **liste des types de boutiques et des unités** est dans **`docs/categories.md`**.
- Un **fichier par type de boutique** : produits, noms courants (y compris les noms locaux), unités et conversions, catégorie et image.
- Une copie est **intégrée à l'APK** (fonctionne sans Internet). Une version à jour est publiée sur **Cloudflare Pages** (§2.2) : on peut enrichir les catalogues **sans nouvel APK**.
- **Images** : illustrations simples et libres de droits, ou photos prises par votre équipe dans de vraies boutiques. On évite les logos de marques. Le patron peut remplacer chaque image par **sa propre photo**.
- **Prix** : **non préremplis**, car ils varient trop selon la ville et le quartier. C'est le patron qui les fixe.

---

## 5. Architecture retenue (schéma)

```
 Téléphone VENDEUR                    Google Drive de la BOUTIQUE                 Téléphone PATRON
 (base locale complète)               (dossier caché de l'application)            (base locale complète, jamais effacée)
 ┌─────────────────────┐   envoi     ┌────────────────────────────────┐  relève    ┌──────────────────────────┐
 │ ventes, caisse,     │ ──────────▶ │ journal-A-*.json.gz (signés,    │ ─────────▶ │ tableau de bord,         │
 │ dépenses, stock     │             │   numérotés, chaînés)           │ ◀───────── │ contrôle des trous,      │
 │ (on ajoute, on ne   │ ◀────────── │ journal-P-*, vie-A.json,        │  envoi /   │ re-dépôt si Drive vidé,  │
 │  modifie jamais)    │   relève    │ telephones.json, réglages       │  re-dépôt  │ alertes locales          │
 └─────────┬───────────┘             └────────────────────────────────┘            └──────────────────────────┘
           │ alerte grave (code court chiffré, ne dépend PAS du compte Google)                   ▲
           └──────────▶ relais Cloudflare Worker (gratuit) ──▶ Firebase Cloud Messaging (gratuit) ┘ instantanée
           (option, désactivée par défaut) SMS de secours sans Internet, payé par la boutique ──────▶ patron

 Dépôt GitHub PRIVÉ (code) ──GitHub Actions──▶ Cloudflare Pages : APK arm64 + armv7, version.json signé,
                                               catalogues, liste noire (lien fixe, 0 F, sans carte bancaire)
```

---

## 6. Sources vérifiées

- Permissions Google Drive (`drive.appdata` recommandée et non sensible) : [Choose Google Drive API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- Applications non vérifiées et limite de 100 utilisateurs (permissions sensibles ou restreintes seulement) : [Unverified apps](https://support.google.com/cloud/answer/7454865)
- Vérification des applications : [FAQ vérification OAuth](https://support.google.com/cloud/answer/13463817)
- Limites de l'API Drive : [Usage limits](https://developers.google.com/workspace/drive/api/guides/limits)
- Nouveau modèle de quotas Google Workspace (2026) : [Google Workspace API tiering model](https://developers.google.com/workspace/tools-safety)
- Sauvegarde automatique Android (25 Mo, 24 h) : [Back up user data with Auto Backup](https://developer.android.com/identity/data/autobackup)
- Limite d'utilisation d'un numéro pour vérifier un compte Google : [Verify your account (Google)](https://support.google.com/accounts/answer/114129), [étude universitaire, 2 par jour et environ 10 au total](https://par.nsf.gov/servlets/purl/10356388), [forum Google : compteur non réinitialisable](https://support.google.com/accounts/thread/13443342/phone-number-limit?hl=en)
- Firebase, offre gratuite : [Firebase pricing](https://firebase.google.com/pricing), [Realtime Database limits](https://firebase.google.com/docs/database/usage/limits)
- Firebase Hosting (APK interdits sur Spark, fichiers de 2 Go max., 10 Go/mois) : [Hosting FAQ](https://firebase.google.com/docs/hosting/faq-and-troubleshooting)
- Firebase App Distribution (500 testeurs, 150 jours) : [Troubleshooting](https://firebase.google.com/docs/app-distribution/troubleshooting)
- Cloudflare Pages (25 Mio par fichier, 20 000 fichiers, 500 déploiements/mois) : [Pages limits](https://developers.cloudflare.com/pages/platform/limits) ; bande passante et usage commercial selon une source secondaire : [temps.sh](https://temps.sh/blog/cloudflare-pages-free-tier-limits-2026)
- Cloudflare R2 (carte bancaire : informations contradictoires) : [R2](https://www.cloudflare.com/developer-platform/products/r2/), [R2 pricing](https://developers.cloudflare.com/r2/pricing)
- Netlify (crédits, environ 15 Go/mois) : [Credit-based pricing](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/)
- Supabase, offre gratuite : [Pricing](https://supabase.com/pricing), [Project pausing](https://supabase.com/docs/guides/platform/free-project-pausing), [Egress](https://www.supabase.com/docs/guides/platform/manage-your-usage/egress)
- Cloudflare Workers et D1 : [Workers pricing](https://developers.cloudflare.com/workers/about/pricing), [D1 limits](https://developers.cloudflare.com/d1/platform/limits), [D1 : application des limites gratuites (sept. 2026)](https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/)

*Certaines limites diffèrent d'une page à l'autre chez Google et Cloudflare : elles seront revérifiées au moment de coder les étapes concernées. Les calculs sont des estimations prudentes, à confirmer pendant le pilote en mesurant le volume réel par boutique.*
