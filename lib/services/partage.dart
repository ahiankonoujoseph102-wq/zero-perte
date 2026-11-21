import 'package:flutter/services.dart';

const _canal = MethodChannel('tg.zeroperte/telephone');

/// Résultat d'un partage de reçu.
/// `enregistre` : sur PC, le fichier a été enregistré (Documents\Zero Perte).
enum ResultatPartage { whatsapp, autre, enregistre, echec }

/// Envoie une image PNG (le reçu) : directement dans WhatsApp s'il est
/// installé, sinon par le menu de partage d'Android.
Future<ResultatPartage> partagerImageAndroid(
  Uint8List png,
  String texte,
) async {
  try {
    final r = await _canal.invokeMethod<String>('partagerImage', {
      'png': png,
      'texte': texte,
    });
    return switch (r) {
      'whatsapp' => ResultatPartage.whatsapp,
      'autre' => ResultatPartage.autre,
      _ => ResultatPartage.echec,
    };
  } catch (_) {
    return ResultatPartage.echec;
  }
}

/// Partage un fichier (sauvegarde) par le menu de partage d'Android.
Future<ResultatPartage> partagerFichierAndroid(
  Uint8List octets,
  String nom,
) async {
  try {
    final r = await _canal.invokeMethod<String>('partagerFichier', {
      'octets': octets,
      'nom': nom,
    });
    return r == 'autre' ? ResultatPartage.autre : ResultatPartage.echec;
  } catch (_) {
    return ResultatPartage.echec;
  }
}
