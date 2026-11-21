import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo Zéro Perte dessiné par l'application (mêmes formes que
/// assets/logo/zero-perte.svg, fabriqué par outils/logo/dessiner_logo.py) :
/// zéro blanc fermé, coche verte détachée par un contour bleu nuit, anneau or
/// ouvert. Aucun fichier image : net à toutes les tailles, rien de plus dans
/// l'APK.
class LogoZeroPerte extends StatelessWidget {
  const LogoZeroPerte({super.key, this.taille = 48, this.fond = true});

  final double taille;

  /// Carré bleu nuit aux coins arrondis derrière le dessin.
  final bool fond;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Zéro Perte',
      image: true,
      child: SizedBox(
        width: taille,
        height: taille,
        child: CustomPaint(painter: _PeintreLogo(fond: fond)),
      ),
    );
  }
}

const _bleuNuit = Color(0xFF0B1730);
const _vert = Color(0xFF2BC77A);
const _or = Color(0xFFF8BE5F);

class _PeintreLogo extends CustomPainter {
  const _PeintreLogo({required this.fond});
  final bool fond;

  static final Path _zero = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(
      Rect.fromCenter(center: const Offset(512, 498), width: 448, height: 516),
    )
    ..addOval(
      Rect.fromCenter(center: const Offset(512, 498), width: 196, height: 316),
    );

  static final Path _anneau = () {
    const cx = 506.0, cy = 500.0, rx = 380.0, ry = 366.0;
    const debut = -18.0, fin = 318.0, epaisseur = 54.0, n = 240;
    final ext = <Offset>[];
    final inte = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final t = (debut + (fin - debut) * u) * math.pi / 180;
      final w = 4.0 + (epaisseur - 4.0) * math.pow(math.sin(math.pi * u), 0.7);
      ext.add(Offset(cx + rx * math.cos(t), cy + ry * math.sin(t)));
      inte.add(
        Offset(cx + (rx - w) * math.cos(t), cy + (ry - w) * math.sin(t)),
      );
    }
    return Path()..addPolygon([...ext, ...inte.reversed], true);
  }();

  static final Path _coche = Path()
    ..moveTo(398, 488)
    ..lineTo(532, 606)
    ..lineTo(862, 308);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 1024;
    canvas.save();
    canvas.scale(s);
    if (fond) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 1024, 1024),
          const Radius.circular(220),
        ),
        Paint()..color = _bleuNuit,
      );
    }
    canvas.drawPath(
      _anneau,
      Paint()
        ..color = _or
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      _zero,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );
    Paint trait(Color c, double l) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = l
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(_coche, trait(_bleuNuit, 106));
    canvas.drawPath(_coche, trait(_vert, 70));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeintreLogo old) => old.fond != fond;
}
