/// Fichier de sauvegarde chiffré de la boutique.
///
/// Format « ZPS2 » : 4 octets « ZPS2 », sel (16), nonce (12), code
/// d'authentification (16), puis le journal compressé (gzip) et chiffré
/// (AES-256-GCM). La clé est dérivée du code secret du patron (6 chiffres)
/// par PBKDF2-SHA256 avec 300 000 tours (lent à deviner). Toute modification
/// du fichier est détectée. Les anciens fichiers « ZPS1 » (60 000 tours) se
/// lisent toujours.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const List<int> _magieV1 = [0x5A, 0x50, 0x53, 0x31]; // « ZPS1 »
const List<int> _magie = [0x5A, 0x50, 0x53, 0x32]; // « ZPS2 »
const int iterationsSauvegardeV1 = 60000;
const int iterationsSauvegarde = 300000;

class ErreurSauvegarde implements Exception {
  const ErreurSauvegarde(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<SecretKey> _cle(
  String motDePasse,
  List<int> sel, {
  int tours = iterationsSauvegarde,
}) => Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: tours,
  bits: 256,
).deriveKey(secretKey: SecretKey(utf8.encode(motDePasse)), nonce: sel);

/// Compresse puis chiffre [clair] avec [motDePasse].
Future<Uint8List> chiffrerSauvegarde(
  List<int> clair,
  String motDePasse, {
  Random? hasard,
  int format = 2, // 1 : ancien format, seulement pour les tests de lecture
}) async {
  final r = hasard ?? Random.secure();
  final sel = List<int>.generate(16, (_) => r.nextInt(256));
  final nonce = List<int>.generate(12, (_) => r.nextInt(256));
  final boite = await AesGcm.with256bits().encrypt(
    gzip.encode(clair),
    secretKey: await _cle(
      motDePasse,
      sel,
      tours: format == 1 ? iterationsSauvegardeV1 : iterationsSauvegarde,
    ),
    nonce: nonce,
  );
  return Uint8List.fromList([
    ...(format == 1 ? _magieV1 : _magie),
    ...sel,
    ...nonce,
    ...boite.mac.bytes,
    ...boite.cipherText,
  ]);
}

/// Déchiffre un fichier « ZPS2 » (ou l'ancien « ZPS1 »). Erreur claire si ce n'est pas une
/// sauvegarde Zéro Perte, si le code est faux ou si le fichier est abîmé.
Future<Uint8List> dechiffrerSauvegarde(
  List<int> fichier,
  String motDePasse,
) async {
  final entete = fichier.length < 48 ? const <int>[] : fichier.sublist(0, 4);
  final v1 = const ListEquality().equals(entete, _magieV1);
  if (!v1 && !const ListEquality().equals(entete, _magie)) {
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
      secretKey: await _cle(
        motDePasse,
        sel,
        tours: v1 ? iterationsSauvegardeV1 : iterationsSauvegarde,
      ),
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
