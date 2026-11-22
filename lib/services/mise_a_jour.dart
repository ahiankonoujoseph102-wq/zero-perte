import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Adresse des versions publiées (dernière Release GitHub).
const String adresseVersions =
    'https://github.com/ahiankonoujoseph102-wq/zero-perte/releases/latest/download';

/// Faux dans les tests (pas d'Internet).
bool verifierMisesAJour = true;

/// Une version plus récente que celle installée.
class InfosMiseAJour {
  const InfosMiseAJour({
    required this.version,
    required this.versionCode,
    required this.lien,
  });

  final String version;
  final int versionCode;

  /// Lien de téléchargement direct (APK sur Android, ZIP sur Windows).
  final Uri lien;

  /// Lit « version.json » ; nul s'il est abîmé ou pas plus récent.
  static InfosMiseAJour? depuisJson(
    String texte, {
    required int versionInstallee,
    required bool windows,
  }) {
    try {
      final j = jsonDecode(texte) as Map<String, dynamic>;
      final code = (j['versionCode'] as num).toInt();
      if (code <= versionInstallee) return null;
      return InfosMiseAJour(
        version: j['version'] as String,
        versionCode: code,
        lien: Uri.parse(
          '$adresseVersions/${windows ? 'ZeroPerte-Windows.zip' : 'ZeroPerte.apk'}',
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Cherche une version plus récente, au plus une fois par jour. Sans Internet
/// ou en cas d'erreur : nul, rien n'est bloqué. Rien n'est installé tout seul.
class VerificateurMiseAJour {
  VerificateurMiseAJour._();
  static final instance = VerificateurMiseAJour._();

  Future<InfosMiseAJour?>? _resultat;
  DateTime? _quand;

  Future<InfosMiseAJour?> verifier(int versionInstallee) {
    final maintenant = DateTime.now();
    final r = _resultat;
    if (r != null &&
        _quand != null &&
        maintenant.difference(_quand!) < const Duration(hours: 24)) {
      return r;
    }
    _quand = maintenant;
    return _resultat = _lire(versionInstallee);
  }

  /// Tests : fixe le résultat (nul = rien de nouveau).
  @visibleForTesting
  void fixer(InfosMiseAJour? m) {
    _quand = DateTime.now();
    _resultat = Future.value(m);
  }

  Future<InfosMiseAJour?> _lire(int versionInstallee) async {
    if (!verifierMisesAJour || kIsWeb || versionInstallee <= 0) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(
        Uri.parse('$adresseVersions/version.json'),
      );
      final rep = await req.close().timeout(const Duration(seconds: 10));
      if (rep.statusCode != 200) return null;
      final texte = await rep
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      return InfosMiseAJour.depuisJson(
        texte,
        versionInstallee: versionInstallee,
        windows: Platform.isWindows,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
