import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as chemins;
import 'package:sqflite/sqflite.dart';

import 'app/demo.dart';
import 'app/etat_application.dart';
import 'domaine/licence.dart';
import 'donnees/journal_local.dart';
import 'ecrans/accueil_vendeur.dart';
import 'ecrans/assistant/assistant_installation.dart';
import 'ecrans/caisse/fermeture.dart';
import 'ecrans/caisse/saisie_montant.dart';
import 'ecrans/communs.dart';
import 'ecrans/connexion.dart';
import 'ecrans/depense/page_depense.dart';
import 'ecrans/patron/espace_patron.dart';
import 'ecrans/vente/page_vendre.dart';
import 'services/aide.dart';
import 'services/partage.dart';
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

/// Démonstration : base à part, effacée à chaque ouverture.
Future<EtatApplication> creerDemoTelephone(ServicesZp services) async {
  final dossier = await getDatabasesPath();
  return preparerDemo(
    fabrique: databaseFactory,
    chemin: chemins.join(dossier, 'zero_perte_demo.db'),
    services: services,
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
      partagerImage: partagerImageAndroid,
      partagerFichier: partagerFichierAndroid,
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
        if (r.hasData) {
          final etat = r.data!;
          return ZeroPerteApp(
            etat: etat,
            creerDemo: () => creerDemoTelephone(etat.services),
          );
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
    this.creerDemo,
    this.quitterDemo,
  });

  final EtatApplication etat;

  /// Crée une boutique de démonstration neuve (bouton de l'étape d'activation).
  final Future<EtatApplication> Function()? creerDemo;

  /// Non nul quand CETTE application est la démonstration : ferme la démo.
  final VoidCallback? quitterDemo;

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
        final quitter = quitterDemo;
        if (quitter != null) {
          return Column(
            children: [
              BandeauDemo(onQuitter: quitter),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: contenu,
                ),
              ),
            ],
          );
        }
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
        builder: (context, _) => !etat.installationTerminee
            ? Builder(
                builder: (context) => AssistantInstallation(
                  etat: etat,
                  onDemonstration: creerDemo == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PageDemonstration(
                              creer: creerDemo!,
                              infosPaquet: infosPaquet,
                              maintenant: maintenant,
                            ),
                          ),
                        ),
                ),
              )
            : (etat.utilisateurActuel == null && etat.utilisateurs.isNotEmpty)
            ? PageConnexion(etat: etat)
            : AccueilVendeur(
                onChangerUtilisateur: etat.utilisateurs.isEmpty
                    ? null
                    : etat.deconnecter,
                onEspacePatron: etat.patron == null
                    ? null
                    : () async {
                        if (await demanderPin(
                              context,
                              etat,
                              etat.patron!,
                              titre: 'Espace patron',
                            ) &&
                            context.mounted) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EspacePatron(etat: etat),
                            ),
                          );
                        }
                      },
                actions: {
                  'depense': () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PageChoixDepense(
                        etat: etat,
                        ouvrirDepenseArgent: (_) => pageDepenseArgent(etat),
                      ),
                    ),
                  ),
                  'fermer': () async {
                    if (!await etat.caisseOuverte()) {
                      if (context.mounted) {
                        annoncer(context, 'La caisse n\'est pas ouverte.');
                      }
                      return;
                    }
                    final modes = await etat.modesAFermer();
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PageFermerCaisse(etat: etat, modes: modes),
                      ),
                    );
                  },
                  'vendre': () async {
                    // Première vente depuis la fermeture : on ouvre d'abord la caisse.
                    if (!await etat.caisseOuverte()) {
                      if (!context.mounted) return;
                      final ouverte = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => pageOuvrirCaisse(etat),
                        ),
                      );
                      if (ouverte != true) return;
                    }
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PageVendre(etat: etat)),
                    );
                  },
                },
                config: etat.config,
                nomVendeur:
                    etat.utilisateurActuel?.nom ??
                    etat.patron?.nom ??
                    'Vendeur',
                maintenant: maintenant,
                pied: PiedDePage(
                  infosPaquet: infosPaquet ?? PackageInfo.fromPlatform(),
                  baseOuverte: true,
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

/// Ouvre la démonstration (une boutique fictive neuve) par-dessus l'assistant.
class PageDemonstration extends StatefulWidget {
  const PageDemonstration({
    super.key,
    required this.creer,
    this.infosPaquet,
    this.maintenant,
  });

  final Future<EtatApplication> Function() creer;
  final Future<PackageInfo>? infosPaquet;
  final DateTime? maintenant;

  @override
  State<PageDemonstration> createState() => _PageDemonstrationState();
}

class _PageDemonstrationState extends State<PageDemonstration> {
  late final Future<EtatApplication> _demo = widget.creer();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EtatApplication>(
      future: _demo,
      builder: (context, r) {
        if (r.hasData) {
          return ZeroPerteApp(
            etat: r.data!,
            infosPaquet: widget.infosPaquet,
            maintenant: widget.maintenant,
            quitterDemo: () => Navigator.of(context).pop(),
          );
        }
        return Scaffold(
          body: Center(
            child: r.hasError
                ? Text(
                    'La démonstration ne peut pas s\'ouvrir.\n${r.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

/// Bandeau permanent de la démonstration, avec le code du patron et « Quitter ».
class BandeauDemo extends StatelessWidget {
  const BandeauDemo({super.key, required this.onQuitter});

  final VoidCallback onQuitter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursZp.credit,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'DÉMONSTRATION — rien n\'est gardé\nCode du patron : $codePatronDemo',
                  key: Key('bandeau-demo'),
                  style: TextStyle(
                    color: CouleursZp.texteSurCredit,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: policeZp,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('bouton-quitter-demo'),
                onPressed: onQuitter,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Quitter'),
                style: FilledButton.styleFrom(
                  backgroundColor: CouleursZp.texteSurCredit,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
