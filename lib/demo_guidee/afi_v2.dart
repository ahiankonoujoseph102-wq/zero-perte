import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Afi (validée par le propriétaire le 22/11).
///
/// Afi en buste (tête, cou, haut des épaules) dans un médaillon rond aux
/// couleurs de l'application, comme les assistants des grandes applications.
/// Illustration plate dessinée en formes vectorielles : robe en pagne,
/// foulard noué, boucles d'oreilles, visage expressif et formes de bouche
/// pour la parole. Pas de bras : le cadre or et la flèche montrent le bouton,
/// Afi tourne un peu la tête et le regard vers lui.

/// Formes de bouche pour la parole.
enum FormeBouche { fermee, a, o, e, m }

enum Humeur { neutre, sourire, joie }

class EtatAfi {
  const EtatAfi({
    this.t = 0,
    this.ouverture = 0,
    this.forme = FormeBouche.fermee,
    this.humeur = Humeur.sourire,
    this.regard = 0,
    this.regardY = 0,
    this.inclinaison = 0,
    this.paupieres = 1,
  });

  /// Temps en secondes (respiration, tête).
  final double t;

  /// Ouverture de la bouche (0 à 1).
  final double ouverture;
  final FormeBouche forme;
  final Humeur humeur;

  /// Direction du regard : −1 = vers la gauche de l'écran, 1 = vers la
  /// droite ; [regardY] : −1 = vers le haut, 1 = vers le bas. La tête suit
  /// un peu.
  final double regard;
  final double regardY;

  /// Inclinaison de la tête en plus (radians, « au revoir »).
  final double inclinaison;

  /// 1 = yeux ouverts, 0 = fermés (clignement).
  final double paupieres;
}

// Palette (thème de l'application + peau).
const _peau = Color(0xFF8B5A3C);
const _peauOmbre = Color(0xFF6E432B);
const _peauClaire = Color(0xFFA06B49);
const _bleu = Color(0xFF2F6FE0);
const _bleuOmbre = Color(0xFF2257B8);
const _bleuNuit = Color(0xFF0B1730);
const _or = Color(0xFFF2A33A);
const _orClair = Color(0xFFF8BE5F);
const _orOmbre = Color(0xFFCF8424);
const _vert = Color(0xFF2BC77A);
const _blanc = Color(0xFFFCF8F2);
const _brun = Color(0xFF26170F);
const _levreHaut = Color(0xFF5E2A24);
const _levreBas = Color(0xFF76372F);
const _interieur = Color(0xFF3A1311);

/// Peintre d'Afi : médaillon rond (le buste est dessiné sur une grille de
/// 400 de large ; le médaillon en montre la tête, le cou et le haut des
/// épaules).
class PeintreAfiV2 extends CustomPainter {
  const PeintreAfiV2(this.e);
  final EtatAfi e;

  /// Centre et rayon du médaillon dans la grille du buste.
  static const _centre = Offset(200, 230);
  static const _rayon = 230.0;

  Paint _p(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Le médaillon remplit le carré disponible.
    final s = math.min(size.width, size.height) / (2 * _rayon);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-_centre.dx, -_centre.dy);

    // Fond du médaillon : bleu de l'application, plus clair au centre.
    final disque = Rect.fromCircle(center: _centre, radius: _rayon);
    canvas.drawCircle(
      _centre,
      _rayon,
      Paint()
        ..isAntiAlias = true
        ..shader = const RadialGradient(
          center: Alignment(0, -0.25),
          radius: 0.85,
          colors: [Color(0xFF24448A), Color(0xFF102250)],
        ).createShader(disque),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(disque));

    // Respiration : le buste monte et descend à peine.
    final souffle = math.sin(e.t * 1.7) * 1.6;
    final regard = e.regard.clamp(-1.0, 1.0);
    final teteX = math.sin(e.t * 0.8) * 2.2 + regard * 6;
    final teteAngle =
        math.sin(e.t * 0.6) * 0.025 +
        regard * 0.06 +
        e.inclinaison +
        (e.humeur == Humeur.joie ? math.sin(e.t * 2.4) * 0.02 : 0);

    _buste(canvas, souffle);
    canvas.save();
    // Tête un peu plus basse : cou de longueur naturelle.
    canvas.translate(200 + teteX, 316 + souffle * 0.6);
    canvas.rotate(teteAngle);
    canvas.translate(-200, -300);
    _cou(canvas);
    _tete(canvas);
    canvas.restore();
    canvas.restore();

    // Anneau or, liseré vert à l'intérieur.
    canvas.drawCircle(
      _centre,
      _rayon - 5,
      _p(_or)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawCircle(
      _centre,
      _rayon - 12.5,
      _p(_vert)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Buste : épaules, robe en pagne
  // ---------------------------------------------------------------------------

  void _buste(Canvas c, double souffle) {
    c.save();
    c.translate(0, souffle);
    final robe = Path()
      ..moveTo(168, 298)
      ..cubicTo(140, 304, 112, 312, 96, 334) // épaule gauche
      ..cubicTo(84, 352, 78, 400, 74, 440)
      ..lineTo(66, 660)
      ..lineTo(334, 660)
      ..lineTo(326, 440)
      ..cubicTo(322, 400, 316, 352, 304, 334)
      ..cubicTo(288, 312, 260, 304, 232, 298)
      ..cubicTo(222, 318, 178, 318, 168, 298)
      ..close();
    c.drawPath(robe, _p(_bleu));
    // Ombre douce sous les épaules (volume).
    c.drawPath(
      Path()
        ..moveTo(96, 334)
        ..cubicTo(110, 372, 112, 420, 108, 660)
        ..lineTo(66, 660)
        ..lineTo(74, 440)
        ..cubicTo(78, 400, 84, 352, 96, 334)
        ..close(),
      _p(_bleuOmbre),
    );
    c.drawPath(
      Path()
        ..moveTo(304, 334)
        ..cubicTo(290, 372, 288, 420, 292, 660)
        ..lineTo(334, 660)
        ..lineTo(326, 440)
        ..cubicTo(322, 400, 316, 352, 304, 334)
        ..close(),
      _p(_bleuOmbre),
    );

    // Encolure bordée d'or et de vert.
    final encolure = Path()
      ..moveTo(166, 297)
      ..cubicTo(176, 326, 224, 326, 234, 297);
    c.drawPath(
      encolure,
      _p(_or)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()
        ..moveTo(160, 304)
        ..cubicTo(174, 340, 226, 340, 240, 304),
      _p(_vert)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Bande de pagne en travers de la poitrine : losanges réguliers.
    c.save();
    c.clipPath(robe);
    final bande = Rect.fromLTWH(60, 400, 280, 34);
    c.drawRect(bande, _p(_bleuNuit));
    for (var x = 62.0; x < 340; x += 28) {
      final l = Path()
        ..moveTo(x + 14, 403)
        ..lineTo(x + 26, 417)
        ..lineTo(x + 14, 431)
        ..lineTo(x + 2, 417)
        ..close();
      c.drawPath(l, _p(_or));
      c.drawCircle(Offset(x + 14, 417), 3, _p(_bleuNuit));
    }
    c.drawLine(
      const Offset(60, 400),
      const Offset(340, 400),
      _p(_vert)..strokeWidth = 3,
    );
    c.drawLine(
      const Offset(60, 434),
      const Offset(340, 434),
      _p(_vert)..strokeWidth = 3,
    );
    // Petits motifs réguliers sur le haut de la robe.
    for (var y = 352.0; y < 396; y += 22) {
      for (var x = 98.0 + (y % 44 == 0 ? 0 : 11); x < 304; x += 22) {
        if ((x - 200).abs() < 30 && y < 340) continue;
        c.drawCircle(Offset(x, y), 2.2, _p(_orClair.withValues(alpha: 0.55)));
      }
    }
    c.restore();
    // Haut des manches, par-dessus les côtés de la robe : les épaules
    // continuent jusqu'au bord du médaillon (le buste n'a pas l'air coupé).
    for (final sens in [-1.0, 1.0]) {
      double x(double v) => 200 + sens * (v - 200);
      final manche = Path()
        ..moveTo(x(128), 304)
        ..cubicTo(x(100), 309, x(76), 322, x(62), 344)
        ..cubicTo(x(44), 370, x(30), 420, x(22), 520)
        ..lineTo(x(106), 520)
        ..cubicTo(x(104), 440, x(108), 360, x(128), 304)
        ..close();
      c.drawPath(manche, _p(_bleu));
      // Volume : côté extérieur un peu plus sombre.
      c.drawPath(
        Path()
          ..moveTo(x(56), 354)
          ..cubicTo(x(42), 390, x(34), 440, x(32), 520)
          ..lineTo(x(22), 520)
          ..cubicTo(x(30), 420, x(44), 370, x(56), 354)
          ..close(),
        _p(_bleuOmbre),
      );
      // Couture d'emmanchure.
      c.drawPath(
        Path()
          ..moveTo(x(128), 304)
          ..cubicTo(x(108), 360, x(104), 440, x(106), 520),
        _p(_bleuOmbre)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    }
    c.restore();
  }

  void _cou(Canvas c) {
    final cou = Path()
      ..moveTo(176, 232)
      ..lineTo(224, 232)
      ..cubicTo(224, 262, 228, 282, 238, 290)
      ..cubicTo(222, 302, 178, 302, 162, 290)
      ..cubicTo(172, 282, 176, 262, 176, 232)
      ..close();
    c.drawPath(cou, _p(_peau));
    // Ombre sous le menton.
    c.drawPath(
      Path()
        ..moveTo(178, 238)
        ..cubicTo(190, 258, 210, 258, 222, 238)
        ..lineTo(222, 250)
        ..cubicTo(208, 266, 192, 266, 178, 250)
        ..close(),
      _p(_peauOmbre),
    );
  }

  // ---------------------------------------------------------------------------
  // Tête : visage, oreilles, foulard
  // ---------------------------------------------------------------------------

  void _tete(Canvas c) {
    // Boucles d'oreilles (derrière les oreilles, devant le cou).
    for (final x in [140.0, 260.0]) {
      c.drawCircle(
        Offset(x, 214),
        9,
        _p(_or)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2,
      );
    }
    // Oreilles.
    for (final (x, sens) in [(140.0, -1.0), (260.0, 1.0)]) {
      final o = Path()
        ..moveTo(x - sens * 2, 170)
        ..cubicTo(x + sens * 12, 166, x + sens * 13, 196, x - sens * 1, 202)
        ..close();
      c.drawPath(o, _p(_peau));
      c.drawPath(
        Path()
          ..moveTo(x + sens * 2, 176)
          ..cubicTo(x + sens * 8, 178, x + sens * 8, 192, x + sens * 2, 196),
        _p(_peauOmbre)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // Visage : front, pommettes, mâchoire, menton.
    final visage = Path()
      ..moveTo(200, 108)
      ..cubicTo(236, 108, 262, 132, 262, 170)
      ..cubicTo(262, 206, 246, 232, 222, 246)
      ..cubicTo(212, 252, 188, 252, 178, 246)
      ..cubicTo(154, 232, 138, 206, 138, 170)
      ..cubicTo(138, 132, 164, 108, 200, 108)
      ..close();
    c.drawPath(visage, _p(_peau));
    // Lumière douce sur le front et les pommettes.
    c.drawOval(
      Rect.fromCenter(center: const Offset(206, 136), width: 52, height: 18),
      _p(_peauClaire.withValues(alpha: 0.45)),
    );
    for (final x in [166.0, 234.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(x, 200), width: 26, height: 14),
        _p(
          const Color(0xFFB0614A)
              .withValues(alpha: e.humeur == Humeur.neutre ? 0.18 : 0.32),
        ),
      );
    }

    _sourcils(c);
    _yeux(c);
    _nez(c);
    _bouche(c);
    _foulard(c);
  }

  void _sourcils(Canvas c) {
    final leve = switch (e.humeur) {
      Humeur.joie => -4.0,
      Humeur.sourire => -1.5,
      Humeur.neutre => 0.0,
    };
    for (final sens in [-1.0, 1.0]) {
      final x0 = 200 + sens * 12;
      final x1 = 200 + sens * 44;
      final s = Path()
        ..moveTo(x0, 150 + leve)
        ..cubicTo(
          200 + sens * 22,
          142 + leve,
          200 + sens * 34,
          140 + leve,
          x1,
          147 + leve,
        )
        ..cubicTo(
          200 + sens * 34,
          144 + leve,
          200 + sens * 22,
          146 + leve,
          x0,
          154 + leve,
        )
        ..close();
      c.drawPath(s, _p(_brun));
    }
  }

  void _yeux(Canvas c) {
    final rieurs = e.humeur == Humeur.joie;
    for (final sens in [-1.0, 1.0]) {
      final cx = 200 + sens * 28;
      const cy = 170.0;
      if (rieurs) {
        // Yeux plissés de joie : arc + petit pli.
        c.drawPath(
          Path()
            ..moveTo(cx - 13, cy + 2)
            ..quadraticBezierTo(cx, cy - 9, cx + 13, cy + 2),
          _p(_brun)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      final h = 9.5 * e.paupieres.clamp(0.05, 1);
      final oeil = Path()
        ..moveTo(cx - 15, cy + 1)
        ..cubicTo(cx - 8, cy - h - 1, cx + 8, cy - h - 1, cx + 15, cy - 1)
        ..cubicTo(cx + 8, cy + h * 0.75, cx - 8, cy + h * 0.75, cx - 15, cy + 1)
        ..close();
      c.drawPath(oeil, _p(_blanc));
      if (e.paupieres > 0.25) {
        c.save();
        c.clipPath(oeil);
        // L'iris suit le regard (vers le bouton montré).
        final iris = Offset(
          cx + sens * 0.5 + e.regard.clamp(-1.0, 1.0) * 5,
          cy + e.regardY.clamp(-1.0, 1.0) * 2.5,
        );
        c.drawCircle(iris, 7.2, _p(const Color(0xFF4A2A16)));
        c.drawCircle(iris, 3.8, _p(_brun));
        c.drawCircle(iris + const Offset(2.3, -2.8), 2, _p(Colors.white));
        c.restore();
      }
      // Paupière supérieure et cils.
      c.drawPath(
        Path()
          ..moveTo(cx - 16, cy + 1)
          ..cubicTo(cx - 8, cy - h - 2, cx + 8, cy - h - 2, cx + 16, cy - 1),
        _p(_brun)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
      c.drawLine(
        Offset(cx + sens * 15, cy - 1),
        Offset(cx + sens * 20, cy - 5),
        _p(_brun)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
      // Pli de la paupière.
      c.drawPath(
        Path()
          ..moveTo(cx - 11, cy - h - 4)
          ..quadraticBezierTo(cx, cy - h - 9, cx + 11, cy - h - 4),
        _p(_peauOmbre)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  void _nez(Canvas c) {
    // Arête (ombre légère) et base avec narines.
    c.drawPath(
      Path()
        ..moveTo(196, 176)
        ..cubicTo(194, 188, 192, 196, 190, 202),
      _p(_peauOmbre.withValues(alpha: 0.6))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final base = Path()
      ..moveTo(184, 204)
      ..cubicTo(184, 212, 192, 213, 196, 210)
      ..cubicTo(198, 213, 202, 213, 204, 210)
      ..cubicTo(208, 213, 216, 212, 216, 204);
    c.drawPath(
      base,
      _p(_peauOmbre)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(200, 203), width: 14, height: 8),
      _p(_peauClaire.withValues(alpha: 0.5)),
    );
  }

  /// Bouche : lèvres dessinées (arc de Cupidon, lèvre inférieure pleine),
  /// intérieur, dents et langue selon la forme.
  void _bouche(Canvas c) {
    const cx = 200.0;
    const cy = 226.0;
    final sourire = switch (e.humeur) {
      Humeur.joie => 1.0,
      Humeur.sourire => 0.6,
      Humeur.neutre => 0.1,
    };
    var ouv = e.ouverture.clamp(0.0, 1.0);
    var largeur = 46.0 + sourire * 6;
    var rond = 0.0;
    switch (e.forme) {
      case FormeBouche.fermee:
        ouv = 0;
      case FormeBouche.m:
        ouv = 0;
        largeur -= 6;
      case FormeBouche.a:
        ouv = math.max(ouv, 0.15);
      case FormeBouche.o:
        rond = 1;
        largeur = 30;
        ouv = math.max(ouv, 0.15);
      case FormeBouche.e:
        largeur += 6;
        ouv = math.min(math.max(ouv, 0.1), 0.45);
    }
    final w = largeur / 2;
    final h = ouv * 24; // hauteur de l'ouverture
    final coin = -sourire * 4 * (1 - rond); // coins relevés
    final gauche = Offset(cx - w, cy + coin);
    final droite = Offset(cx + w, cy + coin);

    // Bord intérieur haut et bas de l'ouverture.
    final hautInt = cy - h * 0.25;
    final basInt = cy + h * 0.85;
    if (h > 1) {
      final bouche = Path()
        ..moveTo(gauche.dx + 3, gauche.dy)
        ..cubicTo(
          cx - w * 0.5,
          hautInt - rond * 4,
          cx + w * 0.5,
          hautInt - rond * 4,
          droite.dx - 3,
          droite.dy,
        )
        ..cubicTo(
          cx + w * (0.55 - rond * 0.1),
          basInt + rond * 3,
          cx - w * (0.55 - rond * 0.1),
          basInt + rond * 3,
          gauche.dx + 3,
          gauche.dy,
        )
        ..close();
      c.drawPath(bouche, _p(_interieur));
      c.save();
      c.clipPath(bouche);
      // Dents du haut (forme arrondie, coupée par la bouche).
      if (rond < 0.5) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(cx, hautInt + 1),
            width: w * 1.5,
            height: math.min(10, h * 0.7) * 2,
          ),
          _p(_blanc),
        );
      }
      // Langue.
      if (h > 7) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(cx, basInt - 2),
            width: w * 1.1,
            height: h * 0.55,
          ),
          _p(const Color(0xFFB4504A)),
        );
      }
      c.restore();
    }

    // Lèvre supérieure : arc de Cupidon.
    final haut = Path()
      ..moveTo(gauche.dx, gauche.dy)
      ..cubicTo(
        cx - w * 0.7,
        cy - 7 - rond * 3,
        cx - w * 0.3,
        cy - 9 - rond * 2,
        cx - 3,
        cy - 7 - rond * 2,
      )
      ..quadraticBezierTo(cx, cy - 5 - rond * 2, cx + 3, cy - 7 - rond * 2)
      ..cubicTo(
        cx + w * 0.3,
        cy - 9 - rond * 2,
        cx + w * 0.7,
        cy - 7 - rond * 3,
        droite.dx,
        droite.dy,
      )
      ..cubicTo(
        cx + w * 0.5,
        hautInt + 1 - rond * 4,
        cx - w * 0.5,
        hautInt + 1 - rond * 4,
        gauche.dx,
        gauche.dy,
      )
      ..close();
    c.drawPath(haut, _p(_levreHaut));

    // Lèvre inférieure, pleine.
    final bas = Path()
      ..moveTo(gauche.dx + 2, gauche.dy + 1)
      ..cubicTo(
        cx - w * 0.5,
        basInt + (h > 1 ? 0 : 1) + rond * 3,
        cx + w * 0.5,
        basInt + (h > 1 ? 0 : 1) + rond * 3,
        droite.dx - 2,
        droite.dy + 1,
      )
      ..cubicTo(
        cx + w * 0.6,
        basInt + 12 + rond * 3,
        cx - w * 0.6,
        basInt + 12 + rond * 3,
        gauche.dx + 2,
        gauche.dy + 1,
      )
      ..close();
    c.drawPath(bas, _p(_levreBas));
    // Reflet de la lèvre inférieure.
    c.drawOval(
      Rect.fromCenter(
        center: Offset(cx, basInt + 6 + rond * 2),
        width: w * 0.7,
        height: 3.4,
      ),
      _p(Colors.white.withValues(alpha: 0.18)),
    );
    // Lèvres pincées pour « m ».
    if (e.forme == FormeBouche.m || h <= 1) {
      c.drawPath(
        Path()
          ..moveTo(gauche.dx, gauche.dy)
          ..cubicTo(
            cx - w * 0.4,
            cy + 1.5,
            cx + w * 0.4,
            cy + 1.5,
            droite.dx,
            droite.dy,
          ),
        _p(_interieur)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Foulard noué (gele) : volume qui enveloppe la tête, plis, nœud devant
  /// avec deux pans qui s'ouvrent en éventail.
  void _foulard(Canvas c) {
    // Base : enveloppe la tête, s'arrête sur le front (ligne courbe).
    final base = Path()
      ..moveTo(134, 168)
      ..cubicTo(122, 120, 140, 66, 200, 58)
      ..cubicTo(260, 66, 278, 120, 266, 168)
      ..cubicTo(258, 144, 236, 128, 200, 128)
      ..cubicTo(164, 128, 142, 144, 134, 168)
      ..close();
    c.drawPath(base, _p(_or));
    // Plis enroulés (bandes en biais, plus sombres).
    c.save();
    c.clipPath(base);
    final pli = _p(_orOmbre);
    for (final (y0, y1) in [(150.0, 96.0), (132.0, 74.0)]) {
      c.drawPath(
        Path()
          ..moveTo(120, y0)
          ..cubicTo(170, y0 - 30, 230, y1 - 10, 290, y1 - 36)
          ..lineTo(290, y1 - 24)
          ..cubicTo(230, y1 + 4, 170, y0 - 16, 120, y0 + 12)
          ..close(),
        pli,
      );
    }
    // Liseré vert sur le bord frontal.
    c.restore();
    c.drawPath(
      Path()
        ..moveTo(136, 164)
        ..cubicTo(144, 142, 166, 131, 200, 131)
        ..cubicTo(234, 131, 256, 142, 264, 164),
      _p(_vert)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    // Motif discret (points bleu nuit réguliers).
    c.save();
    c.clipPath(base);
    for (var y = 76.0; y < 128; y += 16) {
      for (var x = 140.0 + (y % 32 == 12 ? 8 : 0); x < 262; x += 16) {
        c.drawCircle(Offset(x, y), 1.8, _p(_bleuNuit.withValues(alpha: 0.35)));
      }
    }
    c.restore();

    // Nœud devant, un peu sur le côté, et deux pans en éventail.
    final pan1 = Path()
      ..moveTo(212, 70)
      ..cubicTo(196, 40, 172, 22, 150, 26)
      ..cubicTo(158, 40, 176, 58, 206, 80)
      ..close();
    final pan2 = Path()
      ..moveTo(220, 70)
      ..cubicTo(238, 36, 266, 22, 286, 30)
      ..cubicTo(276, 46, 254, 64, 226, 82)
      ..close();
    c.drawPath(pan1, _p(_orClair));
    c.drawPath(pan2, _p(_or));
    c.drawPath(
      Path()
        ..moveTo(160, 30)
        ..cubicTo(178, 36, 194, 54, 208, 76),
      _p(_orOmbre)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    c.drawPath(
      Path()
        ..moveTo(278, 32)
        ..cubicTo(260, 40, 240, 58, 222, 78),
      _p(_orOmbre)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Le nœud lui-même.
    c.drawOval(
      Rect.fromCenter(center: const Offset(216, 78), width: 30, height: 22),
      _p(_orOmbre),
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(216, 76), width: 24, height: 16),
      _p(_or),
    );
  }

  @override
  bool shouldRepaint(PeintreAfiV2 old) => true;
}

/// Médaillon fixe (planche, essais).
class AfiV2 extends StatelessWidget {
  const AfiV2({super.key, required this.etat, this.taille = 200});
  final EtatAfi etat;
  final double taille;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: taille,
    child: CustomPaint(painter: PeintreAfiV2(etat)),
  );
}

/// Médaillon animé d'Afi : respiration, petits mouvements de tête,
/// clignements, bouche qui suit la voix ([bouche] : ouverture de 0 à 1,
/// [forme] : forme de la bouche si la voix la donne).
class MedaillonAfi extends StatefulWidget {
  const MedaillonAfi({
    super.key,
    this.taille = 96,
    required this.bouche,
    this.forme,
    this.humeur = Humeur.sourire,
    this.auRevoir = false,
    this.cible,
    this.anime = true,
  });

  final double taille;
  final ValueListenable<double> bouche;
  final ValueListenable<FormeBouche?>? forme;
  final Humeur humeur;

  /// « Au revoir » : yeux rieurs et petit signe de tête.
  final bool auRevoir;

  /// Direction du bouton montré, vue depuis Afi (dx, dy de longueur
  /// quelconque) ; nul : Afi regarde la personne.
  final Offset? cible;

  /// Faux dans les captures d'écran (image fixe).
  final bool anime;

  @override
  State<MedaillonAfi> createState() => _EtatMedaillon();
}

class _EtatMedaillon extends State<MedaillonAfi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _temps = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  /// Regard actuel (suit la cible en douceur).
  double _regard = 0;
  double _regardY = 0;

  @override
  void initState() {
    super.initState();
    if (widget.anime) _temps.repeat();
  }

  @override
  void didUpdateWidget(MedaillonAfi old) {
    super.didUpdateWidget(old);
    if (widget.anime && !_temps.isAnimating) _temps.repeat();
    if (!widget.anime && _temps.isAnimating) _temps.stop();
  }

  @override
  void dispose() {
    _temps.dispose();
    super.dispose();
  }

  /// Les yeux se ferment brièvement toutes les ~3,7 s.
  static double _paupieres(double t) {
    final cycle = t % 3.7;
    if (cycle < 0.09) return 1 - cycle / 0.09;
    if (cycle < 0.18) return (cycle - 0.09) / 0.09;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final listes = <Listenable>[_temps, widget.bouche];
    if (widget.forme != null) listes.add(widget.forme!);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.taille,
        child: AnimatedBuilder(
          animation: Listenable.merge(listes),
          builder: (context, _) {
            final t = widget.anime ? _temps.value * 60 : 0.0;
            var vise = 0.0;
            var viseY = 0.0;
            final c = widget.cible;
            if (c != null && c.distance > 0) {
              final d = c / c.distance;
              vise = d.dx;
              viseY = d.dy;
            }
            final f = widget.anime ? 0.12 : 1.0;
            _regard += (vise - _regard) * f;
            _regardY += (viseY - _regardY) * f;
            final o = widget.bouche.value.clamp(0.0, 1.0);
            final forme =
                widget.forme?.value ??
                (o < 0.08
                    ? FormeBouche.fermee
                    : (o < 0.4 ? FormeBouche.e : FormeBouche.a));
            return CustomPaint(
              painter: PeintreAfiV2(
                EtatAfi(
                  t: t,
                  ouverture: o,
                  forme: forme,
                  humeur: widget.auRevoir ? Humeur.joie : widget.humeur,
                  regard: _regard,
                  regardY: _regardY,
                  inclinaison: widget.auRevoir
                      ? 0.06 + (widget.anime ? math.sin(t * 3) * 0.05 : 0)
                      : 0,
                  paupieres: widget.humeur == Humeur.joie || widget.auRevoir
                      ? 1
                      : _paupieres(t),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
