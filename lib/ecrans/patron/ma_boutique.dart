/// Gestion → « Ma boutique » : tout ce qui n'est plus demandé au démarrage
/// (0.36) se règle ici, quand le patron a le temps.
library;

import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart';
import '../communs.dart';

class PageMaBoutique extends StatelessWidget {
  const PageMaBoutique({super.key, required this.etat});
  final EtatApplication etat;

  Future<void> _ouvrir(
    BuildContext context,
    String titre,
    EtapeAssistant etape,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PageZp(
        titre: titre,
        corps: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ModeReglage(
            etape: etape,
            child: pageEtapeBoutique(etat, etape),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final c = etat.config;
        String ou(String v, String sinon) => v.trim().isEmpty ? sinon : v;
        final lignes = <(String, IconData, String, String, EtapeAssistant)>[
          (
            'nom',
            Icons.storefront_rounded,
            'Nom et photo',
            c.nom,
            EtapeAssistant.identite,
          ),
          (
            'profil',
            Icons.tune_rounded,
            'Comment vous vendez',
            '${c.vente?.libelle ?? 'Détail et gros'} · ${c.quiVend?.libelle ?? '—'}',
            EtapeAssistant.profil,
          ),
          (
            'contact',
            Icons.phone_rounded,
            'Téléphone et adresse',
            ou(
              [
                c.telephone,
                c.quartier,
                c.ville,
              ].where((x) => x.isNotEmpty).join(' · '),
              'À ajouter (écrit sur les reçus)',
            ),
            EtapeAssistant.contact,
          ),
          (
            'couleur',
            Icons.palette_rounded,
            'Couleur',
            'Couleur de la boutique',
            EtapeAssistant.couleur,
          ),
          (
            'recu',
            Icons.receipt_long_rounded,
            'Le reçu',
            ou(c.messageRecu, 'Message du bas du reçu'),
            EtapeAssistant.recu,
          ),
          (
            'types',
            Icons.category_rounded,
            'Type de boutique',
            ou(c.types.join(', '), 'Pour proposer des produits connus'),
            EtapeAssistant.typeBoutique,
          ),
          (
            'produits-connus',
            Icons.playlist_add_rounded,
            'Ajouter des produits connus',
            'Choisir dans la liste, puis écrire les prix',
            EtapeAssistant.produits,
          ),
        ];
        return PageZp(
          titre: 'Ma boutique',
          icone: Icons.storefront_rounded,
          corps: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (cle, icone, titre, detail, etape) in lignes) ...[
                Material(
                  color: CouleursZp.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: CouleursZp.ligne),
                  ),
                  child: ListTile(
                    key: Key('ma-boutique-$cle'),
                    minVerticalPadding: 14,
                    leading: Icon(icone, size: 32),
                    title: Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await _ouvrir(context, titre, etape);
                      // Produits choisis dans la liste : ensuite leurs prix.
                      if (etape == EtapeAssistant.produits && context.mounted) {
                        await _ouvrir(context, 'Les prix', EtapeAssistant.prix);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}
