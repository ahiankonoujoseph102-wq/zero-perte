/// Licences Zéro Perte : codes d'activation signés, vérifiés SANS Internet.
///
/// Format d'un code : `ZP1.<charge>.<signature>` (base64url sans « = »).
///   - la charge est un petit JSON : boutique, nom, nombre de téléphones, type,
///     date, identifiant du code ;
///   - la signature Ed25519 est faite par la clé PRIVÉE du propriétaire (secret
///     GitHub) ; l'application ne contient que la clé PUBLIQUE.
/// Un code modifié, même d'un seul caractère, est refusé.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Nombre de téléphones d'une licence de base (décision du propriétaire).
const int telephonesParLicence = 2;

enum TypeCode { licence, extension }

/// Contenu d'un code d'activation.
class CodeActivation {
  const CodeActivation({
    required this.texte,
    required this.boutiqueId,
    required this.nomBoutique,
    required this.telephones,
    required this.type,
    required this.date,
    required this.codeId,
    required this.charge,
    required this.signature,
  });

  /// Le code complet « ZP1.… ».
  final String texte;
  final String boutiqueId;
  final String nomBoutique;

  /// Téléphones apportés : 2 pour une licence, 1 (ou plus) pour une extension.
  final int telephones;
  final TypeCode type;
  final String date;
  final String codeId;

  /// Octets signés et signature (pour la vérification).
  final List<int> charge;
  final List<int> signature;
}

/// Erreurs possibles, avec un message simple pour le patron.
enum ProblemeCode {
  introuvable(
    'Le texte copié ne contient pas de code Zéro Perte. Dans WhatsApp, copiez le message entier de Zéro Perte, ou touchez « Écrire le code ».',
  ),
  abime('Ce code est abîmé ou incomplet. Copiez de nouveau tout le message.'),
  signatureFausse('Ce code n\'est pas un vrai code Zéro Perte.'),
  autreBoutique('Ce code appartient à une autre boutique.'),
  dejaUtilise('Ce code a déjà été utilisé sur cet appareil.'),
  extensionSansLicence(
    'Activez d\'abord la licence de la boutique, puis ce code « appareil en plus ».',
  ),
  cleAbsente(
    'Cette version de l\'application ne peut pas encore vérifier les codes. Contactez l\'assistance.',
  );

  const ProblemeCode(this.message);
  final String message;
}

class ErreurCode implements Exception {
  const ErreurCode(this.probleme);
  final ProblemeCode probleme;
  @override
  String toString() => probleme.message;
}

/// Une signature Ed25519 (64 octets) fait exactement 86 caractères en base64url.
/// Le code peut avoir été coupé sur plusieurs lignes par WhatsApp : les espaces et
/// retours à la ligne À L'INTÉRIEUR du code sont ignorés.
final RegExp _motifCode = RegExp(
  r'ZP1\.[A-Za-z0-9_\-\s]{10,}?\.(?:[A-Za-z0-9_\-]\s*){86}',
);

/// Cherche un code dans un texte collé (le message WhatsApp entier convient).
String? extraireCode(String texte) =>
    _motifCode.firstMatch(texte)?[0]?.replaceAll(RegExp(r'\s'), '');

List<int> _base64url(String s) => base64Url.decode(base64Url.normalize(s));

/// Lit un code (sans vérifier la signature). Lève [ErreurCode] si illisible.
CodeActivation lireCode(String texteColle) {
  final code = extraireCode(texteColle);
  if (code == null) throw const ErreurCode(ProblemeCode.introuvable);
  final parts = code.split('.');
  try {
    final charge = _base64url(parts[1]);
    final signature = _base64url(parts[2]);
    final j = jsonDecode(utf8.decode(charge)) as Map<String, dynamic>;
    if (j['v'] != 1 || signature.length != 64) throw const FormatException();
    final type = TypeCode.values.byName(j['type'] as String);
    final telephones = j['t'] as int;
    if (telephones < 1 || telephones > 50) throw const FormatException();
    return CodeActivation(
      texte: code,
      boutiqueId: j['b'] as String,
      nomBoutique: (j['n'] as String?) ?? '',
      telephones: telephones,
      type: type,
      date: j['d'] as String,
      codeId: j['i'] as String,
      charge: charge,
      signature: signature,
    );
  } on ErreurCode {
    rethrow;
  } catch (_) {
    throw const ErreurCode(ProblemeCode.abime);
  }
}

/// Vérifie la signature d'un code avec la clé publique (32 octets).
Future<bool> signatureValide(CodeActivation code, List<int> clePublique) async {
  if (clePublique.length != 32) return false;
  return Ed25519().verify(
    code.charge,
    signature: Signature(
      code.signature,
      publicKey: SimplePublicKey(clePublique, type: KeyPairType.ed25519),
    ),
  );
}

/// Lit ET vérifie un code. Lève [ErreurCode] en cas de problème.
Future<CodeActivation> verifierCode(
  String texteColle,
  List<int>? clePublique,
) async {
  if (clePublique == null || clePublique.length != 32) {
    throw const ErreurCode(ProblemeCode.cleAbsente);
  }
  final code = lireCode(texteColle);
  if (!await signatureValide(code, clePublique)) {
    throw const ErreurCode(ProblemeCode.signatureFausse);
  }
  return code;
}

/// Lit la clé publique (texte base64 de 32 octets). Nulle si absente ou invalide.
List<int>? lireClePublique(String texte) {
  try {
    final octets = base64.decode(texte.trim());
    return octets.length == 32 ? octets : null;
  } catch (_) {
    return null;
  }
}

/// Licence d'une boutique : la licence de base + les extensions.
class Licence {
  const Licence({
    required this.boutiqueId,
    required this.nomBoutique,
    required this.telephones,
    required this.codes,
  });

  final String boutiqueId;
  final String nomBoutique;

  /// Nombre total de téléphones autorisés.
  final int telephones;

  /// Identifiants des codes déjà utilisés.
  final Set<String> codes;
}

/// Calcule la licence à partir des codes activés (dans l'ordre d'activation).
/// Renvoie nul si aucune licence de base n'a été activée.
Licence? calculerLicence(Iterable<CodeActivation> codes) {
  CodeActivation? base;
  var extensions = 0;
  final ids = <String>{};
  for (final c in codes) {
    ids.add(c.codeId);
    if (c.type == TypeCode.licence) {
      base ??= c;
    } else if (base != null && c.boutiqueId == base.boutiqueId) {
      extensions += c.telephones;
    }
  }
  if (base == null) return null;
  return Licence(
    boutiqueId: base.boutiqueId,
    nomBoutique: base.nomBoutique,
    telephones: base.telephones + extensions,
    codes: ids,
  );
}

/// Contrôles avant d'accepter un nouveau code, par rapport à la licence actuelle.
void controlerNouveauCode(CodeActivation code, Licence? actuelle) {
  if (actuelle != null && actuelle.codes.contains(code.codeId)) {
    throw const ErreurCode(ProblemeCode.dejaUtilise);
  }
  if (code.type == TypeCode.extension) {
    if (actuelle == null) {
      throw const ErreurCode(ProblemeCode.extensionSansLicence);
    }
    if (code.boutiqueId != actuelle.boutiqueId) {
      throw const ErreurCode(ProblemeCode.autreBoutique);
    }
  } else if (actuelle != null && code.boutiqueId != actuelle.boutiqueId) {
    throw const ErreurCode(ProblemeCode.autreBoutique);
  }
}
