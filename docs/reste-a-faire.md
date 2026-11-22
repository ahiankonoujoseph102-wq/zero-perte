# Ce qui reste à faire (liste complète, 22 novembre 2026)

Relu : `docs/journal-avancement.md` et `docs/etapes-proprietaire.md`. Ordre = priorité.

## Claude — ordre décidé par le propriétaire (22/11)

| # | Quoi | État |
|---|---|---|
| 1 | **0.31.0** : finir la voix Sulafat (32 phrases sur 50 restent ; quota Gemini gratuit de 10 demandes par jour), vérifier les fichiers, l'intégrer, tests + visite à vitesse réelle sur 4 tailles + captures, APK < 20 Mo, publier, rapport court | **Priorité absolue** (relance chaque matin à 8 h 12) |
| 2 | ✅ (0.32.0) **PRIORITÉ 1 — Produits et prix après l'installation**, depuis Gestion, patron seul : ajouter un produit (nom, image, unités, prix de vente, prix d'achat, stock de départ, seuil de stock bas), modifier un prix, modifier un produit, masquer un produit qui ne se vend plus (historique gardé). Chaque changement de prix au journal (ancien prix, nouveau prix, date), ventes passées inchangées. Téléphone, tablette, PC. Inclut l'écran du **seuil de stock bas** (ouvert depuis le bloc B). | Après la 0.31.0 |
| 3 | **PRIORITÉ 2 — Alléger les données** sans casser la chaîne de sécurité du journal ni la synchronisation : format plus compact des nouvelles opérations, synchronisation de ce qui est nouveau seulement, compression, « point de départ » résumé pour un nouvel appareil. **Objectifs mesurés sur la boutique d'essai d'un an : < 1 Ko par vente stockée, < 5 Mo à télécharger pour un nouvel appareil.** Avant : 127 Mo par an (≈ 1,7 Ko par vente), 74 Mo de première synchronisation. | Après la priorité 1 |
| 4 | 0.32 — résumé du soir à la fermeture (synchronisation, notification Firebase plus tard, bouton « Envoyer sur WhatsApp ») | Décidé (Q1 audit) |
| 5 | 0.32 — stock bas → WhatsApp ouvert avec la liste d'achats | Décidé (Q2 audit) |
| 6 | 0.32 — rappel des crédits en retard, validé en un toucher | Décidé (Q3 audit) |
| 7 | 0.32 — « Tableau » + « Rapports » fusionnés en « Chiffres » | Décidé (Q4 audit) |
| 8 | Relais Cloudflare : correction « dernière alerte » dans `relais/worker.js` + partie B mise à jour (nouveaux menus) | Après la 0.32 |
| 9 | Message « Nouvelle version disponible » | **Fait** sur la branche `claude/suite-apres-031` |
| 10 | Rapidité après 1 an (stock courant, index, requêtes par période) | **Fait** sur la branche |
| 11 | Bloc E : guides de mise en service (`docs/mise-en-service/`) | **Fait** sur la branche, à valider par le propriétaire |
| 12 | Le paquet `flutter_tts` utilise un ancien outil Kotlin : une future version de Flutter refusera de fabriquer l'APK | À surveiller à chaque montée de Flutter |
| 13 | Relais : à **50 boutiques**, revoir (alertes poussées par Firebase, consultations espacées) | Noté pour plus tard |
| 14 | Fichiers d'Afi v1 et extraits de voix du site : plus utiles après la 0.31.0 | Ménage après publication |

## Propriétaire

| # | Quoi | Où |
|---|---|---|
| A | **Essai A5** : connecter le compte Google de la boutique sur un vrai téléphone, puis sur le PC (synchronisation Drive) | `etapes-proprietaire.md` partie A5 |
| B | **Cloudflare** (alertes graves) : après la correction n° 2 | partie B |
| C | **Firebase** (alertes même application fermée) | partie F |
| D | Microsoft Store (supprime l'avertissement Windows, gratuit) — facultatif | partie E |
| E | Valider les guides de mise en service, former les agents, imprimer l'aide-mémoire | `docs/mise-en-service/` |
| F | Essai sur vrais appareils de la 0.31.0 : voix d'Afi sur Android 8 et sur PC Windows, partage WhatsApp | après publication |
| G | Répondre aux questions (a)/(b) du rapport | rapport |
| H | Plus tard : certificat de signature Windows (payant) si le Store n'est pas choisi | journal, partie Windows |

Déjà fait et retiré de la liste : jeton des codes (C), pages publiques (G), Google Cloud A1–A4 et A6, clé
Gemini (H), code patron à 6 chiffres, retour partiel, suppression d'un client, restauration.
