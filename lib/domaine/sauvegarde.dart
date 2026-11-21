/// Fichier de sauvegarde chiffré de la boutique.
///
/// Format « ZPS1 » : 4 octets « ZPS1 », sel (16), nonce (12), code
/// d'authentification (16), puis le journal compressé (gzip) et chiffré
/// (AES-256-GCM). La clé est dérivée du code secret du patron
/// (PBKDF2-SHA256). Toute modification du fichier est détectée.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const List<int> _magie = [0x5A, 0x50, 0x53, 0x31]; // « ZPS1 »
const int iterationsSauvegarde = 60000;

class ErreurSauvegarde implements Exception {
  const ErreurSauvegarde(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<SecretKey> _cle(String motDePasse, List<int> sel) => Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: iterationsSauvegarde,
  bits: 256,
).deriveKey(secretKey: SecretKey(utf8.encode(motDePasse)), nonce: sel);

/// Compresse puis chiffre [clair] avec [motDePasse].
Future<Uint8List> chiffrerSauvegarde(
  List<int> clair,
  String motDePasse, {
  Random? hasard,
}) async {
  final r = hasard ?? Random.secure();
  final sel = List<int>.generate(16, (_) => r.nextInt(256));
  final nonce = List<int>.generate(12, (_) => r.nextInt(256));
  final boite = await AesGcm.with256bits().encrypt(
    gzip.encode(clair),
    secretKey: await _cle(motDePasse, sel),
    nonce: nonce,
  );
  return Uint8List.fromList([
    ..._magie,
    ...sel,
    ...nonce,
    ...boite.mac.bytes,
    ...boite.cipherText,
  ]);
}

/// Déchiffre un fichier « ZPS1 ». Erreur claire si ce n'est pas une
/// sauvegarde Zéro Perte, si le code est faux ou si le fichier est abîmé.
Future<Uint8List> dechiffrerSauvegarde(
  List<int> fichier,
  String motDePasse,
) async {
  if (fichier.length < 48 ||
      !const ListEquality().equals(fichier.sublist(0, 4), _magie)) {
    throw const ErreurSauvegarde(
      'Ce fichier n\'est pas une sauvegarde Zéro Perte.',
    );
  }
  final sel = fichier.sublist(4, 20);
  final nonce = fichier.sublist(20, 32);
  final mac = Mac(fichier.sublist(32, 48));
  try {
    final clair = await AesGcm.with256bits().decrypt(
      SecretBox(fichier.sublist(48), nonce: nonce, mac: mac),
      secretKey: await _cle(motDePasse, sel),
    );
    return Uint8List.fromList(gzip.decode(clair));
  } on SecretBoxAuthenticationError {
    throw const ErreurSauvegarde('Code faux, ou fichier de sauvegarde abîmé.');
  }
}

class ListEquality {
  const ListEquality();
  bool equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
