import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../communs.dart';
import 'rapports.dart';
import 'tableau.dart';

/// « Chiffres » : l'ancien « Tableau » (le résumé) et les anciens « Rapports »
/// (à envoyer, jour par jour, les plus vendus) réunis dans une seule page.
class PageChiffres extends StatefulWidget {
  const PageChiffres({super.key, required this.etat, this.rapport = false});

  final EtatApplication etat;

  /// Vrai : ouvre directement sur « Rapport à envoyer ».
  final bool rapport;

  @override
  State<PageChiffres> createState() => _PageChiffresState();
}

// Le style du texte seulement : la police de l'application est gardée.
const _style = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

class _PageChiffresState extends State<PageChiffres> {
  late bool _rapport = widget.rapport;

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Chiffres',
      icone: Icons.insights_rounded,
      pleineLargeur: !_rapport,
      corps: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.insights_rounded),
                    label: Text(
                      'Résumé',
                      key: Key('onglet-resume'),
                      style: _style,
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.summarize_rounded),
                    label: Text(
                      'À envoyer',
                      key: Key('onglet-rapport'),
                      style: _style,
                    ),
                  ),
                ],
                selected: {_rapport},
                onSelectionChanged: (s) => setState(() => _rapport = s.first),
              ),
            ),
          ),
          Expanded(
            child: _rapport
                ? PageRapports(etat: widget.etat, integree: true)
                : PageTableau(etat: widget.etat, integree: true),
          ),
        ],
      ),
    );
  }
}
