import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/etat_application.dart';
import '../domaine/utilisateurs.dart';
import '../theme/couleurs.dart';
import 'communs.dart';
import 'logo_boutique.dart';

/// Couleur de l'avatar d'une personne (stable, d'après son nom ; jamais vert ni rouge).
Color couleurAvatar(String nom, {int? position}) {
  const couleurs = [
    0xFF1E5AA8,
    0xFF5B3F9A,
    0xFF0E6B73,
    0xFF6D4C3D,
    0xFF283593,
    0xFF7A2E5C,
    0xFF37474F,
  ];
  final h = nom.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
  return Color(couleurs[(position ?? h) % couleurs.length]);
}

/// Avatar rond avec l'initiale.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.nom,
    this.taille = 72,
    this.bloque = false,
    this.position,
  });
  final String nom;
  final double taille;
  final bool bloque;

  /// Position dans une liste : deux voisins n'ont jamais la même couleur.
  final int? position;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: taille / 2,
    backgroundColor: bloque
        ? CouleursZp.ligne
        : couleurAvatar(nom, position: position),
    child: Text(
      nom.isEmpty ? '?' : nom.substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: taille * 0.45,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Écran d'entrée : on tape son code et on entre (le code reconnaît la
/// personne : patron ou vendeur). Pas de liste de noms à toucher.
class PageConnexion extends StatefulWidget {
  const PageConnexion({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageConnexion> createState() => _PageConnexionState();
}

class _PageConnexionState extends State<PageConnexion> {
  String _code = '';
  String? _erreur;
  bool _enCours = false;

  EtatApplication get etat => widget.etat;

  @override
  void initState() {
    super.initState();
    // Un message resté affiché ne doit pas cacher le clavier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
  }

  void _touche(String t) {
    if (_enCours) return;
    setState(() {
      _erreur = null;
      if (t == '<') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < longueurPinPatron) {
        _code += t;
      }
    });
  }

  Future<void> _valider() async {
    if (_code.length < longueurPin || _enCours) return;
    setState(() => _enCours = true);
    try {
      final bloque = await etat.entreeBloqueeJusqua();
      if (bloque != null) {
        setState(() {
          _code = '';
          _erreur =
              'Trop de codes faux. Réessayez à ${bloque.hour.toString().padLeft(2, '0')}:${bloque.minute.toString().padLeft(2, '0')}.';
        });
        return;
      }
      final u = await etat.connecterParCode(_code);
      if (u == null) {
        final reste = etat.essaisEntreeRestants;
        setState(() {
          _code = '';
          _erreur =
              'Code faux.${reste < EtatApplication.essaisPin ? ' Encore $reste essai${reste > 1 ? 's' : ''}.' : ''}';
        });
        await etat.services.voix.dire('Code faux.');
      }
    } catch (e) {
      setState(() {
        _code = '';
        _erreur = messageErreur(e);
      });
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  KeyEventResult _clavier(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _valider();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      _touche('<');
      return KeyEventResult.handled;
    }
    final c = e.character;
    if (c != null && RegExp(r'^[0-9]$').hasMatch(c)) {
      _touche(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _clavier,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: LayoutBuilder(
                builder: (context, c) {
                  final touche = ((c.maxHeight - 340) / 4 - 10).clamp(
                    48.0,
                    84.0,
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LogoBoutique(config: etat.config, taille: 64),
                        const SizedBox(height: 8),
                        Text(
                          etat.config.nom,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Tapez votre code',
                          style: TextStyle(
                            fontSize: 19,
                            color: CouleursZp.texteDoux,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Un rond par chiffre tapé (le code n'est jamais montré).
                        SizedBox(
                          height: 26,
                          child: Row(
                            key: const Key('code-points'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _code.length; i++)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: couleur,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 30,
                          child: _erreur == null
                              ? null
                              : Text(
                                  _erreur!,
                                  key: const Key('code-erreur'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: CouleursZp.argentSort,
                                  ),
                                ),
                        ),
                        for (final rangee in const [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['<', '0', 'OK'],
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                for (final t in rangee)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: SizedBox(
                                        height: touche,
                                        child: _ToucheCode(
                                          texte: t,
                                          couleur: couleur,
                                          onTap: t == 'OK'
                                              ? (_code.length >= longueurPin
                                                    ? _valider
                                                    : null)
                                              : () => _touche(t),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToucheCode extends StatelessWidget {
  const _ToucheCode({
    required this.texte,
    required this.couleur,
    required this.onTap,
  });

  final String texte;
  final Color couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ok = texte == 'OK';
    return Material(
      color: ok
          ? (onTap == null ? CouleursZp.ligne : CouleursZp.argentEntre)
          : CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ok ? Colors.transparent : CouleursZp.ligne),
      ),
      child: InkWell(
        key: Key('code-$texte'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: texte == '<'
              ? const Icon(Icons.backspace_rounded, size: 30)
              : ok
              ? const Icon(
                  Icons.arrow_forward_rounded,
                  size: 34,
                  color: Colors.white,
                )
              : Text(
                  texte,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
