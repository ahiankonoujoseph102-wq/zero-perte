/// Équivalents Windows (version PC) des fonctions propres à Android.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as chemins;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/etat_application.dart' show SourcePhoto;
import 'google.dart' show ConnexionStockage;
import 'google_pc.dart';
import 'partage.dart';
import 'telephone.dart';

bool get surWindows => Platform.isWindows;

/// Sur PC, les contrôles « téléphone » (version d'Android, services Google)
/// n'ont pas de sens : l'appareil est déclaré compatible.
class ServiceTelephoneWindows implements ServiceTelephone {
  @override
  Future<InfosTelephone> infos() async => InfosTelephone.depuisCarte({
    'androidSdk': 99,
    'androidVersion': 'Windows',
    'fabricant': 'PC',
    'modele': Platform.operatingSystemVersion,
    'servicesGoogle': true,
    'espaceLibreMo': 4096,
  });
}

/// Dossier « Documents\Zero Perte\<sous-dossier> » (créé si besoin).
Future<Directory> dossierZeroPerte(String sousDossier) async {
  final docs = await getApplicationDocumentsDirectory();
  final d = Directory(chemins.join(docs.path, 'Zero Perte', sousDossier));
  await d.create(recursive: true);
  return d;
}

/// Reçu sur PC : l'image est enregistrée dans Documents\Zero Perte\Recus, le
/// texte est copié, puis WhatsApp (application PC) s'ouvre. Le vendeur joint
/// l'image dans la conversation du client.
Future<ResultatPartage> partagerImageWindows(
  Uint8List png,
  String texte,
) async {
  try {
    final d = await dossierZeroPerte('Recus');
    final f = File(
      chemins.join(d.path, 'recu-${DateTime.now().millisecondsSinceEpoch}.png'),
    );
    await f.writeAsBytes(png);
    await Clipboard.setData(ClipboardData(text: texte));
    final whatsapp = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(texte)}',
    );
    if (!await launchUrl(whatsapp)) {
      await launchUrl(Uri.file(d.path));
    }
    return ResultatPartage.enregistre;
  } catch (_) {
    return ResultatPartage.echec;
  }
}

/// Sauvegarde ou export sur PC : fenêtre « Enregistrer sous ».
Future<ResultatPartage> partagerFichierWindows(
  Uint8List octets,
  String nom,
) async {
  try {
    final dossier = await dossierZeroPerte('Sauvegardes');
    final lieu = await getSaveLocation(
      suggestedName: nom,
      initialDirectory: dossier.path,
    );
    final chemin = lieu?.path ?? chemins.join(dossier.path, nom);
    await File(chemin).writeAsBytes(octets);
    return ResultatPartage.enregistre;
  } catch (_) {
    return ResultatPartage.echec;
  }
}

/// Photo sur PC : on choisit une image existante (pas d'appareil photo).
Future<Uint8List?> prendrePhotoWindows(SourcePhoto source) async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 70,
  );
  return photo?.readAsBytes();
}

/// Connexion Google sur PC (si la fabrication a reçu l'identifiant
/// « Application de bureau ») : jeton gardé dans le dossier de l'utilisateur.
Future<ConnexionStockage?> connecterDriveWindows({
  bool silencieux = false,
}) async {
  if (!connexionPcConfiguree) return null;
  final dossier = (await getApplicationSupportDirectory()).path;
  final fichierCompte = File(chemins.join(dossier, 'zp_google_compte.txt'));
  final c = ConnexionGooglePc(
    idClient: idClientPc,
    secretClient: secretClientPc,
    coffre: CoffreFichier(chemins.join(dossier, 'zp_google.txt')),
    ouvrirNavigateur: (url) =>
        launchUrl(url, mode: LaunchMode.externalApplication),
  );
  final connu = await fichierCompte.exists()
      ? (await fichierCompte.readAsString()).trim()
      : null;
  final r = await c.ouvrir(silencieux: silencieux, compteConnu: connu);
  if (r != null && !silencieux) await fichierCompte.writeAsString(r.compte);
  return r;
}
