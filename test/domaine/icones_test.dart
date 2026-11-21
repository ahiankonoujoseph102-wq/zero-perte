// Logo Zéro Perte : toutes les icônes sont présentes, aux bonnes tailles.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Largeur et hauteur d'un PNG (lues dans l'en-tête IHDR).
(int, int) taillePng(String chemin) {
  final o = File(chemin).readAsBytesSync();
  expect(o.sublist(1, 4), 'PNG'.codeUnits, reason: chemin);
  final d = ByteData.sublistView(Uint8List.fromList(o.sublist(16, 24)));
  return (d.getUint32(0), d.getUint32(4));
}

void main() {
  const res = 'android/app/src/main/res';
  const densites = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  test('logo source : SVG et PNG 1024 × 1024', () {
    for (final f in [
      'zero-perte.svg',
      'zero-perte-avant-plan.svg',
      'zero-perte-monochrome.svg',
      'zero-perte-notification.svg',
    ]) {
      expect(File('assets/logo/$f').readAsStringSync(), contains('<svg'));
    }
    expect(taillePng('assets/logo/zero-perte-1024.png'), (1024, 1024));
  });

  test('Android : icône adaptative (fond, avant-plan, monochrome)', () {
    final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();
    expect(xml, contains('@color/ic_launcher_background'));
    expect(xml, contains('@mipmap/ic_launcher_foreground'));
    expect(xml, contains('@mipmap/ic_launcher_monochrome'));
    for (final e in densites.entries) {
      final n108 = (108 * e.value).toInt();
      expect(taillePng('$res/mipmap-${e.key}/ic_launcher_foreground.png'), (
        n108,
        n108,
      ));
      expect(taillePng('$res/mipmap-${e.key}/ic_launcher_monochrome.png'), (
        n108,
        n108,
      ));
      final n48 = (48 * e.value).toInt();
      expect(taillePng('$res/mipmap-${e.key}/ic_launcher.png'), (n48, n48));
      final n24 = (24 * e.value).toInt();
      expect(taillePng('$res/drawable-${e.key}/ic_notification.png'), (
        n24,
        n24,
      ));
    }
    final manifeste = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifeste, contains('@drawable/ic_notification'));
  });

  test('Windows et Microsoft Store : icône et logo du paquet', () {
    final ico = File('windows/runner/resources/app_icon.ico').readAsBytesSync();
    expect(ico.sublist(0, 4), [0, 0, 1, 0]); // en-tête ICO
    expect(ico[4], greaterThanOrEqualTo(6)); // au moins 6 tailles
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('logo_path: assets/logo/zero-perte-1024.png'));
  });

  test('le logo n\'entre pas dans l\'application (APK léger)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('- assets/logo')));
  });
}
