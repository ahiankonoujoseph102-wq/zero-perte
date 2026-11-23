// Captures de la refonte « commerçant » (0.36) sur les 4 tailles.
// Lancement : flutter test test_captures/refonte_036_captures_test.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/boutique.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/patron/a_faire.dart';
import 'package:zero_perte/ecrans/patron/compter_stock.dart';
import 'package:zero_perte/ecrans/patron/ma_boutique.dart';
import 'package:zero_perte/ecrans/patron/produits.dart';

import '../test/domaine/licence_test.dart' show codeLicence;
import '../test/ecrans/refonte_036_test.dart' show boutiqueVide;
import '../test/ecrans/vente_test.dart' show ouvrirLaCaisseSiDemande;
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

Future<void> capture(WidgetTester tester, String nom) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('captures/refonte_036/$nom.png'),
);

/// Boutique d'un grossiste-détaillant après quelques jours.
Future<void> boutiqueLait(EtatApplication e) async {
  await boutiqueVide(e);
  await e.enregistrerConfig(
    e.config.copie(vente: FaconDeVendre.lesDeux, quiVend: QuiVend.unVendeur),
  );
  final lait = await e.creerProduit(
    nom: 'Lait',
    uniteBase: 'boîte',
    prixVente: 550,
    prixAchat: 450,
    conditionnements: [
      ('carton de 24', 24, 12000),
      ('carton de 24 (revendeur)', 24, 11500),
    ],
  );
  await e.creerProduit(
    nom: 'Riz',
    uniteBase: 'bol',
    prixVente: 500,
    conditionnements: [('sac de 50 kg', 110, 27500)],
  );
  await e.creerProduit(nom: 'Savon', uniteBase: 'morceau', prixVente: 250);
  final carton = e
      .grosDe(lait.id)
      .firstWhere((c) => !c.nom.contains('revendeur'));
  await e.enregistrerArrivage(
    produit: lait,
    conditionnement: carton,
    nombre: 3,
    coutTotal: 32400,
  );
  await e.ouvrirCaisse(5000);
  final p = Panier()
    ..ajouter(
      LignePanier(
        produitId: lait.id,
        nomProduit: 'Lait',
        uniteBase: 'boîte',
        nombre: 5,
        prixUnitaire: 550,
      ),
    );
  await e.vendre(p, mode: ModePaiement.especes, montantRecu: 2750);
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

    testWidgets('démarrage ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.bienvenue,
        relais: FauxRelaisInvitations(),
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await capture(tester, 'bienvenue_${e.key}');
      await tester.runAsync(() async {
        await env.etat.activer(codeLicence);
        await env.etat.allerA(EtapeAssistant.identite);
      });
      await attendre(tester);
      await capture(tester, 'etape1_nom_${e.key}');
      await tester.runAsync(() => env.etat.allerA(EtapeAssistant.profil));
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('vente-les_deux')));
      await toucher(tester, find.byKey(const Key('qui-un')));
      await capture(tester, 'etape2_profil_${e.key}');
      await tester.runAsync(() async {
        await env.etat.enregistrerConfig(
          env.etat.config.copie(nom: 'Boutique Mama Ama'),
        );
        await env.etat.allerA(EtapeAssistant.fin);
      });
      await attendre(tester);
      await capture(tester, 'vous_pouvez_vendre_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('vendre sans inventaire ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await capture(tester, 'accueil_jour1_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await ouvrirLaCaisseSiDemande(tester);
      await capture(tester, 'vendre_vide_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-nouveau-produit')));
      await tester.pump(const Duration(seconds: 2));
      await capture(tester, 'nouveau_produit_${e.key}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('gros et détail ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueLait);
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await attendre(tester, tours: 10);
      await capture(tester, 'accueil_patron_${e.key}');
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await ouvrirLaCaisseSiDemande(tester);
      final lait = env.etat.produits.firstWhere((p) => p.nom == 'Lait');
      await toucher(tester, find.byKey(Key('vendre-${lait.id}')));
      await tester.pump(const Duration(seconds: 2));
      await capture(tester, 'detail_ou_gros_${e.key}');
      await revenirAccueil(tester);
      Navigator.of(tester.element(find.byType(Scaffold).first)).push(
        MaterialPageRoute(
          builder: (_) => PageFicheProduit(etat: env.etat, produit: lait),
        ),
      );
      await attendre(tester, tours: 8);
      await tester.scrollUntilVisible(
        find.byKey(const Key('titre-vente-en-gros')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(PageFicheProduit),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await attendre(tester);
      await capture(tester, 'fiche_vente_en_gros_${e.key}');
      await revenirAccueil(tester);
      Navigator.of(
        tester.element(find.byType(Scaffold).first),
      ).push(MaterialPageRoute(builder: (_) => PageProduits(etat: env.etat)));
      await attendre(tester, tours: 8);
      await capture(tester, 'stock_lisible_${e.key}');
      await revenirAccueil(tester);
      for (final (nom, page) in [
        ('compter_stock', PageCompterStock(etat: env.etat)),
        ('a_faire', PageAFaire(etat: env.etat)),
        ('ma_boutique', PageMaBoutique(etat: env.etat)),
      ]) {
        Navigator.of(tester.element(find.byType(Scaffold).first))
            .push(MaterialPageRoute(builder: (_) => page));
        await attendre(tester, tours: 8);
        await capture(tester, '${nom}_${e.key}');
        await revenirAccueil(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
