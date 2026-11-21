// Captures de la nouvelle allure (bleu nuit) sur les 4 tailles demandées :
// petit téléphone 4", grand téléphone, tablette 10" paysage, PC 1366×768.
// Lancement manuel : flutter test test_captures/allure_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
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

/// Jours en arrière pour l'horloge du journal (ventes des jours passés).
int _joursEnArriere = 0;
int _horloge() => DateTime.now()
    .subtract(Duration(days: _joursEnArriere))
    .millisecondsSinceEpoch;

const _produits = [
  ('alimentation.riz', 600, 100),
  ('alimentation.sucre', 800, 30),
  ('alimentation.huile', 1300, 40),
  ('alimentation.pates', 350, 60),
  ('alimentation.sardines', 500, 48),
  ('alimentation.savon', 250, 80),
];

/// Boutique avec 7 jours de ventes, des caisses fermées, un client à crédit.
Future<void> boutiqueVivante(EtatApplication etat) async {
  _joursEnArriere = 8;
  await etat.enregistrerConfig(
    etat.config.copie(nom: 'Boutique Mama Ama', types: ['alimentation']),
  );
  await etat.definirPatron(nom: 'Ama', pin: '482713');
  final ids = {for (final p in _produits) p.$1};
  await etat.ajouterDuCatalogue(
    etat.catalogue
        .produitsDe(['alimentation'])
        .where((p) => ids.contains(p.id)),
  );
  for (final (id, prix, stock) in _produits) {
    final p = etat.produits.firstWhere((x) => x.catalogueId == id);
    final conds = await etat.journal.conditionnements(p.id);
    await etat.fixerPrix(p, prix, {
      for (final c in conds) c: prix * c.facteurMilliemes ~/ 1000,
    });
    await etat.enregistrerArrivage(
      produit: etat.produits.firstWhere((x) => x.id == p.id),
      nombre: stock,
      coutTotal: stock * prix * 80 ~/ 100,
    );
  }
  await etat.enregistrerClient(
    nom: 'Kofi',
    telephone: '90112233',
    plafond: 10000,
  );
  await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
  final kofi = (await etat.clients()).single;
  String id(String c) => etat.produits.firstWhere((p) => p.catalogueId == c).id;
  // Ventes des 6 jours passés et d'aujourd'hui (nombre de ventes variable).
  const parJour = [3, 5, 4, 7, 6, 8, 5];
  for (var j = 6; j >= 0; j--) {
    _joursEnArriere = j;
    await etat.ouvrirCaisse(5000);
    for (var v = 0; v < parJour[6 - j]; v++) {
      await etat.journal.enregistrerVente(
        lignes: [
          LigneDemandee.quantite(
            produitId: id(_produits[v % 6].$1),
            nombre: 1 + (v + j) % 3,
          ),
          if (v.isEven)
            LigneDemandee.quantite(
              produitId: id('alimentation.riz'),
              nombre: 2,
            ),
        ],
        mode: v % 4 == 3 ? ModePaiement.flooz : ModePaiement.especes,
        montantRecu: v % 4 == 3 ? null : 20000,
        auteurId: etat.auteurActuel,
      );
    }
    if (j == 1) {
      await etat.journal.enregistrerVente(
        lignes: [
          LigneDemandee.quantite(
            produitId: id('alimentation.huile'),
            nombre: 1,
          ),
        ],
        mode: ModePaiement.credit,
        clientId: kofi.id,
        auteurId: etat.auteurActuel,
      );
    }
    if (j > 0) {
      final enCours = await etat.journal.caisseEnCours();
      await etat.fermerCaisse({
        for (final e in enCours.entries)
          e.key:
              attenduAFermeture(e.key, e.value) -
              (j == 2 && e.key == ModePaiement.especes ? 500 : 0),
      });
    }
  }
  _joursEnArriere = 0;
  await etat.rechargerProduits();
  await etat.allerA(EtapeAssistant.termine);
}

void main() {
  setUpAll(_chargerPolices);
  const tailles = {
    '4pouces': (Size(320, 568), 2.0),
    'telephone': (Size(412, 915), 2.625),
    'tablette_paysage': (Size(1280, 800), 1.5),
    'pc': (Size(1366, 768), 1.0),
  };
  Future<void> capture(String nom) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('captures/allure/$nom.png'),
  );

  for (final e in tailles.entries) {
    final (taille, densite) = e.value;
    final grand = taille.width >= 840;
    testWidgets('allure patron ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueVivante,
        horloge: _horloge,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await attendre(tester, tours: 10);
      await capture('01_accueil_patron_${e.key}');

      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('vendre-alimentation.riz')));
      await toucher(tester, find.byKey(const Key('choix-base')));
      await toucher(tester, find.byKey(const Key('vendre-alimentation.huile')));
      if (find.byKey(const Key('choix-base')).evaluate().isNotEmpty) {
        await toucher(tester, find.byKey(const Key('choix-base')));
      }
      await attendre(tester, tours: 4);
      await capture('02_vente_${e.key}');

      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      await attendre(tester, tours: 4);
      await toucher(tester, find.byKey(const Key('rapide-5000')));
      await attendre(tester, tours: 4);
      await capture('03_encaissement_${e.key}');

      await revenirAccueil(tester);
      await toucher(tester, find.byKey(const Key('bouton-ma-caisse')));
      await attendre(tester, tours: 10);
      await capture('04_ma_caisse_${e.key}');

      await revenirAccueil(tester);
      if (grand) {
        await toucher(tester, find.byKey(const Key('menu-tableau')));
      } else {
        await toucher(tester, find.byKey(const Key('accueil-tableau')));
      }
      await attendre(tester, tours: 10);
      await capture('05_tableau_${e.key}');

      await revenirAccueil(tester);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 10);
      await capture('06_clients_${e.key}');

      await revenirAccueil(tester);
      await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
      await attendre(tester, tours: 6);
      await capture('07_gestion_${e.key}');
    });

    testWidgets('allure vendeur ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueVivante(etat);
          etat.deconnecter();
        },
        horloge: _horloge,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      for (final c in ['5', '9', '1']) {
        await tester.tap(find.byKey(Key('code-$c')));
        await tester.pump();
      }
      await capture('00_entree_${e.key}');
      await taperCode(tester, '3');
      // « 5913 » : le 3 a été tapé par taperCode, qui valide avec OK.
      await attendre(tester, tours: 10);
      await capture('08_accueil_vendeur_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-ma-caisse')));
      await attendre(tester, tours: 10);
      await capture('09_ma_caisse_vendeur_${e.key}');
    });
  }
}
