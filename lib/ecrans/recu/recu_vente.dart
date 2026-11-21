import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/boutique.dart';
import '../../domaine/quantites.dart';
import '../../donnees/journal_local.dart';
import '../../services/partage.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import '../vente/page_encaisser.dart' show nomPaiement;
import 'apercu_recu.dart';
import 'capture.dart';

/// « 21/11/2026 10:42 »
String dateRecu(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String n(int v) => v.toString().padLeft(2, '0');
  return '${n(d.day)}/${n(d.month)}/${d.year} ${n(d.hour)}:${n(d.minute)}';
}

/// Texte envoyé avec l'image du reçu.
String texteRecu(ConfigBoutique c, String recu, int total) =>
    'Reçu n° $recu – ${c.nom} : ${formatFrancs(total)}. ${c.messageRecu}'
        .trim();

/// Lignes lisibles du reçu : « 2 kg de Riz », « 1 sac de 50 kg de Riz »…
Future<List<LigneRecu>> lignesDuRecu(
  EtatApplication etat,
  Map<String, Object?> donnees,
) async {
  final lignes = <LigneRecu>[];
  for (final l in (donnees['lignes'] as List).cast<Map>()) {
    final id = l['produit'] as String;
    final p = etat.produits.where((p) => p.id == id).firstOrNull;
    final nom = p?.nom ?? 'Produit';
    final prix = l['prix_total'] as int;
    final condId = l['conditionnement'] as String?;
    final nombre = l['nombre'] as int?;
    String quantite;
    if (condId != null && nombre != null) {
      final c = (await etat.journal.conditionnements(id))
          .where((c) => c.id == condId)
          .firstOrNull;
      quantite = '$nombre ${pluriel(c?.nom ?? '', nombre)}';
    } else {
      quantite = decrireUnites(
        l['quantite_milliemes'] as int,
        p?.uniteBase ?? '',
      );
    }
    lignes.add(LigneRecu('$quantite de $nom', prix));
  }
  return lignes;
}

/// Reçu d'une vente, affiché à l'écran, avec le bouton pour l'envoyer.
class RecuPartageable extends StatefulWidget {
  const RecuPartageable({
    super.key,
    required this.etat,
    required this.donnees,
    required this.heure,
  });

  final EtatApplication etat;
  final Map<String, Object?> donnees;
  final int heure;

  @override
  State<RecuPartageable> createState() => _RecuPartageableState();
}

class _RecuPartageableState extends State<RecuPartageable> {
  final _cadre = GlobalKey();
  late final Future<List<LigneRecu>> _lignes = lignesDuRecu(
    widget.etat,
    widget.donnees,
  );

  /// Vente à crédit : nom du client et ce qu'il doit maintenant.
  late final Future<String?> _credit = () async {
    final id = widget.donnees['client'] as String?;
    if (id == null) return null;
    final c = await widget.etat.journal.client(id);
    if (c == null) return null;
    if (widget.donnees['mode_paiement'] != ModePaiement.credit.code) {
      return 'Client : ${c.nom}';
    }
    return 'Client : ${c.nom} — reste à payer : ${formatFrancs(c.solde)}';
  }();
  bool _enCours = false;

  String get _recu => widget.donnees['recu'] as String;

  Future<void> _envoyer() async {
    setState(() => _enCours = true);
    try {
      final png = await capturerPng(_cadre);
      if (png == null) return;
      final r = await widget.etat.services.partagerImage(
        png,
        (widget.etat.estDemo ? 'DÉMONSTRATION — SANS VALEUR. ' : '') +
            texteRecu(
              widget.etat.config,
              _recu,
              widget.donnees['total'] as int,
            ),
      );
      if (r == ResultatPartage.echec && mounted) {
        annoncer(context, 'Impossible d\'envoyer le reçu.', erreur: true);
      } else if (r == ResultatPartage.enregistre && mounted) {
        annoncer(
          context,
          'Reçu enregistré dans Documents › Zero Perte › Recus. '
          'Joignez-le dans WhatsApp (le texte est déjà copié).',
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ModePaiement.depuisCode(
      widget.donnees['mode_paiement'] as String,
    );
    return FutureBuilder<(List<LigneRecu>, String?)>(
      future: Future.wait([_lignes, _credit])
          .then((r) => (r[0] as List<LigneRecu>, r[1] as String?)),
      builder: (context, s) {
        if (!s.hasData) return const SizedBox(height: 80);
        final (lignes, credit) = s.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              key: const Key('bouton-envoyer-recu'),
              onPressed: _enCours ? null : _envoyer,
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Envoyer le reçu sur WhatsApp',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 60),
                foregroundColor: CouleursZp.argentEntre,
                side: const BorderSide(color: CouleursZp.argentEntre, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _cadre,
              child: ColoredBox(
                color: CouleursRecu.cadre,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ApercuRecu(
                    config: widget.etat.config,
                    numero: _recu,
                    date: dateRecu(widget.heure),
                    lignes: lignes,
                    credit: credit,
                    paiement: nomPaiement(mode),
                    demo: widget.etat.estDemo,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
