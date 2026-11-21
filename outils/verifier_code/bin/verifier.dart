// Vérifie un code d'activation exactement comme l'application : même fichier
// lib/domaine/licence.dart, même clé publique (assets/licence/cle_publique.txt).
// Utilisé par l'action « 4 - Générer un code d'activation ».
// N'affiche ni le code ni le nom de la boutique.
//
//   dart run bin/verifier.dart <fichier du message ou du code> <clé publique>
import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../../../lib/domaine/licence.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage : verifier.dart <code> <cle_publique.txt>');
    exit(2);
  }
  final texte = File(args[0]).readAsStringSync();
  final cle = lireClePublique(File(args[1]).readAsStringSync());
  try {
    final code = await verifierCode(texte, cle);
    final licence = calculerLicence([code]);
    stdout.writeln(
      'Code accepté par l\'application : ${code.type.name}, '
      '${code.telephones} téléphone(s)'
      '${licence == null ? '' : ', licence de ${licence.telephones} téléphone(s)'}.',
    );
  } on ErreurCode catch (e) {
    stderr.writeln('Code REFUSÉ par l\'application : ${e.probleme.message}');
    exit(1);
  }
}
