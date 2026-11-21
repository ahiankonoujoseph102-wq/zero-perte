/// Patron et vendeurs, avec un code secret (PIN) de 4 chiffres.
///
/// Le PIN n'est JAMAIS enregistré en clair : on garde seulement un « hachage »
/// (PBKDF2-SHA256 avec un sel aléatoire). Après 5 erreurs, l'accès est bloqué
/// quelques minutes (géré par l'écran de connexion, étape B7).
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

enum Role { patron, vendeur }

/// Longueur du code secret.
const int longueurPin = 4;

/// Codes trop faciles à deviner, refusés.
const Set<String> pinsInterdits = {
  '0000',
  '1111',
  '2222',
  '3333',
  '4444',
  '5555',
  '6666',
  '7777',
  '8888',
  '9999',
  '1234',
  '4321',
  '0123',
  '9876',
  '1212',
  '2580',
};

/// Problème avec un PIN choisi (null si le PIN est acceptable).
String? problemePin(String pin) {
  if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
    return 'Le code doit avoir 4 chiffres.';
  }
  if (pinsInterdits.contains(pin)) {
    return 'Ce code est trop facile à deviner. Choisissez-en un autre.';
  }
  return null;
}

class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.nom,
    required this.role,
    required this.sel,
    required this.hachage,
    this.actif = true,
  });

  final String id;
  final String nom;
  final Role role;
  final String sel;
  final String hachage;

  /// Faux = utilisateur bloqué par le patron.
  final bool actif;

  Map<String, Object?> versDonnees() => {
    'utilisateur': id,
    'nom': nom,
    'role': role.name,
    'sel': sel,
    'hachage': hachage,
    'actif': actif,
  };

  factory Utilisateur.depuisDonnees(Map<String, Object?> d) => Utilisateur(
    id: d['utilisateur'] as String,
    nom: d['nom'] as String,
    role: Role.values.byName(d['role'] as String),
    sel: d['sel'] as String,
    hachage: d['hachage'] as String,
    actif: (d['actif'] as bool?) ?? true,
  );
}

final _pbkdf2 = Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: 20000,
  bits: 256,
);

/// Nouveau sel aléatoire (16 octets, base64).
String nouveauSel() {
  final r = Random.secure();
  return base64.encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Hachage d'un PIN avec son sel.
Future<String> hacherPin(String pin, String sel) async {
  final cle = await _pbkdf2.deriveKeyFromPassword(
    password: pin,
    nonce: base64.decode(sel),
  );
  return base64.encode(await cle.extractBytes());
}

/// Vrai si le PIN correspond.
Future<bool> pinCorrect(Utilisateur u, String pin) async =>
    await hacherPin(pin, u.sel) == u.hachage;
