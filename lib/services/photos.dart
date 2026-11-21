import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../app/etat_application.dart';

/// Prend une photo (ou la choisit dans la galerie), réduite à 480 × 480 et
/// compressée : environ 20 à 40 Ko, pour ne pas remplir le téléphone ni le Drive.
Future<Uint8List?> prendrePhotoAndroid(SourcePhoto source) async {
  final photo = await ImagePicker().pickImage(
    source: source == SourcePhoto.appareil
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 70,
  );
  return photo?.readAsBytes();
}
