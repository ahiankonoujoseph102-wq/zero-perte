import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'script_visite.dart' show Expression;

/// Afi, la commerçante qui guide la démonstration.
///
/// Personnage original dessiné en formes vectorielles (aucune image) : une
/// commerçante togolaise souriante, foulard aux couleurs de l'application,
/// boucles d'oreilles or. Léger : un seul [CustomPainter], une seule
/// animation (fluide sur un Android 8 modeste).
///
/// Animations : clignement des yeux, mouvement de tête, bouche qui suit
/// [bouche] (0 = fermée, 1 = grande ouverte), bras qui montre une direction
/// ([geste], angle en radians, nul = bras baissé), expressions.
class AvatarAfi extends StatefulWidget {
  const AvatarAfi({
    super.key,
    this.taille = 120,
    required this.bouche,
    this.expression = Expression.sourire,
    this.geste,
    this.anime = true,
  });

  final double taille;
  final ValueNotifier<double> bouche;
  final Expression expression;

  /// Direction montrée par le bras (radians : 0 = vers la droite, −π/2 =
  /// vers le haut, π = vers la gauche). Nul : bras baissé.
  final double? geste;

  /// Faux dans les captures d'écran (image fixe).
  final bool anime;

  @override
  State<AvatarAfi> createState() => _AvatarAfiState();
}

class _AvatarAfiState extends State<AvatarAfi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _temps = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  /// Bras : de baissé (0) à levé (1), en douceur.
  double _bras = 0;
  double _angleBras = 0;

  @override
  void initState() {
    super.initState();
    if (widget.anime) _temps.repeat();
    _angleBras = widget.geste ?? -math.pi / 2;
  }

  @override
  void didUpdateWidget(AvatarAfi old) {
    super.didUpdateWidget(old);
    if (widget.anime && !_temps.isAnimating) _temps.repeat();
    if (!widget.anime && _temps.isAnimating) _temps.stop();
  }

  @override
  void dispose() {
    _temps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.taille,
        height: widget.taille * 1.2,
        child: AnimatedBuilder(
          animation: Listenable.merge([_temps, widget.bouche]),
          builder: (context, _) {
            final t = _temps.value * 60; // secondes
            // Le bras suit le geste en douceur.
            final leve = widget.expression == Expression.auRevoir
                ? 1.0
                : (widget.geste == null ? 0.0 : 1.0);
            // Image fixe (captures) : position finale tout de suite.
            final f = widget.anime ? 0.15 : 1.0;
            _bras += (leve - _bras) * f;
            if (widget.geste != null) {
              _angleBras += (widget.geste! - _angleBras) * f;
            } else if (widget.expression == Expression.auRevoir) {
              _angleBras = -math.pi / 2 + math.sin(t * 7) * 0.35;
            }
            return CustomPaint(
              painter: _PeintreAfi(
                t: widget.anime ? t : 0,
                bouche: widget.bouche.value.clamp(0, 1).toDouble(),
                expression: widget.expression,
                bras: _bras,
                angleBras: _angleBras,
              ),
            );
          },
        ),
      ),
    );
  }
}

// Couleurs (thème de l'application + peau et cheveux).
const _peau = Color(0xFF8A5A3B);
const _peauOmbre = Color(0xFF6E4429);
const _bleu = Color(0xFF2F7DF6);
const _bleuNuit = Color(0xFF0B1730);
const _or = Color(0xFFF8BE5F);
const _vert = Color(0xFF2BC77A);
const _blanc = Color(0xFFFDFBF7);
const _brun = Color(0xFF2A1A12);
const _levres = Color(0xFF7A3A33);

class _PeintreAfi extends CustomPainter {
  _PeintreAfi({
    required this.t,
    required this.bouche,
    required this.expression,
    required this.bras,
    required this.angleBras,
  });

  final double t;
  final double bouche;
  final Expression expression;
  final double bras;
  final double angleBras;

  /// Les yeux se ferment brièvement toutes les ~3,7 s.
  double get _ouvertureYeux {
    final cycle = t % 3.7;
    if (cycle < 0.12) return 1 - cycle / 0.12;
    if (cycle < 0.24) return (cycle - 0.12) / 0.12;
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Dessin sur une grille de 200 × 240, mise à l'échelle.
    final s = size.width / 200;
    canvas.save();
    canvas.scale(s);
    final p = Paint()..isAntiAlias = true;

    // --- Corps (haut en tissu bleu, col en pagne or et vert) ---
    final corps = Path()
      ..moveTo(28, 240)
      ..quadraticBezierTo(30, 178, 100, 170)
      ..quadraticBezierTo(170, 178, 172, 240)
      ..close();
    canvas.drawPath(corps, p..color = _bleu);
    // Motif de pagne sur le col.
    final col = Path()
      ..moveTo(70, 174)
      ..quadraticBezierTo(100, 200, 130, 174)
      ..lineTo(124, 171)
      ..quadraticBezierTo(100, 190, 76, 171)
      ..close();
    canvas.drawPath(col, p..color = _or);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(60 + i * 20.0, 214 + (i.isEven ? 0 : 8)),
        4,
        p..color = _or.withValues(alpha: 0.85),
      );
    }

    // Bras gauche (côté droit de l'image) : il montre le bouton.
    _dessinerBras(canvas, p);

    // --- Tête (léger mouvement) ---
    final penche =
        math.sin(t * 0.9) * 0.04 +
        (expression == Expression.contente ? math.sin(t * 2.2) * 0.03 : 0);
    final hoche = math.sin(t * 1.3) * 1.5;
    canvas.save();
    canvas.translate(100, 160 + hoche);
    canvas.rotate(penche);
    canvas.translate(-100, -160);

    // Cou.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(86, 132, 28, 44),
        const Radius.circular(10),
      ),
      p..color = _peauOmbre,
    );
    // Oreilles + boucles or.
    for (final x in [52.0, 148.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 104), width: 16, height: 22),
        p..color = _peau,
      );
      canvas.drawCircle(Offset(x, 124), 6, p..color = _or);
      canvas.drawCircle(Offset(x, 124), 2.5, p..color = _bleuNuit);
    }
    // Visage.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 100), width: 96, height: 112),
      p..color = _peau,
    );

    // Foulard (tête) : bleu nuit à bandes or et vert, nœud sur le côté.
    final foulard = Path()
      ..moveTo(48, 92)
      ..quadraticBezierTo(46, 30, 100, 26)
      ..quadraticBezierTo(156, 30, 152, 92)
      ..quadraticBezierTo(126, 66, 100, 68)
      ..quadraticBezierTo(74, 66, 48, 92)
      ..close();
    canvas.drawPath(foulard, p..color = _bleuNuit);
    final bande = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(54, 74)
        ..quadraticBezierTo(100, 44, 146, 74),
      bande..color = _or,
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 60)
        ..quadraticBezierTo(100, 34, 140, 60),
      bande..color = _vert,
    );
    // Nœud.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(140, 30), width: 34, height: 22),
      p..color = _bleuNuit,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(158, 22), width: 22, height: 14),
      p..color = _or,
    );

    // Sourcils.
    final sourcil = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = _brun;
    final hautSourcil = expression == Expression.contente ? -2.0 : 0.0;
    canvas.drawLine(
      Offset(72, 84 + hautSourcil),
      Offset(90, 82 + hautSourcil),
      sourcil,
    );
    canvas.drawLine(
      Offset(110, 82 + hautSourcil),
      Offset(128, 84 + hautSourcil),
      sourcil,
    );

    // Yeux.
    final yeuxRieurs =
        expression == Expression.contente || expression == Expression.auRevoir;
    for (final x in [81.0, 119.0]) {
      if (yeuxRieurs) {
        // Yeux plissés de joie.
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, 98), width: 16, height: 12),
          math.pi,
          math.pi,
          false,
          sourcil..strokeWidth = 3,
        );
      } else {
        final h = 12 * _ouvertureYeux;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 97), width: 16, height: h + 0.5),
          p..color = _blanc,
        );
        if (h > 3) {
          canvas.drawCircle(Offset(x + 1, 97), 4.2, p..color = _brun);
          canvas.drawCircle(Offset(x + 2.2, 95.6), 1.3, p..color = _blanc);
        }
      }
    }

    // Nez.
    canvas.drawPath(
      Path()
        ..moveTo(96, 106)
        ..quadraticBezierTo(100, 118, 106, 114),
      sourcil
        ..strokeWidth = 2.4
        ..color = _peauOmbre,
    );

    // Bouche : sourire au repos, s'ouvre avec la voix.
    final ouverture = bouche * 14;
    final largeur = expression == Expression.neutre ? 22.0 : 28.0;
    if (ouverture < 1.5) {
      canvas.drawPath(
        Path()
          ..moveTo(100 - largeur / 2, 128)
          ..quadraticBezierTo(100, 138, 100 + largeur / 2, 128),
        sourcil
          ..strokeWidth = 3.4
          ..color = _levres,
      );
    } else {
      final r = Rect.fromCenter(
        center: Offset(100, 131 + ouverture / 4),
        width: largeur - ouverture * 0.3,
        height: 4 + ouverture,
      );
      canvas.drawOval(r, p..color = _levres);
      canvas.drawOval(r.deflate(2.2), p..color = const Color(0xFF3A1512));
      // Dents du haut.
      canvas.drawRect(
        Rect.fromLTWH(r.left + 5, r.top + 2, r.width - 10, 3.2),
        p..color = _blanc,
      );
    }
    // Joues (douces) quand elle sourit.
    if (expression != Expression.neutre) {
      for (final x in [70.0, 130.0]) {
        canvas.drawCircle(
          Offset(x, 118),
          6,
          p..color = const Color(0xFFB0644A).withValues(alpha: 0.35),
        );
      }
    }
    canvas.restore();
    canvas.restore();
  }

  void _dessinerBras(Canvas canvas, Paint p) {
    // Au repos, le bras reste le long du corps (caché dans la silhouette).
    if (bras < 0.05) return;
    // Épaule (côté droit de l'image) ; au repos, le bras descend le long du
    // corps.
    // Elle montre avec le bras du côté du bouton (jamais en travers du corps).
    final aGauche = math.cos(angleBras) < -0.05;
    final epaule = aGauche ? const Offset(50, 188) : const Offset(150, 188);
    final repos = aGauche ? math.pi / 2 - 0.25 : math.pi / 2 + 0.25;
    final angle = repos + (angleBras - repos) * bras;
    const longueur = 62.0;
    final coude = epaule + Offset(math.cos(angle), math.sin(angle)) * longueur;
    final manche = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 22
      ..color = _bleu;
    canvas.drawLine(epaule, coude, manche);
    // Main + index tendu.
    canvas.drawCircle(coude, 10, p..color = _peau);
    final doigt = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = _peau;
    if (bras > 0.3) {
      canvas.drawLine(
        coude,
        coude + Offset(math.cos(angle), math.sin(angle)) * 16,
        doigt,
      );
    }
  }

  @override
  bool shouldRepaint(_PeintreAfi old) =>
      old.t != t ||
      old.bouche != bouche ||
      old.expression != expression ||
      old.bras != bras ||
      old.angleBras != angleBras;
}
