// Dates en français simple (sans bibliothèque externe).

const _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « 21 nov. » : date courte pour l'en-tête.
String dateCourte(DateTime d) {
  final mois = _mois[d.month - 1];
  return '${d.day} ${mois.length <= 4 ? mois : '${mois.substring(0, mois.startsWith('juil') ? 4 : 3)}.'}';
}

/// « samedi 21 novembre » (sans bibliothèque externe).
String dateEnFrancais(DateTime d) =>
    '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
