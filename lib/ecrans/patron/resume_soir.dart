import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/messages_whatsapp.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';

/// Montre au patron le résumé du soir (fermeture de caisse faite par un
/// vendeur, reçue par la synchronisation), une seule fois. Le patron peut
/// l'envoyer sur WhatsApp lui-même ; rien ne part automatiquement.
class GuetteurResumeSoir extends StatefulWidget {
  const GuetteurResumeSoir({
    super.key,
    required this.etat,
    required this.child,
  });

  final EtatApplication etat;
  final Widget child;

  @override
  State<GuetteurResumeSoir> createState() => _GuetteurResumeSoirState();
}

class _GuetteurResumeSoirState extends State<GuetteurResumeSoir> {
  bool _prevu = false;
  bool _ouvert = false;

  @override
  void initState() {
    super.initState();
    widget.etat.addListener(_planifier);
    _planifier();
  }

  @override
  void dispose() {
    widget.etat.removeListener(_planifier);
    super.dispose();
  }

  /// Plusieurs changements d'affilée : une seule vérification, après
  /// l'affichage suivant.
  void _planifier() {
    if (!widget.etat.estPatron || _ouvert || _prevu) return;
    _prevu = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prevu = false;
      _verifier();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _verifier() async {
    if (!mounted || _ouvert || !widget.etat.estPatron) return;
    final ResumeSoir? r;
    try {
      r = await widget.etat.resumeDuSoir();
    } catch (_) {
      return;
    }
    if (r == null || !mounted || _ouvert) return;
    _ouvert = true;
    await showDialog<void>(
      context: context,
      builder: (_) => DialogueResumeSoir(etat: widget.etat, resume: r!),
    );
    await widget.etat.marquerResumeVu(r);
    _ouvert = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Le résumé du soir, avec le bouton « Envoyer sur WhatsApp ».
class DialogueResumeSoir extends StatelessWidget {
  const DialogueResumeSoir({
    super.key,
    required this.etat,
    required this.resume,
  });

  final EtatApplication etat;
  final ResumeSoir resume;

  Widget _ligne(String titre, String valeur, {Color? couleur, Key? cle}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(titre, style: const TextStyle(fontSize: 17))),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                valeur,
                key: cle,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: couleur,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = resume;
    return AlertDialog(
      key: const Key('resume-soir'),
      title: Row(
        children: [
          const Icon(Icons.nightlight_round, color: CouleursZp.marque),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Résumé du soir',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${r.date} · caisse fermée par ${r.fermePar}',
              style: const TextStyle(fontSize: 15, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 8),
            _ligne(
              'Ventes (${r.nombreVentes})',
              formatFrancs(r.ventes),
              couleur: CouleursZp.argentEntre,
              cle: const Key('resume-soir-ventes'),
            ),
            _ligne(
              'Bénéfice estimé',
              formatFrancs(r.benefice),
              couleur: r.benefice >= 0
                  ? CouleursZp.argentEntre
                  : CouleursZp.argentSort,
            ),
            _ligne('Dépenses', formatFrancs(r.depenses)),
            _ligne(
              'Caisse',
              r.texteEcart,
              couleur: r.ecart < 0 ? CouleursZp.argentSort : null,
              cle: const Key('resume-soir-ecart'),
            ),
            _ligne(
              'Stock bas',
              r.stockBas.isEmpty
                  ? 'rien à racheter'
                  : '${r.stockBas.length} produit${r.stockBas.length > 1 ? 's' : ''}',
            ),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(
          key: const Key('bouton-resume-vu'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer', style: TextStyle(fontSize: 17)),
        ),
        FilledButton.icon(
          key: const Key('bouton-resume-whatsapp'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () async {
            final ok = await etat.services.ouvrirLien(lienWhatsApp(r.texte()));
            if (!context.mounted) return;
            if (ok) {
              Navigator.of(context).pop();
            } else {
              annoncer(context, 'WhatsApp ne s\'ouvre pas.', erreur: true);
            }
          },
          icon: const Icon(Icons.send_rounded),
          label: const Text(
            'Envoyer sur WhatsApp',
            style: TextStyle(fontSize: 17),
          ),
        ),
      ],
    );
  }
}
