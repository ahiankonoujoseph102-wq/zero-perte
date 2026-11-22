import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/messages_whatsapp.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import '../patron/graphiques.dart' show CarteZp;

/// Crédits en retard : pour chaque client, un seul toucher ouvre WhatsApp
/// avec le rappel déjà écrit ; le patron envoie lui-même.
class PageCreditsEnRetard extends StatefulWidget {
  const PageCreditsEnRetard({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageCreditsEnRetard> createState() => _PageCreditsEnRetardState();
}

class _PageCreditsEnRetardState extends State<PageCreditsEnRetard> {
  late final Future<List<(Client, int)>> _liste = widget.etat.creditsEnRetard();
  final Set<String> _rappeles = {};

  Future<void> _rappeler(Client c) async {
    final lien = widget.etat.lienRappel(c);
    if (lien == null) return;
    final ok = await widget.etat.services.ouvrirLien(lien);
    if (!mounted) return;
    if (ok) {
      setState(() => _rappeles.add(c.id));
    } else {
      annoncer(context, 'WhatsApp ne s\'ouvre pas.', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Crédits en retard',
      icone: Icons.schedule_rounded,
      corps: FutureBuilder<List<(Client, int)>>(
        future: _liste,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final l = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Clients qui doivent encore et n\'ont rien remboursé depuis '
                '$joursRetardCredit jours ou plus. Touchez « Rappeler » : '
                'WhatsApp s\'ouvre avec le message déjà écrit.',
                style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
              ),
              const SizedBox(height: 12),
              if (l.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucun crédit en retard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              for (final (c, jours) in l)
                Padding(
                  key: Key('retard-${c.nom}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CarteZp(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nom,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Doit ${formatFrancs(c.solde)} · rien payé depuis $jours jours',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: CouleursZp.creditTexte,
                                ),
                              ),
                              if (widget.etat.lienRappel(c) == null)
                                const Text(
                                  'Pas de numéro : ajoutez-le dans sa fiche.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: CouleursZp.texteDoux,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_rappeles.contains(c.id))
                          const Icon(
                            Icons.check_circle_rounded,
                            color: CouleursZp.argentEntre,
                            size: 32,
                          )
                        else
                          FilledButton.icon(
                            key: Key('rappeler-${c.nom}'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: widget.etat.lienRappel(c) == null
                                ? null
                                : () => _rappeler(c),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text(
                              'Rappeler',
                              style: TextStyle(fontSize: 17),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
