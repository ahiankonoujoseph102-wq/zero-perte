/// Le journal des opérations : « on ajoute, on ne modifie jamais ».
///
/// Chaque action (vente, arrivage, dépense, annulation…) est une NOUVELLE
/// opération, jamais modifiée ni effacée. Chaque opération porte :
///   - un identifiant unique (UUID) ;
///   - le téléphone d'origine et son numéro d'ordre sur ce téléphone (1, 2, 3…) ;
///   - l'auteur (patron ou vendeur) et l'heure du téléphone ;
///   - l'empreinte de l'opération précédente du même téléphone (chaîne) et la
///     sienne : une opération supprimée, modifiée ou inventée se voit.
///   - une signature (ajoutée à l'étape D2, synchronisation Drive).
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Types d'opérations connus. Une nouvelle sorte d'opération = un nouveau type,
/// jamais la modification d'un type existant.
abstract final class TypeOperation {
  static const produitDefini = 'produit.defini';
  static const conditionnementDefini = 'conditionnement.defini';
  static const arrivage = 'stock.arrivage';
  static const perte = 'stock.perte';
  static const vente = 'vente';
  static const venteAnnulee = 'vente.annulee';
  static const emballage = 'emballage.mouvement';
  static const fondsDeCaisse = 'caisse.fonds';
  static const depense = 'caisse.depense';
  static const retraitPatron = 'caisse.retrait_patron';
  static const fermetureCaisse = 'caisse.fermeture';
  static const licenceActivee = 'licence.activee';
  static const boutiqueConfiguree = 'boutique.configuree';
  static const utilisateurDefini = 'utilisateur.defini';
  static const clientDefini = 'client.defini';
  static const remboursementCredit = 'credit.remboursement';
  static const inventaire = 'stock.inventaire';
  static const fournisseurDefini = 'fournisseur.defini';
  static const achatFournisseur = 'fournisseur.achat';
  static const paiementFournisseur = 'fournisseur.paiement';

  /// Retour partiel d'une vente : marchandise remise en stock, client remboursé.
  static const venteRetour = 'vente.retour';

  /// Devis (facture proforma) : ne touche ni le stock ni la caisse.
  static const devisCree = 'devis.cree';

  /// Devis transformé en vente.
  static const devisVendu = 'devis.vendu';
}

/// Une opération du journal.
class Operation {
  const Operation({
    required this.id,
    required this.telephoneId,
    required this.numero,
    required this.type,
    required this.auteurId,
    required this.heureTelephone,
    required this.donnees,
    required this.empreintePrecedente,
    required this.empreinte,
    this.signature,
  });

  final String id;
  final String telephoneId;

  /// Numéro d'ordre sur le téléphone d'origine : 1, 2, 3… sans trou.
  final int numero;
  final String type;
  final String auteurId;

  /// Heure du téléphone, en millisecondes depuis le 1er janvier 1970 (UTC).
  /// Elle peut être faussée par le vendeur : elle sera comparée à l'heure du
  /// serveur Drive lors de la synchronisation (étape D6).
  final int heureTelephone;

  /// Contenu de l'opération. Uniquement des entiers, textes, booléens, listes et
  /// dictionnaires : jamais de nombre à virgule.
  final Map<String, Object?> donnees;

  /// Empreinte de l'opération précédente du même téléphone ('' pour la première).
  final String empreintePrecedente;

  /// Empreinte SHA-256 de cette opération (tous les champs sauf la signature).
  final String empreinte;

  /// Signature du téléphone (étape D2). Vide pour l'instant.
  final String? signature;

  /// Recalcule l'empreinte et vérifie qu'elle correspond.
  bool get empreinteValide =>
      empreinte ==
      calculerEmpreinte(
        id: id,
        telephoneId: telephoneId,
        numero: numero,
        type: type,
        auteurId: auteurId,
        heureTelephone: heureTelephone,
        donnees: donnees,
        empreintePrecedente: empreintePrecedente,
      );
}

/// Calcule l'empreinte SHA-256 (en hexadécimal) d'une opération.
String calculerEmpreinte({
  required String id,
  required String telephoneId,
  required int numero,
  required String type,
  required String auteurId,
  required int heureTelephone,
  required Map<String, Object?> donnees,
  required String empreintePrecedente,
}) {
  final contenu = jsonCanonique({
    'id': id,
    'telephone': telephoneId,
    'numero': numero,
    'type': type,
    'auteur': auteurId,
    'heure': heureTelephone,
    'donnees': donnees,
    'precedente': empreintePrecedente,
  });
  return sha256.convert(utf8.encode(contenu)).toString();
}

/// JSON « canonique » : clés triées, aucun espace. Le même contenu donne
/// toujours exactement le même texte, donc la même empreinte sur tous les téléphones.
/// Refuse les nombres à virgule (règle « montants entiers »).
String jsonCanonique(Object? valeur) {
  final tampon = StringBuffer();
  _ecrire(valeur, tampon);
  return tampon.toString();
}

void _ecrire(Object? v, StringBuffer t) {
  if (v == null || v is bool || v is String) {
    t.write(jsonEncode(v));
  } else if (v is int) {
    t.write(v.toString());
  } else if (v is double) {
    throw ArgumentError(
      'Nombre à virgule interdit dans une opération : $v. Utilisez des entiers (F, millièmes).',
    );
  } else if (v is List) {
    t.write('[');
    for (var i = 0; i < v.length; i++) {
      if (i > 0) t.write(',');
      _ecrire(v[i], t);
    }
    t.write(']');
  } else if (v is Map) {
    final cles = v.keys.map((k) => k.toString()).toList()..sort();
    t.write('{');
    for (var i = 0; i < cles.length; i++) {
      if (i > 0) t.write(',');
      t.write(jsonEncode(cles[i]));
      t.write(':');
      _ecrire(v[cles[i]], t);
    }
    t.write('}');
  } else {
    throw ArgumentError(
      'Type non pris en charge dans une opération : ${v.runtimeType}',
    );
  }
}

final Random _aleatoire = Random.secure();

/// Identifiant unique aléatoire (UUID version 4).
String nouvelIdentifiant() {
  final octets = List<int>.generate(16, (_) => _aleatoire.nextInt(256));
  octets[6] = (octets[6] & 0x0f) | 0x40; // version 4
  octets[8] = (octets[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Vérifie la chaîne des opérations d'UN téléphone (triées par numéro).
/// Renvoie la liste des problèmes trouvés (vide si tout est en ordre).
/// [depuisNumero] / [depuisEmpreinte] : dernière opération déjà connue et
/// vérifiée (on ne revérifie pas tout l'historique à chaque synchronisation).
List<String> verifierChaine(
  List<Operation> operations, {
  int depuisNumero = 0,
  String depuisEmpreinte = '',
}) {
  final problemes = <String>[];
  var precedente = depuisEmpreinte;
  var attendu = depuisNumero + 1;
  for (final op in operations) {
    if (op.numero != attendu) {
      problemes.add(
        'Numéro ${op.numero} au lieu de $attendu : opération(s) manquante(s).',
      );
      attendu = op.numero;
    }
    if (op.empreintePrecedente != precedente) {
      problemes.add('Opération n° ${op.numero} : la chaîne est rompue.');
    }
    if (!op.empreinteValide) {
      problemes.add('Opération n° ${op.numero} : contenu modifié.');
    }
    precedente = op.empreinte;
    attendu++;
  }
  return problemes;
}
