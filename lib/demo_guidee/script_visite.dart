/// Déroulé de la démonstration guidée : chapitres et étapes.
///
/// Chaque étape fait dire une phrase à Afi (texte de [phrasesVisite]), montre
/// un bouton (entouré et désigné par une flèche) et peut le toucher pour
/// avancer dans la boutique de démonstration.
library;

import 'phrases.dart';

/// Heure à partir de laquelle on dit « Bonsoir » au lieu de « Bonjour »
/// (réglage facile à changer).
const int heureBonsoir = 15;

/// Expressions du visage d'Afi.
enum Expression { neutre, sourire, contente, auRevoir }

class EtapeVisite {
  const EtapeVisite(
    this.phrase, {
    this.cibles = const [],
    this.toucher = false,
    this.expression = Expression.sourire,
    this.revenirAccueil = false,
  });

  /// Numéro de la phrase (et du fichier audio).
  final String phrase;

  /// Clés possibles du bouton à montrer (la première trouvée à l'écran est
  /// prise : téléphone, tablette et PC n'ont pas toujours la même). Une clé
  /// qui finit par `*` désigne le premier élément dont la clé commence ainsi.
  final List<String> cibles;

  /// Après la phrase, toucher le bouton montré (pour avancer).
  final bool toucher;

  final Expression expression;

  /// Avant la phrase, revenir à l'accueil (toutes les pages fermées).
  final bool revenirAccueil;

  String get texte => phrasesVisite[phrase] ?? '';
}

class ChapitreVisite {
  const ChapitreVisite(this.titre, this.etapes, {this.suite = false});
  final String titre;
  final List<EtapeVisite> etapes;

  /// Vrai si ce chapitre continue l'écran du chapitre précédent (« La
  /// monnaie » suit « Vendre ») : « Rejouer » et « Chapitre suivant »
  /// repartent alors du début du groupe.
  final bool suite;
}

/// Premier chapitre du groupe de [i] (un groupe = un chapitre et ses suites).
int debutDuGroupe(List<ChapitreVisite> c, int i) {
  var j = i;
  while (j > 0 && c[j].suite) {
    j--;
  }
  return j;
}

/// Premier chapitre du groupe suivant celui de [i] (ou c.length à la fin).
int groupeSuivant(List<ChapitreVisite> c, int i) {
  var j = i + 1;
  while (j < c.length && c[j].suite) {
    j++;
  }
  return j;
}

/// Phrase de salutation selon l'heure.
String phraseSalutation(DateTime maintenant) =>
    maintenant.hour < heureBonsoir ? '001' : '002';

/// Les chapitres de la visite. [salutation] : « 001 » (Bonjour) ou « 002 »
/// (Bonsoir).
List<ChapitreVisite> chapitresVisite({String salutation = '001'}) => [
  ChapitreVisite('Bienvenue', [
    EtapeVisite(salutation, expression: Expression.contente),
    const EtapeVisite('003', expression: Expression.contente),
    const EtapeVisite('004'),
    const EtapeVisite('005', cibles: ['bouton-vendre'], revenirAccueil: true),
    const EtapeVisite('006', cibles: ['bouton-ma-caisse']),
    const EtapeVisite('007', cibles: ['bouton-credit']),
    const EtapeVisite('008', cibles: ['bouton-espace-patron']),
  ]),
  const ChapitreVisite('Vendre', [
    EtapeVisite(
      '009',
      cibles: ['bouton-vendre'],
      toucher: true,
      revenirAccueil: true,
    ),
    EtapeVisite('010', cibles: ['vendre-alimentation.riz'], toucher: true),
    EtapeVisite('011', cibles: ['choix-base'], toucher: true),
    EtapeVisite('012', cibles: ['plus-0'], toucher: true),
    EtapeVisite('013', cibles: ['total-panier']),
    EtapeVisite('014', cibles: ['bouton-encaisser'], toucher: true),
  ]),
  const ChapitreVisite('La monnaie', [
    EtapeVisite('015', cibles: ['rapide-5000'], toucher: true),
    EtapeVisite('016', cibles: ['a-rendre', 'rendre-final']),
    EtapeVisite(
      '017',
      cibles: ['bouton-valider-vente'],
      toucher: true,
      expression: Expression.contente,
    ),
  ], suite: true),
  const ChapitreVisite('Le reçu', [
    EtapeVisite('018', cibles: ['numero-recu', 'rendre-final']),
    EtapeVisite('019', cibles: ['bouton-envoyer-recu']),
    EtapeVisite('020', cibles: ['bouton-nouvelle-vente'], toucher: true),
  ], suite: true),
  const ChapitreVisite('Client et crédit', [
    EtapeVisite(
      '021',
      cibles: ['bouton-credit'],
      toucher: true,
      revenirAccueil: true,
    ),
    EtapeVisite('022', cibles: ['client-Kofi'], toucher: true),
    EtapeVisite('023', cibles: ['solde-client']),
    EtapeVisite('024', cibles: ['bouton-rembourse']),
    EtapeVisite('025', cibles: ['bouton-rappeler']),
  ]),
  const ChapitreVisite('Le devis', [
    EtapeVisite(
      '026',
      cibles: ['bouton-vendre'],
      toucher: true,
      revenirAccueil: true,
    ),
    EtapeVisite('027', cibles: ['bouton-devis']),
    EtapeVisite('028', cibles: ['bouton-devis']),
  ]),
  const ChapitreVisite('Le retour', [
    EtapeVisite('029', cibles: ['bouton-ventes-du-jour'], toucher: true),
    EtapeVisite('030', cibles: ['vente-D-*'], toucher: true),
    EtapeVisite('031', cibles: ['bouton-retour']),
    EtapeVisite('032', cibles: ['bouton-annuler-vente', 'bouton-retour']),
  ], suite: true),
  const ChapitreVisite('La dépense', [
    EtapeVisite(
      '033',
      cibles: ['bouton-ma-caisse'],
      toucher: true,
      revenirAccueil: true,
    ),
    EtapeVisite('034', cibles: ['bouton-depense']),
    EtapeVisite('035', cibles: ['bouton-retrait']),
  ]),
  const ChapitreVisite('La fermeture', [
    EtapeVisite('036', cibles: ['bouton-fermer-caisse']),
    EtapeVisite('037', cibles: ['bouton-fermer-caisse']),
    EtapeVisite('038', cibles: ['bouton-fermer-caisse']),
  ], suite: true),
  const ChapitreVisite('Le tableau du patron', [
    EtapeVisite(
      '039',
      cibles: ['accueil-tableau', 'menu-tableau'],
      toucher: true,
      revenirAccueil: true,
    ),
    EtapeVisite('040', cibles: ['periode-semaine', 'periode-jour']),
    EtapeVisite('041', cibles: ['stock-bas-*', 'periode-mois']),
  ]),
  const ChapitreVisite('L\'inventaire', [
    EtapeVisite(
      '042',
      cibles: ['accueil-inventaire', 'menu-inventaire'],
      toucher: true,
      revenirAccueil: true,
    ),
    EtapeVisite('043', cibles: ['bouton-inventaire-complet']),
    EtapeVisite('044', cibles: ['bouton-inventaire-du-jour']),
  ]),
  const ChapitreVisite('La sauvegarde', [
    EtapeVisite('045', cibles: ['bouton-espace-patron'], revenirAccueil: true),
    EtapeVisite('046', cibles: ['bouton-espace-patron']),
    EtapeVisite('047', cibles: ['bouton-espace-patron']),
  ]),
  const ChapitreVisite('Au revoir', [
    EtapeVisite('048', expression: Expression.contente, revenirAccueil: true),
    EtapeVisite('049', cibles: ['visite-quitter']),
    EtapeVisite('050', expression: Expression.auRevoir),
  ]),
];
