import 'package:flutter/material.dart';

import '../domaine/boutique.dart';
import '../theme/couleurs.dart';
import 'logo_boutique.dart';
import 'bouton_action.dart';

/// Écran d'accueil du vendeur : 4 gros boutons, un geste chacun.
/// Étape A3 : les boutons n'ont pas encore de fonction (elles arrivent en B).
class AccueilVendeur extends StatelessWidget {
  const AccueilVendeur({
    super.key,
    required this.config,
    required this.nomVendeur,
    required this.pied,
    this.maintenant,
    this.onEspacePatron,
    this.actions = const {},
  });

  /// Ouvre l'espace du patron (après son code secret).
  final VoidCallback? onEspacePatron;

  /// Actions des gros boutons ('vendre', 'credit', 'depense', 'fermer') ;
  /// un bouton sans action affiche « arrive bientôt ».
  final Map<String, VoidCallback> actions;

  /// Configuration de la boutique (nom, logo, couleur).
  final ConfigBoutique config;
  final String nomVendeur;

  /// Ligne du bas (version, état de la base).
  final Widget pied;

  /// Permet aux tests de fixer la date affichée.
  final DateTime? maintenant;

  void _bientot(BuildContext context, String fonction) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.construction_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('« $fonction » arrive bientôt.')),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, contraintes) {
              // Écran très bas (petit téléphone, grand texte) : on donne plus de
              // place aux petits boutons pour qu'ils restent faciles à toucher.
              final bas = contraintes.maxHeight < 560;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // L'en-tête et le pied grossissent avec le réglage « taille du texte »
                  // du téléphone, mais au plus ×1,3 pour laisser la place aux boutons
                  // (qui, eux, s'adaptent tout seuls).
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: _EnTete(
                      config: config,
                      nomVendeur: nomVendeur,
                      date: maintenant ?? DateTime.now(),
                      compact: bas,
                      onEspacePatron: onEspacePatron,
                    ),
                  ),
                  SizedBox(height: bas ? 10 : 16),
                  Expanded(
                    flex: bas ? 4 : 5,
                    child: BoutonAction(
                      key: const Key('bouton-vendre'),
                      titre: 'Vendre',
                      sousTitre: 'Encaisser une vente',
                      icone: Icons.shopping_basket_rounded,
                      couleur: CouleursZp.argentEntre,
                      couleurClaire: CouleursZp.argentEntreClair,
                      principal: true,
                      onTap:
                          actions['vendre'] ??
                          () => _bientot(context, 'Vendre'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 3,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: BoutonAction(
                            key: const Key('bouton-credit'),
                            titre: 'Crédit',
                            icone: Icons.menu_book_rounded,
                            couleur: CouleursZp.credit,
                            couleurClaire: CouleursZp.creditClair,
                            couleurTexte: CouleursZp.texteSurCredit,
                            onTap:
                                actions['credit'] ??
                                () => _bientot(context, 'Crédit'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: BoutonAction(
                            key: const Key('bouton-depense'),
                            titre: 'Dépense',
                            icone: Icons.payments_rounded,
                            couleur: CouleursZp.argentSort,
                            couleurClaire: CouleursZp.argentSortClair,
                            onTap:
                                actions['depense'] ??
                                () => _bientot(context, 'Dépense'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: bas ? 3 : 2,
                    child: BoutonAction(
                      key: const Key('bouton-fermer-caisse'),
                      titre: 'Fermer la caisse',
                      icone: Icons.lock_rounded,
                      couleur: CouleursZp.marque,
                      couleurClaire: const Color(0xFF2E4A72),
                      horizontal: true,
                      onTap:
                          actions['fermer'] ??
                          () => _bientot(context, 'Fermer la caisse'),
                    ),
                  ),
                  SizedBox(height: bas ? 6 : 10),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: pied,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.config,
    required this.nomVendeur,
    required this.date,
    this.compact = false,
    this.onEspacePatron,
  });

  final VoidCallback? onEspacePatron;

  final ConfigBoutique config;
  final String nomVendeur;
  final DateTime date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LogoBoutique(config: config, taille: compact ? 44 : 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.nom.isEmpty ? 'Ma boutique' : config.nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CouleursZp.texte,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: CouleursZp.texteDoux,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        nomVendeur,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 17,
                      color: CouleursZp.texteDoux,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateCourte(date),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 17,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onEspacePatron != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const Key('bouton-espace-patron'),
            onPressed: onEspacePatron,
            tooltip: 'Espace patron',
            iconSize: 28,
            style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
            icon: const Icon(Icons.key_rounded),
          ),
        ],
      ],
    );
  }
}

/// Logo provisoire : disque bleu nuit avec « ZP » (remplacé par le logo de la
/// boutique à l'étape B3).
class LogoZp extends StatelessWidget {
  const LogoZp({super.key, this.taille = 120});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E4A72), CouleursZp.marque],
        ),
        boxShadow: [
          BoxShadow(
            color: CouleursZp.marque.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'ZP',
        style: TextStyle(
          color: Colors.white,
          fontSize: taille * 0.4,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

const _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « 21 nov. » : date courte pour l'en-tête.
String dateCourte(DateTime d) {
  final mois = _mois[d.month - 1];
  return '${d.day} ${mois.length <= 4 ? mois : '${mois.substring(0, mois.startsWith('juil') ? 4 : 3)}.'}';
}

/// « samedi 21 novembre » (sans bibliothèque externe).
String dateEnFrancais(DateTime d) =>
    '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
