/// Synchronisation des appareils d'une boutique par un dossier partagé
/// (en vrai : le dossier caché de l'application dans le Google Drive de la
/// boutique, autorisation `drive.appdata`).
///
/// Principe (docs/decision-serveur.md §1.a) : chaque appareil écrit
/// UNIQUEMENT ses propres fichiers et lit ceux des autres. Comme les
/// opérations ne sont jamais modifiées, il n'y a aucun conflit possible.
///
/// Fichiers :
/// - `ops-<appareil>-<premier n°>-<dernier n°>.json` : opérations d'un appareil ;
/// - `appareil-<appareil>.json` : qui est cet appareil (préfixe des reçus, nom) ;
/// - `boutique.json` : identifiant de la boutique et jeton du relais d'alertes
///   (écrit une seule fois, par le premier appareil).
library;

import 'dart:convert';
import 'dart:io' show gzip;

import 'point_depart.dart';

import 'dart:math';

import '../domaine/operation.dart';
import '../donnees/journal_local.dart';

/// Un fichier du dossier partagé.
class FichierDistant {
  const FichierDistant({required this.id, required this.nom});
  final String id;
  final String nom;
}

/// Le dossier partagé de la boutique (Drive, ou mémoire pour les tests).
abstract class StockageDistant {
  Future<List<FichierDistant>> lister();
  Future<List<int>> lire(FichierDistant fichier);

  /// Crée le fichier, ou le remplace s'il existe déjà sous ce nom.
  Future<void> ecrire(String nom, List<int> contenu);
}

/// Dossier partagé en mémoire (tests, démonstration).
class StockageMemoire implements StockageDistant {
  final Map<String, List<int>> fichiers = {};
  int lectures = 0;

  @override
  Future<List<FichierDistant>> lister() async => [
    for (final n in fichiers.keys) FichierDistant(id: n, nom: n),
  ];

  @override
  Future<List<int>> lire(FichierDistant fichier) async {
    lectures++;
    final f = fichiers[fichier.id];
    if (f == null) throw StateError('Fichier absent : ${fichier.nom}');
    return f;
  }

  @override
  Future<void> ecrire(String nom, List<int> contenu) async {
    fichiers[nom] = List<int>.of(contenu);
  }
}

/// Un appareil inscrit dans le dossier de la boutique.
class Appareil {
  const Appareil({
    required this.id,
    required this.prefixe,
    required this.nom,
    required this.inscrit,
    this.formatSync = 1,
  });

  factory Appareil.depuisJson(List<int> octets) {
    final d = (jsonDecode(utf8.decode(octets)) as Map).cast<String, Object?>();
    return Appareil(
      id: d['appareil'] as String,
      prefixe: d['prefixe'] as String,
      nom: (d['nom'] as String?) ?? '',
      inscrit: (d['inscrit'] as int?) ?? 0,
      formatSync: (d['format_sync'] as int?) ?? 1,
    );
  }

  final String id;
  final String prefixe;
  final String nom;
  final int inscrit;

  /// Formats de synchronisation que cet appareil sait lire : 1 = fichiers
  /// JSON ; 2 = aussi les fichiers compressés (.json.gz) et le « point de
  /// départ ». Les versions avant 0.33 n'écrivent rien (= 1).
  final int formatSync;

  Appareil avecFormat(int f) => Appareil(
    id: id,
    prefixe: prefixe,
    nom: nom,
    inscrit: inscrit,
    formatSync: f,
  );

  List<int> versJson() => utf8.encode(
    jsonEncode({
      'appareil': id,
      'prefixe': prefixe,
      'nom': nom,
      'inscrit': inscrit,
      'format_sync': formatSync,
    }),
  );
}

/// Licence pleine : la boutique a déjà tous ses appareils.
class ErreurLicencePleine extends ErreurZeroPerte {
  const ErreurLicencePleine(int maximum)
    : super(
        'La licence permet $maximum appareils et ils sont déjà tous utilisés. '
        'Achetez un appareil en plus, ou remplacez un ancien appareil.',
      );
}

class ResultatSynchro {
  const ResultatSynchro({
    required this.envoyees,
    required this.recues,
    required this.appareils,
  });

  /// Opérations de cet appareil envoyées vers le dossier partagé.
  final int envoyees;

  /// Opérations d'autres appareils ajoutées ici.
  final int recues;

  /// Appareils inscrits dans la boutique.
  final List<Appareil> appareils;
}

const _cleEnvoye = 'sync.envoye';

/// Format de synchronisation de cette version (voir [Appareil.formatSync]).
const int formatSyncActuel = 2;
const int _parFichier = 500;

/// Synchronise le journal local avec le dossier partagé de la boutique.
class Synchroniseur {
  Synchroniseur({required this.journal, required this.stockage});

  final JournalLocal journal;
  final StockageDistant stockage;

  static const String _clePointDepart = 'sync.point_depart';
  static const int _intervallePointDepart = 7 * 24 * 3600 * 1000;

  static final RegExp _nomOps = RegExp(
    r'^ops-(.+)-(\d{8})-(\d{8})\.json(\.gz)?$',
  );

  /// Contenu d'un fichier d'opérations (compressé ou non).
  /// Un fichier abîmé ou trafiqué est refusé : rien n'est écrit.
  Future<List<Operation>> _lireOps(FichierDistant f) async {
    final octets = await stockage.lire(f);
    try {
      return JournalLocal.operationsDepuisJson(
        f.nom.endsWith('.gz') ? gzip.decode(octets) : octets,
      );
    } on ErreurZeroPerte {
      rethrow;
    } catch (_) {
      throw ErreurZeroPerte(
        'Fichier de synchronisation illisible (${f.nom}) : rien n\'a été '
        'importé. Relancez la synchronisation depuis l\'appareil qui l\'a envoyé.',
      );
    }
  }

  /// Appareils inscrits dans le dossier partagé.
  Future<List<Appareil>> appareils([List<FichierDistant>? liste]) async {
    final fichiers = liste ?? await stockage.lister();
    return [
      for (final f in fichiers.where(
        (f) => f.nom.startsWith('appareil-') && f.nom.endsWith('.json'),
      ))
        Appareil.depuisJson(await stockage.lire(f)),
    ];
  }

  /// Lit `boutique.json` (nul si la boutique n'en a pas encore).
  Future<Map<String, Object?>?> infosBoutique([
    List<FichierDistant>? liste,
  ]) async {
    final fichiers = liste ?? await stockage.lister();
    final f = fichiers.where((f) => f.nom == 'boutique.json').firstOrNull;
    if (f == null) return null;
    return (jsonDecode(utf8.decode(await stockage.lire(f))) as Map)
        .cast<String, Object?>();
  }

  /// Une synchronisation complète : inscription de l'appareil, envoi de ses
  /// opérations, réception de celles des autres.
  /// [maxAppareils] : nombre d'appareils permis par la licence (nul = pas de
  /// contrôle). [nomAppareil] : nom affiché au patron (ex. « Téléphone d'Ama »).
  Future<ResultatSynchro> synchroniser({
    int? maxAppareils,
    String nomAppareil = '',
    String? boutiqueId,
    int Function()? horloge,
  }) async {
    var fichiers = await stockage.lister();

    // 1. Inscription (une seule fois) et contrôle de la licence.
    var liste = await appareils(fichiers);
    if (!liste.any((a) => a.id == journal.telephoneId)) {
      if (maxAppareils != null && liste.length >= maxAppareils) {
        throw ErreurLicencePleine(maxAppareils);
      }
      final pris = {for (final a in liste) a.prefixe};
      if (pris.contains(journal.prefixeRecu)) {
        final aVendu = (await journal.mesOperationsApres(0))
            .any((o) => o.type == TypeOperation.vente);
        if (aVendu) {
          throw ErreurZeroPerte(
            'Un autre appareil utilise déjà les reçus « ${journal.prefixeRecu} ».',
          );
        }
        final libre = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
            .split('')
            .firstWhere((l) => !pris.contains(l));
        await journal.changerPrefixeRecu(libre);
      }
      final moi = Appareil(
        id: journal.telephoneId,
        prefixe: journal.prefixeRecu,
        nom: nomAppareil,
        inscrit: (horloge ?? () => DateTime.now().millisecondsSinceEpoch)(),
        formatSync: formatSyncActuel,
      );
      await stockage.ecrire('appareil-${moi.id}.json', moi.versJson());
      liste = [...liste, moi];
    }
    // Appareil déjà inscrit par une ancienne version : il annonce maintenant
    // qu'il sait lire les fichiers compressés.
    final moiInscrit = liste
        .where((a) => a.id == journal.telephoneId)
        .firstOrNull;
    if (moiInscrit != null && moiInscrit.formatSync < formatSyncActuel) {
      final maj = moiInscrit.avecFormat(formatSyncActuel);
      await stockage.ecrire('appareil-${maj.id}.json', maj.versJson());
      liste = [for (final a in liste) a.id == maj.id ? maj : a];
    }
    // Fichiers compressés seulement si TOUS les appareils savent les lire
    // (sinon un appareil resté sur une ancienne version perdrait des ventes).
    final compresser = liste.every((a) => a.formatSync >= 2);
    if (!compresser) {
      // Un appareil d'une ancienne version est (re)venu : nos fichiers déjà
      // compressés sont aussi écrits en clair pour qu'il ne perde rien.
      final noms = {for (final f in fichiers) f.nom};
      for (final f in fichiers) {
        final m = _nomOps.firstMatch(f.nom);
        if (m == null || m.group(1) != journal.telephoneId) continue;
        if (!f.nom.endsWith('.gz')) continue;
        final clair = f.nom.substring(0, f.nom.length - 3);
        if (noms.contains(clair)) continue;
        await stockage.ecrire(clair, gzip.decode(await stockage.lire(f)));
      }
    }
    if (!fichiers.any((f) => f.nom == 'boutique.json')) {
      await stockage.ecrire(
        'boutique.json',
        utf8.encode(
          jsonEncode({
            'boutique': boutiqueId,
            'jeton_relais': _jetonAleatoire(),
          }),
        ),
      );
    }

    // 2. Envoi de nos opérations pas encore envoyées.
    final envoye =
        int.tryParse(await journal.lireParametre(_cleEnvoye) ?? '') ?? 0;
    final aEnvoyer = await journal.mesOperationsApres(envoye);
    for (var i = 0; i < aEnvoyer.length; i += _parFichier) {
      final lot = aEnvoyer.sublist(i, min(i + _parFichier, aEnvoyer.length));
      final nom =
          'ops-${journal.telephoneId}-${_n8(lot.first.numero)}-${_n8(lot.last.numero)}.json';
      final json = JournalLocal.operationsVersJson(lot);
      if (compresser) {
        await stockage.ecrire('$nom.gz', gzip.encode(json));
      } else {
        await stockage.ecrire(nom, json);
      }
      await journal.ecrireParametre(_cleEnvoye, '${lot.last.numero}');
    }

    // 3. Réception des opérations des autres appareils.
    fichiers = await stockage.lister();
    final parAppareil = <String, List<(int, int, FichierDistant)>>{};
    for (final f in fichiers) {
      final m = _nomOps.firstMatch(f.nom);
      if (m == null || m.group(1) == journal.telephoneId) continue;
      parAppareil.putIfAbsent(m.group(1)!, () => []).add((
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        f,
      ));
    }
    var recues = 0;
    for (final MapEntry(key: tel, value: lots) in parAppareil.entries) {
      lots.sort((a, b) => a.$1.compareTo(b.$1));
      final connu = await journal.dernierNumero(tel);
      final ops = <Operation>[];
      final lus = <(int, int)>{};
      for (final (debut, fin, f) in lots) {
        if (fin <= connu) continue;
        // Même lot en clair et compressé : une seule lecture.
        if (!lus.add((debut, fin))) continue;
        ops.addAll(await _lireOps(f));
      }
      recues += await journal.importerOperations(ops);
    }

    // 4. Point de départ pour les nouveaux appareils (une fois par semaine),
    //    seulement quand tous les appareils savent le lire.
    if (compresser) {
      final maintenant =
          (horloge ?? () => DateTime.now().millisecondsSinceEpoch)();
      final dernier =
          int.tryParse(await journal.lireParametre(_clePointDepart) ?? '') ?? 0;
      final present = fichiers.any((f) => f.nom == nomPointDepart);
      if (!present || maintenant - dernier > _intervallePointDepart) {
        final tout = <Operation>[
          for (final tel in await journal.telephonesConnus())
            ...await journal.operationsDuTelephone(tel),
        ];
        await stockage.ecrire(
          nomPointDepart,
          fabriquerPointDepart(tout, cree: maintenant),
        );
        await journal.ecrireParametre(_clePointDepart, '$maintenant');
      }
    }

    return ResultatSynchro(
      envoyees: aEnvoyer.length,
      recues: recues,
      appareils: liste,
    );
  }

  /// Nouveau téléphone : récupère TOUTE la boutique depuis le dossier partagé.
  /// Avec [remplace], il prend l'identité de cet ancien appareil (perdu ou
  /// cassé) et continue ses reçus ; sinon il devient un nouvel appareil.
  Future<int> recupererBoutique({Appareil? remplace}) async {
    if (remplace != null) {
      await journal.reprendreIdentite(remplace.id, remplace.prefixe);
    }
    final fichiers = await stockage.lister();
    final ops = <Operation>[];
    final vues = <String>{};
    // Point de départ : tout l'historique en un seul fichier ; ensuite,
    // seulement les fichiers plus récents que lui.
    var jusqua = const <String, int>{};
    final depart = fichiers.where((f) => f.nom == nomPointDepart).firstOrNull;
    if (depart != null) {
      final p = lirePointDepart(await stockage.lire(depart));
      ops.addAll(p.operations);
      jusqua = p.jusqua;
    }
    for (final f in fichiers.where((f) => _nomOps.hasMatch(f.nom))) {
      final m = _nomOps.firstMatch(f.nom)!;
      if (int.parse(m.group(3)!) <= (jusqua[m.group(1)] ?? 0)) continue;
      // Même lot en clair et compressé : une seule lecture.
      if (!vues.add('${m.group(1)}-${m.group(2)}-${m.group(3)}')) continue;
      ops.addAll(await _lireOps(f));
    }
    if (remplace == null) return journal.importerOperations(ops);
    // Nos propres opérations (ancien appareil) : on les reprend telles quelles.
    final miennes = ops.where((o) => o.telephoneId == remplace.id).toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
    final n = await journal.restaurerOperationsPropres(miennes);
    if (miennes.isNotEmpty) {
      await journal.ecrireParametre(_cleEnvoye, '${miennes.last.numero}');
    }
    return n + await journal.importerOperations(ops);
  }

  static String _n8(int n) => n.toString().padLeft(8, '0');

  static String _jetonAleatoire() {
    final r = Random.secure();
    return base64Url
        .encode(List<int>.generate(24, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }
}
