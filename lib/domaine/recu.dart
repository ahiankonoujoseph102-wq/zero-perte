/// Numérotation des reçus : un préfixe par téléphone, sans trou.
///
/// Chaque téléphone de la boutique a sa lettre (A, B, P pour le patron…) et sa
/// propre suite de numéros. Deux téléphones hors ligne ne peuvent donc jamais
/// donner le même numéro : A-000042 et B-000042 sont deux reçus différents.
library;

final RegExp _prefixeValide = RegExp(r'^[A-Z]{1,2}$');

/// Vrai si le préfixe est valable : 1 ou 2 lettres majuscules sans accent.
bool prefixeRecuValide(String prefixe) => _prefixeValide.hasMatch(prefixe);

/// Écrit un numéro de reçu : `formatNumeroRecu('A', 42)` → « A-000042 ».
String formatNumeroRecu(String prefixe, int numero) {
  if (!prefixeRecuValide(prefixe)) {
    throw ArgumentError('Préfixe de reçu invalide : « $prefixe ».');
  }
  if (numero < 1) throw ArgumentError('Le premier reçu porte le numéro 1.');
  return '$prefixe-${numero.toString().padLeft(6, '0')}';
}

/// Vérifie qu'une liste de numéros de reçus d'un même téléphone n'a pas de trou.
/// Renvoie les numéros manquants (liste vide si tout est complet).
List<int> numerosManquants(Iterable<int> numeros) {
  final tries = numeros.toSet().toList()..sort();
  if (tries.isEmpty) return const [];
  final manquants = <int>[];
  for (var n = 1; n < tries.last; n++) {
    if (!tries.contains(n)) manquants.add(n);
  }
  return manquants;
}
