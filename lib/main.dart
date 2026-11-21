import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Canal de fabrication, fixé par GitHub Actions avec
/// `--dart-define=ZP_CANAL=officiel` quand l'APK est signé avec la clé officielle.
/// Toute autre valeur (ou aucune) signifie : version d'essai, à ne pas distribuer.
const String canalFabrication =
    String.fromEnvironment('ZP_CANAL', defaultValue: 'essai');

bool get estVersionOfficielle => canalFabrication == 'officiel';

/// Couleurs fixes de Zéro Perte. Le vert et le rouge sont réservés à
/// l'argent qui entre et à l'argent qui sort : ils ne servent à rien d'autre.
class CouleursZp {
  static const Color marque = Color(0xFF0B5D3B);
  static const Color argentEntre = Color(0xFF1B8A3C);
  static const Color argentSort = Color(0xFFC62828);
  static const Color fond = Color(0xFFF7F7F2);
  static const Color texte = Color(0xFF1A1A1A);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZeroPerteApp());
}

class ZeroPerteApp extends StatelessWidget {
  const ZeroPerteApp({super.key, this.infosPaquet});

  /// Permet aux tests de fournir les informations de version.
  final Future<PackageInfo>? infosPaquet;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zéro Perte',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: CouleursZp.marque),
        scaffoldBackgroundColor: CouleursZp.fond,
        useMaterial3: true,
      ),
      home: EcranAccueil(infosPaquet: infosPaquet ?? PackageInfo.fromPlatform()),
    );
  }
}

class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key, required this.infosPaquet});

  final Future<PackageInfo> infosPaquet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!estVersionOfficielle) const BandeauEssai(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LogoZp(),
                      const SizedBox(height: 24),
                      const Text(
                        'Zéro Perte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: CouleursZp.marque,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Votre boutique, sans perte.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: CouleursZp.texte),
                      ),
                      const SizedBox(height: 40),
                      FutureBuilder<PackageInfo>(
                        future: infosPaquet,
                        builder: (context, instantane) {
                          final infos = instantane.data;
                          final texte = infos == null
                              ? 'Version …'
                              : 'Version ${infos.version} (${infos.buildNumber})';
                          return Text(
                            texte,
                            key: const Key('texte-version'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: CouleursZp.texte,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau rouge affiché sur les versions d'essai (non signées avec la clé officielle).
class BandeauEssai extends StatelessWidget {
  const BandeauEssai({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: CouleursZp.argentSort,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: const Text(
        'VERSION D\'ESSAI — NE PAS DONNER AUX CLIENTS',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Logo provisoire : un cercle aux couleurs de la marque avec « ZP ».
class LogoZp extends StatelessWidget {
  const LogoZp({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: CouleursZp.marque,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'ZP',
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
