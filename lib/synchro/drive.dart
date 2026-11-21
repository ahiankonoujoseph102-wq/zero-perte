/// Le dossier caché de l'application dans le Google Drive de la boutique
/// (« appDataFolder », autorisation `drive.appdata` : l'application ne voit
/// que ses propres fichiers, invisibles dans l'appli Drive).
///
/// API REST Drive v3, sans bibliothèque supplémentaire (dart:io).
library;

import 'dart:convert';
import 'dart:io';

import 'synchro.dart';

/// Autorisation demandée au compte Google de la boutique.
const String autorisationDriveAppData =
    'https://www.googleapis.com/auth/drive.appdata';

class ErreurDrive implements Exception {
  const ErreurDrive(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => message;
}

/// Accès au dossier caché de l'application. [jeton] donne un jeton d'accès
/// valide (renouvelé par la connexion Google quand [renouveler] est vrai).
class StockageDriveAppData implements StockageDistant {
  StockageDriveAppData({
    required this.jeton,
    HttpClient? client,
    String serveur = 'https://www.googleapis.com',
  }) : _http = client ?? HttpClient(),
       _api = '$serveur/drive/v3/files',
       _envoi = '$serveur/upload/drive/v3/files';

  final Future<String> Function({bool renouveler}) jeton;
  final HttpClient _http;
  final String _api;
  final String _envoi;

  Future<(int, List<int>)> _requete(
    String methode,
    Uri url, {
    List<int>? corps,
    String? typeContenu,
    bool deuxiemeEssai = false,
  }) async {
    final req = await _http.openUrl(methode, url);
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${await jeton(renouveler: deuxiemeEssai)}',
    );
    if (corps != null) {
      req.headers.set(HttpHeaders.contentTypeHeader, typeContenu!);
      req.contentLength = corps.length;
      req.add(corps);
    }
    final rep = await req.close();
    final octets = <int>[];
    await for (final morceau in rep) {
      octets.addAll(morceau);
    }
    if (rep.statusCode == 401 && !deuxiemeEssai) {
      // Jeton expiré : on en demande un nouveau, une fois.
      return _requete(
        methode,
        url,
        corps: corps,
        typeContenu: typeContenu,
        deuxiemeEssai: true,
      );
    }
    if (rep.statusCode >= 300) {
      throw ErreurDrive(
        'Google Drive a répondu ${rep.statusCode}.',
        code: rep.statusCode,
      );
    }
    return (rep.statusCode, octets);
  }

  @override
  Future<List<FichierDistant>> lister() async {
    final fichiers = <FichierDistant>[];
    String? page;
    do {
      final url = Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'fields': 'nextPageToken,files(id,name)',
          'pageSize': '1000',
          'pageToken': ?page,
        },
      );
      final (_, octets) = await _requete('GET', url);
      final d = jsonDecode(utf8.decode(octets)) as Map<String, dynamic>;
      for (final f in (d['files'] as List).cast<Map<String, dynamic>>()) {
        fichiers.add(
          FichierDistant(id: f['id'] as String, nom: f['name'] as String),
        );
      }
      page = d['nextPageToken'] as String?;
    } while (page != null);
    return fichiers;
  }

  @override
  Future<List<int>> lire(FichierDistant fichier) async {
    final (_, octets) = await _requete(
      'GET',
      Uri.parse('$_api/${fichier.id}?alt=media'),
    );
    return octets;
  }

  @override
  Future<void> ecrire(String nom, List<int> contenu) async {
    final existant = (await lister()).where((f) => f.nom == nom).firstOrNull;
    if (existant != null) {
      await _requete(
        'PATCH',
        Uri.parse('$_envoi/${existant.id}?uploadType=media'),
        corps: contenu,
        typeContenu: 'application/octet-stream',
      );
      return;
    }
    const limite = 'zeroperte-limite-7f3a';
    final meta = utf8.encode(
      jsonEncode({
        'name': nom,
        'parents': ['appDataFolder'],
      }),
    );
    final corps = <int>[
      ...utf8.encode(
        '--$limite\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n',
      ),
      ...meta,
      ...utf8.encode(
        '\r\n--$limite\r\nContent-Type: application/octet-stream\r\n\r\n',
      ),
      ...contenu,
      ...utf8.encode('\r\n--$limite--\r\n'),
    ];
    await _requete(
      'POST',
      Uri.parse('$_envoi?uploadType=multipart'),
      corps: corps,
      typeContenu: 'multipart/related; boundary=$limite',
    );
  }
}
