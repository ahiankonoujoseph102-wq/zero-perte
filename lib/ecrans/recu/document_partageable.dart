import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../services/partage.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import 'capture.dart';

/// Un document blanc (devis, reçu de retour, rapport) affiché à l'écran, avec
/// le bouton qui l'envoie en image sur WhatsApp (ou l'enregistre sur PC).
class DocumentPartageable extends StatefulWidget {
  const DocumentPartageable({
    super.key,
    required this.etat,
    required this.texte,
    required this.child,
    this.cleBouton = 'bouton-envoyer-document',
    this.libelleBouton = 'Envoyer sur WhatsApp',
    this.fondBlanc = true,
  });

  final EtatApplication etat;

  /// Texte envoyé avec l'image.
  final String texte;
  final Widget child;
  final String cleBouton;
  final String libelleBouton;

  /// Faux : le document garde le fond de l'application (rapport en image).
  final bool fondBlanc;

  @override
  State<DocumentPartageable> createState() => _DocumentPartageableState();
}

class _DocumentPartageableState extends State<DocumentPartageable> {
  final _cadre = GlobalKey();
  bool _enCours = false;

  Future<void> _envoyer() async {
    setState(() => _enCours = true);
    try {
      final png = await capturerPng(_cadre);
      if (png == null) return;
      final r = await widget.etat.services.partagerImage(png, widget.texte);
      if (!mounted) return;
      if (r == ResultatPartage.echec) {
        annoncer(context, 'Impossible d\'envoyer l\'image.', erreur: true);
      } else if (r == ResultatPartage.enregistre) {
        annoncer(
          context,
          'Image enregistrée dans Documents › Zero Perte › Recus. '
          'Joignez-la dans WhatsApp (le texte est déjà copié).',
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: Key(widget.cleBouton),
          onPressed: _enCours ? null : _envoyer,
          icon: const Icon(Icons.send_rounded),
          label: Text(
            widget.libelleBouton,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 60),
            foregroundColor: CouleursZp.argentEntreClair,
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
            color: widget.fondBlanc ? CouleursRecu.cadre : CouleursZp.fond,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
