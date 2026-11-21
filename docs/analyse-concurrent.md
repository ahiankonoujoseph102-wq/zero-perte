# Analyse d'un logiciel concurrent (caisse Windows « MikahPOS »)

*Source : deux courtes vidéos filmées dans une boutique (21 novembre 2026), regardées image par image.
Le son a été transcrit automatiquement, mais très mal (bruit, reflets) : seuls quelques mots sont sûrs
(« ouvrez la caisse », « tu comptes », « espèces… trois mille… valider », « message », « promotion »).
Les vidéos ne sont pas gardées dans ce dépôt.*

## 1. Ce qu'ils ont

- **Matériel** : ordinateur Windows avec écran tactile posé sur le comptoir. Le clavier de Windows
  s'ouvre à l'écran pour taper les montants (pas de clavier de chiffres dans le logiciel lui-même).
- **Entrée** : code à chiffres sur un pavé numérique.
- **Menu à gauche** d'environ **16 rubriques** : tableau de bord, caisse/ventes, devis/proforma, produits,
  stock, inventaire, stock interne, fournisseurs, clients, retours, messages, caisse, promotions (codes promo),
  rendez-vous, dépenses, rapports.
- **Tableau de bord** : revenus des 7 derniers jours (courbe), produits les plus vendus sur 30 jours.
- **Caisse** : ouverture avec un fonds initial, historique des sessions, fermeture.
- **Vente** : produits en cases (nom + prix, sans image) classés par catégories en onglets (Tous, Alimentation,
  Papeterie, Téléphonie…), panier à droite avec quantité, bouton « Sélectionner un client », total.
- **Encaissement** (fenêtre) : espèces, Mobile Money, carte, crédit ; montant reçu, monnaie à rendre, clavier
  de chiffres ; boutons « Annuler (Échap) » et « Valider (Entrée) ».
- **Messages** entre caissier, serveur et magasinier.
- **Dépenses** : liste avec totaux.
- **Clients** : liste.
- Thème sombre, petits textes, peu de contraste ; beaucoup de reflets sur l'écran filmé.

## 2. Ce que nous avons (Zéro Perte, version 0.16)

Téléphone Android (et bientôt tablette et PC Windows), entrée par code, accueil à **4 gros boutons**
(Vendre, Crédit, Dépense, Fermer la caisse) + espace patron ; vente par cases avec images/emoji,
panier, unités (kg, sac, bol…), « donne pour 100 F » ; encaissement espèces / Flooz / Mixx / crédit avec
**monnaie à rendre et billets à rendre détaillés**, voix ; reçu aux couleurs de la boutique envoyé sur
WhatsApp ; fonds de caisse, dépenses par icônes, argent pris par le patron ; **fermeture à l'aveugle**
(le vendeur ne voit pas l'attendu) ; vendeurs avec code, blocage ; annulations avec motif, pertes ;
tableau du patron (jour / semaine / mois, bénéfice estimé, stock bas, crédits) ; crédit client avec
plafond, remboursement, rappel WhatsApp ; journal infalsifiable ; sauvegarde chiffrée ; démonstration.

## 3. Ce que nous faisons mieux

| Point | Eux | Nous |
|---|---|---|
| Simplicité | 16 rubriques, petits textes | 4 gros boutons, icônes, voix, peu de mots |
| Matériel | PC + écran tactile (cher) | le téléphone du patron suffit |
| Saisie des montants | clavier de Windows à l'écran | clavier de chiffres géant intégré |
| Monnaie à rendre | un montant | le montant **et les billets/pièces** à rendre |
| Vol de caisse | fermeture où l'on voit l'attendu | **comptage à l'aveugle**, écart vu par le patron seul |
| Historique | non visible | journal en ajout seulement, annulations avec motif |
| Reçu | (non vu) | image aux couleurs de la boutique, envoyée sur WhatsApp |
| Crédit | mode de paiement « crédit » | fiche, plafond, remboursement partiel, rappel WhatsApp |
| Unités locales | (non vu) | sac / bol / tas, vente « pour 100 F » |
| Patron à distance | (non vu) | prévu (bloc D) |

## 4. Ce qui nous manque, et quand le faire

| Manque | Classement | Décision |
|---|---|---|
| Choisir un client dans le panier en un toucher (vente sans client par défaut) | **maintenant** | fait (0.18) |
| Boutons de billets à l'encaissement (1 000, 2 000, 5 000, 10 000 F, montant exact) | **maintenant** | nous les avions déjà ; liste ajustée (0.18) |
| Catégories en onglets dans la vente quand il y a beaucoup de produits | **maintenant** (petit) | fait : filtre par catégorie au-dessus des produits quand la boutique a plusieurs catégories (0.18) |
| Courbe des ventes des 7 derniers jours au tableau du patron | **maintenant** (petit) | fait : barres simples des 7 derniers jours (0.17) |
| Version PC Windows / grand écran tactile | **maintenant** | étapes 3 et 5 de la nuit |
| Carte bancaire | après la version 1 | rare dans nos boutiques |
| Devis / facture proforma | après la version 1 | décision du propriétaire |
| Retours partiels | après la version 1 | décision du propriétaire (Q7) |
| Inventaire | après la version 1 → bloc C2 prévu | |
| Fournisseurs (crédit fournisseur) | bloc C4 prévu | |
| Promotions / codes promo | après la version 1 | |
| Messages internes entre employés | jamais (trop compliqué pour notre cible) | WhatsApp fait déjà ce travail |
| Rendez-vous | jamais (pas notre métier : boutiques) | |
| Stock interne (magasin / réserve séparés) | après la version 1 | utile aux grossistes seulement |
| Menu de 16 rubriques | jamais | contraire à notre principe de simplicité |
| Raccourcis clavier (Échap / Entrée) | maintenant, sur PC (petit) | prévu avec la version Windows |
