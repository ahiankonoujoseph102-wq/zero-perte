// Textes préparés pour WhatsApp : le patron les relit et envoie lui-même.
// Rien n'est jamais envoyé automatiquement.

import 'argent.dart';

/// Lien WhatsApp avec un texte déjà écrit. [telephone] vide : WhatsApp
/// demande à qui l'envoyer. Numéro togolais à 8 chiffres : +228 ajouté.
Uri lienWhatsApp(String texte, {String telephone = ''}) {
  final chiffres = telephone.replaceAll(RegExp(r'[^0-9]'), '');
  final numero = chiffres.length == 8 ? '228$chiffres' : chiffres;
  return Uri.https('wa.me', numero.length >= 8 ? '/$numero' : '/', {
    'text': texte,
  });
}

/// Chiffres d'une journée, à la fermeture de la caisse.
class ResumeSoir {
  const ResumeSoir({
    required this.fermetureId,
    required this.heure,
    required this.boutique,
    required this.date,
    required this.ventes,
    required this.nombreVentes,
    required this.benefice,
    required this.depenses,
    required this.ecart,
    required this.fermePar,
    required this.stockBas,
  });

  final String fermetureId;
  final int heure;
  final String boutique;

  /// « samedi 21 novembre ».
  final String date;
  final int ventes;
  final int nombreVentes;
  final int benefice;
  final int depenses;

  /// Écart de caisse de la journée : négatif = il manque.
  final int ecart;
  final String fermePar;

  /// Noms des produits en stock bas.
  final List<String> stockBas;

  String get texteEcart => ecart == 0
      ? 'caisse juste'
      : ecart < 0
      ? 'il manque ${formatFrancs(-ecart)}'
      : '${formatFrancs(ecart)} de trop';

  /// Texte à envoyer sur WhatsApp (ou à lire dans la notification).
  String texte() {
    final l = <String>[
      'Résumé du soir – $boutique, $date',
      'Ventes : ${formatFrancs(ventes)} ($nombreVentes '
          '${nombreVentes > 1 ? 'ventes' : 'vente'})',
      'Bénéfice : ${formatFrancs(benefice)}',
      'Dépenses : ${formatFrancs(depenses)}',
      'Caisse fermée par $fermePar : $texteEcart',
      if (stockBas.isEmpty)
        'Stock bas : rien à racheter'
      else
        'Stock bas : ${stockBas.take(8).join(', ')}'
            '${stockBas.length > 8 ? ' (+${stockBas.length - 8})' : ''}',
    ];
    return l.join('\n');
  }

  /// Version courte pour la notification du téléphone.
  String texteCourt() =>
      'Ventes ${formatFrancs(ventes)}, bénéfice ${formatFrancs(benefice)}, '
      '$texteEcart${stockBas.isEmpty ? '' : ', ${stockBas.length} en stock bas'}.';
}

/// Commande au fournisseur : la liste d'achats déjà écrite.
String messageCommande({
  required String boutique,
  required String fournisseur,
  required List<String> produits,
}) {
  final l = <String>[
    fournisseur.isEmpty ? 'Bonjour,' : 'Bonjour $fournisseur,',
    'Commande de $boutique :',
    for (final p in produits) '- $p : ',
    'Merci de me dire le prix et quand vous pouvez livrer.',
  ];
  return l.join('\n');
}

/// Un crédit est « en retard » quand le client doit encore de l'argent et
/// n'a rien remboursé depuis [joursRetardCredit] jours (ou, s'il n'a jamais
/// remboursé, depuis son premier achat à crédit).
const int joursRetardCredit = 14;

/// Type d'« alerte » du relais qui porte le résumé du soir (pas une alerte
/// grave : ni bandeau rouge ni voix chez le patron).
const String typeResumeSoir = 'resume_soir';
