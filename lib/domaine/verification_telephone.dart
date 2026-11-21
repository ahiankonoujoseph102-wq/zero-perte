/// Contrôles du téléphone à l'installation (étape 1 de l'assistant).
library;

import '../services/telephone.dart';

enum NiveauControle { ok, attention, bloquant }

class Controle {
  const Controle(this.cle, this.titre, this.detail, this.niveau);
  final String cle;
  final String titre;
  final String detail;
  final NiveauControle niveau;
}

/// Place libre en dessous de laquelle l'installation est refusée / déconseillée (Mo).
const int espaceMinimumMo = 100;
const int espaceConseilleMo = 300;

List<Controle> evaluerTelephone(
  InfosTelephone t, {
  required bool voixFrancaise,
}) => [
  Controle(
    'android',
    'Version d\'Android',
    t.androidSdk >= 26
        ? 'Android ${t.androidVersion} : compatible.'
        : 'Android ${t.androidVersion} : trop ancien (il faut Android 8 ou plus).',
    t.androidSdk >= 26 ? NiveauControle.ok : NiveauControle.bloquant,
  ),
  Controle(
    'google',
    'Services Google',
    t.servicesGoogle
        ? 'Présents : la boutique pourra être sauvegardée et suivie à distance.'
        : 'Absents sur ce téléphone : Zéro Perte ne peut pas sauvegarder la boutique ni la suivre à distance. Ce téléphone n\'est pas compatible.',
    t.servicesGoogle ? NiveauControle.ok : NiveauControle.bloquant,
  ),
  Controle(
    'espace',
    'Place libre',
    t.espaceLibreMo < espaceMinimumMo
        ? 'Seulement ${t.espaceLibreMo} Mo libres : effacez des vidéos ou des photos (il faut au moins $espaceMinimumMo Mo).'
        : (t.espaceLibreMo < espaceConseilleMo
              ? '${t.espaceLibreMo} Mo libres : ça suffit, mais libérez de la place bientôt.'
              : '${t.espaceLibreMo} Mo libres : suffisant.'),
    t.espaceLibreMo < espaceMinimumMo
        ? NiveauControle.bloquant
        : (t.espaceLibreMo < espaceConseilleMo
              ? NiveauControle.attention
              : NiveauControle.ok),
  ),
  Controle(
    'voix',
    'Voix en français',
    voixFrancaise ? 'Installée : l\'application peut parler.' : 'Pas installée : l\'application marchera, mais sans parler. (Réglages → Langues → Synthèse vocale)',
    voixFrancaise ? NiveauControle.ok : NiveauControle.attention,
  ),
];

bool peutContinuer(List<Controle> controles) =>
    controles.every((c) => c.niveau != NiveauControle.bloquant);
