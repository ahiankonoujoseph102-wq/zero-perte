# Essai de 30 minutes avant le premier client (2 vrais téléphones)

À faire UNE fois par le propriétaire ou un agent, avec 2 téléphones Android 8 ou plus (« A » = patron,
« B » = vendeur), Internet, et un compte Google réservé à la boutique d'essai. Utilisez un code
d'activation de test (action 4, nom « TEST … »).

| # | Étape | Résultat attendu | Si ça échoue |
|---|---|---|---|
| 1 | Sur A et B : installer `…/releases/latest/download/ZeroPerte.apk` | L'application s'ouvre sur « Installation » (pas de bandeau rouge « ESSAI ») | Autoriser l'installation depuis Chrome (Paramètres → Applications → Chrome → Installer des applis inconnues) |
| 2 | Sur A : assistant → **Activation** → coller le code | « Code accepté », nom de la boutique affiché | Copier TOUT le message (appui long → Copier) ; sinon refaire un code |
| 3 | Sur A : finir l'assistant (produits, prix, code patron 6 chiffres) | Accueil avec la carte « Aujourd'hui » et le gros bouton Vendre | Noter l'étape qui bloque, capture d'écran |
| 4 | Sur A : Gestion → **Produits et prix** → Ajouter « Savon test », 400 F, stock 10 | Le savon apparaît dans la liste et dans Vendre | Vérifier qu'on est bien entré avec le code PATRON |
| 5 | Changer le prix du savon à 450 F | La fiche montre l'historique 400 → 450 | — |
| 6 | Sur A : Gestion → Vendeurs → ajouter « Test » | Un code à 4 chiffres s'affiche | — |
| 7 | Sur A : Ma caisse → Ouvrir avec 5 000 F, puis Vendre : 1 savon, client donne 1 000 F | « Rendez 550 F », reçu n° A-000001 | — |
| 8 | Toucher **Envoyer le reçu** | WhatsApp s'ouvre avec l'image du reçu | Si WhatsApp n'est pas installé, le menu de partage s'ouvre : normal |
| 9 | Sur A : Gestion → **Compte Google** → Connecter le compte Google de la boutique | L'adresse du compte et « Dernière fois : … » s'affichent | Message « 10 » ou « DEVELOPER_ERROR » : voir partie A4 de `etapes-proprietaire.md` |
| 10 | Sur B : installer, « J'ai déjà une boutique : la retrouver », même compte Google | B récupère la boutique (produits, savon à 450 F) | Vérifier que le compte Google est le même sur A et B |
| 11 | Sur B : entrer avec le code du vendeur « Test », vendre 2 savons | Vente faite, reçu n° B-000001 | Le vendeur ne doit voir ni bénéfice ni prix d'achat |
| 12 | Sur A : attendre 1 à 2 minutes (ou rouvrir l'application) | La vente de B apparaît dans « Vendu aujourd'hui » (accueil du patron) | Les 2 appareils ont-ils Internet ? Synchronisation : Gestion → Compte Google |
| 13 | Sur B : Ma caisse → **Fermer la caisse**, compter 0 F de moins que prévu | B ne voit aucun chiffre attendu (comptage à l'aveugle) ; A voit l'écart dans « Caisses fermées » et, à l'ouverture, la fenêtre **Résumé du soir** | — |
| 14 | Sur A : Gestion → **Sauvegarde** → créer une sauvegarde | Fichier proposé au partage (Drive, WhatsApp…) | Code patron demandé : c'est normal |
| 15 | Fin | Désinstaller les 2 applications d'essai | — |

Durée : environ 30 minutes. Si TOUT est conforme, la mise en service chez un vrai client peut commencer
(`1-guide-installation-agents.md`). Sinon, envoyez les captures à l'assistance avant d'aller chez un client.
