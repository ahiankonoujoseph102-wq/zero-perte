import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Afi, version 2 (refonte, EN ATTENTE DE VALIDATION : pas encore utilisée
/// par l'application).
///
/// Illustration plate et soignée, dessinée en formes vectorielles :
/// anatomie juste (cou, épaules, bras en deux parties, coude qui plie, main
/// avec pouce et index), robe en pagne à motif régulier, foulard noué,
/// boucles d'oreilles, visage expressif et formes de bouche pour la parole.

/// Formes de bouche pour la parole.
enum FormeBouche { fermee, a, o, e, m }

/// Pose d'un bras.
sealed class PoseBras {
  const PoseBras();
}

class BrasRepos extends PoseBras {
  const BrasRepos();
}

/// Le bras montre dans la direction [angle] (radians, repère de l'écran :
/// 0 = droite, −π/2 = haut).
class BrasMontre extends PoseBras {
  const BrasMontre(this.angle);
  final double angle;
}

/// Salut de la main ([phase] fait balancer la main).
class BrasSalue extends PoseBras {
  const BrasSalue(this.phase);
  final double phase;
}

enum Humeur { neutre, sourire, joie }

class EtatAfi {
  const EtatAfi({
    this.t = 0,
    this.ouverture = 0,
    this.forme = FormeBouche.fermee,
    this.humeur = Humeur.sourire,
    this.brasGauche = const BrasRepos(),
    this.brasDroit = const BrasRepos(),
    this.paupieres = 1,
  });

  /// Temps en secondes (respiration, tête).
  final double t;

  /// Ouverture de la bouche (0 à 1).
  final double ouverture;
  final FormeBouche forme;
  final Humeur humeur;

  /// Bras du côté gauche de l'image / du côté droit de l'image.
  final PoseBras brasGauche;
  final PoseBras brasDroit;

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

/// Peintre d'Afi sur une grille de 400 × 640 (plus 100 de marge de chaque
/// côté pour les bras).
class PeintreAfiV2 extends CustomPainter {
  const PeintreAfiV2(this.e);
  final EtatAfi e;

  static const double largeur = 600;
  static const double hauteur = 640;

  Paint _p(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / largeur, size.height / hauteur);
    canvas.save();
    canvas.translate(
      (size.width - largeur * s) / 2,
      (size.height - hauteur * s) / 2,
    );
    canvas.scale(s);
    // Le dessin est fait sur 400 de large ; 100 de marge de chaque côté pour
    // les bras qui montrent.
    canvas.translate(100, 0);
    canvas.clipRect(const Rect.fromLTWH(-100, 0, largeur, hauteur));

    // Respiration : le buste monte et descend à peine.
    final souffle = math.sin(e.t * 1.7) * 1.6;
    final teteX = math.sin(e.t * 0.8) * 2.2;
    final teteAngle =
        math.sin(e.t * 0.6) * 0.025 +
        (e.humeur == Humeur.joie ? math.sin(e.t * 2.4) * 0.02 : 0);

    // Bras au repos le long du corps (sur la robe) ; bras levés devant tout.
    final gaucheDevant = e.brasGauche is! BrasRepos;
    final droitDevant = e.brasDroit is! BrasRepos;

    _buste(canvas, souffle);
    if (!gaucheDevant) _bras(canvas, true, e.brasGauche, souffle);
    if (!droitDevant) _bras(canvas, false, e.brasDroit, souffle);

    canvas.save();
    // Tête un peu plus basse : cou de longueur naturelle.
    canvas.translate(200 + teteX, 316 + souffle * 0.6);
    canvas.rotate(teteAngle);
    canvas.translate(-200, -300);
    _cou(canvas);
    _tete(canvas);
    canvas.restore();

    if (gaucheDevant) _bras(canvas, true, e.brasGauche, souffle);
    if (droitDevant) _bras(canvas, false, e.brasDroit, souffle);
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
        c.drawCircle(
          Offset(cx + sens * 0.5, cy),
          7.2,
          _p(const Color(0xFF4A2A16)),
        );
        c.drawCircle(Offset(cx + sens * 0.5, cy), 3.8, _p(_brun));
        c.drawCircle(Offset(cx + 2.8, cy - 2.8), 2, _p(Colors.white));
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

  // ---------------------------------------------------------------------------
  // Bras : épaule → coude → poignet → main (cinématique à deux segments)
  // ---------------------------------------------------------------------------

  static const _l1 = 82.0; // bras (épaule → coude)
  static const _l2 = 72.0; // avant-bras (coude → poignet)

  /// Haut de l'épaule, là où part la manche (couture d'épaule).
  static Offset _epaule(double sens, double souffle) =>
      Offset(200 + sens * 82, 330 + souffle);

  void _bras(Canvas c, bool gauche, PoseBras pose, double souffle) {
    final sens = gauche ? -1.0 : 1.0;
    final epaule = _epaule(sens, souffle);
    late Offset coude;
    late Offset poignet;
    var main = _Main.detendue;
    double angleMain;

    switch (pose) {
      case BrasRepos():
        // Le long du corps : bras légèrement écarté, coude à peine plié.
        coude = epaule + Offset(sens * 12, _l1);
        poignet = coude + Offset(sens * 2, _l2);
        angleMain = math.atan2(poignet.dy - coude.dy, poignet.dx - coude.dx);
      case BrasMontre(:final angle):
        // Le bras part vers le bouton, coude un peu plié vers le bas ;
        // l'avant-bras et l'index visent le bouton.
        final bas = math.cos(angle) >= 0 ? 0.5 : -0.5;
        final a1 = angle + bas;
        final a2 = angle - bas * 0.3;
        coude = epaule + Offset(math.cos(a1), math.sin(a1)) * _l1;
        poignet = coude + Offset(math.cos(a2), math.sin(a2)) * _l2;
        angleMain = a2;
        main = _Main.montre;
      case BrasSalue(:final phase):
        // Bras levé sur le côté, coude plié, avant-bras dressé, main ouverte
        // qui se balance un peu.
        final a1 = sens > 0 ? -0.35 : math.pi + 0.35;
        coude = epaule + Offset(math.cos(a1), math.sin(a1)) * _l1;
        final a2 = -math.pi / 2 + sens * 0.12 + math.sin(phase) * 0.22;
        poignet = coude + Offset(math.cos(a2), math.sin(a2)) * _l2;
        angleMain = a2;
        main = _Main.ouverte;
    }

    // Avant-bras (presque aussi large que la manche, poignet un peu plus fin).
    _segment(c, coude, poignet, 31, 24, _peau);
    // Ombre douce le long de l'avant-bras (volume).
    _ombreSegment(c, coude, poignet, 31, 24, sens);
    _dessinerMain(c, poignet, angleMain, sens, main);
    // Manche : du haut de l'épaule jusqu'au coude, un peu évasée.
    _segment(c, epaule, coude, 40, 36, _bleu);
    _ombreSegment(c, epaule, coude, 40, 36, sens, couleur: _bleuOmbre);
    // Revers de la manche au coude (or et vert).
    final dir = (coude - epaule) / (coude - epaule).distance;
    final perp = Offset(-dir.dy, dir.dx);
    final bord = coude + dir * 4;
    c.drawLine(
      bord + perp * 17,
      bord - perp * 17,
      _p(_or)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      bord - dir * 7 + perp * 17,
      bord - dir * 7 - perp * 17,
      _p(_vert)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    // Tête de manche arrondie sur l'épaule, et couture d'épaule.
    c.drawCircle(epaule, 21, _p(_bleu));
    final couture = Path()
      ..moveTo(epaule.dx - sens * 6, epaule.dy - 20)
      ..quadraticBezierTo(
        epaule.dx - sens * 22,
        epaule.dy + 4,
        epaule.dx - sens * 12,
        epaule.dy + 28,
      );
    c.drawPath(
      couture,
      _p(_bleuOmbre)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Segment arrondi qui s'affine (bras, avant-bras) : un trapèze et deux
  /// disques aux extrémités (aucun creux possible).
  void _segment(Canvas c, Offset a, Offset b, double wa, double wb, Color col) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final p = Path()
      ..moveTo((a + n * wa / 2).dx, (a + n * wa / 2).dy)
      ..lineTo((b + n * wb / 2).dx, (b + n * wb / 2).dy)
      ..lineTo((b - n * wb / 2).dx, (b - n * wb / 2).dy)
      ..lineTo((a - n * wa / 2).dx, (a - n * wa / 2).dy)
      ..close();
    final pinceau = _p(col);
    c.drawPath(p, pinceau);
    c.drawCircle(a, wa / 2, pinceau);
    c.drawCircle(b, wb / 2, pinceau);
  }

  /// Bande d'ombre sur le côté extérieur d'un segment (donne du volume).
  void _ombreSegment(
    Canvas c,
    Offset a,
    Offset b,
    double wa,
    double wb,
    double sens, {
    Color couleur = _peauOmbre,
  }) {
    final d = b - a;
    var n = Offset(-d.dy, d.dx) / d.distance;
    if (n.dx * sens < 0) n = -n; // côté extérieur
    final p = Path()
      ..moveTo((a + n * wa / 2).dx, (a + n * wa / 2).dy)
      ..lineTo((b + n * wb / 2).dx, (b + n * wb / 2).dy)
      ..lineTo((b + n * wb * 0.18).dx, (b + n * wb * 0.18).dy)
      ..lineTo((a + n * wa * 0.18).dx, (a + n * wa * 0.18).dy)
      ..close();
    c.drawPath(p, _p(couleur.withValues(alpha: 0.55)));
  }

  /// Main dessinée dans un repère local : x = du poignet vers le bout des
  /// doigts, y > 0 = côté du pouce. Longueur ≈ 3/4 de la hauteur du visage.
  void _dessinerMain(
    Canvas c,
    Offset poignet,
    double angle,
    double sens,
    _Main forme,
  ) {
    c.save();
    c.translate(poignet.dx, poignet.dy);
    c.rotate(angle);
    // Côté du pouce à l'écran : vers le corps (repos, salut), vers le haut
    // (montrer).
    final yPouce = Offset(-math.sin(angle), math.cos(angle));
    final veutX = forme == _Main.montre ? 0.0 : -sens;
    final veutY = forme == _Main.montre ? -1.0 : 0.0;
    final ok = forme == _Main.montre
        ? yPouce.dy * veutY >= 0
        : yPouce.dx * veutX >= 0;
    if (!ok) c.scale(1, -1);
    // Main à l'échelle du visage (≈ 3/4 de sa hauteur).
    c.scale(1.12);

    final peau = _p(_peau);
    final trait = _p(_peauOmbre)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    switch (forme) {
      case _Main.ouverte:
        // Paume visible : un peu plus large aux jointures.
        final paume = Path()
          ..moveTo(0, -15)
          ..cubicTo(14, -19, 34, -23, 46, -22)
          ..lineTo(48, 20)
          ..cubicTo(34, 22, 14, 20, 0, 15)
          ..cubicTo(-6, 8, -6, -8, 0, -15)
          ..close();
        c.drawPath(paume, peau);
        // Quatre doigts serrés et arrondis (du petit doigt à l'index).
        const doigts = [
          (-16.5, 30.0), // auriculaire
          (-5.5, 38.0), // annulaire
          (5.5, 41.0), // majeur
          (16.5, 37.0), // index
        ];
        for (final (y, long) in doigts) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(40, y - 5.6, long + 6, 11.2),
              const Radius.circular(5.6),
            ),
            peau,
          );
        }
        for (final (y, long) in doigts.skip(1)) {
          c.drawLine(Offset(46, y - 5.5), Offset(40 + long, y - 5.5), trait);
        }
        // Plis de la paume : ligne de cœur, ligne de vie (autour du pouce)
        // et talon de la main, sans tache.
        final pli = _p(_peauOmbre.withValues(alpha: 0.7))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        c.drawPath(
          Path()
            ..moveTo(36, -16)
            ..quadraticBezierTo(30, -2, 34, 12),
          pli,
        );
        c.drawPath(
          Path()
            ..moveTo(32, 15)
            ..quadraticBezierTo(16, 10, 8, 2),
          pli,
        );
        // Pouce attaché à la base de la paume, écarté vers le côté.
        c.save();
        c.translate(8, 14);
        c.rotate(0.62);
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -7, 38, 14),
            const Radius.circular(7),
          ),
          peau,
        );
        c.drawLine(const Offset(18, -6), const Offset(18, -3), trait);
        c.restore();
      case _Main.montre:
        // Poing : doigts repliés (jointures arrondies), index tendu, pouce
        // posé le long des doigts.
        final poing = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -16, 46, 34),
          const Radius.circular(14),
        );
        c.drawRRect(poing, peau);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset(40 - i * 1.0, -8.0 + i * 9.5), 8.2, peau);
        }
        c.drawPath(
          Path()
            ..moveTo(36, -4)
            ..lineTo(44, -4)
            ..moveTo(36, 5)
            ..lineTo(44, 5),
          trait,
        );
        // Index tendu (long, arrondi, avec une articulation).
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(30, 7, 50, 12.5),
            const Radius.circular(6.25),
          ),
          peau,
        );
        c.drawLine(const Offset(60, 8.5), const Offset(60, 11), trait);
        // Pouce le long du poing, côté index.
        c.save();
        c.translate(6, 18);
        c.rotate(-0.12);
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, -6.5, 32, 13),
            const Radius.circular(6.5),
          ),
          peau,
        );
        c.restore();
      case _Main.detendue:
        // Main qui pend le long du corps, dos de la main vers l'avant :
        // paume, quatre doigts serrés un peu repliés, pouce côté corps.
        final dos = Path()
          ..moveTo(0, -14)
          ..cubicTo(14, -17, 32, -20, 42, -19)
          ..lineTo(44, 18)
          ..cubicTo(30, 19, 14, 17, 0, 14)
          ..cubicTo(-5, 7, -5, -7, 0, -14)
          ..close();
        c.drawPath(dos, peau);
        const doigts = [
          (-14.5, 22.0), // auriculaire
          (-5.0, 28.0), // annulaire
          (4.5, 30.0), // majeur
          (13.8, 27.0), // index
        ];
        for (final (y, long) in doigts) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(36, y - 5, long + 6, 10),
              const Radius.circular(5),
            ),
            peau,
          );
        }
        for (final (y, long) in doigts.skip(1)) {
          c.drawLine(Offset(44, y - 4.8), Offset(36 + long, y - 4.8), trait);
        }
        // Jointures (doigts légèrement repliés).
        final jointure = _p(_peauOmbre.withValues(alpha: 0.6))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (final (y, long) in doigts) {
          final x = 36 + long * 0.62;
          c.drawLine(Offset(x, y - 2.5), Offset(x, y + 2.5), jointure);
        }
        // Pouce posé le long de l'index.
        c.save();
        c.translate(6, 13);
        c.rotate(0.32);
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -6, 32, 12),
            const Radius.circular(6),
          ),
          peau,
        );
        c.drawLine(const Offset(20, -5), const Offset(20, -2), trait);
        c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(PeintreAfiV2 old) => true;
}

/// Widget simple pour afficher Afi v2 (planche, essais).
class AfiV2 extends StatelessWidget {
  const AfiV2({super.key, required this.etat, this.taille = 200});
  final EtatAfi etat;
  final double taille;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: taille,
    height: taille * PeintreAfiV2.hauteur / PeintreAfiV2.largeur,
    child: CustomPaint(painter: PeintreAfiV2(etat)),
  );
}

enum _Main { detendue, montre, ouverte }
