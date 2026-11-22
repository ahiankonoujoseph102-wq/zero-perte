// Point de départ : tout l'historique de la boutique dans UN fichier compact,
// pour qu'un nouvel appareil n'ait pas à télécharger des centaines de fichiers.
//
// Rien n'est perdu ni « résumé » : chaque opération est gardée telle quelle,
// mais les champs qui se recalculent ne sont pas écrits :
//  - le numéro (1, 2, 3… sans trou pour chaque téléphone) ;
//  - les empreintes (recalculées à la lecture, puis comparées à la DERNIÈRE
//    empreinte de chaque téléphone, écrite en tête du fichier) ;
//  - les identifiants de téléphone, d'auteur et les types (remplacés par un
//    numéro dans une petite table) ;
//  - l'heure (écart avec l'opération précédente) ;
//  - les identifiants répétés (produits, clients…), remplacés par un numéro.
// Un fichier abîmé ou modifié est refusé : la chaîne recalculée ne retombe
// pas sur l'empreinte attendue.

import 'dart:convert';
import 'dart:io' show GZipCodec;

import '../domaine/operation.dart';
import '../donnees/journal_local.dart';

/// Nom du fichier dans le dossier partagé.
const String nomPointDepart = 'point-de-depart.json.gz';

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
const String _marque = '\u0001';

/// Identifiant d'opération raccourci (sans tirets) ; « ! » devant sinon.
String _idCourt(String id) =>
    _uuid.hasMatch(id) ? id.replaceAll('-', '') : '!$id';

String _idLong(String c) => c.startsWith('!')
    ? c.substring(1)
    : '${c.substring(0, 8)}-${c.substring(8, 12)}-${c.substring(12, 16)}-'
          '${c.substring(16, 20)}-${c.substring(20)}';

/// Remplace les identifiants répétés (produits, clients…) par un numéro.
Object? _replier(Object? v, Map<String, int> refs) {
  if (v is String) {
    if (_uuid.hasMatch(v)) {
      return '$_marque${refs.putIfAbsent(v, () => refs.length)}';
    }
    return v.startsWith(_marque) ? '$_marque$v' : v;
  }
  if (v is Map) {
    return {for (final e in v.entries) e.key: _replier(e.value, refs)};
  }
  if (v is List) return [for (final x in v) _replier(x, refs)];
  return v;
}

Object? _deplier(Object? v, List<String> refs) {
  if (v is String) {
    if (!v.startsWith(_marque)) return v;
    final reste = v.substring(1);
    return reste.startsWith(_marque) ? reste : refs[int.parse(reste)];
  }
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) e.key as String: _deplier(e.value, refs),
    };
  }
  if (v is List) return [for (final x in v) _deplier(x, refs)];
  return v;
}

/// Fabrique le point de départ à partir de toutes les opérations connues.
/// Les champs de même nature sont rangés ensemble (colonnes) : la
/// compression est bien meilleure.
List<int> fabriquerPointDepart(List<Operation> operations, {int? cree}) {
  final parTel = <String, List<Operation>>{};
  for (final op in operations) {
    parTel.putIfAbsent(op.telephoneId, () => []).add(op);
  }
  final types = <String, int>{};
  final auteurs = <String, int>{};
  final refs = <String, int>{};
  final telephones = <Map<String, Object?>>[];
  for (final MapEntry(key: tel, value: liste) in parTel.entries) {
    liste.sort((a, b) => a.numero.compareTo(b.numero));
    // Seulement une suite complète depuis le n° 1 (sinon on s'arrête au trou).
    final suite = <Operation>[];
    for (final op in liste) {
      if (op.numero != suite.length + 1) break;
      suite.add(op);
    }
    if (suite.isEmpty) continue;
    var heure = 0;
    final heures = <int>[];
    for (final op in suite) {
      heures.add(op.heureTelephone - heure);
      heure = op.heureTelephone;
    }
    telephones.add({
      'id': tel,
      'derniere': suite.last.empreinte,
      'types': [
        for (final op in suite) types.putIfAbsent(op.type, () => types.length),
      ],
      'auteurs': [
        for (final op in suite)
          auteurs.putIfAbsent(op.auteurId, () => auteurs.length),
      ],
      'heures': heures,
      'ids': [for (final op in suite) _idCourt(op.id)],
      'donnees': [for (final op in suite) _replier(op.donnees, refs)],
      if (suite.any((o) => o.signature != null))
        'signatures': [for (final op in suite) op.signature],
    });
  }
  final contenu = utf8.encode(
    jsonEncode({
      'format': 1,
      'cree': cree ?? DateTime.now().millisecondsSinceEpoch,
      'types': types.keys.toList(),
      'auteurs': auteurs.keys.toList(),
      'refs': refs.keys.toList(),
      'telephones': telephones,
    }),
  );
  return GZipCodec(level: 9).encode(contenu);
}

/// Contenu d'un point de départ.
class PointDepart {
  const PointDepart(this.operations, this.jusqua, this.cree);

  /// Toutes les opérations, vérifiées.
  final List<Operation> operations;

  /// Dernier numéro contenu, par téléphone.
  final Map<String, int> jusqua;
  final int cree;
}

/// Relit (et vérifie) un point de départ. Refus clair s'il est abîmé.
PointDepart lirePointDepart(List<int> octets) {
  const refus = ErreurZeroPerte(
    'Point de départ abîmé ou modifié : refusé, rien n\'a été importé.',
  );
  final Map<String, Object?> d;
  try {
    d = (jsonDecode(utf8.decode(GZipCodec().decode(octets))) as Map)
        .cast<String, Object?>();
  } catch (_) {
    throw refus;
  }
  if (d['format'] != 1) {
    throw const ErreurZeroPerte(
      'Point de départ d\'une version plus récente : mettez Zéro Perte à jour.',
    );
  }
  try {
    final types = (d['types'] as List).cast<String>();
    final auteurs = (d['auteurs'] as List).cast<String>();
    final refs = (d['refs'] as List).cast<String>();
    final ops = <Operation>[];
    final jusqua = <String, int>{};
    for (final t in (d['telephones'] as List).cast<Map>()) {
      final tel = t['id'] as String;
      final ts = (t['types'] as List).cast<int>();
      final as = (t['auteurs'] as List).cast<int>();
      final hs = (t['heures'] as List).cast<int>();
      final ids = (t['ids'] as List).cast<String>();
      final ds = t['donnees'] as List;
      final sigs = (t['signatures'] as List?)?.cast<String?>();
      if ({
                as.length,
                hs.length,
                ids.length,
                ds.length,
                sigs?.length ?? ts.length,
              }.length !=
              1 ||
          as.length != ts.length) {
        throw refus;
      }
      var precedente = '';
      var heure = 0;
      var numero = 0;
      for (var i = 0; i < ts.length; i++) {
        numero++;
        heure += hs[i];
        final donnees = (_deplier(ds[i], refs) as Map).cast<String, Object?>();
        final type = types[ts[i]];
        final auteur = auteurs[as[i]];
        final id = _idLong(ids[i]);
        final empreinte = calculerEmpreinte(
          id: id,
          telephoneId: tel,
          numero: numero,
          type: type,
          auteurId: auteur,
          heureTelephone: heure,
          donnees: donnees,
          empreintePrecedente: precedente,
        );
        ops.add(
          Operation(
            id: id,
            telephoneId: tel,
            numero: numero,
            type: type,
            auteurId: auteur,
            heureTelephone: heure,
            donnees: donnees,
            empreintePrecedente: precedente,
            empreinte: empreinte,
            signature: sigs?[i],
          ),
        );
        precedente = empreinte;
      }
      if (precedente != t['derniere']) throw refus;
      jusqua[tel] = numero;
    }
    return PointDepart(ops, jusqua, d['cree'] as int);
  } on ErreurZeroPerte {
    rethrow;
  } catch (_) {
    throw refus;
  }
}
