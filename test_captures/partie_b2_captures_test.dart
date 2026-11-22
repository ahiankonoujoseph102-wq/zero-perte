// Captures de la partie B2 sur les 4 tailles : « Chiffres » (résumé et
// rapport), « Commander », crédits en retard, résumé du soir.
// Lancement : flutter test test_captures/partie_b2_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../test/ecrans/tableau_test.dart' show journee;
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;
import '../test/support/outils.dart';

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

void main() {
  setUpAll(_polices);
  const tailles = {
    '4pouces': (Size(320, 568), 2.0),
    'telephone': (Size(412, 915), 2.625),
    'tablette_paysage': (Size(1280, 800), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };
  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    testWidgets('chiffres et commander ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await journee(etat);
          await etat.ajouterFournisseur(
            nom: 'Ets Koffi',
            telephone: '91002200',
          );
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await capture(tester, 'gestion_${e.key}');
      await ouvrirPagePatron(tester, 'chiffres');
      await attendre(tester, tours: 10);
      await capture(tester, 'chiffres_${e.key}');
      await tester.scrollUntilVisible(
        find.byKey(const Key('bouton-commander')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await attendre(tester);
      await capture(tester, 'stock_bas_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-commander')));
      await attendre(tester, tours: 6);
      await capture(tester, 'commander_${e.key}');
      Navigator.of(tester.element(find.byKey(const Key('commander-autre'))))
          .pop();
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('onglet-rapport')));
      await attendre(tester, tours: 8);
      await capture(tester, 'rapport_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('crédits en retard ${e.key}', (tester) async {
      var t = DateTime(2026, 11, 1, 10).millisecondsSinceEpoch;
      final env = await environnementDeTest(
        tester,
        horloge: () => t,
        preparer: (etat) async {
          etat.maintenant = () => DateTime.fromMillisecondsSinceEpoch(t);
          await journee(etat);
          final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
          for (final (nom, tel) in [
            ('Kofi Mensah', '90112233'),
            ('Akosua', '91234567'),
          ]) {
            await etat.enregistrerClient(
              nom: nom,
              telephone: tel,
              plafond: 50000,
            );
            final c = (await etat.journal.clients()).firstWhere(
              (c) => c.nom == nom,
            );
            await etat.journal.enregistrerVente(
              lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 5)],
              mode: ModePaiement.credit,
              clientId: c.id,
              auteurId: etat.auteurActuel,
            );
          }
          t += 21 * Duration.millisecondsPerDay;
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      await capture(tester, 'clients_${e.key}');
      await toucher(tester, find.byKey(const Key('bandeau-retards')));
      await attendre(tester, tours: 8);
      await capture(tester, 'retards_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('résumé du soir ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await journee(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          etat.deconnecter();
          await etat.connecterParCode('5913');
          await etat.ouvrirCaisse(1000);
          await etat.fermerCaisse({ModePaiement.especes: 1000});
          etat.deconnecter();
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await taperCode(tester, '482713', fermerResumeSoir: false);
      await attendre(tester, tours: 12);
      await capture(tester, 'resume_soir_${e.key}');
      expect(find.byKey(const Key('resume-soir')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> capture(WidgetTester tester, String nom) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('captures/partie_b2/$nom.png'),
);
