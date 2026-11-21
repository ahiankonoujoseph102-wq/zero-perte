import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Une phrase enregistrée : durée et mouvement de la bouche calculé d'avance
/// (un chiffre de 0 à 9 toutes les [pasBoucheMs] millisecondes).
class PhraseEnregistree {
  const PhraseEnregistree({
    required this.fichier,
    required this.dureeMs,
    required this.bouche,
  });

  factory PhraseEnregistree.depuisJson(Map<String, dynamic> j) =>
      PhraseEnregistree(
        fichier: j['fichier'] as String,
        dureeMs: (j['duree_ms'] as num).toInt(),
        bouche: j['bouche'] as String? ?? '',
      );

  final String fichier;
  final int dureeMs;
  final String bouche;

  /// Ouverture de la bouche (0 à 1) au temps [ms].
  double boucheA(int ms) {
    if (bouche.isEmpty || ms < 0) return 0;
    final i = ms ~/ pasBoucheMs;
    if (i >= bouche.length) return 0;
    return (int.tryParse(bouche[i]) ?? 0) / 9;
  }
}

/// Intervalle entre deux valeurs de bouche (doit être celui de l'action 6).
const int pasBoucheMs = 50;

/// Voix enregistrée de la démonstration (assets/demo/voix/bouches.json).
class VoixEnregistree {
  const VoixEnregistree({
    this.phrases = const {},
    this.service = '',
    this.mentionIA = false,
  });

  /// Lit le fichier JSON ; vide s'il est absent ou abîmé.
  factory VoixEnregistree.depuisJson(String texte) {
    try {
      final j = jsonDecode(texte) as Map<String, dynamic>;
      final p = (j['phrases'] as Map<String, dynamic>? ?? const {});
      return VoixEnregistree(
        phrases: {
          for (final e in p.entries)
            e.key: PhraseEnregistree.depuisJson(
              (e.value as Map).cast<String, dynamic>(),
            ),
        },
        service: j['service'] as String? ?? '',
        mentionIA: p.isNotEmpty,
      );
    } catch (_) {
      return const VoixEnregistree();
    }
  }

  final Map<String, PhraseEnregistree> phrases;

  /// Service qui a fabriqué la voix (« gemini », « openai »).
  final String service;

  /// Vrai si des voix générées par IA sont présentes (mention à afficher).
  final bool mentionIA;

  static Future<VoixEnregistree> charger() async {
    try {
      return VoixEnregistree.depuisJson(
        await rootBundle.loadString(
          'assets/demo/voix/bouches.json',
          cache: false,
        ),
      );
    } catch (_) {
      return const VoixEnregistree();
    }
  }
}

/// Lecture d'un fichier de voix. Renvoie vrai à la fin de la lecture, faux
/// si le fichier ne peut pas être lu (on prend alors la voix de synthèse).
abstract class LecteurVoixDemo {
  Future<bool> jouer(String fichier);
  Future<void> arreter();
}

/// Aucun fichier lisible (PC, tests) : toujours la voix de synthèse.
class SansLecteur implements LecteurVoixDemo {
  const SansLecteur();
  @override
  Future<bool> jouer(String fichier) async => false;
  @override
  Future<void> arreter() async {}
}

/// Android : lecteur du système (MediaPlayer), via le canal natif.
class LecteurAndroid implements LecteurVoixDemo {
  static const _canal = MethodChannel('tg.zeroperte/telephone');

  @override
  Future<bool> jouer(String fichier) async {
    try {
      final octets = await rootBundle.load('assets/demo/voix/$fichier');
      final dossier = await getTemporaryDirectory();
      final f = File('${dossier.path}/voix-demo-$fichier');
      if (!f.existsSync() || f.lengthSync() != octets.lengthInBytes) {
        await f.writeAsBytes(octets.buffer.asUint8List(), flush: true);
      }
      return await _canal.invokeMethod<bool>('jouerSon', {'chemin': f.path}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> arreter() async {
    try {
      await _canal.invokeMethod<bool>('arreterSon');
    } catch (_) {}
  }
}

/// Le lecteur adapté à l'appareil.
LecteurVoixDemo lecteurParDefaut() =>
    !kIsWeb && Platform.isAndroid ? LecteurAndroid() : const SansLecteur();

/// Durée estimée d'une phrase dite par la voix de synthèse (rythme posé).
Duration dureeEstimee(String texte) =>
    Duration(milliseconds: math.max(1200, (texte.length * 78)));

/// Bouche « parlée » quand on n'a pas le mouvement calculé (voix de synthèse).
double boucheSimulee(int ms) {
  final t = ms / 1000;
  final v =
      (math.sin(t * 17) * 0.5 + 0.5) * (0.55 + 0.45 * math.sin(t * 3.3).abs());
  return v.clamp(0, 1);
}

/// Réglages de rythme de la visite (les tests les raccourcissent).
Duration Function(String texte) dureeParoleVisite = dureeEstimee;
Duration pauseEntrePhrasesVisite = const Duration(milliseconds: 700);
