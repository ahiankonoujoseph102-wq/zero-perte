// Version 0.28 : décisions du propriétaire sur le rapport 0.27.
// - Devis : prix gardés pendant 7 jours, prix du jour après expiration.
// - Retour sur une vente à crédit déjà payée : le reste est rendu en espèces,
//   la dette ne devient jamais négative.
// - Alertes graves gardées sur l'appareil sans réseau, envoyées au retour.
// - Avertissements de l'installation : bandeau orange, une fois.
// - Écran de retour sur 4 pouces : caisse, motif et bouton visibles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/clavier_montant.dart';
import 'package:zero_perte/services/telephone.dart';
import 'package:zero_perte/synchro/relais.dart';

import '../support/outils.dart';
import 'credit_test.dart' show boutiqueAvecKofi;
import 'lot_e_test.dart' show panier, ouvrirRetour;
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock, ouvrirVendre;

/// Relais simulé qui peut être « en panne » (pas de réseau).
class RelaisCoupable implements TransportAlertes {
  bool enPanne = false;
  final List<(String, Alerte)> recues = [];

  @override
  Future<void> envoyer(String jeton, Alerte alerte) async {
    if (enPanne) throw Exception('pas de réseau');
    recues.add((jeton, alerte));
  }

  @override
  Future<List<Alerte>> relever(String jeton, int depuis) async => [
    for (final (j, a) in recues)
      if (j == jeton && a.heure > depuis) a,
  ];
}

/// Devis de 2 kg de riz (1 200 F), puis le riz passe à 650 F le kg.
Future<void> devisPuisHausse(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  await etat.ouvrirCaisse(0);
  await etat.creerDevis(panier(etat, kgRiz: 2));
  final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
  final conds = await etat.journal.conditionnements(riz.id);
  await etat.fixerPrix(riz, 650, {for (final c in conds) c: c.prixVente});
}

/// Ouvre le devis n° 1 depuis « Gestion → Devis », le transforme en vente et
/// encaisse le compte exact.
Future<void> transformerEtEncaisser(WidgetTester tester) async {
  await ouvrirEspacePatron(tester);
  await toucher(tester, find.byKey(const Key('patron-devis')));
  await toucher(tester, find.byKey(const Key('devis-0')));
  await attendre(tester, tours: 6);
  await toucher(tester, find.byKey(const Key('bouton-devis-en-vente')));
  await attendre(tester, tours: 10);
}

Future<void> encaisserExact(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6)); // le message s'en va
  await attendre(tester);
  await toucher(tester, find.byKey(const Key('bouton-encaisser')));
  await toucher(tester, find.byKey(const Key('rapide-exact')));
  await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
  await toucher(tester, find.byKey(const Key('bouton-nouvelle-vente')));
  await attendre(tester, tours: 10);
}

void main() {
  // ---------------------------------------------------------------------------
  // Devis : prix gardés 7 jours
  // ---------------------------------------------------------------------------

  testWidgets(
    'devis transformé 6 jours après : le prix du devis est gardé (1 200 F, '
    'pas 1 300 F)',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: devisPuisHausse);
      env.etat.maintenant = () => DateTime.now().add(const Duration(days: 6));
      await afficherApp(tester, env.etat);
      await transformerEtEncaisserPrep(tester);
      expect(find.textContaining('Devis expiré'), findsNothing);
      await encaisserExact(tester);
      await tester.runAsync(() async {
        final v = (await env.journal.ventesDepuis(0)).single;
        expect(v.total, 1200);
        expect(v.lignes.single['prix_total'], 1200);
        expect((await env.journal.devis()).single.$2, v.recu);
      });
    },
  );

  testWidgets(
    'devis transformé 8 jours après : « Devis expiré, nouveaux prix : 1 300 F »',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: devisPuisHausse);
      env.etat.maintenant = () => DateTime.now().add(const Duration(days: 8));
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-devis')));
      await toucher(tester, find.byKey(const Key('devis-0')));
      await attendre(tester, tours: 6);
      expect(
        tester.widget<Text>(find.byKey(const Key('devis-validite'))).data,
        startsWith('Expiré depuis le'),
      );
      await toucher(tester, find.byKey(const Key('bouton-devis-en-vente')));
      await attendre(tester, tours: 10);
      expect(
        find.text('Devis expiré, nouveaux prix : ${formatFrancs(1300)}.'),
        findsOneWidget,
      );
      await encaisserExact(tester);
      await tester.runAsync(() async {
        final v = (await env.journal.ventesDepuis(0)).single;
        expect(v.total, 1300);
      });
    },
  );

  testWidgets('validité : jusqu\'à la fin du 7e jour, puis expiré', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: devisPuisHausse);
    await tester.runAsync(() async {
      final d = (await env.journal.devis()).single.$1;
      final cree = DateTime.fromMillisecondsSinceEpoch(d.heure);
      env.etat.maintenant = () =>
          DateTime(cree.year, cree.month, cree.day + 7, 23, 59);
      expect(env.etat.devisValable(d), isTrue);
      final r = await env.etat.panierDepuisDevis(d);
      expect(r.panier.total, 1200);
      expect(r.panier.lignes.single.prixDuDevis, isTrue);
      env.etat.maintenant = () =>
          DateTime(cree.year, cree.month, cree.day + 8, 0, 1);
      expect(env.etat.devisValable(d), isFalse);
      final r2 = await env.etat.panierDepuisDevis(d);
      expect(r2.panier.total, 1300);
      expect(r2.totalChange, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Retour sur une vente à crédit déjà payée
  // ---------------------------------------------------------------------------

  testWidgets('Kofi doit 300 F (3 kg à crédit, 1 500 F remboursés) et rend 1 kg (600 F) : '
      'dette 0 F et 300 F rendus en espèces ; jamais de dette négative', (tester) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecKofi(etat);
        final kofi = (await etat.journal.clients()).single;
        await etat.vendre(
          panier(etat, kgRiz: 3)..choisirClient(kofi.id, kofi.nom),
          mode: ModePaiement.credit,
          clientId: kofi.id,
        );
        await etat.rembourser(kofi, 1500, mode: ModePaiement.especes);
      },
    );
    await ouvrirVendre(tester, env);
    await ouvrirRetour(tester, 'A-000001');
    await toucher(tester, find.byKey(const Key('retour-plus-0')));
    await attendre(tester, tours: 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('retour-credit-info'))).data,
      'Sa dette tombe à 0 F et vous lui rendez ${formatFrancs(300)} en espèces.',
    );
    await toucher(
      tester,
      find.byKey(const Key('motif-retour-Mauvais produit')),
    );
    await toucher(tester, find.byKey(const Key('bouton-valider-retour')));
    await attendre(tester, tours: 10);
    expect(find.text('Rendez au client (Espèces)'), findsOneWidget);
    expect(
      tester
          .widget<MontantGeant>(find.byKey(const Key('retour-a-rendre')))
          .montant,
      300,
    );
    expect(
      find.text(
        'Sa dette baisse aussi de ${formatFrancs(300)} : il ne doit plus rien.',
      ),
      findsOneWidget,
    );
    expect(env.voix.phrases.last, contains('en espèces'));

    await tester.runAsync(() async {
      final kofi = (await env.journal.clients()).single;
      expect(await env.journal.soldeClient(kofi.id), 0);
      final caisse = await env.journal.mouvementsCaisse(ModePaiement.especes);
      // Fonds 0 + remboursement 1 500 − 300 rendus = 1 200 F.
      expect(caisse.attendu, 1200);

      // Il rend encore 1 kg : il ne doit plus rien → tout en espèces.
      final v = (await env.journal.ventesDepuis(0)).single;
      final op = await env.etat.retournerVente(
        v,
        rendus: {0: 1},
        mode: ModePaiement.especes,
        motif: 'Mauvais produit',
      );
      expect(op.donnees['rendu_especes'], 600);
      expect(await env.journal.soldeClient(kofi.id), 0);
      expect(
        (await env.journal.mouvementsCaisse(ModePaiement.especes)).attendu,
        600,
      );
      final r = await env.etat.rapport(Periode.jour);
      expect(r.creditsDus, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Alertes graves sans réseau
  // ---------------------------------------------------------------------------

  testWidgets(
    'sans réseau, les 4 alertes graves (codes faux, caisse, annulation, retour) '
    'sont gardées, même après fermeture, puis envoyées au retour du réseau',
    (tester) async {
      final relais = RelaisCoupable()..enPanne = true;
      var heure = DateTime.now();
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          await etat.journal.ecrireParametre('relais.jeton', 'jeton-test');
          etat.transportAlertes = relais;
          etat.maintenant = () => heure;
        },
      );
      await tester.runAsync(() async {
        final e = env.etat;
        e.deconnecter();
        // 1. Codes faux.
        for (var i = 0; i < 5; i++) {
          await e.connecterParCode('2468');
        }
        heure = heure.add(const Duration(minutes: 6));
        expect((await e.connecterParCode('5913'))!.nom, 'Kossi');
        // 2. Grosse annulation (sac de 50 kg, 28 000 F).
        await e.ouvrirCaisse(5000);
        final riz = e.produits.firstWhere((p) => p.nom == 'Riz');
        final sac = (await e.journal.conditionnements(riz.id))
            .firstWhere((c) => c.nom == 'sac de 50 kg');
        await e.vendre(
          Panier()..ajouter(
            LignePanier(
              produitId: riz.id,
              nomProduit: riz.nom,
              uniteBase: riz.uniteBase,
              conditionnement: sac,
              nombre: 1,
              prixUnitaire: sac.prixVente,
            ),
          ),
          mode: ModePaiement.especes,
          montantRecu: 28000,
        );
        await e.annulerVente(
          (await e.journal.ventesDepuis(0)).single,
          'Erreur en tapant la vente',
        );
        // 3. Retour fait par le vendeur.
        await e.vendre(
          panier(e, kgRiz: 2),
          mode: ModePaiement.especes,
          montantRecu: 1200,
        );
        final v = (await e.journal.ventesDepuis(0)).first;
        await e.retournerVente(
          v,
          rendus: {0: 1},
          mode: ModePaiement.especes,
          motif: 'Produit abîmé',
        );
        // 4. Caisse fermée avec 2 000 F de manque (attendu 5 600 F).
        await e.fermerCaisse({ModePaiement.especes: 3600});
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(relais.recues, isEmpty);
        expect(await e.nombreAlertesEnAttente(), 4);

        // L'application est fermée puis rouverte : rien n'est perdu.
        final rouvert = await EtatApplication.charger(
          journal: env.journal,
          services: e.services,
        );
        rouvert.transportAlertes = relais;
        heure = heure.add(const Duration(minutes: 30));
        rouvert.maintenant = () => heure;
        expect(await rouvert.nombreAlertesEnAttente(), 4);
        // Toujours pas de réseau : rien ne part, rien ne se perd.
        expect(await rouvert.envoyerAlertesEnAttente(), 0);
        expect(await rouvert.nombreAlertesEnAttente(), 4);

        // Le réseau revient.
        relais.enPanne = false;
        expect(await rouvert.envoyerAlertesEnAttente(), 4);
        expect(await rouvert.nombreAlertesEnAttente(), 0);
        expect(relais.recues.map((r) => r.$2.type).toList(), [
          'code',
          'annulation',
          'retour',
          'ecart',
        ]);
        expect(relais.recues.first.$2.message, contains('5 codes faux'));
        expect(
          relais.recues.first.$2.message,
          contains('envoyée au retour du réseau'),
        );
        expect(relais.recues.last.$2.message, contains('il manque'));
        // Pas envoyées deux fois.
        expect(await rouvert.envoyerAlertesEnAttente(), 0);
        expect(relais.recues, hasLength(4));
      });

      // Le patron les reçoit (bandeau + voix).
      final patron = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.journal.ecrireParametre('relais.jeton', 'jeton-test');
          etat.transportAlertes = relais;
          await etat.releverAlertes();
        },
      );
      expect(patron.etat.alertes, hasLength(4));
    },
  );

  testWidgets('avec réseau, l\'alerte part tout de suite et ne reste pas', (
    tester,
  ) async {
    final relais = RelaisCoupable();
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
        await etat.journal.ecrireParametre('relais.jeton', 'jeton-test');
        etat.transportAlertes = relais;
        etat.deconnecter();
      },
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await env.etat.connecterParCode('2468');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(relais.recues.single.$2.type, 'code');
      expect(
        relais.recues.single.$2.message,
        isNot(contains('retour du réseau')),
      );
      expect(await env.etat.nombreAlertesEnAttente(), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Avertissements de l'installation
  // ---------------------------------------------------------------------------

  testWidgets(
    'installation : 250 Mo libres et pas de voix française → on passe quand '
    'même, les 2 avertissements sont gardés',
    (tester) async {
      const faible = InfosTelephone(
        androidSdk: 30,
        androidVersion: '11',
        fabricant: 'Itel',
        modele: 'A56',
        servicesGoogle: true,
        espaceLibreMo: 250,
      );
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.verification,
        telephone: faible,
        voixFrancaise: false,
      );
      await afficherApp(tester, env.etat);
      await attendre(tester, tours: 8);
      expect(env.etat.etape, EtapeAssistant.activation);
      final brut = await tester.runAsync(
        () => env.journal.lireParametre('installation.avertissements'),
      );
      expect(brut, contains('Peu de place libre (250 Mo)'));
      expect(brut, contains('Pas de voix française'));
      // Pas encore de bandeau pendant l'installation.
      expect(find.byKey(const Key('bandeau-avertissements')), findsNothing);
    },
  );

  testWidgets('après l\'installation : bandeau orange une seule fois, « Compris » le ferme '
      'pour de bon', (tester) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await boutiqueAvecStock(etat);
        await etat.noterAvertissementsInstallation([
          'Peu de place libre (250 Mo) : libérez de la place bientôt.',
          'Pas de voix française : l\'application ne parlera pas.',
        ]);
      },
    );
    await afficherApp(tester, env.etat);
    expect(find.byKey(const Key('bandeau-avertissements')), findsOneWidget);
    expect(find.textContaining('250 Mo'), findsOneWidget);
    await toucher(
      tester,
      find.byKey(const Key('bouton-avertissements-compris')),
    );
    expect(find.byKey(const Key('bandeau-avertissements')), findsNothing);
    final rouvert = await tester.runAsync(
      () => EtatApplication.charger(
        journal: env.journal,
        services: env.etat.services,
      ),
    );
    expect(rouvert!.avertissementsInstallation, isEmpty);
  });

  for (final (nom, taille, densite) in [
    ('PC 1366×768', const Size(1366, 768), 1.0),
    ('tablette 10 pouces paysage', const Size(1280, 800), 1.5),
  ]) {
    testWidgets(
      '$nom avec le bandeau orange : tout le menu de gauche reste dans l\'écran',
      (tester) async {
        final env = await environnementDeTest(
          tester,
          preparer: (etat) async {
            await boutiqueAvecStock(etat);
            await etat.noterAvertissementsInstallation([
              'Peu de place libre (250 Mo) : libérez de la place bientôt.',
              'Pas de voix française : l\'application ne parlera pas.',
            ]);
          },
        );
        await afficherApp(tester, env.etat, taille: taille, densite: densite);
        expect(find.byKey(const Key('bandeau-avertissements')), findsOneWidget);
        for (final cle in [
          'menu-accueil',
          'bouton-vendre',
          'menu-fournisseurs',
          'menu-vendeurs',
          'bouton-espace-patron',
        ]) {
          final r = tester.getRect(find.byKey(Key(cle)));
          expect(
            r.bottom <= taille.height,
            isTrue,
            reason: '$cle dans l\'écran',
          );
        }
        // La personne connectée (bas du menu) aussi.
        final bas = tester.getRect(
          find.byKey(const Key('bouton-changer-utilisateur')),
        );
        expect(bas.bottom <= taille.height, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Écran de retour sur 4 pouces
  // ---------------------------------------------------------------------------

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets(
      'retour sur ${e.key} : caisse, motif et bouton visibles sans défiler',
      (tester) async {
        final env = await environnementDeTest(
          tester,
          preparer: (etat) async {
            await boutiqueAvecStock(etat);
            await etat.ouvrirCaisse(0);
            await etat.vendre(
              panier(etat, kgRiz: 3, paquetsSucre: 2),
              mode: ModePaiement.especes,
              montantRecu: 3400,
            );
          },
        );
        await ouvrirVendre(tester, env, taille: taille, densite: densite);
        await ouvrirRetour(tester, 'A-000001');
        // (La liste des articles, elle, peut défiler : les tests utilisent une
        // police plus large que la vraie.)
        await toucher(tester, find.byKey(const Key('retour-plus-0')));
        for (final cle in [
          'retour-mode-especes',
          'retour-mode-flooz',
          'retour-mode-mixx',
          'motif-retour-Produit abîmé',
          'motif-retour-Autre',
          'bouton-valider-retour',
        ]) {
          final r = tester.getRect(find.byKey(Key(cle)));
          expect(
            r.top >= 0 && r.bottom <= taille.height,
            isTrue,
            reason: '$cle visible sans défiler',
          );
        }
        // Les gestes marchent directement, sans défilement.
        await tester.tap(find.byKey(const Key('motif-retour-Produit abîmé')));
        await attendre(tester);
        await tester.tap(find.byKey(const Key('bouton-valider-retour')));
        await attendre(tester, tours: 10);
        expect(find.byKey(const Key('retour-a-rendre')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// Ouvre le devis et touche « Transformer en vente » (sans encaisser).
Future<void> transformerEtEncaisserPrep(WidgetTester tester) =>
    transformerEtEncaisser(tester);
