import 'package:flutter_tts/flutter_tts.dart';

/// Lecture à voix haute (synthèse vocale d'Android, en français).
/// Remplaçable dans les tests.
abstract class Voix {
  /// Vrai si une voix française est installée sur le téléphone.
  Future<bool> francaisDisponible();
  Future<void> dire(String texte);
  Future<void> arreter();
}

class VoixAndroid implements Voix {
  final FlutterTts _tts = FlutterTts();
  bool _pret = false;

  Future<void> _preparer() async {
    if (_pret) return;
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45); // un peu lent : plus facile à comprendre
    await _tts.setPitch(1.0);
    _pret = true;
  }

  @override
  Future<bool> francaisDisponible() async {
    try {
      final r = await _tts.isLanguageAvailable('fr-FR');
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dire(String texte) async {
    try {
      await _preparer();
      await _tts.stop();
      await _tts.speak(texte);
    } catch (_) {
      // Pas de voix : l'application continue sans parler.
    }
  }

  @override
  Future<void> arreter() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
