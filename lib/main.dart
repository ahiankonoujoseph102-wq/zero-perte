import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as chemins;
import 'package:sqflite/sqflite.dart';

import 'donnees/journal_local.dart';
import 'ecrans/accueil_vendeur.dart';
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
  runApp(ZeroPerteApp(journal: ouvrirJournalDuTelephone()));
}

/// Ouvre (ou crée) la base locale du téléphone.
Future<JournalLocal> ouvrirJournalDuTelephone() async {
  final dossier = await getDatabasesPath();
  return JournalLocal.ouvrir(
    fabrique: databaseFactory,
    chemin: chemins.join(dossier, 'zero_perte.db'),
  );
}

class ZeroPerteApp extends StatelessWidget {
  const ZeroPerteApp({
    super.key,
    this.infosPaquet,
    this.journal,
    this.maintenant,
  });

  /// Permettent aux tests de fournir la version, la base et la date.
  final Future<PackageInfo>? infosPaquet;
  final Future<JournalLocal>? journal;
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zéro Perte',
      debugShowCheckedModeBanner: false,
      theme: themeZeroPerte(),
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
      home: AccueilVendeur(
        nomBoutique: 'Ma boutique',
        nomVendeur: 'Vendeur',
        maintenant: maintenant,
        pied: PiedDePage(
          infosPaquet: infosPaquet ?? PackageInfo.fromPlatform(),
          journal: journal,
        ),
      ),
    );
  }
}

/// Ligne du bas : version de l'application et état de la base locale.
class PiedDePage extends StatelessWidget {
  const PiedDePage({super.key, required this.infosPaquet, this.journal});

  final Future<PackageInfo> infosPaquet;
  final Future<JournalLocal>? journal;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, color: CouleursZp.texteDoux);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (journal != null)
          FutureBuilder<JournalLocal>(
            future: journal,
            builder: (context, etat) {
              final pret = etat.hasData;
              final erreur = etat.hasError;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  key: Key(
                    erreur
                        ? 'base-erreur'
                        : (pret ? 'base-prete' : 'base-ouverture'),
                  ),
                  color: erreur
                      ? CouleursZp.argentSort
                      : (pret ? CouleursZp.argentEntre : CouleursZp.ligne),
                  semanticLabel: erreur
                      ? 'Base de données en erreur'
                      : 'Base de données prête',
                ),
              );
            },
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
