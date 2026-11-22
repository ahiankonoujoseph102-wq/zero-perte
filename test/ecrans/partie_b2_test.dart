// Partie B2 (réponses à l'audit) : résumé du soir, « Commander » au
// fournisseur, rappel des crédits en retard, « Chiffres ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/patron/chiffres.dart';

import '../support/outils.dart';
import 'tableau_test.dart' show journee;
import 'vente_test.dart' show boutiqueAvecStock;
import 'vendeurs_test.dart' show ouvrirEspacePatron;

const jour = Duration.millisecondsPerDay;

void main() {
  testWidgets(
    'crédits en retard : Kofi (20 jours) oui ; Ama (3 jours) et Yao (a payé '
    'il y a 2 jours) non ; un toucher ouvre WhatsApp avec le rappel',
    (tester) async {
      var t = DateTime(2026, 11, 1, 10).millisecondsSinceEpoch;
      final env = await environnementDeTest(
        tester,
        horloge: () => t,
        preparer: (etat) async {
          etat.maintenant = () => DateTime.fromMillisecondsSinceEpoch(t);
          await boutiqueAvecStock(etat);
          await etat.ouvrirCaisse(0);
          final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
          Future<void> credit(String nom, String tel) async {
            await etat.enregistrerClient(
              nom: nom,
              telephone: tel,
              plafond: 50000,
            );
            final c = (await etat.journal.clients()).firstWhere(
              (c) => c.nom == nom,
            );
            await etat.journal.enregistrerVente(
              lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 2)],
              mode: ModePaiement.credit,
              clientId: c.id,
              auteurId: etat.auteurActuel,
            );
          }

          await credit('Kofi', '90112233');
          await credit('Yao', '90445566');
          t += 18 * jour;
          final yao = (await etat.journal.clients()).firstWhere(
            (c) => c.nom == 'Yao',
          );
          await etat.rembourser(yao, 200, mode: ModePaiement.especes);
          await credit('Ama', '90778899');
          t += 2 * jour;
        },
      );
      final l = (await tester.runAsync(() => env.etat.creditsEnRetard()))!;
      expect([for (final (c, j) in l) '${c.nom} $j'], ['Kofi 20']);

      await afficherApp(tester, env.etat);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      await attendre(tester, tours: 8);
      expect(
        find.text('1 crédit en retard : rappeler en un toucher'),
        findsOne,
      );
      await toucher(tester, find.byKey(const Key('bandeau-retards')));
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('retard-Kofi')), findsOneWidget);
      expect(find.byKey(const Key('retard-Yao')), findsNothing);
      await toucher(tester, find.byKey(const Key('rappeler-Kofi')));
      await attendre(tester);
      final lien = env.liens.single;
      expect(lien.host, 'wa.me');
      expect(lien.path, '/22890112233');
      expect(lien.queryParameters['text'], contains(formatFrancs(1200)));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    },
  );

  for (final e in ecransDeTest.entries) {
    testWidgets('Chiffres sur ${e.key} : résumé, rapport, Commander', (
      tester,
    ) async {
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
      final (taille, densite) = e.value;
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'chiffres');
      await attendre(tester, tours: 10);
      expect(find.byType(PageChiffres), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chiffre-ventes')), findsOneWidget);

      // Stock bas (sucre épuisé) → Commander → le fournisseur.
      await tester.scrollUntilVisible(
        find.byKey(const Key('bouton-commander')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await toucher(tester, find.byKey(const Key('bouton-commander')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('commander-a-Ets Koffi')));
      await attendre(tester);
      final lien = env.liens.single;
      expect(lien.path, '/22891002200');
      final texte = lien.queryParameters['text']!;
      expect(texte, startsWith('Bonjour Ets Koffi,'));
      expect(texte, contains('Commande de Boutique Mama Ama'));
      expect(texte, contains('- Sucre'));

      // Onglet « À envoyer » : l'ancien « Rapports ».
      await toucher(tester, find.byKey(const Key('onglet-rapport')));
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('rapport-titre')), findsOneWidget);
      expect(find.byKey(const Key('bouton-export-csv')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Commander sans fournisseur enregistré : WhatsApp choisit le contact',
    (tester) async {
      final env = await environnementDeTest(tester, preparer: journee);
      await afficherApp(tester, env.etat);
      await ouvrirEspacePatron(tester);
      await ouvrirPagePatron(tester, 'chiffres');
      await attendre(tester, tours: 10);
      await tester.scrollUntilVisible(
        find.byKey(const Key('bouton-commander')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await toucher(tester, find.byKey(const Key('bouton-commander')));
      await attendre(tester, tours: 6);
      await toucher(tester, find.byKey(const Key('commander-autre')));
      await attendre(tester);
      expect(env.liens.single.path, '/');
      expect(env.liens.single.queryParameters['text'], startsWith('Bonjour,'));
    },
  );

  for (final e in ecransDeTest.entries) {
    testWidgets(
      'résumé du soir sur ${e.key} : caisse fermée par Kossi, le patron le voit '
      'une seule fois et peut l\'envoyer sur WhatsApp',
      (tester) async {
        final env = await environnementDeTest(
          tester,
          preparer: (etat) async {
            await boutiqueAvecStock(etat);
            await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
            etat.deconnecter();
            await etat.connecterParCode('5913');
            await etat.ouvrirCaisse(1000);
            final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
            await etat.journal.enregistrerVente(
              lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 2)],
              mode: ModePaiement.especes,
              montantRecu: 1200,
              auteurId: etat.auteurActuel,
            );
            // 2 200 F attendus, 1 700 F comptés : il manque 500 F.
            await etat.fermerCaisse({ModePaiement.especes: 1700});
            etat.deconnecter();
          },
        );
        final (taille, densite) = e.value;
        await afficherApp(tester, env.etat, taille: taille, densite: densite);
        // Le vendeur ne voit jamais le résumé.
        expect(find.byKey(const Key('resume-soir')), findsNothing);
        await taperCode(tester, '482713', fermerResumeSoir: false);
        await attendre(tester, tours: 12);
        expect(find.byKey(const Key('resume-soir')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Text>(find.byKey(const Key('resume-soir-ventes'))).data,
          formatFrancs(1200),
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('resume-soir-ecart'))).data,
          'il manque ${formatFrancs(500)}',
        );
        await toucher(tester, find.byKey(const Key('bouton-resume-whatsapp')));
        await attendre(tester, tours: 6);
        expect(find.byKey(const Key('resume-soir')), findsNothing);
        final texte = env.liens.single.queryParameters['text']!;
        expect(texte, startsWith('Résumé du soir – Boutique Mama Ama'));
        expect(
          texte,
          contains('Caisse fermée par Kossi : il manque ${formatFrancs(500)}'),
        );
        // Rien n'a été envoyé tout seul : seulement le lien ouvert par le patron.
        expect(env.liens, hasLength(1));
        // Vu : il ne revient pas.
        env.etat.notifyListeners();
        await attendre(tester, tours: 8);
        expect(find.byKey(const Key('resume-soir')), findsNothing);
      },
    );
  }

  testWidgets(
    'le patron qui ferme lui-même sa caisse ne reçoit pas de résumé',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          await etat.ouvrirCaisse(0);
          await etat.fermerCaisse({ModePaiement.especes: 0});
        },
      );
      await afficherApp(tester, env.etat);
      await attendre(tester, tours: 8);
      expect(find.byKey(const Key('resume-soir')), findsNothing);
    },
  );
}
