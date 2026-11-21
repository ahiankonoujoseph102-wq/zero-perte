import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../domaine/boutique.dart';

const _canal = MethodChannel('tg.zeroperte/telephone');

/// Demande à Android d'ajouter le raccourci de la boutique sur l'écran d'accueil.
Future<bool> creerRaccourciAndroid(String nom, Uint8List png) async {
  try {
    return await _canal.invokeMethod<bool>('creerRaccourci', {
          'nom': nom,
          'png': png,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// Dessine le logo de la boutique (photo ronde, ou initiales sur sa couleur) en PNG.
Future<Uint8List> dessinerLogoPng(ConfigBoutique c, {int taille = 192}) async {
  final enregistreur = ui.PictureRecorder();
  final toile = Canvas(enregistreur);
  final t = taille.toDouble();
  final cercle = Path()..addOval(Rect.fromLTWH(0, 0, t, t));
  toile.clipPath(cercle);
  if (c.logo != null) {
    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(c.logo!),
      targetWidth: taille,
      targetHeight: taille,
    );
    final image = (await codec.getNextFrame()).image;
    toile.drawImage(image, Offset.zero, Paint());
  } else {
    toile.drawRect(
      Rect.fromLTWH(0, 0, t, t),
      Paint()..color = Color(c.couleur),
    );
    final texte = TextPainter(
      text: TextSpan(
        text: c.initiales,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: t * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texte.paint(toile, Offset((t - texte.width) / 2, (t - texte.height) / 2));
  }
  final image = await enregistreur.endRecording().toImage(taille, taille);
  final octets = await image.toByteData(format: ui.ImageByteFormat.png);
  return octets!.buffer.asUint8List();
}
