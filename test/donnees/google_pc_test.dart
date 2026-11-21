import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/services/google_pc.dart';

class CoffreMemoire implements CoffreJetonPc {
  String? valeur;
  @override
  Future<String?> lire() async => valeur;
  @override
  Future<void> ecrire(String? v) async => valeur = v;
}

/// Faux Google : page d'autorisation (simulée par le « navigateur ») + jetons.
void main() {
  test('PC : navigateur → retour local avec code → jetons ; reconnexion silencieuse', () async {
    final google = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final demandes = <Map<String, String>>[];
    google.listen((req) async {
      final corps = await utf8.decoder.bind(req).join();
      final champs = Uri.splitQueryString(corps);
      demandes.add(champs);
      final idJeton =
          'x.${base64Url.encode(utf8.encode(jsonEncode({'email': 'boutique.ama@gmail.com'})))}.y';
      req.response.write(
        jsonEncode({
          'access_token': 'acces-${demandes.length}',
          'expires_in': 3600,
          if (champs['grant_type'] == 'authorization_code') ...{
            'refresh_token': 'rafraichir-1',
            'id_token': idJeton,
          },
        }),
      );
      await req.response.close();
    });
    final coffre = CoffreMemoire();
    late Uri ouverte;
    final c = ConnexionGooglePc(
      idClient: 'id-pc.apps.googleusercontent.com',
      secretClient: 'secret-de-test',
      coffre: coffre,
      urlJeton: 'http://127.0.0.1:${google.port}/token',
      ouvrirNavigateur: (url) async {
        ouverte = url;
        // Le « navigateur » : Google renvoie vers le serveur local avec un code.
        final retour = Uri.parse(url.queryParameters['redirect_uri']!).replace(
          queryParameters: {
            'code': 'code-123',
            'state': url.queryParameters['state'],
          },
        );
        Future(() async {
          final r = await HttpClient().getUrl(retour);
          await (await r.close()).drain<void>();
        });
        return true;
      },
    );
    final connexion = await c.ouvrir();
    expect(connexion!.compte, 'boutique.ama@gmail.com');
    expect(ouverte.queryParameters['code_challenge_method'], 'S256');
    expect(ouverte.queryParameters['scope'], contains('drive.appdata'));
    expect(
      ouverte.queryParameters['redirect_uri'],
      startsWith('http://127.0.0.1:'),
    );
    final echange = demandes.single;
    expect(echange['code'], 'code-123');
    expect(echange['code_verifier'], hasLength(64));
    expect(coffre.valeur, 'rafraichir-1');
    expect(await c.jeton(), 'acces-1');

    // Plus tard (application relancée) : reconnexion sans navigateur.
    final c2 = ConnexionGooglePc(
      idClient: 'id-pc.apps.googleusercontent.com',
      secretClient: 'secret-de-test',
      coffre: coffre,
      urlJeton: 'http://127.0.0.1:${google.port}/token',
      ouvrirNavigateur: (_) async => fail('pas de navigateur en silencieux'),
    );
    final r = await c2.ouvrir(
      silencieux: true,
      compteConnu: 'boutique.ama@gmail.com',
    );
    expect(r, isNotNull);
    expect(demandes.last['grant_type'], 'refresh_token');
    await google.close(force: true);
  });

  test('silencieux sans jeton gardé : rien (il faut se connecter)', () async {
    final c = ConnexionGooglePc(
      idClient: 'x',
      secretClient: 'y',
      coffre: CoffreMemoire(),
      ouvrirNavigateur: (_) async => true,
    );
    expect(await c.ouvrir(silencieux: true), isNull);
  });
}
