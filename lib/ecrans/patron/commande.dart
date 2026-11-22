import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/messages_whatsapp.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';

/// « Commander » : le patron choisit le fournisseur, WhatsApp s'ouvre avec
/// la liste d'achats déjà écrite (produits en stock bas). Il complète les
/// quantités et envoie lui-même.
Future<void> commanderStockBas(
  BuildContext context,
  EtatApplication etat,
  List<Produit> produits,
) async {
  final fournisseurs = (await etat.fournisseurs())
      .where((f) => f.telephone.replaceAll(RegExp(r'[^0-9]'), '').length >= 8)
      .toList();
  if (!context.mounted) return;
  final choix = await showModalBottomSheet<Fournisseur?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Commander ${produits.length} produit${produits.length > 1 ? 's' : ''} à qui ?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'WhatsApp s\'ouvre avec la liste déjà écrite : ajoutez les '
              'quantités, puis envoyez.',
              style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 8),
            for (final f in fournisseurs)
              ListTile(
                key: Key('commander-a-${f.nom}'),
                leading: const Icon(Icons.handshake_rounded),
                title: Text(f.nom, style: const TextStyle(fontSize: 18)),
                subtitle: Text(f.telephone),
                onTap: () => Navigator.of(c).pop(f),
              ),
            ListTile(
              key: const Key('commander-autre'),
              leading: const Icon(Icons.contacts_rounded),
              title: const Text(
                'Choisir dans WhatsApp',
                style: TextStyle(fontSize: 18),
              ),
              subtitle: const Text('Fournisseur pas encore enregistré'),
              onTap: () => Navigator.of(
                c,
              ).pop(const Fournisseur(id: '', nom: '', telephone: '', doit: 0)),
            ),
          ],
        ),
      ),
    ),
  );
  if (choix == null) return;
  final texte = messageCommande(
    boutique: etat.config.nom,
    fournisseur: choix.nom,
    produits: [for (final p in produits) p.nom],
  );
  final ok = await etat.services.ouvrirLien(
    lienWhatsApp(texte, telephone: choix.telephone),
  );
  if (!ok && context.mounted) {
    annoncer(context, 'WhatsApp ne s\'ouvre pas.', erreur: true);
  }
}
