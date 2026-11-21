/// Connexion Google sur PC Windows (synchronisation par le Drive de la boutique).
///
/// Méthode recommandée par Google pour les applications de bureau : le
/// navigateur s'ouvre, la personne choisit le compte de la boutique, Google
/// renvoie vers un petit serveur local (127.0.0.1) de l'application, avec
/// « PKCE » (un code à usage unique : rien n'est réutilisable s'il est volé).
///
/// L'identifiant « Application de bureau » est donné à la fabrication :
/// `--dart-define=ZP_GOOGLE_PC_ID=…` (variable GitHub) et
/// `--dart-define=ZP_GOOGLE_PC_SECRET=…` (secret GitHub ; pour une application
/// de bureau, Google indique qu'il n'est pas confidentiel, mais on ne le met
/// jamais dans le dépôt). Voir docs/etapes-proprietaire.md, étape A6.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../synchro/drive.dart';
import 'google.dart' show ConnexionStockage;

const String idClientPc = String.fromEnvironment('ZP_GOOGLE_PC_ID');
const String secretClientPc = String.fromEnvironment('ZP_GOOGLE_PC_SECRET');

bool get connexionPcConfiguree => idClientPc.isNotEmpty;

/// Où garder le « jeton de rafraîchissement » (pour se reconnecter sans
/// redemander) : un fichier dans le dossier de données de l'utilisateur.
abstract class CoffreJetonPc {
  Future<String?> lire();
  Future<void> ecrire(String? valeur);
}

class CoffreFichier implements CoffreJetonPc {
  CoffreFichier(this.chemin);
  final String chemin;

  @override
  Future<String?> lire() async {
    final f = File(chemin);
    return await f.exists() ? (await f.readAsString()).trim() : null;
  }

  @override
  Future<void> ecrire(String? valeur) async {
    final f = File(chemin);
    if (valeur == null) {
      if (await f.exists()) await f.delete();
      return;
    }
    await f.writeAsString(valeur, flush: true);
  }
}

class ConnexionGooglePc {
  ConnexionGooglePc({
    required this.idClient,
    required this.secretClient,
    required this.coffre,
    required this.ouvrirNavigateur,
    this.urlAutorisation = 'https://accounts.google.com/o/oauth2/v2/auth',
    this.urlJeton = 'https://oauth2.googleapis.com/token',
    this.serveurDrive = 'https://www.googleapis.com',
    HttpClient? http,
  }) : _http = http ?? HttpClient();

  final String idClient;
  final String secretClient;
  final CoffreJetonPc coffre;
  final Future<bool> Function(Uri) ouvrirNavigateur;
  final String urlAutorisation;
  final String urlJeton;
  final String serveurDrive;
  final HttpClient _http;

  String? _acces;
  DateTime _expiration = DateTime.fromMillisecondsSinceEpoch(0);

  static String _aleatoire(int n) {
    const lettres =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(n, (_) => lettres[r.nextInt(lettres.length)]).join();
  }

  Future<Map<String, dynamic>> _demanderJeton(
    Map<String, String> champs,
  ) async {
    final req = await _http.postUrl(Uri.parse(urlJeton));
    req.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    req.write(Uri(queryParameters: champs).query);
    final rep = await req.close();
    final texte = await rep.transform(utf8.decoder).join();
    if (rep.statusCode != 200) {
      throw ErreurDrive('Connexion Google refusée (${rep.statusCode}).');
    }
    return jsonDecode(texte) as Map<String, dynamic>;
  }

  void _garder(Map<String, dynamic> d) {
    _acces = d['access_token'] as String?;
    final duree = (d['expires_in'] as num?)?.toInt() ?? 3600;
    _expiration = DateTime.now().add(Duration(seconds: duree - 60));
  }

  static String? _emailDuJetonId(String? jetonId) {
    if (jetonId == null) return null;
    final parties = jetonId.split('.');
    if (parties.length < 2) return null;
    final charge = utf8.decode(
      base64Url.decode(base64Url.normalize(parties[1])),
    );
    return (jsonDecode(charge) as Map<String, dynamic>)['email'] as String?;
  }

  /// Jeton d'accès valide (renouvelé avec le jeton de rafraîchissement).
  Future<String> jeton({bool renouveler = false}) async {
    if (!renouveler && _acces != null && DateTime.now().isBefore(_expiration)) {
      return _acces!;
    }
    final rafraichir = await coffre.lire();
    if (rafraichir == null) {
      throw const ErreurDrive('Reconnectez le compte Google de la boutique.');
    }
    _garder(
      await _demanderJeton({
        'client_id': idClient,
        'client_secret': secretClient,
        'refresh_token': rafraichir,
        'grant_type': 'refresh_token',
      }),
    );
    return _acces!;
  }

  /// Ouvre le navigateur et attend le retour de Google (3 minutes au plus).
  Future<String?> connecter() async {
    final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final retour = 'http://127.0.0.1:${serveur.port}';
    final verifieur = _aleatoire(64);
    final defi = base64Url
        .encode(sha256.convert(ascii.encode(verifieur)).bytes)
        .replaceAll('=', '');
    final etat = _aleatoire(24);
    final url = Uri.parse(urlAutorisation).replace(
      queryParameters: {
        'client_id': idClient,
        'redirect_uri': retour,
        'response_type': 'code',
        'scope': 'openid email $autorisationDriveAppData',
        'code_challenge': defi,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
        'state': etat,
      },
    );
    try {
      if (!await ouvrirNavigateur(url)) return null;
      final req = await serveur.first.timeout(const Duration(minutes: 3));
      final code = req.uri.queryParameters['code'];
      final bonEtat = req.uri.queryParameters['state'] == etat;
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><meta charset="utf-8"><body style="font-family:sans-serif;font-size:22px;padding:40px">'
          '${code != null && bonEtat ? 'Compte connecté. Vous pouvez fermer cette fenêtre et revenir à Zéro Perte.' : 'Connexion annulée.'}'
          '</body>',
        );
      await req.response.close();
      if (code == null || !bonEtat) return null;
      final d = await _demanderJeton({
        'client_id': idClient,
        'client_secret': secretClient,
        'code': code,
        'code_verifier': verifieur,
        'redirect_uri': retour,
        'grant_type': 'authorization_code',
      });
      _garder(d);
      final rafraichir = d['refresh_token'] as String?;
      if (rafraichir != null) await coffre.ecrire(rafraichir);
      return _emailDuJetonId(d['id_token'] as String?) ?? 'compte Google';
    } on Exception {
      return null;
    } finally {
      await serveur.close(force: true);
    }
  }

  /// Connexion (ou reconnexion silencieuse) : le dossier de la boutique.
  Future<ConnexionStockage?> ouvrir({
    bool silencieux = false,
    String? compteConnu,
  }) async {
    String? compte = compteConnu;
    if (silencieux) {
      if (await coffre.lire() == null) return null;
      try {
        await jeton(renouveler: true);
      } on Exception {
        return null;
      }
    } else {
      compte = await connecter();
      if (compte == null) return null;
    }
    return ConnexionStockage(
      compte: compte ?? 'compte Google',
      stockage: StockageDriveAppData(jeton: jeton, serveur: serveurDrive),
    );
  }
}
