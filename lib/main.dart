import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as chemins;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'app/etat_application.dart';
import 'domaine/licence.dart';
import 'donnees/journal_local.dart';
import 'ecrans/patron/resume_soir.dart';
import 'ecrans/accueil_vendeur.dart';
import 'ecrans/assistant/assistant_installation.dart';
import 'ecrans/code_patron.dart';
import 'ecrans/connexion.dart';
import 'ecrans/vendeur_qr.dart' show PageAppareilRetire;
import 'services/mise_a_jour.dart';
import 'services/aide.dart';
import 'services/google.dart';
import 'services/lecteur_qr.dart';
import 'services/google_pc.dart' show connexionPcConfiguree;
import 'synchro/invitation.dart' show ClientRelaisInvitations;
import 'synchro/relais.dart';
import 'services/notifications.dart';
import 'services/partage.dart';
import 'services/photos.dart';
import 'services/raccourci.dart';
import 'services/telephone.dart';
import 'services/voix.dart';
import 'services/windows.dart';
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

/// Base de données : celle d'Android sur téléphone ; sur PC Windows, SQLite
/// fourni avec l'application, dans le dossier de données de l'utilisateur.
DatabaseFactory get fabriqueBase {
  if (surWindows) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return databaseFactory;
}

Future<String> dossierBase() async => surWindows
    ? (await getApplicationSupportDirectory()).path
    : await getDatabasesPath();

/// Ouvre (ou crée) la base locale du téléphone.
Future<JournalLocal> ouvrirJournalDuTelephone() async {
  return JournalLocal.ouvrir(
    fabrique: fabriqueBase,
    chemin: chemins.join(await dossierBase(), 'zero_perte.db'),
  );
}

/// Charge l'état complet de l'application sur le téléphone.
Future<EtatApplication> chargerEtatDuTelephone() async {
  final journal = await ouvrirJournalDuTelephone();
  final etat = await EtatApplication.charger(
    journal: journal,
    services: ServicesZp(
      telephone: surWindows
          ? ServiceTelephoneWindows()
          : ServiceTelephoneAndroid(),
      voix: VoixAndroid(),
      ouvrirLien: ouvrirLienExterne,
      lirePressePapiers: () async =>
          (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      clePublique: () async => lireClePublique(
        await rootBundle.loadString('assets/licence/cle_publique.txt'),
      ),
      lireCatalogue: () =>
          rootBundle.loadString('assets/catalogues/catalogues.json'),
      prendrePhoto: surWindows ? prendrePhotoWindows : prendrePhotoAndroid,
      creerRaccourci: surWindows
          ? (_, _) async => false
          : creerRaccourciAndroid,
      partagerImage: surWindows ? partagerImageWindows : partagerImageAndroid,
      partagerFichier: surWindows
          ? partagerFichierWindows
          : partagerFichierAndroid,
      // Windows : connexion Google par le navigateur, pas encore branchée
      // (identifiant « Application de bureau » à créer : etapes-proprietaire A6).
      connecterDrive: surWindows
          ? (connexionPcConfiguree ? connecterDriveWindows : null)
          : connecterDriveAndroid,
      choisirFichier: choisirFichierSauvegarde,
      activerNotifications: surWindows ? null : activerNotificationsAndroid,
      codeGoogleServeur: surWindows ? null : codeGoogleServeurAndroid,
      lecteurQr: surWindows ? null : LecteurQrAndroid(),
    ),
  );
  // Téléphone tout neuf (peut-être celui d'un vendeur) : le module du lecteur
  // de QR code est demandé tout de suite, sans attendre ni rien afficher.
  final lecteur = etat.services.lecteurQr;
  if (lecteur != null && etat.etape == EtapeAssistant.bienvenue) {
    unawaited(() async {
      try {
        if (!await lecteur.estPret()) await lecteur.preparer();
      } catch (_) {}
    }());
  }
  // Relève des ventes des autres appareils (si le Drive est connecté).
  etat.demarrerSynchroAuto();
  // Alertes graves par le relais (si cette version en a l'adresse).
  if (adresseRelais.isNotEmpty) {
    etat.transportAlertes = ClientRelais(adresseRelais);
    etat.relaisInvitations = ClientRelaisInvitations(adresseRelais);
    etat.demarrerAlertesAuto();
  }
  return etat;
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
        if (r.hasData) {
          final etat = r.data!;
          // 0.36 : plus de démonstration dans l'application (décision du
          // propriétaire : une vidéo de l'écran la remplace). Le code reste,
          // sans aucun bouton pour l'ouvrir.
          return ZeroPerteApp(etat: etat);
        }
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
        // PC : Échap = revenir en arrière.
        final page = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              final ctx = FocusManager.instance.primaryFocus?.context;
              if (ctx != null) Navigator.maybeOf(ctx)?.maybePop();
            },
          },
          child: enfant ?? const SizedBox.shrink(),
        );
        // Alertes graves (écart de caisse, grosse annulation…) : bandeau rouge
        // en haut, sur l'appareil du patron.
        final contenu = ListenableBuilder(
          listenable: etat,
          builder: (context, _) {
            final alertes = etat.alertes.isNotEmpty && etat.estPatron;
            final avertir =
                etat.avertissementsInstallation.isNotEmpty &&
                etat.utilisateurActuel != null;
            if (!alertes && !avertir) return page;
            return Column(
              children: [
                if (alertes) BandeauAlertes(etat: etat),
                if (avertir) BandeauAvertissements(etat: etat),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: page,
                  ),
                ),
              ],
            );
          },
        );
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
        builder: (context, _) => etat.appareilRetire
            ? const PageAppareilRetire()
            : !etat.installationTerminee
            ? Builder(builder: (context) => AssistantInstallation(etat: etat))
            : etat.patronDoitChangerCode
            ? PageNouveauCodePatron(etat: etat)
            : (etat.utilisateurActuel == null && etat.utilisateurs.isNotEmpty)
            ? PageConnexion(etat: etat)
            : GuetteurResumeSoir(
                etat: etat,
                child: AccueilVendeur(
                  etat: etat,
                  maintenant: maintenant,
                  pied: PiedDePage(
                    infosPaquet: infosPaquet ?? PackageInfo.fromPlatform(),
                    baseOuverte: true,
                  ),
                ),
              ),
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
            final version = Text(
              texte,
              key: const Key('texte-version'),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
            if (infos == null) return Flexible(child: version);
            // Une version plus récente est publiée : on le dit, avec le lien.
            // Rien ne s'installe tout seul ; sans Internet, rien ne change.
            return Flexible(
              child: FutureBuilder<InfosMiseAJour?>(
                future: VerificateurMiseAJour.instance.verifier(
                  int.tryParse(infos.buildNumber) ?? 0,
                ),
                builder: (context, s) {
                  final m = s.data;
                  if (m == null) return version;
                  return InkWell(
                    key: const Key('bouton-mise-a-jour'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        launchUrl(m.lien, mode: LaunchMode.externalApplication),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.system_update_rounded,
                          size: 18,
                          color: CouleursZp.marque,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Nouvelle version disponible (${m.version}) : '
                            'la mettre à jour',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CouleursZp.marque,
                              decoration: TextDecoration.underline,
                              decorationColor: CouleursZp.marque,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

/// Bandeau rouge : la dernière alerte grave et le nombre d'alertes.
class BandeauAlertes extends StatelessWidget {
  const BandeauAlertes({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    final a = etat.alertes;
    return Material(
      color: CouleursZp.argentSort,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.length > 1
                      ? '${a.last.message} (+${a.length - 1})'
                      : a.last.message,
                  key: const Key('bandeau-alerte'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: policeZp,
                  ),
                ),
              ),
              TextButton(
                key: const Key('bouton-alerte-vue'),
                onPressed: etat.effacerAlertes,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Vu', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau orange : avertissements non bloquants de l'installation (peu de
/// place, pas de voix française), montrés une seule fois, jusqu'à « Compris ».
class BandeauAvertissements extends StatelessWidget {
  const BandeauAvertissements({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursZp.credit,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            children: [
              const Icon(
                Icons.info_rounded,
                color: CouleursZp.texteSurCredit,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  etat.avertissementsInstallation.join('\n'),
                  key: const Key('bandeau-avertissements'),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CouleursZp.texteSurCredit,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: policeZp,
                  ),
                ),
              ),
              TextButton(
                key: const Key('bouton-avertissements-compris'),
                onPressed: etat.avertissementsVus,
                style: TextButton.styleFrom(
                  foregroundColor: CouleursZp.texteSurCredit,
                ),
                child: const Text('Compris', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
