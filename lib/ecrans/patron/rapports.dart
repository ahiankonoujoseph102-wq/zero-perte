import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/tableau.dart';
import '../../services/partage.dart';
import '../../theme/couleurs.dart';
import '../accueil_vendeur.dart' show dateEnFrancais;
import '../communs.dart';
import '../recu/document_partageable.dart';
import 'graphiques.dart';

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

/// « samedi 21 novembre », « semaine du 16/11 au 22/11 », « novembre 2026 ».
String titreRapport(Rapport r) {
  String court(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  return switch (r.periode) {
    Periode.jour => dateEnFrancais(r.debut),
    Periode.semaine =>
      'semaine du ${court(r.debut)} au ${court(r.fin.subtract(const Duration(days: 1)))}',
    Periode.mois => '${_mois[r.debut.month - 1]} ${r.debut.year}',
  };
}

/// Rapport en tableau (CSV, séparateur « ; », lisible dans Excel).
String rapportCsv(Rapport r, String boutique) {
  final l = <String>[
    'Rapport;${titreRapport(r)}',
    'Boutique;"${boutique.replaceAll('"', '""')}"',
    '',
    'Ventes (F);${r.ventes}',
    'Nombre de ventes;${r.nombreVentes}',
    'Bénéfice estimé (F);${r.benefice}',
    'Dépenses (F);${r.depenses}',
    'Retours rendus (F);${r.retours}',
    'Crédit accordé (F);${r.creditAccorde}',
    'Crédit remboursé (F);${r.creditRembourse}',
    'Les clients doivent aujourd\'hui (F);${r.creditsDus}',
    'Inventaires;${r.inventaires.length}',
    'Écart des inventaires (F);${r.ecartsInventaires}',
    if (r.jours.isNotEmpty) ...[
      '',
      'Jour;Ventes (F);Dépenses (F);Bénéfice (F)',
      for (final j in r.jours)
        '${j.jour.day.toString().padLeft(2, '0')}/${j.jour.month.toString().padLeft(2, '0')}/${j.jour.year};${j.ventes};${j.depenses};${j.benefice}',
    ],
    if (r.meilleurs.isNotEmpty) ...[
      '',
      'Produit;Ventes (F)',
      for (final (n, m) in r.meilleurs) '"${n.replaceAll('"', '""')}";$m',
    ],
  ];
  return '${l.join('\r\n')}\r\n';
}

/// Rapports du patron : ventes, bénéfice, dépenses, crédits, inventaires, par
/// jour, semaine ou mois ; envoi en image ou en fichier (Excel).
class PageRapports extends StatefulWidget {
  const PageRapports({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageRapports> createState() => _PageRapportsState();
}

class _PageRapportsState extends State<PageRapports> {
  Periode _periode = Periode.jour;
  int _decalage = 0;
  late Future<Rapport> _rapport = widget.etat.rapport(_periode);

  void _changer(Periode p, int decalage) {
    setState(() {
      _periode = p;
      _decalage = decalage;
      _rapport = widget.etat.rapport(p, decalage: decalage);
    });
  }

  Future<void> _exporter(Rapport r) async {
    final octets = Uint8List.fromList([
      0xEF, 0xBB, 0xBF, // les accents s'affichent bien dans Excel
      ...utf8.encode(rapportCsv(r, widget.etat.config.nom)),
    ]);
    final nom =
        'rapport-${r.periode.name}-${r.debut.year}-${r.debut.month.toString().padLeft(2, '0')}-${r.debut.day.toString().padLeft(2, '0')}.csv';
    final res = await widget.etat.services.partagerFichier(octets, nom);
    if (res == ResultatPartage.echec && mounted) {
      annoncer(context, 'Le fichier n\'a pas pu être envoyé.', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Rapports',
      icone: Icons.summarize_rounded,
      corps: FutureBuilder<Rapport>(
        future: _rapport,
        builder: (context, s) {
          final r = s.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in Periode.values)
                    ChoiceChip(
                      key: Key('rapport-${p.name}'),
                      label: Text(switch (p) {
                        Periode.jour => 'Jour',
                        Periode.semaine => 'Semaine',
                        Periode.mois => 'Mois',
                      }, style: const TextStyle(fontSize: 17)),
                      selected: _periode == p,
                      onSelected: (_) => _changer(p, 0),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    key: const Key('rapport-precedent'),
                    onPressed: () => _changer(_periode, _decalage - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      r == null ? '' : titreRapport(r),
                      key: const Key('rapport-titre'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    key: const Key('rapport-suivant'),
                    onPressed: _decalage < 0
                        ? () => _changer(_periode, _decalage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (r == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                OutlinedButton.icon(
                  key: const Key('bouton-export-csv'),
                  onPressed: () => _exporter(r),
                  icon: const Icon(Icons.table_view_rounded),
                  label: const Text(
                    'Envoyer en fichier (Excel)',
                    style: TextStyle(fontSize: 17),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 54),
                  ),
                ),
                const SizedBox(height: 8),
                DocumentPartageable(
                  etat: widget.etat,
                  fondBlanc: false,
                  cleBouton: 'bouton-export-image',
                  libelleBouton: 'Envoyer en image (WhatsApp)',
                  texte:
                      'Rapport ${titreRapport(r)} – ${widget.etat.config.nom} : '
                      'ventes ${formatFrancs(r.ventes)}.',
                  child: _ContenuRapport(
                    r: r,
                    boutique: widget.etat.config.nom,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ContenuRapport extends StatelessWidget {
  const _ContenuRapport({required this.r, required this.boutique});

  final Rapport r;
  final String boutique;

  Widget _ligne(String cle, String libelle, int montant, Color couleur) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(libelle, style: const TextStyle(fontSize: 17)),
            ),
            Text(
              formatFrancs(montant),
              key: Key(cle),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: couleur,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$boutique · ${titreRapport(r)}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        CarteZp(
          child: Column(
            children: [
              _ligne(
                'rapport-ventes',
                'Ventes (${r.nombreVentes})',
                r.ventes,
                CouleursZp.argentEntreClair,
              ),
              _ligne(
                'rapport-benefice',
                'Bénéfice estimé',
                r.benefice,
                r.benefice >= 0
                    ? CouleursZp.argentEntreClair
                    : CouleursZp.argentSortClair,
              ),
              _ligne(
                'rapport-depenses',
                'Dépenses',
                r.depenses,
                CouleursZp.argentSortClair,
              ),
              _ligne(
                'rapport-retours',
                'Retours rendus',
                r.retours,
                CouleursZp.argentSortClair,
              ),
              _ligne(
                'rapport-credit-accorde',
                'Crédit accordé',
                r.creditAccorde,
                CouleursZp.creditTexte,
              ),
              _ligne(
                'rapport-credit-rembourse',
                'Crédit remboursé',
                r.creditRembourse,
                CouleursZp.argentEntreClair,
              ),
              _ligne(
                'rapport-credits-dus',
                'Les clients doivent',
                r.creditsDus,
                CouleursZp.creditTexte,
              ),
              _ligne(
                'rapport-inventaires',
                'Inventaires (${r.inventaires.length}) : écart',
                r.ecartsInventaires,
                r.ecartsInventaires < 0
                    ? CouleursZp.argentSortClair
                    : CouleursZp.texte,
              ),
            ],
          ),
        ),
        if (r.jours.isNotEmpty) ...[
          const SizedBox(height: 10),
          CarteZp(
            titre: 'Jour par jour',
            child: Column(
              children: [
                for (final j in r.jours)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${j.jour.day.toString().padLeft(2, '0')}/${j.jour.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            formatFrancs(j.ventes),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '− ${formatFrancs(j.depenses)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16,
                              color: CouleursZp.argentSortClair,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        CarteZp(
          titre: 'Les plus vendus',
          child: BarresClassement(
            lignes: r.meilleurs,
            prefixeCle: 'rapport-top',
          ),
        ),
      ],
    );
  }
}
