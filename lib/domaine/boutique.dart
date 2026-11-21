/// Personnalisation de la boutique (nom, logo, couleur, contact, reçu).
library;

import 'dart:convert';

/// Couleurs proposées pour la boutique. Le vert, le rouge et l'ambre en sont
/// EXCLUS : ils sont réservés à l'argent (entre, sort, crédit).
const List<int> paletteBoutique = [
  0xFF1D3557, // bleu nuit (Zéro Perte)
  0xFF1E5AA8, // bleu roi
  0xFF283593, // indigo
  0xFF5B3F9A, // violet
  0xFF7A2E5C, // prune
  0xFF0E6B73, // bleu canard
  0xFF6D4C3D, // brun
  0xFF37474F, // ardoise
];

/// Villes proposées (les plus grandes villes du Togo) ; « Autre » permet de taper la sienne.
const List<String> villesTogo = [
  'Lomé',
  'Kara',
  'Sokodé',
  'Atakpamé',
  'Kpalimé',
  'Dapaong',
  'Tsévié',
  'Aného',
  'Bassar',
  'Notsé',
  'Mango',
  'Tchamba',
  'Badou',
  'Vogan',
  'Kandé',
  'Sotouboua',
  'Blitta',
  'Bafilo',
  'Niamtougou',
  'Tabligbo',
];

/// Message par défaut en bas des reçus (modifiable par le patron).
const String messageRecuParDefaut = 'Merci, à bientôt !';

/// Configuration de la boutique.
class ConfigBoutique {
  const ConfigBoutique({
    this.nom = '',
    this.types = const [],
    this.telephone = '',
    this.ville = '',
    this.quartier = '',
    this.repere = '',
    this.couleur = 0xFF1D3557,
    this.messageRecu = messageRecuParDefaut,
    this.logo,
  });

  final String nom;

  /// Types de boutique choisis (identifiants des catalogues).
  final List<String> types;
  final String telephone;
  final String ville;
  final String quartier;
  final String repere;

  /// Couleur de la boutique (ARGB), prise dans [paletteBoutique].
  final int couleur;
  final String messageRecu;

  /// Photo ou logo (JPEG réduit), ou nul : on affiche alors les initiales.
  final List<int>? logo;

  /// Initiales pour le logo par défaut : « Boutique Mama Ama » → « MA ».
  String get initiales {
    const motsIgnores = {
      'boutique',
      'chez',
      'la',
      'le',
      'les',
      'de',
      'du',
      'des',
      'et',
      'l',
      'd',
      'ets',
    };
    final mots = nom
        .split(RegExp(r"[\s'’]+"))
        .where((m) => m.isNotEmpty && !motsIgnores.contains(m.toLowerCase()))
        .toList();
    if (mots.isEmpty) return 'ZP';
    final lettres = mots.take(2).map((m) => m.characters1.toUpperCase()).join();
    return lettres;
  }

  /// Adresse sur une ligne : « Bè-Kpota, Lomé (en face de la pharmacie) ».
  String get adresse {
    final base = [quartier, ville].where((x) => x.trim().isNotEmpty).join(', ');
    return repere.trim().isEmpty ? base : '$base ($repere)';
  }

  ConfigBoutique copie({
    String? nom,
    List<String>? types,
    String? telephone,
    String? ville,
    String? quartier,
    String? repere,
    int? couleur,
    String? messageRecu,
    List<int>? logo,
    bool effacerLogo = false,
  }) => ConfigBoutique(
    nom: nom ?? this.nom,
    types: types ?? this.types,
    telephone: telephone ?? this.telephone,
    ville: ville ?? this.ville,
    quartier: quartier ?? this.quartier,
    repere: repere ?? this.repere,
    couleur: couleur ?? this.couleur,
    messageRecu: messageRecu ?? this.messageRecu,
    logo: effacerLogo ? null : (logo ?? this.logo),
  );

  Map<String, Object?> versDonnees() => {
    'nom': nom,
    'types': types,
    'telephone': telephone,
    'ville': ville,
    'quartier': quartier,
    'repere': repere,
    'couleur': couleur,
    'message_recu': messageRecu,
    'logo': logo == null ? null : base64.encode(logo!),
  };

  factory ConfigBoutique.depuisDonnees(Map<String, Object?> d) =>
      ConfigBoutique(
        nom: (d['nom'] as String?) ?? '',
        types: ((d['types'] as List?) ?? const []).cast<String>(),
        telephone: (d['telephone'] as String?) ?? '',
        ville: (d['ville'] as String?) ?? '',
        quartier: (d['quartier'] as String?) ?? '',
        repere: (d['repere'] as String?) ?? '',
        couleur: (d['couleur'] as int?) ?? 0xFF1D3557,
        messageRecu: (d['message_recu'] as String?) ?? messageRecuParDefaut,
        logo: d['logo'] == null ? null : base64.decode(d['logo'] as String),
      );
}

extension on String {
  /// Première lettre (gère les lettres accentuées composées simplement).
  String get characters1 => isEmpty ? '' : substring(0, 1);
}

/// Numéro de téléphone togolais : 8 chiffres, éventuellement précédés de +228.
/// Renvoie le format « +228 90 12 34 56 », ou nul si le numéro est invalide.
String? normaliserTelephone(String saisie) {
  var chiffres = saisie.replaceAll(RegExp(r'[^0-9]'), '');
  if (chiffres.startsWith('00228')) chiffres = chiffres.substring(5);
  if (chiffres.startsWith('228') && chiffres.length == 11) {
    chiffres = chiffres.substring(3);
  }
  if (chiffres.length != 8) return null;
  final paires = [for (var i = 0; i < 8; i += 2) chiffres.substring(i, i + 2)];
  return '+228 ${paires.join(' ')}';
}
