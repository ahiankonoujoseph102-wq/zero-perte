import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/ecrans/caisse/saisie_montant.dart';
import 'package:zero_perte/ecrans/vente/page_vendre.dart';

import '../support/outils.dart';
import 'annulation_perte_test.dart' show vendreDeuxKg;
import 'vente_test.dart' show boutiqueAvecStock, ouvrirLaCaisseSiDemande;

Future<void> taperMontant(WidgetTester tester, String chiffres) async {
  for (final c in chiffres.split('')) {
    await toucher(tester, find.byKey(Key('montant-$c')));
  }
}

void main() {
  testWidgets(
    'fonds 5 000 F + vente 1 200 F − dépense 1 500 F − retrait 3 000 F → caisse attendue 1 700 F',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueAvecStock,
      );
      await afficherApp(tester, env.etat);

      // Premier « Vendre » : la caisse est d'abord ouverte.
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      expect(find.text('Ouvrir la caisse'), findsWidgets);
      await ouvrirLaCaisseSiDemande(tester, fonds: 5000);
      expect(find.byType(PageVendre), findsOneWidget);
      await vendreDeuxKg(tester);
      await tester.pageBack();
      await attendre(tester);

      // Deuxième « Vendre » : plus de question.
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await attendre(tester, tours: 8);
      expect(find.byType(PageSaisieMontant), findsNothing);
      expect(find.byType(PageVendre), findsOneWidget);
      await tester.pageBack();
      await attendre(tester);

      // Dépense de transport 1 500 F.
      await toucherDansMaCaisse(tester, 'bouton-depense');
      await toucher(tester, find.byKey(const Key('choix-depense-argent')));
      await taperMontant(tester, '1500');
      final bouton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('bouton-valider-montant-page')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(bouton.onPressed, isNull); // motif obligatoire
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('motif-Transport')));
      await toucher(
        tester,
        find.byKey(const Key('bouton-valider-montant-page')),
      );
      await attendre(tester, tours: 20);

      // Retrait du patron 3 000 F.
      await tester.runAsync(
        () => env.etat.retraitPatron(3000, mode: ModePaiement.especes),
      );

      final caisse = await tester.runAsync(
        () => env.journal.mouvementsCaisse(ModePaiement.especes),
      );
      expect(caisse!.fondsDeCaisse, 5000);
      expect(caisse.ventes, 1200);
      expect(caisse.depenses, 1500);
      expect(caisse.retraitsPatron, 3000);
      expect(caisse.attendu, 1700);
    },
  );

  testWidgets('dépense « Autre » avec motif écrit, payée en Flooz', (
    tester,
  ) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await afficherApp(tester, env.etat);
    await toucherDansMaCaisse(tester, 'bouton-depense');
    await toucher(tester, find.byKey(const Key('choix-depense-argent')));
    await toucher(tester, find.byKey(const Key('motif-Autre')));
    await tester.enterText(
      find.byKey(const Key('champ-motif-autre')),
      'Sachets',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await attendre(tester);
    await toucher(tester, find.byKey(const Key('mode-flooz')));
    await taperMontant(tester, '500');
    await toucher(tester, find.byKey(const Key('bouton-valider-montant-page')));
    await attendre(tester, tours: 20);
    final flooz = await tester.runAsync(
      () => env.journal.mouvementsCaisse(ModePaiement.flooz),
    );
    expect(flooz!.depenses, 500);
    final especes = await tester.runAsync(
      () => env.journal.mouvementsCaisse(ModePaiement.especes),
    );
    expect(especes!.depenses, 0);
  });

  testWidgets('« Argent pris » depuis l\'espace patron', (tester) async {
    final env = await environnementDeTest(tester, preparer: boutiqueAvecStock);
    await tester.runAsync(() => env.etat.ouvrirCaisse(10000));
    await afficherApp(tester, env.etat);
    await tester.runAsync(() async {});
    // Ouvre directement l'écran (l'accès à l'espace patron est testé ailleurs).
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => pageRetraitPatron(env.etat)));
    await attendre(tester);
    await taperMontant(tester, '2000');
    await toucher(tester, find.byKey(const Key('bouton-valider-montant-page')));
    await attendre(tester, tours: 20);
    final caisse = await tester.runAsync(
      () => env.journal.mouvementsCaisse(ModePaiement.especes),
    );
    expect(caisse!.retraitsPatron, 2000);
    expect(caisse.attendu, 8000);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets(
      'ouverture de caisse et dépense sur ${e.key} : rien ne déborde',
      (tester) async {
        final env = await environnementDeTest(
          tester,
          preparer: boutiqueAvecStock,
        );
        await afficherApp(tester, env.etat, taille: taille, densite: densite);
        await toucher(tester, find.byKey(const Key('bouton-vendre')));
        await attendre(tester, tours: 8);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('bouton-valider-montant-page')),
          findsOneWidget,
        );
        await tester.pageBack();
        await attendre(tester);
        await toucherDansMaCaisse(tester, 'bouton-depense');
        await toucher(tester, find.byKey(const Key('choix-depense-argent')));
        await toucher(tester, find.byKey(const Key('motif-Autre')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
