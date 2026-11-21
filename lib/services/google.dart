import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
