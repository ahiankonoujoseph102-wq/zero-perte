// Captures des écrans de vente avec les vraies polices (lancement manuel :
// flutter test test_captures --update-goldens).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/ecrans/vente_test.dart'
    show boutiqueAvecStock, ouvrirLaCaisseSiDemande;
import '../test/ecrans/fermeture_test.dart' show journeeEspeces;

import 'package:zero_perte/donnees/journal_local.dart';

import '../test/support/outils.dart';

Future<void> _chargerPolices() async {
  final manifeste =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final famille in manifeste.cast<Map<String, dynamic>>()) {
    final chargeur = FontLoader(famille['family'] as String);
    for (final f in (famille['fonts'] as List).cast<Map<String, dynamic>>()) {
      chargeur.addFont(rootBundle.load(f['asset'] as String));
    }
    await chargeur.load();
  }
}

void main() {
  setUpAll(_chargerPolices);
  const ecrans = {'5pouces': Size(360, 640), '4pouces': Size(320, 568)};
  testWidgets('connexion 5pouces', (tester) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
        await etat.ajouterVendeur(nom: 'Afi', pin: '6024');
        etat.deconnecter();
      },
    );
    await afficherApp(
      tester,
      env.etat,
      taille: const Size(360, 640),
      densite: 2,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/connexion_5pouces.png'),
    );
  });
  for (final e in ecrans.entries) {
    testWidgets('vente ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/accueil_installe_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      for (final c in ['5', '0', '0', '0']) {
        await toucher(tester, find.byKey(Key('montant-$c')));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/caisse_ouvrir_${e.key}.png'),
      );
      await ouvrirLaCaisseSiDemande(tester);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/vente_choix_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.sucre')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/vente_panier_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await toucher(tester, find.byKey(const Key('rapide-5000')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/vente_encaisser_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/vente_terminee_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('depense ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await toucher(tester, find.byKey(const Key('bouton-depense')));
      await toucher(tester, find.byKey(const Key('choix-depense-argent')));
      await toucher(tester, find.byKey(const Key('motif-Transport')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/depense_haut_${e.key}.png'),
      );
      for (final c in ['1', '5', '0', '0']) {
        await toucher(tester, find.byKey(Key('montant-$c')));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/depense_bas_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('fermeture ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await journeeEspeces(etat);
          final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
          await etat.journal.enregistrerVente(
            lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
            mode: ModePaiement.flooz,
            referencePaiement: '123',
            auteurId: etat.auteurActuel,
          );
        },
      );
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await toucher(tester, find.byKey(const Key('bouton-fermer-caisse')));
      await attendre(tester, tours: 8);
      for (final c in ['6', '0', '0', '0']) {
        await toucher(tester, find.byKey(Key('montant-$c')));
      }
      await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/fermeture_flooz_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
      await attendre(tester, tours: 10);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/fermeture_resultat_${e.key}.png'),
      );
    });
  }
}
