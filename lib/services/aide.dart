import 'package:url_launcher/url_launcher.dart';

/// Numéros WhatsApp de l'assistance Zéro Perte (décision du propriétaire).
const List<String> numerosAssistance = ['+228 72 24 02 31', '+228 79 16 23 90'];

/// Lien WhatsApp « wa.me » vers un numéro, avec un message prérempli.
/// Le message contient seulement l'étape bloquée et le modèle du téléphone :
/// AUCUNE donnée de la boutique (ventes, clients…).
Uri lienWhatsApp(String numero, String message) {
  final chiffres = numero.replaceAll(RegExp(r'[^0-9]'), '');
  return Uri.parse(
    'https://wa.me/$chiffres?text=${Uri.encodeComponent(message)}',
  );
}

/// Message d'aide prérempli.
String messageAide({required String etape, required String diagnostic}) =>
    "Bonjour, j'ai besoin d'aide avec Zéro Perte.\n"
    'Étape : $etape\n'
    'Téléphone : $diagnostic';

/// Ouvre un lien (WhatsApp) ; remplaçable dans les tests.
typedef OuvreurDeLien = Future<bool> Function(Uri lien);

Future<bool> ouvrirLienExterne(Uri lien) =>
    launchUrl(lien, mode: LaunchMode.externalApplication);
