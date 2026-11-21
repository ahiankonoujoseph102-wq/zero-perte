import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domaine/utilisateurs.dart';
import '../theme/couleurs.dart';

/// Saisie d'un code secret de 4 chiffres : 4 ronds + un grand clavier.
/// Les chiffres ne s'affichent jamais (personne derrière l'épaule ne les voit).
class SaisiePin extends StatefulWidget {
  const SaisiePin({
    super.key,
    required this.titre,
    required this.onComplet,
    this.erreur,
    this.couleur,
  });

  final String titre;

  /// Appelé avec les 4 chiffres ; le champ se vide ensuite.
  final ValueChanged<String> onComplet;
  final String? erreur;
  final Color? couleur;

  @override
  State<SaisiePin> createState() => _SaisiePinState();
}

class _SaisiePinState extends State<SaisiePin> {
  String _pin = '';

  void _toucher(String chiffre) {
    if (_pin.length >= longueurPin) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += chiffre);
    if (_pin.length == longueurPin) {
      final pin = _pin;
      Future.microtask(() {
        if (mounted) setState(() => _pin = '');
        widget.onComplet(pin);
      });
    }
  }

  void _effacer() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final couleur = widget.couleur ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, c) {
        // Taille des touches adaptée à la place disponible.
        final touche = ((c.maxHeight - 110) / 4 - 10).clamp(40.0, 76.0);
        // Sécurité : si la place manque encore (très petit écran), tout rétrécit
        // un peu plutôt que de déborder.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: c.maxWidth.isFinite ? c.maxWidth : 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  key: const Key('pin-points'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < longueurPin; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? couleur : Colors.transparent,
                          border: Border.all(color: couleur, width: 3),
                        ),
                      ),
                  ],
                ),
                SizedBox(
                  height: 34,
                  child: widget.erreur == null
                      ? null
                      : Center(
                          child: Text(
                            widget.erreur!,
                            key: const Key('pin-erreur'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: CouleursZp.argentSort,
                            ),
                          ),
                        ),
                ),
                for (final rangee in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['', '0', '<'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final t in rangee)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: SizedBox(
                              width: touche * 1.25,
                              height: touche,
                              child: t.isEmpty
                                  ? null
                                  : FilledButton.tonal(
                                      key: Key('pin-$t'),
                                      onPressed: t == '<'
                                          ? _effacer
                                          : () => _toucher(t),
                                      style: FilledButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: CouleursZp.surface,
                                        foregroundColor: CouleursZp.texte,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        side: const BorderSide(
                                          color: CouleursZp.ligne,
                                          width: 2,
                                        ),
                                      ),
                                      child: t == '<'
                                          ? const Icon(
                                              Icons.backspace_rounded,
                                              size: 28,
                                              semanticLabel: 'Effacer',
                                            )
                                          : Text(
                                              t,
                                              style: const TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
