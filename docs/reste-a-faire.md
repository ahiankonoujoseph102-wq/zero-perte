# Ce qui reste à faire (liste complète, 22 novembre 2026)

Relu : `docs/journal-avancement.md` et `docs/etapes-proprietaire.md`. Ordre = priorité.

## Claude

| # | Quoi | État |
|---|---|---|
| 1 | **0.31.0** : finir la voix Sulafat (32 phrases sur 50 restent ; quota Gemini gratuit de 10 demandes par jour), vérifier les fichiers, l'intégrer, tests + visite à vitesse réelle sur 4 tailles + captures, APK < 20 Mo, publier, rapport court | En cours (relance chaque matin à 8 h 12) |
| 2 | Relais Cloudflare : correction « dernière alerte » dans `relais/worker.js` + partie B mise à jour (nouveaux menus) | Après la 0.31.0 |
| 3 | **0.32 — Produits et prix après l'installation** : ajouter un produit (du catalogue ou libre), changer un prix, désactiver un produit. *Aujourd'hui impossible hors de l'assistant d'installation.* | **Manque grave trouvé le 22/11** — question Q1 du rapport |
| 4 | 0.32 — résumé du soir à la fermeture (synchronisation, notification Firebase plus tard, bouton « Envoyer sur WhatsApp ») | Décidé (Q1 audit) |
| 5 | 0.32 — stock bas → WhatsApp ouvert avec la liste d'achats | Décidé (Q2 audit) |
| 6 | 0.32 — rappel des crédits en retard, validé en un toucher | Décidé (Q3 audit) |
| 7 | 0.32 — « Tableau » + « Rapports » fusionnés en « Chiffres » | Décidé (Q4 audit) |
| 8 | Message « Nouvelle version disponible » | **Fait** sur la branche `claude/suite-apres-031` (part avec la 0.32) |
| 9 | Rapidité après 1 an (stock courant, index, requêtes par période) | **Fait** sur la branche (part avec la 0.32) |
| 10 | Bloc E : guides de mise en service (`docs/mise-en-service/`) | **Fait** sur la branche, à valider par le propriétaire |
| 11 | Écran pour régler le **seuil de stock bas** d'un produit (la règle automatique existe, pas l'écran) | Ouvert depuis l'étape 2 (bloc B) — à mettre avec le n° 3 |
| 12 | Première synchronisation après 1 an : **74 Mo** envoyés (format JSON non compressé) ; base **127 Mo par an** | Question Q2 du rapport |
| 13 | Le paquet `flutter_tts` utilise un ancien outil Kotlin : une future version de Flutter refusera de fabriquer l'APK | À surveiller à chaque montée de Flutter (avertissement dans la fabrication) |
| 14 | Relais : à **50 boutiques**, revoir (alertes poussées par Firebase, consultations espacées) | Noté pour plus tard |
| 15 | Fichiers d'Afi v1 et extraits de voix du site : plus utiles après la 0.31.0 | Ménage après publication |

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
