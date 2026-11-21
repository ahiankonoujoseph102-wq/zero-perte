# Zéro Perte — Analyse avant développement (mission 1)

*Date : 21 novembre 2026. Aucun code n'a été écrit à cette étape.*

---

## 0. En une phrase

Le plan du chef de projet est **bon dans l'esprit**. Mais il oublie le **premier trou par lequel l'argent disparaît** : la vente que le vendeur **n'enregistre pas du tout**. Aucun bouton, aucun code PIN ne peut l'empêcher. Seuls l'**inventaire fréquent** et l'**écart chiffré en francs** la révèlent. C'est donc l'inventaire, et non la caisse, qui doit être au cœur de Zéro Perte.

---

## 1. Ce que font les meilleurs logiciels du marché

| Logiciel | Pays / public | Ce qu'il fait de mieux | Ce qui ne va pas pour nos clients |
|---|---|---|---|
| **Loyverse POS** | Mondial, gratuit, très utilisé en Afrique | Gestion des **équipes (shifts)** : à la fermeture, le caissier compte l'argent **sans voir le montant attendu** (« comptage aveugle »). Le patron voit l'attendu, le compté et l'écart. Il trace aussi les entrées et sorties d'argent hors vente et fixe les droits par employé. Des outils comme *POS Detective* repèrent les annulations et remises suspectes. | L'interface est pensée pour des gens qui lisent bien. Le **mode hors ligne** est limité (le bureau du patron passe par le web). Il ne connaît ni le crédit client à l'africaine ni les unités sac, tas ou bol. |
| **Vyapar** | Inde, PME | Fonctionne **hors ligne**, crée des factures, gère le stock, les créances et les **rappels de paiement automatiques**. | Il est trop riche et trop « comptable » (TVA, factures). C'est exactement ce qu'il faut éviter. |
| **Khatabook** | Inde, des millions de boutiquiers | C'est un **cahier de crédit numérique** : chaque client a son solde. Le rappel part par **WhatsApp ou SMS en un geste**. L'application existe en plus de 10 langues. | Il fait seulement le crédit : pas de stock, pas de contrôle des employés. |
| **OkCredit** | Inde | Interface « **comme WhatsApp** », très simple. Rappel automatique de chaque dette avec un lien de paiement. Fonctionne hors ligne. Relevé en PDF. | Même limite : c'est seulement un cahier de crédit. |
| **Proboutik / Digicaisse (Orange Business)** | Sénégal, commerçants informels | Remplace le cahier du boutiquier : trésorerie, rappels de paiement. **Digicaisse (2025) a ajouté une interface vocale** pour les commerçants qui lisent mal. C'est le concurrent le plus proche de notre idée. | Il n'est pas disponible au Togo à notre connaissance. On a peu de détails sur la lutte contre le vol. |
| **Lumi Business** | Nigeria | Caisse avec **mode hors ligne** ajouté parce que le réseau coupe. | Il est en anglais et vise le Nigeria. |

### Leçons à retenir

1. **Comptage aveugle à la fermeture** (Loyverse). C'est la meilleure idée anti-vol du marché, et elle ne coûte presque rien à faire.
2. **Le crédit est un cahier simple** (Khatabook, OkCredit) : une liste de clients avec un gros solde rouge et un bouton « Rappeler sur WhatsApp ».
3. **La voix** (Digicaisse) sert vraiment aux commerçants peu lettrés. Personne au Togo ne le propose encore : c'est une chance pour nous.
4. **Le hors ligne n'est pas une option** en Afrique de l'Ouest. Tous ceux qui réussissent l'ont.
5. **La simplicité gagne** : OkCredit a battu des logiciels plus complets parce qu'il ressemble à WhatsApp.

---

## 2. Adaptation au Togo

### 2.1 Argent

- **Franc CFA (XOF) sans centimes.** Tous les montants sont des **nombres entiers**, jamais de virgule. Affichage : `12 500 F`, avec une espace tous les 3 chiffres.
- Les prix « bizarres » (par exemple 1 sac à 23 000 F vendu au détail à 175 F le bol) créent des arrondis. La règle : **le patron fixe le prix de détail lui-même**, et l'application ne le calcule jamais seule. Elle affiche seulement le bénéfice ou la perte par sac obtenu avec ce prix.
- **Monnaie à rendre** : la petite monnaie manque souvent. L'application doit permettre de noter « **monnaie due au client** » (petite dette de la boutique), ou un arrondi accepté, pour que la caisse reste juste.

### 2.2 Mobile Money au Togo (vérifié en novembre 2026)

| Service | Opérateur | Remarque |
|---|---|---|
| **Mixx by Yas** | Yas (ex-**Togocom**) | C'est l'**ancien T-Money**, renommé fin 2024. Environ 60 % du marché. Raccordé en 2026 à la plateforme interopérable de la BCEAO (PI-SPI). |
| **Flooz** | **Moov Africa** Togo | Environ 40 % du marché. |
| **Gozem Money** | Gozem (avec NSIA) | Nouveau venu (fin 2025), frais de retrait plus bas. Peu répandu chez les boutiquiers pour l'instant. |

> Les gens disent encore souvent « T-Money ». L'application doit afficher **« Mixx (T-Money) »** et **« Flooz »** avec les **couleurs et logos reconnaissables** (attention aux droits sur les logos : utiliser une simple pastille de couleur et le nom).

**Important : on ne peut pas vérifier automatiquement qu'un paiement Mobile Money est réellement arrivé** sans contrat avec un agrégateur de paiement. Un vendeur malhonnête peut donc dire « le client a payé par Flooz » alors qu'il a pris des espèces. Parades proposées pour la V1 :

- Le vendeur saisit les **4 derniers chiffres de la référence** de la transaction (ou le numéro du client).
- Le soir, le patron compare la liste des paiements Mobile Money de l'application avec **son propre historique** Flooz et Mixx. L'application lui donne cette liste prête à cocher.
- Plus tard (V2) : intégration d'un agrégateur local (par exemple PayGate Global, FedaPay ou CinetPay ; à étudier) pour une confirmation automatique.

### 2.3 Internet qui coupe

- L'application doit **tout faire sans Internet** : vendre, encaisser, fermer la caisse, faire l'inventaire.
- La synchronisation se fait **en arrière-plan** dès qu'il y a du réseau, même faible, par petits paquets.
- Un **voyant visible** indique : vert = tout est envoyé au patron ; orange = X opérations en attente ; rouge = rien envoyé depuis plus de 24 h.
- **Risque** : si le vendeur désinstalle l'application ou efface ses données avant l'envoi, ces ventes sont perdues. Il faut donc synchroniser souvent, **alerter le patron si un téléphone ne s'est pas synchronisé depuis X heures**, et détecter les « trous » dans les numéros de reçu.

### 2.4 Téléphones d'entrée de gamme

- Cible : Android 8 ou plus récent (Android Go compris), **1 à 2 Go de mémoire**, écran de 5 à 6 pouces, stockage souvent plein.
- Taille de l'APK visée : **moins de 15 Mo**.
- **Les photos de produits sont réduites** (environ 300×300 pixels, moins de 30 Ko chacune), sinon le téléphone sature et la synchronisation coûte cher en données.
- Il faut tester sur un vrai téléphone bas de gamme (Itel, Tecno, Infinix) avant chaque livraison.

### 2.5 Langues et lecture

- Le français est la langue officielle. **Éwé** (avec le **mina**, sa variante de Lomé) et **kabiyè** sont les deux langues nationales. Environ un tiers des adultes ne lit pas ou lit mal, et la part qui lit couramment le français est plus faible encore.
- Proposition V1 :
  - **Tout passe par l'image** : photo du produit, icônes, couleurs fixes, chiffres géants. Le texte n'est qu'un complément.
  - **Lecture à voix haute en français** grâce à la synthèse vocale d'Android, qui marche sans Internet si la voix française est installée (à vérifier sur les téléphones des clients).
  - **Voix en éwé, mina ou kabiyè** : aucune synthèse vocale fiable n'existe. Solution : **enregistrer nous-mêmes de courts fichiers audio** (chiffres, « total », « monnaie à rendre »…). C'est faisable pour les chiffres et une vingtaine de phrases. **À prévoir en V1.5**, après validation du reste.
- **Nom des produits** : le patron peut **enregistrer le nom à voix haute** en plus de la photo. Le vendeur qui ne lit pas appuie sur la photo et entend le nom.

### 2.6 Unités de vente réelles

Dans les boutiques togolaises, un même produit s'achète en gros et se vend au détail :

- riz, maïs, haricot, gari : **sac** (25 ou 50 kg) → **bol**, **tohoungbé / mesure**, **demi-bol**, **kilo** ;
- boissons : **casier** → **bouteille** ;
- savon, lait, sucre en morceaux, biscuits : **carton** → **paquet** → **pièce** ;
- huile, pétrole : **bidon** (25 L) → **litre** → **bouteille** ;
- tomates, piment, oignons : **tas** ;
- cigarettes, bonbons : **paquet** → **pièce**.

Modèle proposé : chaque produit a **une unité de base** (la plus petite qu'on compte, par exemple le bol) et **des conditionnements** avec leur facteur de conversion (1 sac = 40 bols) et **leur propre prix**.

> **Attention :** le bol et le tas sont **approximatifs**. Un sac ne donne pas toujours exactement 40 bols. L'inventaire de ces produits aura donc toujours un petit écart « normal ». Le patron doit pouvoir fixer une **tolérance** (par exemple 3 %) pour que l'application ne crie pas au vol à chaque fois.

Il faut aussi un **arrivage en gros, avec ouverture du sac** : le patron (ou le vendeur, avec trace) note « j'ai ouvert 1 sac », et le stock passe de 1 sac à 40 bols.

### 2.7 Habitudes de crédit

- Le crédit client (« donner à crédit », « ardoise ») est **quotidien**. C'est aussi une **source de vol** : le vendeur peut inventer un crédit à un « client » pour couvrir de l'argent pris.
  → Règle : un crédit doit être fait à un **client enregistré** (nom + numéro de téléphone, photo si possible). Un **plafond par client** est fixé par le patron. Au-delà du plafond, le PIN du patron est demandé.
  → Le client reçoit **son reçu de crédit par WhatsApp** : il confirme lui-même sa dette. C'est le meilleur contrôle anti-fraude, car un faux crédit sera contesté.
- **Remboursements partiels** fréquents : le solde est mis à jour à chaque paiement, avec un reçu.
- **Crédit fournisseur** (la boutique doit de l'argent au grossiste) : absent du plan, mais très courant. **À ajouter**, au moins côté patron.
- **Rappel en un geste** par WhatsApp, avec un message prêt en français simple (et vocal plus tard).

---

## 3. Critique du plan

### 3.1 Ce qui manque (important)

1. **La vente non enregistrée.** C'est la fraude n°1 : le client paie, le vendeur ne touche pas l'application et garde l'argent. **Aucun code PIN ne l'empêche.** Seul l'**inventaire** la révèle. Il faut donc :
   - un **inventaire tournant** : chaque jour, l'application demande au vendeur (ou au patron) de compter **3 à 5 produits tirés au hasard**, surtout les plus chers et ceux qui partent vite. L'écart s'affiche **en francs**. Le vendeur ne sait pas à l'avance quels produits seront comptés ;
   - un **comptage aveugle** : la personne qui compte ne voit pas la quantité attendue ;
   - un **suivi des écarts par vendeur et par période**, pour voir quand l'argent disparaît.
2. **Comptage aveugle de la caisse** (idée de Loyverse) : à la fermeture, le vendeur saisit ce qu'il a compté (espèces, Flooz, Mixx) **sans voir ce qui est attendu**. Sinon il ajuste simplement.
3. **Fonds de caisse** : l'argent laissé le matin pour rendre la monnaie. Sans lui, l'écart du soir est faux.
4. **Retraits du patron** : le patron prend souvent de l'argent dans la caisse. S'il ne le note pas, la caisse paraît volée. Il faut un bouton **« Le patron a pris »** (avec son PIN).
5. **Pertes déclarées** : casse, produit périmé, pourri, mangé par les rats, consommé par la famille. Sans ce bouton, toute perte ressemble à un vol, ou le vendeur la cache.
6. **Retour d'un produit par un client** : à traiter comme une annulation tracée.
7. **Crédit fournisseur** (voir 2.7).
8. **Gestion des abonnements et licences** : l'APK circule librement sur WhatsApp. N'importe qui peut l'installer. Il faut que **chaque boutique soit activée par vous** (code d'activation) et puisse être **suspendue** si l'abonnement n'est pas payé.
9. **Mise à jour de l'application** : avec un APK sur WhatsApp, les clients gardent de vieilles versions. Il faut un **bouton « Nouvelle version disponible »** dans l'application, qui télécharge le nouvel APK depuis un lien fixe.
10. **Sauvegarde et récupération** : téléphone volé, tombé dans l'eau, ou réinitialisé. Le patron doit pouvoir **réinstaller et tout retrouver** depuis le serveur.
11. **Horloge du téléphone** : un vendeur peut changer la date et l'heure pour fausser l'historique. L'application doit noter l'heure du serveur à chaque synchronisation et **signaler les décalages**.
12. **Plusieurs téléphones dans une même boutique** (patron + vendeur, ou 2 vendeurs) : la numérotation des reçus « sans trou » doit fonctionner **sans Internet**. Solution : un **préfixe par téléphone** (A-0001, B-0001…).

### 3.2 Ce qui est inutile ou trop compliqué pour la V1

- **Ventes de la semaine et du mois avec graphiques** : garder seulement **trois gros chiffres** (aujourd'hui, cette semaine, ce mois) et une comparaison simple (« mieux / moins bien que la semaine dernière »). Pas de graphiques en V1.
- **Lecture à voix haute de tout** : en V1, lire seulement le **total**, la **monnaie à rendre** et le **nom du produit touché**. Ne pas lire les menus.
- **Bénéfice « réel » exact** : le prix d'achat change d'un arrivage à l'autre. En V1, utiliser le **dernier prix d'achat** (ou une moyenne simple) et l'afficher clairement comme « bénéfice estimé ». Une méthode comptable (premier entré, premier sorti) serait trop complexe.
- **4 boutons sur l'écran d'accueil** : c'est bien, mais **Stock** n'est pas une action du vendeur au quotidien. Pour le vendeur, je propose **Vendre (vert, énorme)**, **Crédit**, **Dépense**, **Fermer la caisse**. Le stock, les prix et les arrivages sont dans l'espace du patron.
- **Résumé du soir envoyé sur WhatsApp automatiquement** : l'envoi automatique par WhatsApp passe par l'API WhatsApp Business, qui est **payante** et lourde à mettre en place. En V1 : **notification dans l'application du patron** + un bouton pour partager le résumé lui-même.

### 3.3 Les risques

| Risque | Gravité | Parade |
|---|---|---|
| Le vendeur n'enregistre pas des ventes | Très forte | Inventaire tournant aveugle, écart en francs, suivi par vendeur |
| Perte de la **clé de signature** de l'APK | Très forte : plus aucune mise à jour possible, les clients doivent désinstaller et **perdent leurs données locales** | Clé générée une seule fois, gardée dans les secrets GitHub **et** en copie sûre chez vous (Google Drive privé + papier) |
| Android bloque l'installation (« sources inconnues », Play Protect) | Forte | Guide pas à pas en images et en vocal ; viser le Play Store dès que possible |
| Supabase gratuit **met le projet en pause** après 7 jours d'inactivité, et ne fait **pas de sauvegarde quotidienne** | Moyenne | Avec des boutiques actives, le projet ne s'endort pas. Passer au plan Pro (environ 25 $/mois, soit environ 15 000 F) dès que les abonnements le paient, pour les sauvegardes |
| Conflits de synchronisation (deux téléphones modifient la même chose) | Moyenne | Concevoir les données en **« on ajoute, on ne modifie jamais »** (voir 4.2) : presque plus aucun conflit |
| Fausses déclarations Mobile Money | Moyenne | Référence obligatoire + rapprochement par le patron le soir |
| Faux crédits | Moyenne | Client enregistré, plafond, reçu WhatsApp au client |
| Le patron partage son PIN avec le vendeur | Moyenne | Alerte si le PIN patron est utilisé alors que le patron est « absent » (sur son propre téléphone ailleurs) ; changement de PIN facile |
| Trop de fonctions trop tôt | Forte | Petites étapes, **pilote dans 1 ou 2 boutiques réelles** avant de distribuer |
| Clients déjà payés qui attendent | Forte | Leur livrer vite une version simple qui marche (étapes 1 à 6), puis enrichir |
| Protection des données (dettes des clients, chiffre d'affaires) | Moyenne | Données isolées par boutique (règles de sécurité Supabase), aucun accès croisé ; mentions simples sur l'usage des données |

---

## 4. Choix techniques

### 4.1 Avis sur les choix proposés

| Choix proposé | Avis |
|---|---|
| Hors ligne d'abord, synchro au retour du réseau | ✅ **Indispensable.** C'est la bonne décision. |
| Supabase (gratuit au départ) | ✅ **Bon choix** (base PostgreSQL standard, règles de sécurité par boutique, connexion intégrée). Il faut connaître les limites du plan gratuit (500 Mo, pause après 7 jours d'inactivité, pas de sauvegarde quotidienne) et prévoir le passage payant. |
| APK fabriqué par GitHub Actions | ✅ **Très bon choix** pour travailler sans ordinateur : vous demandez une modification, GitHub fabrique l'APK et vous le téléchargez depuis votre téléphone. |
| Une seule application, un compte par boutique | ✅ **Oui.** Une seule application, qui affiche l'espace patron ou l'espace vendeur selon le PIN. |

### 4.2 Architecture recommandée

- **Base locale SQLite** sur le téléphone. Elle fait foi tant qu'il n'y a pas de réseau.
- **Données « on ajoute, on ne modifie jamais »** : chaque vente, paiement, dépense, mouvement de stock ou annulation est une **nouvelle ligne** avec un identifiant unique, l'auteur, l'heure du téléphone et le téléphone d'origine. Le stock n'est pas une case qu'on modifie. C'est **la somme des mouvements**. Avantages :
  - c'est exactement la règle « aucune suppression, seulement des annulations » ;
  - **la synchronisation devient simple et sans conflit** (on envoie les nouvelles lignes, on reçoit celles des autres) ;
  - l'historique complet sert de preuve en cas de vol.
- Les seules données modifiables (produits, prix, employés, réglages) sont **réservées au patron**. En cas de conflit, la **dernière modification gagne**, et l'ancien prix est gardé dans un historique.
- **Synchronisation** : une petite file d'attente maison (envoi des nouvelles lignes, puis réception de celles des autres depuis le dernier passage). C'est suffisant grâce au modèle « on ajoute seulement ». Alternative si besoin : **PowerSync**, un outil spécialisé compatible avec Supabase et Flutter, avec plan gratuit. À garder en réserve pour ne pas dépendre d'un service de plus dès le début.
- **Comptes** :
  - **un compte Supabase par boutique (le patron)**, créé par vous avec un numéro de téléphone + un mot de passe, ou un e-mail ;
  - les **vendeurs ne sont pas des comptes Internet** : ce sont des profils locaux avec un PIN, créés par le patron ;
  - un nouveau téléphone est **relié à la boutique en scannant un QR code** affiché sur le téléphone du patron, ou avec un code à 6 chiffres. On évite ainsi les SMS de vérification, qui sont payants.
- **PIN** : stockés de façon chiffrée, jamais en clair. Blocage après 5 essais ratés.

### 4.3 Technologie pour fabriquer l'APK sans ordinateur

| Option | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| **Flutter (Dart)** | Une seule base de code ; rapide même sur téléphone bas de gamme ; très bonne prise en charge de SQLite, de la synthèse vocale, du partage WhatsApp, de l'appareil photo et des QR codes ; bibliothèque Supabase officielle ; se compile très bien avec GitHub Actions ; APK d'environ 8 à 12 Mo par type de processeur | APK un peu plus lourd qu'une application Android pure | ⭐ **Recommandé** |
| Kotlin + Jetpack Compose (Android natif) | APK le plus léger, performances maximales | Plus de code à écrire et à maintenir ; aucune possibilité d'iPhone ou de web plus tard | Bon second choix |
| React Native / Expo | JavaScript, très répandu | Le service de compilation Expo (EAS) est limité en version gratuite ; plus lourd sur les petits téléphones | Non |
| Application web (PWA) | Pas d'APK à installer | Android peut effacer les données locales d'un site ; moins fiable hors ligne ; pas de vrai fichier APK | Non |
| Générateurs « sans code » (FlutterFlow, AppSheet…) | Rapide au début | Abonnement payant, limites, contrôle difficile de la logique anti-fraude et du hors ligne | Non |

**Chaîne de fabrication proposée (100 % depuis votre téléphone) :**

1. Vous demandez un changement (à moi ou au chef de projet) → le code est modifié dans GitHub.
2. **GitHub Actions** compile un APK **signé** avec la clé de la boutique Zéro Perte (gardée dans les secrets GitHub).
3. L'APK est publié dans une **« Release » GitHub** avec un **lien fixe** (« dernière version »).
4. Vous ouvrez le lien sur votre téléphone, vous installez et vous testez.
5. Quand c'est validé, l'application de vos clients voit « Nouvelle version disponible » et se met à jour toute seule depuis ce lien.

> GitHub Actions est gratuit et illimité pour un dépôt public, et limité à 2 000 minutes par mois pour un dépôt privé, ce qui suffit largement (une compilation prend environ 5 à 10 minutes). **Le dépôt doit rester privé**, car il contient votre produit commercial.

---

## 5. Découpage de la version 1 en petites étapes

Chaque étape produit **un APK que vous pouvez installer et tester**. On ne passe à la suivante qu'après votre validation.

### Bloc A — Les fondations (invisible mais vital)

| # | Étape | Ce que vous voyez à la fin |
|---|---|---|
| A1 | Projet Flutter vide + GitHub Actions qui fabrique un **APK signé** + lien de téléchargement fixe | Une application « Zéro Perte » qui s'installe sur votre téléphone |
| A2 | Base locale avec le modèle « on ajoute seulement » ; montants en entiers ; identifiants uniques ; numéro de téléphone d'origine | Rien de visible (tests automatiques) |
| A3 | Style visuel : gros boutons, couleurs fixes (vert = entre, rouge = sort), chiffres géants, format `12 500 F` | Écran d'accueil avec les gros boutons (vides) |

### Bloc B — Une boutique qui marche sur un seul téléphone (hors ligne)

| # | Étape |
|---|---|
| B1 | **Patron** : créer la boutique, son PIN, ajouter des **produits** (photo réduite, nom, nom vocal enregistré, prix de vente, prix d'achat, unité de base) |
| B2 | **Conditionnements** : sac → bol, casier → bouteille, carton → pièce, avec un prix pour chacun ; **ouverture d'un sac** |
| B3 | **Arrivages** (patron seulement) : entrée de stock, prix d'achat |
| B4 | **Vendre** : grille de photos, + et −, total géant lu à voix haute, saisie du montant reçu, **monnaie à rendre**, paiement en espèces / Flooz / Mixx (avec référence) ; le stock baisse |
| B5 | **Vendeurs** : création par le patron, PIN, **auteur et heure sur chaque action**, blocage d'un vendeur |
| B6 | **Annulation avec motif** (jamais de suppression) ; retour client ; **perte déclarée** (casse, périmé) |
| B7 | **Dépenses**, **retrait du patron**, **fonds de caisse** du matin |
| B8 | **Fermeture de caisse en comptage aveugle** (espèces, Flooz et Mixx séparés) → écart affiché au patron |
| B9 | **Reçu numéroté sans trou** (préfixe par téléphone), partagé par WhatsApp en un geste (image du reçu) |
| B10 | **Tableau du patron** : ventes du jour, de la semaine et du mois, bénéfice estimé, stock bas |

➡️ **Premier pilote** dans 1 ou 2 boutiques réelles (idéalement celles de clients qui ont déjà payé), pour corriger l'interface avec de vrais vendeurs.

### Bloc C — Crédit et inventaire (le cœur anti-perte)

| # | Étape |
|---|---|
| C1 | **Clients à crédit** : fiche (nom, téléphone, photo), plafond, vente à crédit, **remboursement partiel**, reçu de crédit envoyé au client par WhatsApp, bouton « Rappeler » |
| C2 | **Inventaire complet** en comptage aveugle → écart **en francs** par produit, avec tolérance pour les produits au bol ou au tas |
| C3 | **Inventaire tournant quotidien** (3 à 5 produits au hasard, priorité aux produits chers et rapides) |
| C4 | **Crédit fournisseur** (côté patron) |

### Bloc D — Le patron à distance

| # | Étape |
|---|---|
| D1 | Compte boutique sur Supabase, **règles de sécurité par boutique**, code d'activation fourni par vous |
| D2 | **Liaison d'un téléphone** à la boutique par QR code ou code à 6 chiffres |
| D3 | **Synchronisation** en arrière-plan + voyant vert / orange / rouge + contrôle de l'heure du téléphone |
| D4 | **Application patron à distance** : il voit tout en direct (ventes, caisse, stock, crédits) depuis son propre téléphone |
| D5 | **Notifications** au patron : annulation, écart de caisse, écart d'inventaire, stock bas, téléphone non synchronisé, PIN patron utilisé en boutique |
| D6 | **Résumé du soir** (notification + bouton de partage WhatsApp) |
| D7 | **Restauration** complète d'une boutique sur un nouveau téléphone |

### Bloc E — Mise en service commerciale

| # | Étape |
|---|---|
| E1 | **Mise à jour intégrée** (« Nouvelle version disponible ») |
| E2 | **Licences** : activation et suspension d'une boutique par vous ; petit tableau de bord « mes clients » pour vous |
| E3 | Guide d'installation en images et en vocal (à partager sur WhatsApp) |
| E4 | Déploiement chez tous les clients, avec migration de leurs données actuelles si besoin |

### Version 1.5 / 2 (plus tard)

Voix en éwé, mina et kabiyè (audios enregistrés) ; confirmation automatique des paiements Mobile Money via un agrégateur ; code-barres ; impression Bluetooth ; plusieurs boutiques par patron ; publication sur le Play Store.

---

## 6. Questions à vous poser avant de commencer

### Sur vos clients actuels
1. Combien de clients ont déjà payé, combien ont-ils payé, et **qu'est-ce qu'on leur a promis** (fonctions, date) ?
2. Ont-ils **déjà une version** de Zéro Perte installée ? Si oui, faut-il récupérer leurs données ?
3. Quels **types de boutiques** : alimentation générale, boissons, quincaillerie, pharmacie, pièces détachées, marché ? (Cela change les unités et le nombre de produits.)
4. Combien de **produits** en moyenne par boutique : 30, 200, 1 000 ?
5. Combien de **vendeurs** par boutique, et combien de **téléphones** en boutique (un téléphone partagé, ou chaque vendeur le sien) ?
6. Le **téléphone de la boutique** appartient-il au patron ou au vendeur ?
7. Quels **modèles de téléphones** ont-ils (marque, ancienneté) ? Pouvez-vous m'envoyer la référence de 2 ou 3 téléphones réels ?

### Sur l'usage
8. Le **patron sait-il lire** ? Et les vendeurs ? Quelles **langues** parlent-ils au travail (français, éwé, mina, kabiyè, autre) ?
9. Quelles sont les **unités** les plus utilisées chez vos clients (sac, bol, tas, casier, mesure…) et leurs **noms locaux exacts** ?
10. Comment les clients paient-ils : quelle part en **espèces**, en **Flooz**, en **Mixx** ? Le patron a-t-il un **compte marchand** ou un simple numéro personnel ?
11. Le **crédit client** est-il fréquent chez eux ? Et le **crédit fournisseur** ?
12. Le patron veut-il **recevoir le résumé du soir** dans l'application, par WhatsApp, ou par SMS ?

### Sur le commerce et la technique
13. Quel est votre **modèle de prix** : paiement unique, abonnement mensuel, par boutique ? (Cela décide de la gestion des licences.)
14. Avez-vous déjà un **compte GitHub** (oui, ce dépôt) et un **compte Supabase** ? Acceptez-vous un petit coût mensuel (environ 15 000 F) quand le nombre de clients le justifie ?
15. Le dépôt GitHub est-il **privé** ? (Il doit l'être.)
16. Où voulez-vous garder la **copie de secours de la clé de signature** de l'APK (indispensable) ?
17. Acceptez-vous le choix de **Flutter** comme technologie ?
18. Avez-vous un **téléphone bas de gamme** pour tester, et **une boutique pilote** prête à essayer la première version ?
19. Le nom **« Zéro Perte »** et un logo sont-ils définitifs ? (Ils apparaissent sur les reçus.)
20. Faut-il afficher sur le reçu le **nom, l'adresse et le téléphone de la boutique** ? Y a-t-il une obligation fiscale (numéro NIF) pour vos clients ?

---

## 7. Sources consultées

- Loyverse : [Gestion des employés](https://loyverse.com/employee-management), [Gestion des équipes (shifts)](https://help.loyverse.com/help/shift-management-loyverse-pos), [Fonctionnalités](https://loyverse.com/features), [POS Detective](https://loyverse.com/marketplace/pos-detective)
- OkCredit : [site officiel](https://okcredit.in/en/), [rappels de paiement](https://okcredit.in/payment-reminder-app)
- Khatabook : [avis G2](https://www.g2.com/products/khatabook/reviews), [comparatif Khatabook / OkCredit](https://www.techjockey.com/compare/khatabook-vs-okcredit)
- Vyapar : [rappels de paiement](https://vyaparapp.in/guides/how-to-send-payment-reminders-in-vyapar)
- Proboutik / Digicaisse : [We Are Tech](https://www.wearetech.africa/fr/fils/solutions/senegal-proboutik-numerise-la-comptabilite-des-commercants-de-proximite), [Afrique IT News – Digicaisse](https://afriqueitnews.com/tech-media/digicaisse-orange-business-revolutionne-gestion-commercants-senegalais/)
- Caisse hors ligne en Afrique : [Kolonell (guide d'un prestataire, à prendre avec prudence)](https://kolonell.com/fr/blog/application-caisse-pos-boutique-afrique-2026)
- Mobile Money au Togo : [AXIAN – marques Yas et Mixx by Yas](https://www.zawya.com/en/press-release/companies-news/axian-telecom-launches-unified-pan-african-brands-for-its-mobile-network-operators-and-fintech-operations-bsaz2057), [Togo First – Mixx et la plateforme BCEAO](https://togofirst.com/en/finance/1404-18715-mixx-togo-joins-bceao-payment-platform-enabling-cross-border-transfers-across-uemoa), [Financial Afrik – Mixx interopérable (avril 2026)](https://www.financialafrik.com/en/2026/04/15/togo-mixx-by-yas-activates-interoperable-instant-transfers-within-the-uemoa/), [AllAfrica – Gozem Money](https://fr.allafrica.com/stories/202510150468.html), [AllAfrica – comptes Mobile Money au Togo](https://fr.allafrica.com/stories/202604010688.html)
- Langues et alphabétisation : [CEFAN – Togo](https://axl.cefan.ulaval.ca/afrique/togo.htm), [Atlas sociologique mondial](https://atlasocio.com/etats/fiches/t/togo.php), [AllAfrica – analphabétisme (2026)](https://fr.allafrica.com/stories/202610260691.html)
- Supabase : [mise en pause des projets](https://supabase.com/docs/guides/platform/free-project-pausing), [tarifs](https://supabase.com/pricing)
- Synchronisation hors ligne : [PowerSync + Supabase](https://www.powersync.com/blog/offline-first-apps-made-simple-supabase-powersync), [ElectricSQL vs PowerSync](https://powersync.com/blog/electricsql-vs-powersync)

*Les parts de marché Mobile Money (60/40) sont des estimations de presse. La présence de Wave au Togo n'a pas été confirmée et reste à vérifier.*
