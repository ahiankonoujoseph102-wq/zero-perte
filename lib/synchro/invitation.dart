/// Ajout d'un vendeur par QR code (ou code de secours à 8 chiffres).
///
/// Principe (docs/conception-ajout-vendeur.md) :
/// - le téléphone du PATRON obtient de Google (par le relais, qui seul connaît
///   le code secret de l'identifiant « Application Web ») un jeton de longue
///   durée limité au dossier caché de Zéro Perte ;
/// - il le range, avec la boutique et le code du vendeur, dans un PAQUET
///   CHIFFRÉ (AES-256-GCM) déposé 10 minutes sur le relais ;
/// - le QR code contient seulement l'adresse de la boîte et la clé : le relais
///   ne peut pas ouvrir le paquet, et il l'efface à la première lecture ;
/// - code de secours : la clé n'est PAS dans les 8 chiffres ; elle est
///   convenue entre les deux téléphones (X25519) après l'accord du patron.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hachage;
import 'package:cryptography/cryptography.dart';

import '../donnees/journal_local.dart' show ErreurZeroPerte;

/// Durée de validité d'une invitation.
const Duration dureeInvitation = Duration(minutes: 10);

/// Contenu (secret) d'une invitation, une fois déchiffré.
class PaquetInvitation {
  const PaquetInvitation({
    required this.invitation,
    required this.compte,
    required this.jetonLong,
    required this.jetonRelais,
    required this.vendeurId,
    required this.vendeurNom,
    required this.codeVendeur,
    this.nomBoutique = '',
  });

  factory PaquetInvitation.depuisJson(Map<String, Object?> d) {
    if (d['v'] != 1) throw const ErreurInvitation();
    return PaquetInvitation(
      invitation: d['invitation'] as String,
      compte: d['compte'] as String,
      jetonLong: d['jeton_long'] as String,
      jetonRelais: d['jeton_relais'] as String,
      vendeurId: d['vendeur_id'] as String,
      vendeurNom: d['vendeur_nom'] as String,
      codeVendeur: d['code_vendeur'] as String,
      nomBoutique: (d['boutique'] as String?) ?? '',
    );
  }

  /// Identifiant unique de cette invitation (une seule entrée possible).
  final String invitation;

  /// Adresse du compte Google de la boutique (affichée, pas secrète).
  final String compte;

  /// Jeton Google de longue durée (dossier caché de Zéro Perte seulement).
  final String jetonLong;

  /// Jeton de la boutique pour le relais (alertes).
  final String jetonRelais;
  final String vendeurId;
  final String vendeurNom;

  /// Code à 4 chiffres du vendeur (montré une seule fois sur son téléphone).
  final String codeVendeur;
  final String nomBoutique;

  Map<String, Object?> versJson() => {
    'v': 1,
    'invitation': invitation,
    'compte': compte,
    'jeton_long': jetonLong,
    'jeton_relais': jetonRelais,
    'vendeur_id': vendeurId,
    'vendeur_nom': vendeurNom,
    'code_vendeur': codeVendeur,
    'boutique': nomBoutique,
  };
}

/// Le QR code n'est pas (ou plus) valable.
class ErreurInvitation extends ErreurZeroPerte {
  const ErreurInvitation([
    super.message =
        'Ce QR code n\'est pas valable. Demandez au patron d\'en refaire un.',
  ]);
}

/// Problème avec le relais (réseau, pas configuré…).
class ErreurRelais extends ErreurZeroPerte {
  const ErreurRelais(super.message);
}

/// Le relais refuse l'accès de ce téléphone : retiré par le patron.
class ErreurAccesRetire extends ErreurZeroPerte {
  const ErreurAccesRetire()
    : super('Ce téléphone a été retiré de la boutique par le patron.');
}

/// Google a annulé l'autorisation (« Couper tous les vendeurs », compte…).
class ErreurAccesCoupe extends ErreurZeroPerte {
  const ErreurAccesCoupe()
    : super(
        'Ce téléphone n\'est plus relié à la boutique. Demandez au patron '
        'de refaire un QR code.',
      );
}

final Random _hasard = Random.secure();

Uint8List octetsAleatoires(int n) =>
    Uint8List.fromList(List<int>.generate(n, (_) => _hasard.nextInt(256)));

String _hex(List<int> o) =>
    o.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _b64(List<int> o) => base64Url.encode(o).replaceAll('=', '');

Uint8List _deB64(String s) {
  final n = (4 - s.length % 4) % 4;
  return base64Url.decode(s + '=' * n);
}

/// Empreinte SHA-256 (hexadécimal) d'un jeton : ce que le relais met sur sa
/// liste noire quand le patron retire un appareil.
String empreinteJeton(String jeton) =>
    hachage.sha256.convert(utf8.encode(jeton)).toString();

// --- QR code ------------------------------------------------------------------

const String _prefixeQr = 'ZP1';

/// Ce que contient le QR code : la boîte (16 octets) et la clé (32 octets).
class QrInvitation {
  QrInvitation(this.boite, this.cle)
    : assert(boite.length == 16),
      assert(cle.length == 32);

  factory QrInvitation.nouveau() =>
      QrInvitation(octetsAleatoires(16), octetsAleatoires(32));

  /// Lit le texte d'un QR code ; [ErreurInvitation] si ce n'est pas le nôtre.
  factory QrInvitation.lire(String texte) {
    final t = texte.trim();
    if (!t.startsWith(_prefixeQr)) throw const ErreurInvitation();
    try {
      final o = _deB64(t.substring(_prefixeQr.length));
      if (o.length != 48) throw const ErreurInvitation();
      return QrInvitation(o.sublist(0, 16), o.sublist(16));
    } on ErreurInvitation {
      rethrow;
    } catch (_) {
      throw const ErreurInvitation();
    }
  }

  final Uint8List boite;
  final Uint8List cle;

  String get idBoite => _hex(boite);

  /// Texte à mettre dans le QR code (67 caractères).
  String get texte => '$_prefixeQr${_b64([...boite, ...cle])}';
}

final AesGcm _aes = AesGcm.with256bits();

Future<String> _chiffrer(
  PaquetInvitation p,
  List<int> cle,
  List<int> aad, {
  List<int> avant = const [],
}) async {
  final boite = await _aes.encrypt(
    utf8.encode(jsonEncode(p.versJson())),
    secretKey: SecretKey(cle),
    nonce: octetsAleatoires(12),
    aad: aad,
  );
  return _b64([
    ...avant,
    ...boite.nonce,
    ...boite.cipherText,
    ...boite.mac.bytes,
  ]);
}

Future<PaquetInvitation> _dechiffrer(
  List<int> o,
  List<int> cle,
  List<int> aad,
) async {
  if (o.length < 12 + 16) throw const ErreurInvitation();
  try {
    final clair = await _aes.decrypt(
      SecretBox(
        o.sublist(12, o.length - 16),
        nonce: o.sublist(0, 12),
        mac: Mac(o.sublist(o.length - 16)),
      ),
      secretKey: SecretKey(cle),
      aad: aad,
    );
    return PaquetInvitation.depuisJson(
      (jsonDecode(utf8.decode(clair)) as Map).cast<String, Object?>(),
    );
  } on ErreurInvitation {
    rethrow;
  } catch (_) {
    throw const ErreurInvitation();
  }
}

/// Chiffre le paquet pour un QR code (la clé est dans le QR).
Future<String> chiffrerPourQr(PaquetInvitation p, QrInvitation qr) =>
    _chiffrer(p, qr.cle, qr.boite);

/// Ouvre le paquet pris dans la boîte du QR code.
Future<PaquetInvitation> dechiffrerDepuisQr(String paquet, QrInvitation qr) =>
    _dechiffrer(_deB64(paquet), qr.cle, qr.boite);

// --- Code de secours (8 chiffres) ---------------------------------------------

/// Tire un code de secours à 8 chiffres.
String nouveauCodeSecours() =>
    List.generate(8, (_) => _hasard.nextInt(10)).join();

/// « 48210937 » → « 4821 0937 » (plus facile à lire et à taper).
String codeSecoursLisible(String code) =>
    '${code.substring(0, 4)} ${code.substring(4)}';

/// Garde seulement les chiffres ; nul si ce n'est pas un code à 8 chiffres.
String? codeSecoursNettoye(String texte) {
  final c = texte.replaceAll(RegExp(r'\D'), '');
  return c.length == 8 ? c : null;
}

/// Boîte (sur le relais) correspondant à un code de secours.
String boiteDuCode(String code) => hachage.sha256
    .convert(utf8.encode('zp-code-secours|$code'))
    .toString()
    .substring(0, 32);

final X25519 _x25519 = X25519();

Future<List<int>> _cleCommune(
  SimpleKeyPair moi,
  List<int> autre,
  String code,
) async {
  final commun = await _x25519.sharedSecretKey(
    keyPair: moi,
    remotePublicKey: SimplePublicKey(autre, type: KeyPairType.x25519),
  );
  final cle = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: commun,
    nonce: utf8.encode(boiteDuCode(code)),
    info: utf8.encode('zp-code-secours|$code'),
  );
  return cle.extractBytes();
}

/// Téléphone du vendeur : sa demande d'entrée par code de secours.
class DemandeParCode {
  DemandeParCode._(this.code, this._paire, this.clePublique);

  static Future<DemandeParCode> nouvelle(String code) async {
    final paire = await _x25519.newKeyPair();
    final pub = await paire.extractPublicKey();
    return DemandeParCode._(code, paire, _b64(pub.bytes));
  }

  final String code;
  final SimpleKeyPair _paire;

  /// Clé publique envoyée au relais (pas un secret).
  final String clePublique;

  String get idBoite => boiteDuCode(code);

  /// Ouvre le paquet déposé par le patron après son « OUI ».
  Future<PaquetInvitation> ouvrir(String paquet) async {
    final o = _deB64(paquet);
    if (o.length < 32 + 28) throw const ErreurInvitation();
    final cle = await _cleCommune(_paire, o.sublist(0, 32), code);
    return _dechiffrer(o.sublist(32), cle, utf8.encode(idBoite));
  }
}

/// Téléphone du patron : chiffre le paquet pour LE téléphone qui a demandé
/// (sa clé publique), après l'accord du patron.
Future<String> chiffrerPourDemande(
  PaquetInvitation p,
  String code,
  String clePubliqueVendeur,
) async {
  final paire = await _x25519.newKeyPair();
  final pub = await paire.extractPublicKey();
  final cle = await _cleCommune(paire, _deB64(clePubliqueVendeur), code);
  return _chiffrer(p, cle, utf8.encode(boiteDuCode(code)), avant: pub.bytes);
}

// --- Relais ---------------------------------------------------------------------

/// Demande d'entrée reçue par le patron (code de secours).
class DemandeEntree {
  const DemandeEntree({required this.clePublique, required this.appareil});
  final String clePublique;

  /// Modèle du téléphone qui demande (ex. « Samsung SM-A055F »).
  final String appareil;
}

/// Accès d'une heure au Drive, donné par le relais.
class AccesGoogle {
  const AccesGoogle(this.jeton, this.expire);
  final String jeton;
  final DateTime expire;
}

/// Ce que l'ajout d'un vendeur demande au relais (remplaçable dans les tests).
abstract class RelaisInvitations {
  /// Identifiant public de l'application Web ; nul si le relais n'est pas prêt.
  Future<String?> idClientWeb();
  Future<String> echangerCode(String jetonRelais, String code);
  Future<AccesGoogle> acces(String jetonLong);
  Future<void> retirer(String jetonRelais, String empreinte);
  Future<void> couper(String jetonRelais, String code);
  Future<void> deposer(String jetonRelais, String boite, String paquet);

  /// Prend le paquet (une seule fois) ; nul s'il n'est pas (ou plus) là.
  Future<String?> prendre(String boite);

  /// Le paquet est-il encore dans la boîte (sans le prendre) ?
  Future<bool> present(String boite);
  Future<void> ouvrirAttente(String jetonRelais, String boite);

  /// Faux si le patron n'attend pas ce code (ou plus).
  Future<bool> demander(String boite, String clePublique, String appareil);
  Future<DemandeEntree?> lireDemande(String jetonRelais, String boite);
}

/// Le vrai relais (HTTPS).
class ClientRelaisInvitations implements RelaisInvitations {
  ClientRelaisInvitations(this.adresse, {HttpClient? client})
    : _http = client ?? (HttpClient()..connectionTimeout = _delai);

  static const Duration _delai = Duration(seconds: 20);
  final String adresse;
  final HttpClient _http;

  Future<(int, Map<String, Object?>)> _appel(
    String methode,
    String chemin, {
    String? jeton,
    Map<String, Object?>? corps,
  }) async {
    try {
      final req = await _http.openUrl(methode, Uri.parse('$adresse$chemin'));
      if (jeton != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
      }
      if (corps != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(corps));
      }
      final rep = await req.close().timeout(_delai);
      final texte = await rep.transform(utf8.decoder).join().timeout(_delai);
      Map<String, Object?> d = const {};
      try {
        d = (jsonDecode(texte) as Map).cast<String, Object?>();
      } catch (_) {}
      return (rep.statusCode, d);
    } on ErreurZeroPerte {
      rethrow;
    } catch (_) {
      throw const ErreurRelais(
        'Pas de réseau, ou le relais ne répond pas. Vérifiez Internet et réessayez.',
      );
    }
  }

  Never _echec(int statut, Map<String, Object?> d) {
    if (statut == 503) {
      throw const ErreurRelais(
        'Le relais n\'est pas encore prêt pour l\'ajout par QR code '
        '(identifiant Google à mettre dans Cloudflare).',
      );
    }
    throw ErreurRelais(
      'Le relais a refusé (${d['erreur'] ?? statut}). Réessayez.',
    );
  }

  @override
  Future<String?> idClientWeb() async {
    final (s, d) = await _appel('GET', '/google/id');
    if (s == 503) return null;
    if (s != 200) _echec(s, d);
    return d['id'] as String?;
  }

  @override
  Future<String> echangerCode(String jetonRelais, String code) async {
    final (s, d) = await _appel(
      'POST',
      '/google/echange',
      jeton: jetonRelais,
      corps: {'code': code},
    );
    if (s != 200) _echec(s, d);
    return d['jeton_long'] as String;
  }

  @override
  Future<AccesGoogle> acces(String jetonLong) async {
    final (s, d) = await _appel(
      'POST',
      '/google/acces',
      corps: {'jeton_long': jetonLong},
    );
    if (s == 403) {
      throw d['erreur'] == 'retiré'
          ? const ErreurAccesRetire()
          : const ErreurAccesCoupe();
    }
    if (s != 200) _echec(s, d);
    final secondes = (d['expire_dans'] as num?)?.toInt() ?? 3600;
    return AccesGoogle(
      d['acces'] as String,
      DateTime.now().add(Duration(seconds: secondes)),
    );
  }

  @override
  Future<void> retirer(String jetonRelais, String empreinte) async {
    final (s, d) = await _appel(
      'POST',
      '/google/retirer',
      jeton: jetonRelais,
      corps: {'empreinte': empreinte},
    );
    if (s != 200) _echec(s, d);
  }

  @override
  Future<void> couper(String jetonRelais, String code) async {
    final (s, d) = await _appel(
      'POST',
      '/google/couper',
      jeton: jetonRelais,
      corps: {'code': code},
    );
    if (s != 200) _echec(s, d);
  }

  @override
  Future<void> deposer(String jetonRelais, String boite, String paquet) async {
    final (s, d) = await _appel(
      'PUT',
      '/boite/$boite',
      jeton: jetonRelais,
      corps: {'paquet': paquet},
    );
    if (s != 201) _echec(s, d);
  }

  @override
  Future<String?> prendre(String boite) async {
    final (s, d) = await _appel('GET', '/boite/$boite');
    if (s == 404) return null;
    if (s != 200) _echec(s, d);
    return d['paquet'] as String?;
  }

  @override
  Future<bool> present(String boite) async {
    final (s, d) = await _appel('GET', '/boite/$boite?etat=1');
    if (s != 200) _echec(s, d);
    return d['present'] == true;
  }

  @override
  Future<void> ouvrirAttente(String jetonRelais, String boite) async {
    final (s, d) = await _appel(
      'PUT',
      '/demande/$boite',
      jeton: jetonRelais,
      corps: const {},
    );
    if (s != 201) _echec(s, d);
  }

  @override
  Future<bool> demander(
    String boite,
    String clePublique,
    String appareil,
  ) async {
    final (s, d) = await _appel(
      'POST',
      '/demande/$boite',
      corps: {'cle': clePublique, 'appareil': appareil},
    );
    if (s == 404 || s == 409) return false;
    if (s != 201) _echec(s, d);
    return true;
  }

  @override
  Future<DemandeEntree?> lireDemande(String jetonRelais, String boite) async {
    final (s, d) = await _appel('GET', '/demande/$boite', jeton: jetonRelais);
    if (s != 200) _echec(s, d);
    final q = (d['demande'] as Map?)?.cast<String, Object?>();
    if (q == null) return null;
    return DemandeEntree(
      clePublique: q['cle'] as String,
      appareil: (q['appareil'] as String?) ?? '',
    );
  }
}

/// Jetons d'accès Drive d'un téléphone entré par invitation : demandés au
/// relais (une fois par heure), gardés en mémoire seulement.
class JetonParRelais {
  JetonParRelais(this.relais, this.jetonLong, {DateTime Function()? horloge})
    : _horloge = horloge ?? DateTime.now;

  final RelaisInvitations relais;
  final String jetonLong;
  final DateTime Function() _horloge;
  AccesGoogle? _acces;

  Future<String> jeton({bool renouveler = false}) async {
    final a = _acces;
    if (!renouveler &&
        a != null &&
        _horloge().isBefore(a.expire.subtract(const Duration(minutes: 2)))) {
      return a.jeton;
    }
    final n = await relais.acces(jetonLong);
    _acces = n;
    return n.jeton;
  }
}
