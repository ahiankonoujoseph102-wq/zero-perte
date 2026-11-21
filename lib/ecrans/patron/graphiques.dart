import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domaine/argent.dart';
import '../../theme/couleurs.dart';
import '../../theme/theme_zp.dart';

/// « 12 k », « 1,5 M » : montant court pour les graphiques.
String montantCourt(int f) => f >= 1000000
    ? '${(f / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M'
    : f >= 1000
    ? '${f ~/ 1000} k'
    : '$f';

const _nomsJours = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];

/// Carte à bord net (fond bleu nuit clair), avec un titre.
class CarteZp extends StatelessWidget {
  const CarteZp({
    super.key,
    required this.child,
    this.titre,
    this.icone,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? titre;
  final IconData? icone;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CouleursZp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CouleursZp.ligne),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titre != null) ...[
            Row(
              children: [
                if (icone != null) ...[
                  Icon(icone, color: CouleursZp.texteDoux, size: 22),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    titre!,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// Courbe des ventes des 7 derniers jours : une ligne, la surface en dessous,
/// un point par jour et le montant au-dessus du point.
class CourbeSeptJours extends StatelessWidget {
  const CourbeSeptJours({super.key, required this.jours, this.hauteur = 190});

  final List<(DateTime, int)> jours;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final couleur = CouleursZp.argentEntreClair;
    return SizedBox(
      key: const Key('courbe-sept-jours'),
      height: hauteur,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _PeintreCourbe(
                valeurs: [for (final j in jours) j.$2],
                couleur: couleur,
                style: const TextStyle(
                  fontFamily: policeZp,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CouleursZp.texte,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, (jour, _)) in jours.indexed)
                Expanded(
                  child: Text(
                    i == jours.length - 1
                        ? 'auj.'
                        : _nomsJours[jour.weekday - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: i == jours.length - 1
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: i == jours.length - 1
                          ? CouleursZp.texte
                          : CouleursZp.texteDoux,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeintreCourbe extends CustomPainter {
  _PeintreCourbe({
    required this.valeurs,
    required this.couleur,
    required this.style,
  });

  final List<int> valeurs;
  final Color couleur;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (valeurs.isEmpty) return;
    final max = math.max(1, valeurs.reduce(math.max));
    const haut = 22.0; // place des montants
    const bas = 6.0;
    final pas = size.width / valeurs.length;
    final points = [
      for (var i = 0; i < valeurs.length; i++)
        Offset(
          pas * i + pas / 2,
          haut + (size.height - haut - bas) * (1 - valeurs[i] / max),
        ),
    ];
    // Lignes de repère discrètes.
    final repere = Paint()
      ..color = CouleursZp.ligne
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = haut + (size.height - haut - bas) * k / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), repere);
    }
    final ligne = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mx = (a.dx + b.dx) / 2;
      ligne.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final surface = Path.from(ligne)
      ..lineTo(points.last.dx, size.height - bas)
      ..lineTo(points.first.dx, size.height - bas)
      ..close();
    canvas.drawPath(
      surface,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            couleur.withValues(alpha: 0.35),
            couleur.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      ligne,
      Paint()
        ..color = couleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < points.length; i++) {
      final dernier = i == points.length - 1;
      canvas.drawCircle(
        points[i],
        dernier ? 6.5 : 4.5,
        Paint()..color = dernier ? Colors.white : couleur,
      );
      canvas.drawCircle(points[i], dernier ? 4 : 0, Paint()..color = couleur);
      final texte = TextPainter(
        text: TextSpan(text: montantCourt(valeurs[i]), style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: pas);
      final y = math.max(0.0, points[i].dy - 20);
      texte.paint(canvas, Offset(points[i].dx - texte.width / 2, y));
    }
  }

  @override
  bool shouldRepaint(_PeintreCourbe old) =>
      old.valeurs.toString() != valeurs.toString() || old.couleur != couleur;
}

/// Classement des produits : nom, montant et barre proportionnelle.
class BarresClassement extends StatelessWidget {
  const BarresClassement({
    super.key,
    required this.lignes,
    this.prefixeCle = 'top',
    this.vide = 'Aucune vente sur cette période.',
  });

  final List<(String, int)> lignes;
  final String prefixeCle;
  final String vide;

  @override
  Widget build(BuildContext context) {
    if (lignes.isEmpty) {
      return Text(
        vide,
        style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
      );
    }
    final max = math.max(1, lignes.first.$2);
    final couleur = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (nom, montant)) in lignes.indexed)
          Padding(
            key: Key('$prefixeCle-$i'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i + 1}. $nom',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    Text(
                      formatFrancs(montant),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: montant / max,
                    minHeight: 9,
                    color: couleur,
                    backgroundColor: CouleursZp.ligne,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
