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

import '../test/ecrans/tableau_test.dart' show journee;
import '../test/ecrans/vendeurs_test.dart' show ouvrirEspacePatron;
import '../test/ecrans/demo_test.dart' show demo, cheminDemo;

import 'package:zero_perte/app/etat_application.dart';

import '../test/ecrans/credit_test.dart' show boutiqueAvecKofi, panierACredit;
import '../test/ecrans/code_patron_test.dart' show ancienneBoutique;
import '../test/ecrans/inventaire_test.dart' show boutiquePourInventaire;
import '../test/ecrans/caisse_test.dart' show taperMontant;
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
      await tester.scrollUntilVisible(
        find.byKey(const Key('apercu-recu')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await attendre(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/vente_recu_${e.key}.png'),
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
      await toucherDansMaCaisse(tester, 'bouton-depense');
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
      await toucherDansMaCaisse(tester, 'bouton-fermer-caisse');
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
  for (final e in ecrans.entries) {
    testWidgets('tableau ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await ouvrirEspacePatron(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/patron_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('patron-chiffres')));
      await attendre(tester, tours: 10);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/tableau_haut_${e.key}.png'),
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await attendre(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/tableau_bas_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('sauvegarde ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-sauvegarde')));
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/sauvegarde_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('demo ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.activation,
      );
      final d = (await tester.runAsync(() => demo(env, cheminDemo())))!;
      await afficherApp(
        tester,
        env.etat,
        taille: e.value,
        densite: 2,
        creerDemo: () async => d,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('bouton-demonstration')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('captures/activation_demo_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-demonstration')));
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('captures/demo_accueil_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('credit ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecKofi(etat);
          await etat.enregistrerClient(
            nom: 'Afi Mensah',
            telephone: '91223344',
            plafond: 10000,
          );
        },
      );
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      await panierACredit(tester, 3);
      await toucher(tester, find.byKey(const Key('bouton-choisir-client')));
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/credit_choix_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('client-Kofi')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/credit_encaisser_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      await attendre(tester, tours: 10);
      await tester.scrollUntilVisible(
        find.byKey(const Key('recu-credit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/credit_recu_${e.key}.png'),
      );
      await tester.pageBack();
      await attendre(tester, tours: 8);
      await tester.pageBack();
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/credit_liste_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('client-Kofi')));
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/credit_fiche_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('etape1 ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: ancienneBoutique);
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await taperPin(tester, '4827');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/code6_${e.key}.png'),
      );
      await taperPin(tester, '730518');
      await taperPin(tester, '730518');
      await attendre(tester, tours: 20);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      await toucher(tester, find.byKey(const Key('bouton-nouveau-client')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/client_nouveau_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('etape4 ${e.key}', (tester) async {
      final env = await environnementDeTest(tester, preparer: boutiqueAvecKofi);
      await tester.runAsync(() async {
        await env.etat.connecterSynchro();
        await env.etat.synchroniser();
      });
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await ouvrirEspacePatron(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/patron_tuiles_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('patron-synchro')));
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/drive_${e.key}.png'),
      );
      final neuf = await environnementDeTest(tester, drive: env.drive);
      await tester.pumpWidget(const SizedBox());
      await afficherApp(tester, neuf.etat, taille: e.value, densite: 2);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/bienvenue_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-autres-facons')));
      await toucher(tester, find.byKey(const Key('bouton-retrouver-boutique')));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/retrouver_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('retrouver-drive')));
      await attendre(tester, tours: 10);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/retrouver_drive_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('inventaire ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiquePourInventaire,
      );
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-inventaire')));
      await attendre(tester, tours: 6);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/inventaires_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-inventaire-complet')));
      await attendre(tester, tours: 6);
      await taperMontant(tester, '90');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/inventaire_compte_${e.key}.png'),
      );
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 6);
      await taperMontant(tester, '10');
      await toucher(tester, find.byKey(const Key('bouton-produit-suivant')));
      await attendre(tester, tours: 12);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/inventaire_resultat_${e.key}.png'),
      );
    });
  }
  for (final e in ecrans.entries) {
    testWidgets('fournisseurs ${e.key}', (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecKofi(etat);
          final id = await etat.ajouterFournisseur(
            nom: 'Grossiste Sika',
            telephone: '90001122',
          );
          final f = (await etat.fournisseurs()).firstWhere((x) => x.id == id);
          await etat.achatFournisseur(f, 125000);
        },
      );
      await afficherApp(tester, env.etat, taille: e.value, densite: 2);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-fournisseurs')));
      await attendre(tester, tours: 6);
      await toucher(
        tester,
        find.byKey(const Key('fournisseur-Grossiste Sika')),
      );
      await attendre(tester, tours: 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/fournisseur_${e.key}.png'),
      );
    });
  }
}
