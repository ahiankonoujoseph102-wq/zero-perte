/// Lecteur de QR code des Services Google Play (« Google code scanner »).
///
/// Le lecteur est un MODULE téléchargé à la demande par les Services Google
/// Play. Avant la 0.35.2, le tout premier appel échouait (module pas encore
/// là) et l'application le prenait pour une panne définitive. Maintenant :
/// - [LecteurQr.estPret] / [LecteurQr.preparer] : vérification et installation
///   urgente du module dès l'écran « Je suis vendeur » ;
/// - [scannerAvecReessai] : si le module n'est pas encore prêt, on le prépare
///   et on réessaie (jusqu'à 60 secondes) ;
/// - [messageLecteur] : un message selon la cause, avec le code exact.
library;

import 'package:flutter/services.dart';

import '../donnees/journal_local.dart' show ErreurZeroPerte;

/// Erreur exacte du lecteur (pour le message et pour l'assistance).
class ErreurLecteur extends ErreurZeroPerte {
  ErreurLecteur({required this.source, required this.code, this.detail = ''})
    : super('');

  /// `mlkit` (MlKitException), `api` (Services Google Play), `install`
  /// (installation du module), `delai` (pas prêt après 60 s), `autre`.
  final String source;
  final int code;
  final String detail;

  @override
  String get message => messageLecteur(this);

  @override
  String toString() => message;
}

/// Codes de MlKitException (vérifiés dans com.google.mlkit:common 18.11.0).
abstract final class CodesMlKit {
  static const int annule = 1;
  static const int delaiDepasse = 4;
  static const int interne = 13;
  static const int indisponible = 14;
  static const int reseau = 17;
  static const int placeInsuffisante = 101;
  static const int lecteurIndisponible = 200;
  static const int lecteurAnnule = 201;
  static const int appareilPhotoRefuse = 202;
  static const int nomApplication = 203;
  static const int dejaEnCours = 204;
  static const int servicesTropAnciens = 207;
}

/// Codes des Services Google Play (CommonStatusCodes, ModuleInstallStatusCodes).
abstract final class CodesServicesGoogle {
  static const int miseAJourRequise = 2;
  static const int desactive = 3;
  static const int reseau = 7;
  static const int interne = 8;
  static const int erreur = 13;
  static const int interrompu = 14;
  static const int delai = 15;
  static const int annule = 16;
  static const int moduleInconnu = 46000;
  static const int moduleNonPermis = 46001;
  static const int moduleIntrouvable = 46002;
  static const int placeInsuffisante = 46003;
  static const int reseauPayant = 46004;
}

const Map<int, String> _nomsMlKit = {
  1: 'CANCELLED',
  2: 'UNKNOWN',
  4: 'DEADLINE_EXCEEDED',
  8: 'RESOURCE_EXHAUSTED',
  9: 'FAILED_PRECONDITION',
  13: 'INTERNAL',
  14: 'UNAVAILABLE',
  17: 'NETWORK_ISSUE',
  101: 'NOT_ENOUGH_SPACE',
  200: 'CODE_SCANNER_UNAVAILABLE',
  201: 'CODE_SCANNER_CANCELLED',
  202: 'CODE_SCANNER_CAMERA_PERMISSION_NOT_GRANTED',
  203: 'CODE_SCANNER_APP_NAME_UNAVAILABLE',
  204: 'CODE_SCANNER_TASK_IN_PROGRESS',
  205: 'CODE_SCANNER_PIPELINE_INITIALIZATION_ERROR',
  206: 'CODE_SCANNER_PIPELINE_INFERENCE_ERROR',
  207: 'CODE_SCANNER_GOOGLE_PLAY_SERVICES_VERSION_TOO_OLD',
};

const Map<int, String> _nomsServices = {
  2: 'SERVICE_VERSION_UPDATE_REQUIRED',
  3: 'SERVICE_DISABLED',
  7: 'NETWORK_ERROR',
  8: 'INTERNAL_ERROR',
  10: 'DEVELOPER_ERROR',
  13: 'ERROR',
  14: 'INTERRUPTED',
  15: 'TIMEOUT',
  16: 'CANCELED',
  17: 'API_NOT_CONNECTED',
  46000: 'UNKNOWN_MODULE',
  46001: 'NOT_ALLOWED_MODULE',
  46002: 'MODULE_NOT_FOUND',
  46003: 'INSUFFICIENT_STORAGE',
  46004: 'METERED_NETWORK_NOT_ALLOWED',
};

/// « Code : 14 / UNAVAILABLE (mlkit) » : à lire sur une capture d'écran.
String codeLecteurLisible(ErreurLecteur e) {
  final nom = switch (e.source) {
    'mlkit' => _nomsMlKit[e.code],
    'api' || 'install' => _nomsServices[e.code],
    'delai' => 'PAS_PRET_APRES_60_S',
    _ => null,
  };
  return 'Code : ${e.code} / ${nom ?? 'INCONNU'} (${e.source})';
}

enum CauseLecteur {
  pasEncorePret,
  reseau,
  place,
  servicesGoogle,
  appareilPhoto,
  delai,
  autre,
}

CauseLecteur causeLecteur(ErreurLecteur e) {
  switch (e.source) {
    case 'delai':
      return CauseLecteur.delai;
    case 'mlkit':
      return switch (e.code) {
        CodesMlKit.indisponible ||
        CodesMlKit.lecteurIndisponible ||
        CodesMlKit.dejaEnCours ||
        CodesMlKit.delaiDepasse => CauseLecteur.pasEncorePret,
        CodesMlKit.reseau => CauseLecteur.reseau,
        CodesMlKit.placeInsuffisante => CauseLecteur.place,
        CodesMlKit.servicesTropAnciens => CauseLecteur.servicesGoogle,
        CodesMlKit.appareilPhotoRefuse => CauseLecteur.appareilPhoto,
        _ => CauseLecteur.autre,
      };
    case 'api':
    case 'install':
      return switch (e.code) {
        CodesServicesGoogle.reseau ||
        CodesServicesGoogle.reseauPayant => CauseLecteur.reseau,
        CodesServicesGoogle.placeInsuffisante => CauseLecteur.place,
        CodesServicesGoogle.miseAJourRequise ||
        CodesServicesGoogle.desactive ||
        CodesServicesGoogle.moduleInconnu ||
        CodesServicesGoogle.moduleNonPermis ||
        CodesServicesGoogle.moduleIntrouvable => CauseLecteur.servicesGoogle,
        CodesServicesGoogle.interrompu ||
        CodesServicesGoogle.delai => CauseLecteur.pasEncorePret,
        _ => CauseLecteur.autre,
      };
    default:
      return CauseLecteur.autre;
  }
}

/// Le module n'est pas encore là (ou un instant occupé) : on attend et on
/// réessaie, sans rien afficher.
bool lecteurPasEncorePret(ErreurLecteur e) =>
    causeLecteur(e) == CauseLecteur.pasEncorePret;

/// Message simple selon la cause (le code exact est montré à part, en petit).
String messageLecteur(ErreurLecteur e) => switch (causeLecteur(e)) {
  CauseLecteur.reseau =>
    'Le lecteur de QR code doit se télécharger une fois. '
        'Connectez-vous à Internet (Wi-Fi ou données) puis réessayez.',
  CauseLecteur.place =>
    'Il n\'y a plus assez de place sur ce téléphone pour le lecteur de QR code. '
        'Libérez un peu de place, puis réessayez.',
  CauseLecteur.servicesGoogle =>
    'Les Services Google Play de ce téléphone sont absents, désactivés ou trop '
        'anciens. Mettez-les à jour dans le Play Store, ou touchez '
        '« Pas d\'appareil photo ? ».',
  CauseLecteur.appareilPhoto =>
    'L\'appareil photo a été refusé. Réessayez et touchez « Autoriser », ou '
        'touchez « Pas d\'appareil photo ? ».',
  CauseLecteur.delai || CauseLecteur.pasEncorePret =>
    'Le lecteur de QR code n\'est pas encore prêt (téléchargement trop long). '
        'Vérifiez Internet et réessayez dans une minute, ou touchez '
        '« Pas d\'appareil photo ? ».',
  CauseLecteur.autre =>
    'Le lecteur de QR code n\'a pas pu s\'ouvrir. Réessayez, ou touchez '
        '« Pas d\'appareil photo ? » et tapez le code du patron.',
};

/// Le lecteur (Android : canal natif ; tests : faux lecteur).
abstract class LecteurQr {
  /// Le module est-il déjà installé ? [ErreurLecteur] si on ne peut pas le savoir.
  Future<bool> estPret();

  /// Demande l'installation (urgente) ; se termine quand il est prêt.
  Future<void> preparer();

  /// Ouvre le lecteur ; rend le texte lu, ou nul si la personne l'a fermé.
  Future<String?> scanner();
}

/// Ouvre le lecteur ; s'il n'est pas encore prêt, le prépare et réessaie
/// jusqu'à [limite]. Toute autre erreur est rendue tout de suite.
Future<String?> scannerAvecReessai(
  LecteurQr lecteur, {
  Duration limite = const Duration(seconds: 60),
  Duration pause = const Duration(seconds: 3),
  DateTime Function() maintenant = DateTime.now,
  Future<void> Function(Duration)? attendre,
  void Function()? enPreparation,
}) async {
  final fin = maintenant().add(limite);
  final dormir = attendre ?? (d) => Future<void>.delayed(d);
  ErreurLecteur? derniere;
  var prepareDemande = false;
  while (true) {
    try {
      return await lecteur.scanner();
    } on ErreurLecteur catch (e) {
      if (!lecteurPasEncorePret(e)) rethrow;
      derniere = e;
    }
    if (!maintenant().isBefore(fin)) {
      throw ErreurLecteur(
        source: 'delai',
        code: derniere.code,
        detail: codeLecteurLisible(derniere),
      );
    }
    enPreparation?.call();
    if (!prepareDemande) {
      prepareDemande = true;
      try {
        // Installation urgente ; une vraie panne (réseau, place…) arrête là.
        await lecteur.preparer().timeout(fin.difference(maintenant()));
        continue;
      } on ErreurLecteur catch (e) {
        if (!lecteurPasEncorePret(e)) rethrow;
      } catch (_) {
        // Délai de préparation dépassé : on réessaie quand même le lecteur.
      }
    }
    await dormir(pause);
  }
}

/// Le vrai lecteur (Android).
class LecteurQrAndroid implements LecteurQr {
  static const _canal = MethodChannel('tg.zeroperte/telephone');

  static ErreurLecteur _erreur(PlatformException e) {
    final d = (e.details as Map?)?.cast<Object?, Object?>() ?? const {};
    return ErreurLecteur(
      source: (d['source'] as String?) ?? 'autre',
      code: (d['code'] as int?) ?? -1,
      detail: e.message ?? '',
    );
  }

  @override
  Future<bool> estPret() async {
    try {
      return await _canal.invokeMethod<bool>('lecteurPret') ?? false;
    } on PlatformException catch (e) {
      throw _erreur(e);
    }
  }

  @override
  Future<void> preparer() async {
    try {
      await _canal.invokeMethod<bool>('lecteurPreparer');
    } on PlatformException catch (e) {
      throw _erreur(e);
    }
  }

  @override
  Future<String?> scanner() async {
    try {
      return await _canal.invokeMethod<String>('scannerQr');
    } on PlatformException catch (e) {
      throw _erreur(e);
    }
  }
}
