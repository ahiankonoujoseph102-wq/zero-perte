import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Transforme en image PNG ce qui est dessiné sous [cle] (un RepaintBoundary).
/// Nul si l'élément n'est pas affiché.
Future<Uint8List?> capturerPng(GlobalKey cle, {double pixelRatio = 2.5}) async {
  final ctx = cle.currentContext;
  if (ctx == null) return null;
  await Scrollable.ensureVisible(ctx);
  if (!ctx.mounted) return null;
  final cadre = ctx.findRenderObject();
  if (cadre is! RenderRepaintBoundary) return null;
  final image = await cadre.toImage(pixelRatio: pixelRatio);
  final octets = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return octets?.buffer.asUint8List();
}
