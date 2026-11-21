/// Alertes graves par le relais Cloudflare (relais/worker.js).
library;

import 'dart:convert';
import 'dart:io';

/// Adresse du relais, fixée à la fabrication :
/// `--dart-define=ZP_RELAIS=https://zero-perte-relais.<compte>.workers.dev`.
/// Vide = pas de relais (les alertes restent seulement dans l'application).
const String adresseRelais = String.fromEnvironment('ZP_RELAIS');

/// Une alerte grave, montrée au patron.
class Alerte {
  const Alerte({
    required this.type,
    required this.message,
    required this.heure,
    this.appareil = '',
  });

  factory Alerte.depuisJson(Map<String, dynamic> d) => Alerte(
    type: d['type'] as String? ?? '',
    message: d['message'] as String? ?? '',
    heure: (d['heure'] as num?)?.toInt() ?? 0,
    appareil: d['appareil'] as String? ?? '',
  );

  final String type;
  final String message;
  final int heure;
  final String appareil;
}

/// Envoi et relève des alertes (remplaçable dans les tests).
abstract class TransportAlertes {
  Future<void> envoyer(String jeton, Alerte alerte);
  Future<List<Alerte>> relever(String jeton, int depuis);
}

/// Le vrai relais (HTTPS).
class ClientRelais implements TransportAlertes {
  ClientRelais(this.adresse, {HttpClient? client})
    : _http = client ?? HttpClient();

  final String adresse;
  final HttpClient _http;

  @override
  Future<void> envoyer(String jeton, Alerte alerte) async {
    final req = await _http.postUrl(Uri.parse('$adresse/alertes'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode({
        'type': alerte.type,
        'message': alerte.message,
        'appareil': alerte.appareil,
      }),
    );
    final rep = await req.close();
    await rep.drain<void>();
  }

  @override
  Future<List<Alerte>> relever(String jeton, int depuis) async {
    final req = await _http.getUrl(
      Uri.parse('$adresse/alertes?depuis=$depuis'),
    );
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
    final rep = await req.close();
    final texte = await rep.transform(utf8.decoder).join();
    if (rep.statusCode != 200) return const [];
    final d = jsonDecode(texte) as Map<String, dynamic>;
    return [
      for (final a in (d['alertes'] as List).cast<Map<String, dynamic>>())
        Alerte.depuisJson(a),
    ];
  }
}

/// Seuils au-delà desquels une alerte est envoyée au patron.
const int seuilAlerteEcart = 1000;
const int seuilAlerteAnnulation = 5000;
