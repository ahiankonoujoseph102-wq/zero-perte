import 'package:flutter/foundation.dart';

import '../domaine/licence.dart';
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
    required this.lirePressePapiers,
    required this.clePublique,
  });

  final ServiceTelephone telephone;
  final Voix voix;
  final OuvreurDeLien ouvrirLien;

  /// Lit le texte copié (code d'activation reçu sur WhatsApp).
  final Future<String?> Function() lirePressePapiers;

  /// Clé publique des licences (32 octets), nulle si absente de cette version.
  final Future<List<int>?> Function() clePublique;
}

/// Étapes de l'assistant d'installation, dans l'ordre.
/// Les étapes d'activation (B2) et de personnalisation (B3) s'insèrent ici.
enum EtapeAssistant { bienvenue, verification, activation, termine }

const _cleEtape = 'assistant.etape';

/// État global de l'application.
class EtatApplication extends ChangeNotifier {
  EtatApplication._({
    required this.reglages,
    required this.services,
    required this.journal,
    required EtapeAssistant etape,
    required List<CodeActivation> codes,
    // ignore: prefer_initializing_formals
  }) : _etape = etape,
       // ignore: prefer_initializing_formals
       _codes = codes;

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
      codes: journal == null ? [] : await journal.codesActives(),
    );
  }

  final ReglagesLocaux reglages;
  final ServicesZp services;

  /// Base locale (nulle dans certains tests d'écran).
  final JournalLocal? journal;

  EtapeAssistant _etape;
  EtapeAssistant get etape => _etape;

  bool get installationTerminee => _etape == EtapeAssistant.termine;

  /// Codes d'activation acceptés (licence + extensions).
  final List<CodeActivation> _codes;

  /// Licence de la boutique, nulle tant qu'aucun code n'a été activé.
  Licence? get licence => calculerLicence(_codes);

  /// Vérifie un code collé, le contrôle par rapport à la licence actuelle, puis
  /// l'enregistre dans le journal. Lève [ErreurCode] avec un message simple.
  Future<CodeActivation> activer(String texteColle) async {
    final code = await verifierCode(texteColle, await services.clePublique());
    controlerNouveauCode(code, licence);
    await journal?.enregistrerActivation(code, auteurId: 'patron');
    _codes.add(code);
    notifyListeners();
    return code;
  }

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
