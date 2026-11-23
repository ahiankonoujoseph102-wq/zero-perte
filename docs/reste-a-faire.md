# Ce qui reste à faire (liste complète, 23 novembre 2026)

Relu : `docs/journal-avancement.md` et `docs/etapes-proprietaire.md`. Ordre = priorité.

## Claude — ordre décidé par le propriétaire (22/11)

| # | Quoi | État |
|---|---|---|
| 1 | ✅ Voix d'Afi complète (50/50) dans la 0.35.1 (020, 037, 049, 050 refaites le 23/11) | Fait |
| 2 | ✅ (0.32.0) **PRIORITÉ 1 — Produits et prix après l'installation**, depuis Gestion, patron seul : ajouter un produit (nom, image, unités, prix de vente, prix d'achat, stock de départ, seuil de stock bas), modifier un prix, modifier un produit, masquer un produit qui ne se vend plus (historique gardé). Chaque changement de prix au journal (ancien prix, nouveau prix, date), ventes passées inchangées. Téléphone, tablette, PC. Inclut l'écran du **seuil de stock bas** (ouvert depuis le bloc B). | Après la 0.31.0 |
| 3 | ✅ (0.33.0, sauf « < 1 Ko par vente stockée » : question (a)/(b) posée) **PRIORITÉ 2 — Alléger les données** sans casser la chaîne de sécurité du journal ni la synchronisation : format plus compact des nouvelles opérations, synchronisation de ce qui est nouveau seulement, compression, « point de départ » résumé pour un nouvel appareil. **Objectifs mesurés sur la boutique d'essai d'un an : < 1 Ko par vente stockée, < 5 Mo à télécharger pour un nouvel appareil.** Avant : 127 Mo par an (≈ 1,7 Ko par vente), 74 Mo de première synchronisation. | Après la priorité 1 |
| 4 | ✅ (0.34.0) résumé du soir à la fermeture (synchronisation, notification Firebase plus tard, bouton « Envoyer sur WhatsApp ») | Décidé (Q1 audit) |
| 5 | ✅ (0.34.0) stock bas → WhatsApp ouvert avec la liste d'achats | Décidé (Q2 audit) |
| 6 | ✅ (0.34.0) rappel des crédits en retard, validé en un toucher | Décidé (Q3 audit) |
| 7 | ✅ (0.34.0) « Tableau » + « Rapports » fusionnés en « Chiffres » | Décidé (Q4 audit) |
| 8 | ✅ (0.33.0) Relais Cloudflare : correction « dernière alerte » dans `relais/worker.js` + partie B mise à jour (nouveaux menus) | Après la 0.32 |
| 9 | Message « Nouvelle version disponible » | ✅ 0.32.0 |
| 10 | Rapidité après 1 an (stock courant, index, requêtes par période) | ✅ 0.32.0 |
| 11 | Bloc E : guides de mise en service (`docs/mise-en-service/`) | ✅ 0.32.0 (mis à jour en 0.34.0), à valider par le propriétaire |
| 12 | Le paquet `flutter_tts` utilise un ancien outil Kotlin : une future version de Flutter refusera de fabriquer l'APK | À surveiller à chaque montée de Flutter |
| 13 | Relais : à **50 boutiques**, revoir (alertes poussées par Firebase, consultations espacées) | Noté pour plus tard |
| 14 | Fichiers d'Afi v1 et extraits de voix du site : plus utiles après la 0.31.0 | Ménage après publication |
| 15 | ✅ (0.35.0) Ajout d'un vendeur par QR code ; (0.35.2) lecteur de QR préparé à l'avance, réessai, code d'erreur affiché | **Essai sur 2 vrais téléphones à faire** |
| 16 | ✅ (23/11) Action « 8 - Mettre à jour le relais » (exécution #2 verte, « Relais en ligne : OK ») | Fait |
| 18 | ✅ (0.36.0) Refonte commerçant : démarrage 3 étapes sans inventaire, gros/détail, mots du marché, accueil (bénéfice, caisse, vendeurs), WhatsApp à la fermeture, « Voir un exemple », argumentaire | **Essai réel à faire** |
| 19 | Réserve séparée (« magasin ») : plan dans `docs/refonte-commercant.md` | Prochaine version, après essai réel |
| 20 | Voix d'Afi : quelques phrases disent encore « Clients » et le riz « au kilo » (enregistrées avant la 0.36) ; à refaire avec les nouveaux mots (quota Gemini : 10 par jour) | Plus tard |
| 17 | Supprimer l'ancien passage de l'action « test minimal (temporaire) » (le fichier n'existe plus ; seul son passage du 21/11 la garde dans la liste) | Propriétaire : 3 touchers |

## Propriétaire

| # | Quoi | Où |
|---|---|---|
| A | **Essai A5** : connecter le compte Google de la boutique sur un vrai téléphone, puis sur le PC (synchronisation Drive) | `etapes-proprietaire.md` partie A5 |
| B | ✅ (22/11) **Cloudflare** : relais déployé et vérifié, `ZP_RELAIS_URL` en place. Reste : essai B5 sur 2 vrais téléphones | partie B |
| C | ✅ (22/11) **Firebase** : branché dans `v0.34.0-n101`. Reste : essai F4 sur 2 vrais téléphones | partie F |
| C2 | ✅ (23/11) Parties **I** (Google Web + secrets Cloudflare) et **J** (jeton de l'action 8) | faites |
| C3 | **Essai « Ajouter mon vendeur »** sur 2 vrais téléphones avec la 0.35.2 (Pixel 6 : le lecteur ne s'ouvrait pas en 0.35.1) | guide des agents, 3 bis |
| D | Microsoft Store (supprime l'avertissement Windows, gratuit) — facultatif | partie E |
| E | Valider les guides de mise en service, former les agents, imprimer l'aide-mémoire | `docs/mise-en-service/` |
| F | Essai sur vrais appareils de la 0.31.0 : voix d'Afi sur Android 8 et sur PC Windows, partage WhatsApp | après publication |
| G | ✅ (22/11) Questions (a)/(b) : (a), base gardée telle quelle | rapport |
| H | Plus tard : certificat de signature Windows (payant) si le Store n'est pas choisi | journal, partie Windows |

Déjà fait et retiré de la liste : jeton des codes (C), pages publiques (G), Google Cloud A1–A4 et A6, clé
Gemini (H), code patron à 6 chiffres, retour partiel, suppression d'un client, restauration.
