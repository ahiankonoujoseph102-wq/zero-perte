import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as chemins;
import 'package:sqflite/sqflite.dart';

import 'app/etat_application.dart';
import 'domaine/licence.dart';
import 'donnees/journal_local.dart';
import 'ecrans/accueil_vendeur.dart';
import 'ecrans/assistant/assistant_installation.dart';
import 'services/aide.dart';
import 'services/photos.dart';
import 'services/raccourci.dart';
import 'services/telephone.dart';
import 'services/voix.dart';
import 'theme/couleurs.dart';
import 'theme/theme_zp.dart';

/// Canal de fabrication, fixé par GitHub Actions avec
/// `--dart-define=ZP_CANAL=officiel` quand l'APK est signé avec la clé officielle.
/// Toute autre valeur (ou aucune) signifie : version d'essai, à ne pas distribuer.
const String canalFabrication = String.fromEnvironment(
  'ZP_CANAL',
  defaultValue: 'essai',
);

bool get estVersionOfficielle => canalFabrication == 'officiel';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Demarrage(etat: chargerEtatDuTelephone()));
}

/// Ouvre (ou crée) la base locale du téléphone.
Future<JournalLocal> ouvrirJournalDuTelephone() async {
  final dossier = await getDatabasesPath();
  return JournalLocal.ouvrir(
    fabrique: databaseFactory,
    chemin: chemins.join(dossier, 'zero_perte.db'),
  );
}

/// Charge l'état complet de l'application sur le téléphone.
Future<EtatApplication> chargerEtatDuTelephone() async {
  final journal = await ouvrirJournalDuTelephone();
  return EtatApplication.charger(
    journal: journal,
    services: ServicesZp(
      telephone: ServiceTelephoneAndroid(),
      voix: VoixAndroid(),
      ouvrirLien: ouvrirLienExterne,
      lirePressePapiers: () async =>
          (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      clePublique: () async => lireClePublique(
        await rootBundle.loadString('assets/licence/cle_publique.txt'),
      ),
      lireCatalogue: () =>
          rootBundle.loadString('assets/catalogues/catalogues.json'),
      prendrePhoto: prendrePhotoAndroid,
      creerRaccourci: creerRaccourciAndroid,
    ),
  );
}

/// Écran de démarrage : attend l'ouverture de la base, puis lance l'application.
class Demarrage extends StatelessWidget {
  const Demarrage({super.key, required this.etat});

  final Future<EtatApplication> etat;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EtatApplication>(
      future: etat,
      builder: (context, r) {
        if (r.hasData) return ZeroPerteApp(etat: r.data!);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeZeroPerte(),
          home: Scaffold(
            body: Center(
              child: r.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Zéro Perte ne peut pas démarrer.\n${r.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: CouleursZp.argentSort,
                        ),
                      ),
                    )
                  : const LogoZp(taille: 120),
            ),
          ),
        );
      },
    );
  }
}

class ZeroPerteApp extends StatelessWidget {
  const ZeroPerteApp({
    super.key,
    required this.etat,
    this.infosPaquet,
    this.maintenant,
  });

  final EtatApplication etat;

  /// Permettent aux tests de fournir la version et la date.
  final Future<PackageInfo>? infosPaquet;
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zéro Perte',
      debugShowCheckedModeBanner: false,
      theme: themeZeroPerte(couleurMarque: Color(etat.config.couleur)),
      builder: (context, enfant) {
        final contenu = enfant ?? const SizedBox.shrink();
        if (estVersionOfficielle) return contenu;
        // Le bandeau occupe déjà la zone de la barre d'état : on ne la compte pas deux fois.
        return Column(
          children: [
            const BandeauEssai(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: contenu,
              ),
            ),
          ],
        );
      },
      home: ListenableBuilder(
        listenable: etat,
        builder: (context, _) => etat.installationTerminee
            ? AccueilVendeur(
                config: etat.config,
                nomVendeur: etat.patron?.nom ?? 'Vendeur',
                maintenant: maintenant,
                pied: PiedDePage(
                  infosPaquet: infosPaquet ?? PackageInfo.fromPlatform(),
                  baseOuverte: true,
                ),
              )
            : AssistantInstallation(etat: etat),
      ),
    );
  }
}

/// Ligne du bas : version de l'application et état de la base locale.
class PiedDePage extends StatelessWidget {
  const PiedDePage({
    super.key,
    required this.infosPaquet,
    this.baseOuverte = false,
  });

  final Future<PackageInfo> infosPaquet;

  /// Vrai si la base locale du téléphone est ouverte (point vert).
  final bool baseOuverte;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, color: CouleursZp.texteDoux);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (baseOuverte)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.circle,
              size: 10,
              key: Key('base-prete'),
              color: CouleursZp.argentEntre,
              semanticLabel: 'Base de données prête',
            ),
          ),
        FutureBuilder<PackageInfo>(
          future: infosPaquet,
          builder: (context, instantane) {
            final infos = instantane.data;
            final texte = infos == null
                ? 'Zéro Perte'
                : 'Zéro Perte · version ${infos.version} (${infos.buildNumber})';
            return Flexible(
              child: Text(
                texte,
                key: const Key('texte-version'),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Bandeau rouge affiché sur les versions d'essai (non signées avec la clé officielle).
class BandeauEssai extends StatelessWidget {
  const BandeauEssai({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursZp.argentSort,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: const Text(
            'ESSAI — NE PAS DONNER AUX CLIENTS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: policeZp,
            ),
          ),
        ),
      ),
    );
  }
}
