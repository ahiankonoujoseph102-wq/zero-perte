import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/synchro/drive.dart';

/// Faux Google Drive local : vérifie les requêtes envoyées par l'application.
void main() {
  late HttpServer serveur;
  final fichiers = <String, (String, List<int>)>{}; // id → (nom, contenu)
  final jetonsVus = <String>[];
  var refuserUneFois = false;

  setUp(() async {
    fichiers.clear();
    jetonsVus.clear();
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serveur.listen((req) async {
      final auth = req.headers.value('authorization') ?? '';
      jetonsVus.add(auth);
      final corps = <int>[];
      await for (final m in req) {
        corps.addAll(m);
      }
      final rep = req.response;
      if (refuserUneFois) {
        refuserUneFois = false;
        rep.statusCode = 401;
        await rep.close();
        return;
      }
      final chemin = req.uri.path;
      if (req.method == 'GET' && chemin == '/drive/v3/files') {
        expect(req.uri.queryParameters['spaces'], 'appDataFolder');
        rep.write(
          jsonEncode({
            'files': [
              for (final e in fichiers.entries)
                {'id': e.key, 'name': e.value.$1},
            ],
          }),
        );
      } else if (req.method == 'GET' && chemin.startsWith('/drive/v3/files/')) {
        expect(req.uri.queryParameters['alt'], 'media');
        rep.add(fichiers[chemin.split('/').last]!.$2);
      } else if (req.method == 'POST' && chemin == '/upload/drive/v3/files') {
        expect(req.uri.queryParameters['uploadType'], 'multipart');
        final texte = latin1.decode(corps);
        final meta = RegExp(
          r'\{"name":"([^"]+)","parents":\["appDataFolder"\]\}',
        ).firstMatch(texte)!;
        final debut = texte.indexOf('application/octet-stream\r\n\r\n') + 28;
        final fin = texte.lastIndexOf('\r\n--');
        final id = 'id${fichiers.length + 1}';
        fichiers[id] = (meta.group(1)!, corps.sublist(debut, fin));
        rep.write(jsonEncode({'id': id}));
      } else if (req.method == 'PATCH') {
        final id = chemin.split('/').last;
        fichiers[id] = (fichiers[id]!.$1, corps);
        rep.write('{}');
      } else {
        rep.statusCode = 404;
      }
      await rep.close();
    });
  });

  tearDown(() => serveur.close(force: true));

  test(
    'écrire, lister, relire, remplacer ; jeton renouvelé après un refus',
    () async {
      var n = 0;
      final drive = StockageDriveAppData(
        serveur: 'http://127.0.0.1:${serveur.port}',
        jeton: ({bool renouveler = false}) async =>
            'jeton-${renouveler ? ++n : n}',
      );
      await drive.ecrire('appareil-A.json', utf8.encode('{"a":1}'));
      await drive.ecrire('ops-A-00000001-00000002.json', [0, 1, 2, 255]);
      final liste = await drive.lister();
      expect(liste.map((f) => f.nom).toSet(), {
        'appareil-A.json',
        'ops-A-00000001-00000002.json',
      });
      final ops = liste.firstWhere((f) => f.nom.startsWith('ops-'));
      expect(await drive.lire(ops), [0, 1, 2, 255]);

      // Même nom : le fichier est remplacé, pas dupliqué.
      await drive.ecrire('appareil-A.json', utf8.encode('{"a":2}'));
      expect(await drive.lister(), hasLength(2));
      final app = (await drive.lister()).firstWhere(
        (f) => f.nom == 'appareil-A.json',
      );
      expect(utf8.decode(await drive.lire(app)), '{"a":2}');

      refuserUneFois = true;
      await drive.lister();
      expect(jetonsVus.last, 'Bearer jeton-1');
      expect(jetonsVus.every((j) => j.startsWith('Bearer jeton-')), isTrue);
    },
  );
}
