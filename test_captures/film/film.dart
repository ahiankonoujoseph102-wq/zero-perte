// Outil d'« enregistrement d'écran » de l'application (vidéos de présentation).
// La vraie application tourne dans un téléphone simulé ; chaque image est
// capturée pendant les gestes (un rond blanc montre le doigt), puis ffmpeg en
// fait une vidéo MP4 (voir outils/film.sh).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/main.dart';

import '../../test/support/outils.dart';

/// Dossier des images (ZP_FILM, sinon build/film).
final String dossierFilm = Platform.environment['ZP_FILM'] ?? 'build/film';

Future<void> chargerPolices() async {
  final m =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in m.cast<Map<String, dynamic>>()) {
    final l = FontLoader(f['family'] as String);
    for (final x in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
      l.addFont(rootBundle.load(x['asset'] as String));
    }
    await l.load();
  }
  // Images des produits (émojis) : police d'émojis du système, si présente.
  final emoji = File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
  if (emoji.existsSync()) {
    final l = FontLoader('NotoColorEmoji')
      ..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())));
    await l.load();
  }
}

class Film {
  Film(this.tester, this.scene, {this.taille = const Size(412, 915)});

  final WidgetTester tester;
  final String scene;
  final Size taille;
  static const double densite = 2;

  final _cle = GlobalKey();
  final _doigt = ValueNotifier<Offset?>(null);
  final _images = <(String, double)>[];
  int _n = 0;
  late final Directory _dossier;

  /// Affiche l'application dans le téléphone simulé.
  Future<void> ouvrir(EtatApplication etat, {DateTime? date}) async {
    _dossier = Directory('$dossierFilm/$scene')..createSync(recursive: true);
    for (final f in _dossier.listSync()) {
      f.deleteSync();
    }
    tester.view.physicalSize = taille * densite;
    tester.view.devicePixelRatio = densite;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _cle,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              ZeroPerteApp(
                etat: etat,
                infosPaquet: Future.value(
                  PackageInfo(
                    appName: 'Zéro Perte',
                    packageName: 'tg.zeroperte.app',
                    version: '0.37.2',
                    buildNumber: '124',
                  ),
                ),
                maintenant: date ?? DateTime(2026, 11, 25),
              ),
              ValueListenableBuilder<Offset?>(
                valueListenable: _doigt,
                builder: (_, p, _) => p == null
                    ? const SizedBox.shrink()
                    : Positioned(
                        left: p.dx - 26,
                        top: p.dy - 26,
                        child: IgnorePointer(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.45),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    await attendre(tester, tours: 10);
  }

  /// Une image, montrée [secondes].
  Future<void> image([double secondes = 1.5]) async {
    final b = _cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final chemin = '${_dossier.path}/${(_n++).toString().padLeft(5, '0')}.png';
    await tester.runAsync(() async {
      final img = await b.toImage(pixelRatio: densite);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      File(chemin).writeAsBytesSync(d!.buffer.asUint8List());
      img.dispose();
    });
    _images.add((chemin, secondes));
  }

  /// Laisse vivre l'écran (animations, base) en filmant.
  Future<void> vivre(double secondes, {int fps = 12}) async {
    final n = (secondes * fps).round();
    for (var i = 0; i < n; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(Duration(milliseconds: 1000 ~/ fps));
      await image(1 / fps);
    }
  }

  /// Touche un élément (rond du doigt), puis filme la suite. Faux s'il manque.
  Future<bool> toucher(Finder f, {double pause = 1.2}) async {
    if (f.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).last,
        );
      } catch (_) {}
    }
    if (f.evaluate().isEmpty) {
      // ignore: avoid_print
      print('FILM [$scene] introuvable : $f');
      return false;
    }
    await tester.ensureVisible(f.last);
    await tester.pump(const Duration(milliseconds: 300));
    // Seulement ce qui est visible à l'écran (pas une page cachée dessous).
    final visible = f.hitTestable();
    final cible = visible.evaluate().isNotEmpty ? visible.last : f.last;
    final c = tester.getCenter(cible);
    _doigt.value = c;
    await tester.pump();
    await image(0.35);
    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 60));
    await image(0.12);
    _doigt.value = null;
    await vivre(0.7);
    await attendre(tester, tours: 4);
    await image(pause);
    return true;
  }

  Future<bool> cle(String k, {double pause = 1.2}) =>
      toucher(find.byKey(Key(k)), pause: pause);

  /// Écrit lettre par lettre.
  Future<void> ecrire(Finder f, String texte) async {
    if (f.evaluate().isEmpty) {
      // ignore: avoid_print
      print('FILM [$scene] champ introuvable : $f');
      return;
    }
    await tester.ensureVisible(f.last);
    await tester.tap(f.last);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 1; i <= texte.length; i++) {
      await tester.enterText(f.last, texte.substring(0, i));
      await tester.pump(const Duration(milliseconds: 40));
      await image(0.07);
    }
    await attendre(tester);
    await image(0.6);
  }

  /// Fait défiler l'écran doucement (pour montrer une longue page).
  Future<void> defiler(double pixels, {Finder? dans}) async {
    final s = dans ?? find.byType(Scrollable).last;
    if (s.evaluate().isEmpty) return;
    const pas = 40.0;
    for (var d = 0.0; d < pixels.abs(); d += pas) {
      await tester.drag(s.first, Offset(0, pixels > 0 ? -pas : pas));
      await tester.pump(const Duration(milliseconds: 40));
      await image(0.05);
    }
    await attendre(tester);
    await image(1.0);
  }

  /// Ouvre une page directement (comme la toucher dans un menu).
  Future<void> page(Widget p, {double pause = 2.0}) async {
    Navigator.of(tester.element(find.byType(Scaffold).last))
        .push(MaterialPageRoute(builder: (_) => p));
    await vivre(0.6);
    await attendre(tester, tours: 8);
    await image(pause);
  }

  /// Retour en arrière (flèche en haut à gauche).
  Future<void> retour({double pause = 1.0}) async {
    for (final t in ['Retour', 'Back']) {
      final b = find.byTooltip(t).hitTestable();
      if (b.evaluate().isNotEmpty) {
        await toucher(b.last, pause: pause);
        return;
      }
    }
    final bb = find.byType(BackButton).hitTestable();
    if (bb.evaluate().isNotEmpty) {
      await toucher(bb.last, pause: pause);
      return;
    }
    // ignore: avoid_print
    print('FILM [$scene] pas de bouton retour');
  }

  /// Écrit la liste des images (format « concat » de ffmpeg).
  void finir() {
    final l = StringBuffer();
    for (final (c, s) in _images) {
      l.writeln("file '${File(c).absolute.path}'");
      l.writeln('duration ${s.toStringAsFixed(3)}');
    }
    if (_images.isNotEmpty) {
      l.writeln("file '${File(_images.last.$1).absolute.path}'");
    }
    File('${_dossier.path}/liste.txt').writeAsStringSync(l.toString());
    // ignore: avoid_print
    print(
      'FILM [$scene] ${_images.length} images, '
      '${_images.fold<double>(0, (t, e) => t + e.$2).toStringAsFixed(1)} s',
    );
  }
}
