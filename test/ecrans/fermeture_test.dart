import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/caisse/fermeture.dart';

import '../support/outils.dart';
import 'caisse_test.dart' show taperMontant;
import 'vendeurs_test.dart' show ouvrirEspacePatron;
import 'vente_test.dart' show boutiqueAvecStock;

/// Caisse ouverte avec 5 000 F, puis 1 200 F de riz vendus en espèces.
Future<void> journeeEspeces(EtatApplication etat) async {
  await boutiqueAvecStock(etat);
  await etat.ouvrirCaisse(5000);
  final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
  await etat.journal.enregistrerVente(
    lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 2)],
    mode: ModePaiement.especes,
    montantRecu: 1200,
    auteurId: etat.auteurActuel,
  );
}

Future<void> fermerAvec(WidgetTester tester, List<String> montants) async {
  await toucherDansMaCaisse(tester, 'bouton-fermer-caisse');
  await attendre(tester, tours: 8);
  for (final m in montants) {
    await taperMontant(tester, m);
    await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
    await attendre(tester, tours: 8);
  }
}

void main() {
  testWidgets(
    'vendeur : compte 6 000 F au lieu de 6 200 F → ne voit aucun chiffre ; le patron voit « Il manque 200 F »',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await journeeEspeces(etat);
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          final kossi = etat.vendeurs.first;
          await etat.verifierPin(kossi, '5913');
        },
      );
      await afficherApp(tester, env.etat);
      await fermerAvec(tester, ['6000']);

      expect(find.byType(PageCaisseFermee), findsOneWidget);
      expect(find.textContaining('6\u202F200'), findsNothing); // aveugle
      expect(find.textContaining('manque'), findsNothing);
      expect(env.voix.phrases.last, 'Caisse fermée. Merci.');
      await toucher(tester, find.byKey(const Key('bouton-fin-fermeture')));

      // La caisse est fermée : le prochain « Vendre » redemandera le fonds.
      expect(await tester.runAsync(env.etat.caisseOuverte), isFalse);

      // Le patron consulte le résultat.
      env.etat.deconnecter();
      await tester.runAsync(
        () => env.etat.verifierPin(env.etat.patron!, '482713'),
      );
      await attendre(tester);
      await ouvrirEspacePatron(tester);
      await toucher(tester, find.byKey(const Key('patron-fermetures')));
      await attendre(tester, tours: 8);
      expect(find.text('Il manque 200\u00A0F'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('fermeture-0')));
      expect(find.text('6\u202F200\u00A0F'), findsOneWidget); // attendu
      expect(find.text('6\u202F000\u00A0F'), findsOneWidget); // compté
      expect(find.textContaining('Kossi'), findsOneWidget);
    },
  );

  testWidgets(
    'patron : vente payée par Flooz → deux étapes ; espèces justes, Flooz 100 F en trop',
    (tester) async {
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
          // Dépense Flooz : notée, mais hors du comptage Flooz.
          await etat.depenser(
            500,
            motif: 'Transport',
            mode: ModePaiement.flooz,
          );
          await etat.retraitPatron(300, mode: ModePaiement.especes);
        },
      );
      await afficherApp(tester, env.etat);
      // Espèces : 5 000 + 1 200 − 300 = 5 900. Flooz reçu : 600.
      await toucherDansMaCaisse(tester, 'bouton-fermer-caisse');
      await attendre(tester, tours: 8);
      expect(find.text('Étape 1 sur 2'), findsOneWidget);
      await taperMontant(tester, '5900');
      await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
      expect(find.text('Étape 2 sur 2'), findsOneWidget);
      await taperMontant(tester, '700');
      await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
      await attendre(tester, tours: 10);

      expect(find.byType(PageResultatFermeture), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('ecart-especes'))).data,
        'Juste',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('ecart-flooz'))).data,
        'En trop : 100\u00A0F',
      );
      expect(find.byKey(const Key('ecart-mixx')), findsNothing);
    },
  );

  testWidgets('dépense payée par Flooz seule : pas d\'étape Flooz', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      preparer: (etat) async {
        await journeeEspeces(etat);
        await etat.depenser(500, motif: 'Repas', mode: ModePaiement.flooz);
      },
    );
    final modes = await tester.runAsync(env.etat.modesAFermer);
    expect(modes, [ModePaiement.especes]);
  });

  testWidgets(
    'nouvelle journée : seuls les mouvements après la fermeture comptent',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: journeeEspeces);
      final j = env.journal;
      await tester.runAsync(() async {
        await env.etat.fermerCaisse({ModePaiement.especes: 6200});
        await env.etat.ouvrirCaisse(2000);
        await env.etat.depenser(
          700,
          motif: 'Repas',
          mode: ModePaiement.especes,
        );
      });
      final enCours = await tester.runAsync(j.caisseEnCours);
      expect(enCours![ModePaiement.especes]!.attendu, 1300); // 2 000 − 700
      final liste = await tester.runAsync(() => j.fermetures());
      expect(liste!.single.resultat(ModePaiement.especes).ecart, 0);
    },
  );

  testWidgets('« Fermer la caisse » sans caisse ouverte : message', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await afficherApp(tester, env.etat);
    await toucherDansMaCaisse(tester, 'bouton-fermer-caisse');
    await attendre(tester, tours: 8);
    expect(find.text('La caisse n\'est pas ouverte.'), findsOneWidget);
    expect(find.byType(PageFermerCaisse), findsNothing);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('fermeture et résultat sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await journeeEspeces(etat);
          await etat.depenser(
            100000,
            motif: 'Achat de marchandise',
            mode: ModePaiement.mixx,
          );
        },
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await toucherDansMaCaisse(tester, 'bouton-fermer-caisse');
      await attendre(tester, tours: 8);
      expect(tester.takeException(), isNull);
      await taperMontant(tester, '1234000');
      await toucher(tester, find.byKey(const Key('bouton-suivant-fermeture')));
      await attendre(tester, tours: 10);
      expect(find.byType(PageResultatFermeture), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
