import 'package:flutter/foundation.dart';

import '../donnees/journal_local.dart';
import '../donnees/reglages.dart';
import '../services/aide.dart';
import '../services/telephone.dart';
import '../services/voix.dart';

/// Services extérieurs (téléphone, voix, liens), remplaçables dans les tests.
class ServicesZp {
  const ServicesZp({
    required this.telephone,
    required this.voix,
    required this.ouvrirLien,
  });

  final ServiceTelephone telephone;
  final Voix voix;
  final OuvreurDeLien ouvrirLien;
}

/// Étapes de l'assistant d'installation, dans l'ordre.
/// Les étapes d'activation (B2) et de personnalisation (B3) s'insèrent ici.
enum EtapeAssistant { bienvenue, verification, termine }

const _cleEtape = 'assistant.etape';

/// État global de l'application.
class EtatApplication extends ChangeNotifier {
  EtatApplication._({
    required this.reglages,
    required this.services,
    required this.journal,
    required EtapeAssistant etape,
  }) : _etape = etape; // ignore: prefer_initializing_formals

  /// Charge l'état (reprend l'assistant là où il s'était arrêté).
  static Future<EtatApplication> charger({
    required ReglagesLocaux reglages,
    required ServicesZp services,
    JournalLocal? journal,
  }) async {
    final nom = await reglages.lireParametre(_cleEtape);
    final etape =
        EtapeAssistant.values.where((e) => e.name == nom).firstOrNull ??
        EtapeAssistant.bienvenue;
    return EtatApplication._(
      reglages: reglages,
      services: services,
      journal: journal,
      etape: etape,
    );
  }

  final ReglagesLocaux reglages;
  final ServicesZp services;

  /// Base locale (nulle dans certains tests d'écran).
  final JournalLocal? journal;

  EtapeAssistant _etape;
  EtapeAssistant get etape => _etape;

  bool get installationTerminee => _etape == EtapeAssistant.termine;

  /// Passe à une étape et la mémorise (reprise après interruption).
  Future<void> allerA(EtapeAssistant etape) async {
    _etape = etape;
    await reglages.ecrireParametre(_cleEtape, etape.name);
    notifyListeners();
  }

  /// Étape suivante de l'assistant.
  Future<void> suivante() => allerA(
    EtapeAssistant.values[(_etape.index + 1).clamp(
      0,
      EtapeAssistant.values.length - 1,
    )],
  );

  /// Étape précédente de l'assistant.
  Future<void> precedente() => allerA(
    EtapeAssistant.values[(_etape.index - 1).clamp(
      0,
      EtapeAssistant.values.length - 1,
    )],
  );
}
