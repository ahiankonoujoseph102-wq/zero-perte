import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../communs.dart';
import '../recu/recu_vente.dart';
import 'page_encaisser.dart' show nomPaiement;

String heureCourte(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Ventes du jour : reçu, heure, vendeur, montant ; toucher pour voir ou annuler.
class PageVentesDuJour extends StatefulWidget {
  const PageVentesDuJour({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageVentesDuJour> createState() => _PageVentesDuJourState();
}

class _PageVentesDuJourState extends State<PageVentesDuJour> {
  late Future<List<VenteResume>> _ventes = widget.etat.ventesDuJour();

  void _recharger() {
    if (!mounted) return;
    setState(() {
      _ventes = widget.etat.ventesDuJour();
    });
  }

  @override
  void initState() {
    super.initState();
    // Se recharge dès que la boutique change (annulation, nouvelle vente…).
    widget.etat.addListener(_recharger);
  }

  @override
  void dispose() {
    widget.etat.removeListener(_recharger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Ventes du jour',
      icone: Icons.receipt_long_rounded,
      corps: FutureBuilder<List<VenteResume>>(
        future: _ventes,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ventes = s.data!;
          if (ventes.isEmpty) {
            return const Center(
              child: Text(
                'Aucune vente aujourd\'hui.',
                style: TextStyle(fontSize: 20),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ventes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = ventes[i];
              return Material(
                color: v.annulee ? CouleursZp.fond : CouleursZp.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: CouleursZp.ligne),
                ),
                child: InkWell(
                  key: Key('vente-${v.recu}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PageDetailVente(etat: widget.etat, vente: v),
                      ),
                    );
                    _recharger();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${v.recu} · ${heureCourte(v.heure)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${widget.etat.nomDe(v.auteurId)} · ${nomPaiement(v.mode)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: CouleursZp.texteDoux,
                                ),
                              ),
                              if (v.annulee)
                                Text(
                                  'Annulée : ${v.motifAnnulation}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: CouleursZp.argentSort,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formatFrancs(v.total),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: v.annulee
                                ? CouleursZp.texteDoux
                                : CouleursZp.argentEntre,
                            decoration: v.annulee
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Motifs d'annulation proposés (le dernier permet d'écrire le sien).
const List<String> motifsAnnulation = [
  'Erreur en tapant la vente',
  'Retour du client',
  'Le client a changé d\'avis',
  'Autre',
];

/// Détail d'une vente et bouton « Annuler cette vente » (jamais de suppression).
class PageDetailVente extends StatelessWidget {
  const PageDetailVente({super.key, required this.etat, required this.vente});

  final EtatApplication etat;
  final VenteResume vente;

  Future<void> _annuler(BuildContext context) async {
    final motif = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ChoixMotif(),
    );
    if (motif == null || !context.mounted) return;
    try {
      await etat.annulerVente(vente, motif);
      await etat.services.voix.dire('Vente annulée.');
      if (!context.mounted) return;
      annoncer(context, 'Vente ${vente.recu} annulée.');
      Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) annoncer(context, messageErreur(e), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = vente;
    return PageZp(
      titre: 'Reçu ${v.recu}',
      icone: Icons.receipt_rounded,
      bas: v.annulee
          ? null
          : GrosBouton(
              key: const Key('bouton-annuler-vente'),
              texte: 'Annuler cette vente',
              icone: Icons.undo_rounded,
              couleur: CouleursZp.argentSort,
              onPressed: () => _annuler(context),
            ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${heureCourte(v.heure)} · ${etat.nomDe(v.auteurId)} · ${nomPaiement(v.mode)}',
            style: const TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 12),
          for (final l in v.lignes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      etat.produits
                              .where((p) => p.id == l['produit'])
                              .firstOrNull
                              ?.nom ??
                          'Produit',
                      style: const TextStyle(fontSize: 19),
                    ),
                  ),
                  Text(
                    formatFrancs(l['prix_total'] as int),
                    style: const TextStyle(fontSize: 19),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                formatFrancs(v.total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (v.annulee) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('vente-annulee'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CouleursZp.argentSort.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Vente annulée : ${v.motifAnnulation}',
                style: const TextStyle(
                  fontSize: 18,
                  color: CouleursZp.argentSort,
                ),
              ),
            ),
          ],
          if (!v.annulee) ...[
            const SizedBox(height: 20),
            RecuPartageable(etat: etat, donnees: v.donnees, heure: v.heure),
          ],
        ],
      ),
    );
  }
}

class _ChoixMotif extends StatefulWidget {
  const _ChoixMotif();
  @override
  State<_ChoixMotif> createState() => _ChoixMotifState();
}

class _ChoixMotifState extends State<_ChoixMotif> {
  bool _autre = false;
  final _texte = TextEditingController();

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pourquoi annuler ?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Le patron verra ce motif.',
              style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 12),
            if (!_autre)
              for (final m in motifsAnnulation)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    key: Key('motif-$m'),
                    onPressed: () => m == 'Autre'
                        ? setState(() => _autre = true)
                        : Navigator.of(context).pop(m),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 60),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(m, style: const TextStyle(fontSize: 19)),
                  ),
                )
            else ...[
              TextField(
                key: const Key('champ-motif'),
                controller: _texte,
                autofocus: true,
                style: const TextStyle(fontSize: 20),
                decoration: decorationChamp('Écrivez le motif'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              GrosBouton(
                key: const Key('bouton-valider-motif'),
                texte: 'Valider',
                onPressed: _texte.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_texte.text.trim()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
