/// Patron (code de 6 chiffres) et vendeurs (code de 4 chiffres).
///
/// Le PIN n'est JAMAIS enregistré en clair : on garde seulement un « hachage »
/// (PBKDF2-SHA256 avec un sel aléatoire). Après 5 erreurs, l'accès est bloqué
/// quelques minutes (géré par l'écran de connexion, étape B7).
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

enum Role { patron, vendeur }

/// Longueur du code secret d'un vendeur.
const int longueurPin = 4;

/// Longueur du code secret du patron (décision du propriétaire, Q8) : il
/// protège aussi la sauvegarde.
const int longueurPinPatron = 6;

int longueurPour(Role r) => r == Role.patron ? longueurPinPatron : longueurPin;

/// Tours de calcul du hachage (plus il y en a, plus deviner le code est lent).
/// Les anciens codes (sans valeur enregistrée) utilisaient 20 000 tours.
const int toursPinVendeur = 20000;
const int toursPinPatron = 120000;

int toursPour(Role r) => r == Role.patron ? toursPinPatron : toursPinVendeur;

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

/// Vrai pour un code trop facile : un seul chiffre répété, suite qui monte ou
/// qui descend (123456, 987654), ou deux chiffres répétés (121212).
bool pinTropFacile(String pin) {
  if (pinsInterdits.contains(pin)) return true;
  final c = pin.codeUnits;
  bool suite(int pas) {
    for (var i = 1; i < c.length; i++) {
      if (c[i] - c[i - 1] != pas) return false;
    }
    return true;
  }

  if (suite(0) || suite(1) || suite(-1)) return true;
  if (c.length >= 4) {
    var alterne = true;
    for (var i = 2; i < c.length; i++) {
      if (c[i] != c[i - 2]) alterne = false;
    }
    if (alterne) return true;
  }
  return false;
}

/// Problème avec un PIN choisi (null si le PIN est acceptable).
String? problemePin(String pin, {int longueur = longueurPin}) {
  if (!RegExp('^[0-9]{$longueur}\$').hasMatch(pin)) {
    return 'Le code doit avoir $longueur chiffres.';
  }
  if (pinTropFacile(pin)) {
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
    this.longueurCode = longueurPin,
    this.tours = toursPinVendeur,
  });

  final String id;
  final String nom;
  final Role role;
  final String sel;
  final String hachage;

  /// Faux = utilisateur bloqué par le patron.
  final bool actif;

  /// Nombre de chiffres de son code (4 ; 6 pour le patron depuis 0.17).
  final int longueurCode;

  /// Tours de calcul utilisés pour son hachage.
  final int tours;

  /// Patron installé avant la version 0.17 : doit choisir un code de 6 chiffres.
  bool get doitPasserA6Chiffres =>
      role == Role.patron && longueurCode < longueurPinPatron;

  Map<String, Object?> versDonnees() => {
    'utilisateur': id,
    'nom': nom,
    'role': role.name,
    'sel': sel,
    'hachage': hachage,
    'actif': actif,
    'longueur': longueurCode,
    'tours': tours,
  };

  factory Utilisateur.depuisDonnees(Map<String, Object?> d) => Utilisateur(
    id: d['utilisateur'] as String,
    nom: d['nom'] as String,
    role: Role.values.byName(d['role'] as String),
    sel: d['sel'] as String,
    hachage: d['hachage'] as String,
    actif: (d['actif'] as bool?) ?? true,
    longueurCode: (d['longueur'] as int?) ?? longueurPin,
    tours: (d['tours'] as int?) ?? toursPinVendeur,
  );
}

/// Nouveau sel aléatoire (16 octets, base64).
String nouveauSel() {
  final r = Random.secure();
  return base64.encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Hachage d'un PIN avec son sel (PBKDF2-SHA256, [tours] tours).
Future<String> hacherPin(
  String pin,
  String sel, {
  int tours = toursPinVendeur,
}) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: tours,
    bits: 256,
  );
  final cle = await pbkdf2.deriveKeyFromPassword(
    password: pin,
    nonce: base64.decode(sel),
  );
  return base64.encode(await cle.extractBytes());
}

/// Vrai si le PIN correspond.
Future<bool> pinCorrect(Utilisateur u, String pin) async =>
    pin.length == u.longueurCode &&
    await hacherPin(pin, u.sel, tours: u.tours) == u.hachage;
