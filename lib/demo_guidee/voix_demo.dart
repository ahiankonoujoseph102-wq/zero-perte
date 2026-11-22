import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
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
      final f = await _fichierTemporaire(fichier);
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

/// Écrit le fichier de voix (pris dans l'application) dans un dossier
/// temporaire, une seule fois.
Future<File> _fichierTemporaire(String fichier) async {
  final octets = await rootBundle.load('assets/demo/voix/$fichier');
  final dossier = await getTemporaryDirectory();
  final f = File('${dossier.path}${Platform.pathSeparator}voix-demo-$fichier');
  if (!f.existsSync() || f.lengthSync() != octets.lengthInBytes) {
    await f.writeAsBytes(octets.buffer.asUint8List(), flush: true);
  }
  return f;
}

typedef _MciC = ffi.Uint32 Function(
  ffi.Pointer<Utf16> commande,
  ffi.Pointer<Utf16> retour,
  ffi.Uint32 taille,
  ffi.IntPtr fenetre,
);
typedef _MciDart = int Function(
  ffi.Pointer<Utf16> commande,
  ffi.Pointer<Utf16> retour,
  int taille,
  int fenetre,
);

/// Windows : lecteur du système (MCI de winmm.dll, lit le MP3), sans
/// bibliothèque en plus. Même voix que sur le téléphone.
class LecteurWindows implements LecteurVoixDemo {
  _MciDart? _mci;
  bool _arrete = false;

  _MciDart get _f =>
      _mci ??= ffi.DynamicLibrary.open('winmm.dll')
          .lookupFunction<_MciC, _MciDart>('mciSendStringW');

  /// Envoie une commande MCI ; renvoie (code, réponse). Code 0 = succès.
  (int, String) _commande(String texte) {
    final c = texte.toNativeUtf16();
    final r = calloc<ffi.Uint16>(128).cast<Utf16>();
    try {
      final code = _f(c, r, 128, 0);
      return (code, r.toDartString());
    } finally {
      calloc.free(c);
      calloc.free(r);
    }
  }

  @override
  Future<bool> jouer(String fichier) async {
    try {
      final f = await _fichierTemporaire(fichier);
      _commande('close zpvoix');
      _arrete = false;
      if (_commande('open "${f.path}" type mpegvideo alias zpvoix').$1 != 0) {
        return false;
      }
      if (_commande('play zpvoix').$1 != 0) {
        _commande('close zpvoix');
        return false;
      }
      // Attend la fin de la lecture (au plus 60 s).
      for (var i = 0; i < 600 && !_arrete; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final (code, mode) = _commande('status zpvoix mode');
        if (code != 0 || mode != 'playing') break;
      }
      _commande('close zpvoix');
      return !_arrete;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> arreter() async {
    _arrete = true;
    try {
      _commande('stop zpvoix');
      _commande('close zpvoix');
    } catch (_) {}
  }
}

/// Le lecteur adapté à l'appareil.
LecteurVoixDemo lecteurParDefaut() {
  if (kIsWeb) return const SansLecteur();
  if (Platform.isAndroid) return LecteurAndroid();
  if (Platform.isWindows) return LecteurWindows();
  return const SansLecteur();
}

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
