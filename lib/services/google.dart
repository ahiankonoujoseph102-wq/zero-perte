import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../donnees/journal_local.dart' show ErreurZeroPerte;
import '../synchro/drive.dart';
import '../synchro/synchro.dart';

/// Dossier partagé de la boutique, avec le compte qui y donne accès.
class ConnexionStockage {
  const ConnexionStockage({required this.compte, required this.stockage});

  /// Adresse du compte Google de la boutique (affichée au patron).
  final String compte;
  final StockageDistant stockage;
}

/// Connexion au compte Google de la boutique (Android), autorisation
/// `drive.appdata` seulement. [silencieux] : sans rien demander (relève auto).
/// Nul si la personne annule, ou si ce n'est pas possible sur cet appareil.
Future<ConnexionStockage?> connecterDriveAndroid({
  bool silencieux = false,
}) async {
  // Windows : autre méthode de connexion (voir docs/etapes-proprietaire.md).
  if (!Platform.isAndroid) {
    return null;
  }
  final google = GoogleSignIn(scopes: [autorisationDriveAppData]);
  final compte = silencieux
      ? await google.signInSilently()
      : (await google.signInSilently()) ?? await google.signIn();
  if (compte == null) return null;
  Future<String> jeton({bool renouveler = false}) async {
    if (renouveler) {
      await compte.clearAuthCache();
    }
    final t = (await compte.authentication).accessToken;
    if (t == null) throw const ErreurDrive('Connexion Google expirée.');
    return t;
  }

  return ConnexionStockage(
    compte: compte.email,
    stockage: StockageDriveAppData(jeton: jeton),
  );
}

/// Téléphone du PATRON : demande à Google l'accord pour un nouveau vendeur
/// (compte de la boutique, dossier caché de Zéro Perte seulement) et rend le
/// « code d'échange » (un seul usage, quelques minutes), que le relais échange
/// contre un jeton de longue durée avec le code secret qu'il est seul à
/// connaître. Le mot de passe du compte n'est jamais demandé ni envoyé.
/// Nul si la personne annule.
Future<String?> codeGoogleServeurAndroid(String idClientWeb) async {
  if (!Platform.isAndroid) return null;
  final google = GoogleSignIn(
    scopes: [autorisationDriveAppData],
    serverClientId: idClientWeb,
    forceCodeForRefreshToken: true,
  );
  // Sans cela, Google peut rendre l'ancienne connexion sans nouveau code.
  try {
    await google.signOut();
  } catch (_) {}
  final compte = await google.signIn();
  return compte?.serverAuthCode;
}

/// Lecteur de QR code de Google Play services ; nul si annulé.
/// [ErreurScanner] si le lecteur n'est pas disponible (téléphone
/// sans services Google).
Future<String?> scannerQrAndroid() async {
  try {
    return await const MethodChannel('tg.zeroperte/telephone')
        .invokeMethod<String>('scannerQr');
  } on PlatformException catch (e) {
    throw ErreurScanner(e.message ?? '');
  }
}

/// Le lecteur de QR code ne marche pas sur ce téléphone.
class ErreurScanner extends ErreurZeroPerte {
  const ErreurScanner(this.detail)
    : super(
        'Le lecteur de QR code ne marche pas sur ce téléphone. '
        'Touchez « Pas d\'appareil photo ? » et tapez le code du patron.',
      );
  final String detail;
}

/// Déconnecte le compte Google (le patron change de compte).
Future<void> deconnecterDriveAndroid() async {
  if (!Platform.isAndroid) return;
  await GoogleSignIn(scopes: [autorisationDriveAppData]).signOut();
}

/// Choisit un fichier (sauvegarde .zps) sur l'appareil. Nul si annulé.
Future<Uint8List?> choisirFichierSauvegarde() async {
  final f = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Sauvegarde Zéro Perte', extensions: ['zps']),
    ],
  );
  return f?.readAsBytes();
}
