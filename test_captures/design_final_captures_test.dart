// Captures « avant / après » de la refonte du design (0.37) : écrans
// principaux sur un petit téléphone, une tablette et un PC.
// Lancement :
//   ZP_PHASE=avant flutter test test_captures/design_final_captures_test.dart --update-goldens
//   ZP_PHASE=apres flutter test test_captures/design_final_captures_test.dart --update-goldens
// puis copier test_captures/captures/design_final/ dans docs/design-final/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/caisse/ma_caisse.dart';
import 'package:zero_perte/ecrans/credit/clients.dart';
import 'package:zero_perte/ecrans/patron/chiffres.dart';
import 'package:zero_perte/ecrans/patron/espace_patron.dart';

import '../test/support/outils.dart';
import '../test/ecrans/vente_test.dart' show ouvrirLaCaisseSiDemande;
import 'refonte_036_captures_test.dart' show boutiqueLait;

final _phase = Platform.environment['ZP_PHASE'] ?? 'apres';

Future<void> _polices() async {
  final m =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in m.cast<Map<String, dynamic>>()) {
    final l = FontLoader(f['family'] as String);
    for (final x in (f['fonts'] as List).cast<Map<String, dynamic>>()) {
      l.addFont(rootBundle.load(x['asset'] as String));
    }
    await l.load();
  }
}

Future<void> _capture(WidgetTester tester, String nom) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('captures/design_final/$_phase/$nom.png'),
);

/// Une journée réaliste : ventes au détail et en gros, crédit, vendeur.
Future<String> _journee(EtatApplication e) async {
  await boutiqueLait(e);
  final lait = e.produits.firstWhere((p) => p.nom == 'Lait');
  final carton = e.grosDe(lait.id).firstWhere((c) => !c.nom.contains('rev'));
  final kodjo = await e.enregistrerClient(
    nom: 'Kodjo',
    telephone: '90 12 34 56',
    plafond: 50000,
  );
  await e.vendre(
    Panier()..ajouter(
      LignePanier(
        produitId: lait.id,
        nomProduit: 'Lait',
        uniteBase: 'boîte',
        conditionnement: carton,
        nombre: 1,
        prixUnitaire: carton.prixVente,
      ),
    ),
    mode: ModePaiement.credit,
    clientId: kodjo,
  );
  final v = await e.ajouterVendeur(nom: 'Kossi');
  return v.code;
}

void main() {
  setUpAll(_polices);
  const tailles = {
    'petit_telephone': (Size(360, 720), 2.0),
    'tablette': (Size(1280, 800), 1.25),
    'pc': (Size(1366, 768), 1.0),
  };
  for (final t in tailles.entries) {
    final (taille, densite) = t.value;

    testWidgets('premier lancement ${t.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.bienvenue,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await _capture(tester, '1_bienvenue_${t.key}');
    });

    testWidgets('patron ${t.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: _journee);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await attendre(tester, tours: 10);
      await _capture(tester, '2_accueil_patron_${t.key}');
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await ouvrirLaCaisseSiDemande(tester);
      await attendre(tester, tours: 6);
      await _capture(tester, '3_vendre_${t.key}');
      await revenirAccueil(tester);
      for (final (nom, page) in [
        ('4_ma_caisse', PageMaCaisse(etat: env.etat)),
        ('5_ce_qu_on_me_doit', PageClients(etat: env.etat)),
        ('6_mon_benefice', PageChiffres(etat: env.etat)),
        ('8_gestion', EspacePatron(etat: env.etat)),
      ]) {
        Navigator.of(
          tester.element(find.byType(Scaffold).first),
        ).push(MaterialPageRoute(builder: (_) => page));
        await attendre(tester, tours: 8);
        await _capture(tester, '${nom}_${t.key}');
        await revenirAccueil(tester);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('vendeur ${t.key}', (tester) async {
      late String code;
      final env = await environnementDeTest(
        tester,
        preparer: (e) async => code = await _journee(e),
      );
      await tester.runAsync(() => env.etat.connecterParCode(code));
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await attendre(tester, tours: 10);
      await _capture(tester, '7_accueil_vendeur_${t.key}');
      expect(tester.takeException(), isNull);
    });
  }
}
