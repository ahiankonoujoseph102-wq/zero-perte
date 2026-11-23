/// Démarrage, étape 2 sur 3 : deux questions à gros boutons.
/// - « Vous vendez : au détail / en gros / les deux »
/// - « Qui vend dans la boutique : moi / un vendeur / plusieurs vendeurs »
/// Les réponses règlent l'application (boutons « Gros », vendeurs mis en avant)
/// et se changent ensuite dans Gestion → « Ma boutique ».
library;

import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/boutique.dart';
import '../../theme/couleurs.dart';
import 'etapes_boutique.dart';

class EtapeProfil extends StatefulWidget {
  const EtapeProfil({super.key, required this.etat});
  final EtatApplication etat;

  @override
  State<EtapeProfil> createState() => _EtapeProfilState();
}

class _EtapeProfilState extends State<EtapeProfil> {
  late FaconDeVendre? _vente = widget.etat.config.vente;
  late QuiVend? _qui = widget.etat.config.quiVend;

  @override
  Widget build(BuildContext context) {
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Continuer',
      onPrincipal: _vente == null || _qui == null
          ? null
          : () async {
              await widget.etat.enregistrerConfig(
                widget.etat.config.copie(vente: _vente, quiVend: _qui),
              );
              if (context.mounted) {
                await suivanteOuRetour(context, widget.etat);
              }
            },
      contenu: ListView(
        children: [
          const _Question('Vous vendez :'),
          for (final v in FaconDeVendre.values)
            _Choix(
              cle: 'vente-${v.code}',
              icone: switch (v) {
                FaconDeVendre.detail => Icons.shopping_basket_rounded,
                FaconDeVendre.gros => Icons.inventory_2_rounded,
                FaconDeVendre.lesDeux => Icons.swap_horiz_rounded,
              },
              titre: v.libelle,
              exemple: switch (v) {
                FaconDeVendre.detail => 'la boîte, le bol, la bouteille…',
                FaconDeVendre.gros => 'le carton, le sac, le casier…',
                FaconDeVendre.lesDeux => 'à la boîte ET au carton',
              },
              choisi: _vente == v,
              onTap: () => setState(() => _vente = v),
            ),
          const SizedBox(height: 18),
          const _Question('Qui vend dans la boutique ?'),
          for (final q in QuiVend.values)
            _Choix(
              cle: 'qui-${q.code}',
              icone: switch (q) {
                QuiVend.moi => Icons.person_rounded,
                QuiVend.unVendeur => Icons.person_add_alt_1_rounded,
                QuiVend.plusieurs => Icons.groups_rounded,
              },
              titre: q.libelle,
              exemple: switch (q) {
                QuiVend.moi => 'je suis toujours là',
                QuiVend.unVendeur => 'un vendeur ou un parent',
                QuiVend.plusieurs => 'chacun a son code',
              },
              choisi: _qui == q,
              onTap: () => setState(() => _qui = q),
            ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texte,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
    ),
  );
}

class _Choix extends StatelessWidget {
  const _Choix({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.exemple,
    required this.choisi,
    required this.onTap,
  });

  final String cle;
  final IconData icone;
  final String titre;
  final String exemple;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: choisi ? CouleursZp.marquePale : CouleursZp.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: choisi ? CouleursZp.marque : CouleursZp.ligne,
            width: choisi ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          key: Key(cle),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icone, size: 34, color: CouleursZp.texte),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        exemple,
                        style: const TextStyle(
                          fontSize: 16,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                    ],
                  ),
                ),
                if (choisi)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 32,
                    color: CouleursZp.argentEntre,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
