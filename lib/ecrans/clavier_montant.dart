import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domaine/argent.dart';
import '../theme/couleurs.dart';

/// Grand clavier pour taper un montant en F (pas de virgule : le franc CFA n'a pas de centimes).
class ClavierMontant extends StatelessWidget {
  const ClavierMontant({
    super.key,
    required this.valeur,
    required this.onChange,
    this.maximum = 99999999,
  });

  final int valeur;
  final ValueChanged<int> onChange;
  final int maximum;

  void _toucher(String t) {
    HapticFeedback.selectionClick();
    if (t == '<') {
      onChange(valeur ~/ 10);
      return;
    }
    final nouveau = int.parse('$valeur$t');
    if (nouveau <= maximum) onChange(nouveau);
  }

  static final Map<LogicalKeyboardKey, String> _chiffres = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  /// Clavier physique (PC) : chiffres et effacement.
  KeyEventResult _touche(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _toucher('<');
      return KeyEventResult.handled;
    }
    final chiffre = _chiffres[k];
    if (chiffre != null) {
      _toucher(chiffre);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(autofocus: true, onKeyEvent: _touche, child: _clavier());
  }

  Widget _clavier() {
    return LayoutBuilder(
      builder: (context, c) {
        final hauteur = ((c.maxHeight.isFinite ? c.maxHeight : 300) / 4 - 8)
            .clamp(30.0, 64.0);
        // Si la place manque encore (très petit écran), le clavier rétrécit au lieu de déborder.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: c.maxWidth.isFinite ? c.maxWidth : 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final rangee in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['000', '0', '<'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        for (final t in rangee)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                height: hauteur,
                                child: FilledButton.tonal(
                                  key: Key('montant-$t'),
                                  onPressed: () => _toucher(t),
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: CouleursZp.surface,
                                    foregroundColor: CouleursZp.texte,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: const BorderSide(
                                      color: CouleursZp.ligne,
                                      width: 2,
                                    ),
                                  ),
                                  child: t == '<'
                                      ? const Icon(
                                          Icons.backspace_rounded,
                                          size: 26,
                                          semanticLabel: 'Effacer',
                                        )
                                      : Text(
                                          t,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                          ),
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

/// Montant affiché en très grand (« 12 500 F »), dans la couleur voulue.
class MontantGeant extends StatelessWidget {
  const MontantGeant(
    this.montant, {
    super.key,
    this.couleur = CouleursZp.texte,
    this.taille = 52,
  });

  final int montant;
  final Color couleur;
  final double taille;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      formatFrancs(montant),
      style: TextStyle(
        fontSize: taille,
        fontWeight: FontWeight.w700,
        color: couleur,
        height: 1.05,
      ),
    ),
  );
}

/// Montant pour la voix : « 3250 francs » (la synthèse lit mieux sans espaces).
String montantPourVoix(int montant) => '$montant francs';
