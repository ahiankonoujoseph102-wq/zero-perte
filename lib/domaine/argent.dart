/// Argent en francs CFA (XOF).
///
/// Règle absolue de Zéro Perte : **tous les montants sont des entiers**.
/// Le franc CFA n'a pas de centimes, il n'y a donc jamais de virgule.
library;

/// Espace fine insécable : sépare les milliers (« 12 500 ») sans risque de
/// voir le nombre coupé en deux lignes.
const String espaceMilliers = ' ';

/// Espace insécable entre le nombre et « F ».
const String espaceAvantF = ' ';

/// Écrit un montant au format de Zéro Perte : « 12 500 F », « 0 F », « -3 000 F ».
String formatFrancs(int montant) {
  final negatif = montant < 0;
  final chiffres = montant.abs().toString();
  final morceaux = <String>[];
  for (var fin = chiffres.length; fin > 0; fin -= 3) {
    final debut = fin - 3 < 0 ? 0 : fin - 3;
    morceaux.insert(0, chiffres.substring(debut, fin));
  }
  return '${negatif ? '-' : ''}${morceaux.join(espaceMilliers)}${espaceAvantF}F';
}

/// Résultat du calcul de la monnaie à rendre.
class MonnaieARendre {
  const MonnaieARendre({required this.total, required this.recu});

  /// Total à payer.
  final int total;

  /// Argent donné par le client.
  final int recu;

  /// Vrai si le client a donné assez d'argent.
  bool get suffisant => recu >= total;

  /// Monnaie à rendre au client (0 si le client n'a pas donné assez).
  int get aRendre => suffisant ? recu - total : 0;

  /// Ce qui manque encore (0 si le client a donné assez).
  int get manque => suffisant ? 0 : total - recu;
}

/// Calcule la monnaie à rendre. Les montants négatifs sont refusés.
MonnaieARendre calculerMonnaie({required int total, required int recu}) {
  if (total < 0 || recu < 0) {
    throw ArgumentError('Les montants ne peuvent pas être négatifs.');
  }
  return MonnaieARendre(total: total, recu: recu);
}

/// Billets et pièces du franc CFA (BCEAO) couramment utilisés, du plus grand au
/// plus petit. Les pièces de 1 et 2 F, très rares, ne sont pas proposées.
const List<int> coupuresFcfa = [
  10000, 5000, 2000, 1000, // billets
  500, 250, 200, 100, 50, 25, 10, 5, // pièces
];

/// Comment rendre un montant avec le moins de billets et de pièces possible.
class Decomposition {
  const Decomposition(this.coupures, this.reste);

  /// Nombre de billets ou pièces par valeur (seulement les valeurs utilisées).
  final Map<int, int> coupures;

  /// Montant impossible à rendre avec les coupures (par ex. 3 F) : à arrondir.
  final int reste;
}

/// Décompose un montant en billets et pièces (méthode « du plus grand au plus petit »,
/// exacte pour les coupures du franc CFA).
Decomposition decomposerEnCoupures(
  int montant, {
  List<int> coupures = coupuresFcfa,
}) {
  if (montant < 0) {
    throw ArgumentError('Le montant ne peut pas être négatif.');
  }
  var reste = montant;
  final resultat = <int, int>{};
  for (final valeur in coupures) {
    final nombre = reste ~/ valeur;
    if (nombre > 0) {
      resultat[valeur] = nombre;
      reste -= nombre * valeur;
    }
  }
  return Decomposition(resultat, reste);
}
