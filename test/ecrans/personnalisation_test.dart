import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/utilisateurs.dart';
import 'package:zero_perte/ecrans/accueil_vendeur.dart';

import '../support/outils.dart';

Future<void> taperPin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.tap(find.byKey(Key('pin-$c')));
    await tester.pump();
  }
  await attendre(tester, tours: 8);
}

void main() {
  testWidgets(
    'personnalisation complète : type → nom/photo → contact → couleur → produits → prix → reçu → code → fin',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        etape: EtapeAssistant.typeBoutique,
      );
      await afficherApp(
        tester,
        env.etat,
        taille: const Size(412, 915),
        densite: 2.625,
      );

      // 1. Type : alimentation générale + boissons.
      expect(find.byKey(const Key('bouton-continuer')), findsOneWidget);
      await toucher(tester, find.byKey(const Key('type-alimentation')));
      await toucher(tester, find.byKey(const Key('type-boissons')));
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.config.types, ['alimentation', 'boissons']);

      // 2. Nom + photo.
      await tester.enterText(
        find.byKey(const Key('champ-nom')),
        'Boutique Mama Ama',
      );
      await toucher(tester, find.byKey(const Key('photo-galerie')));
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.config.nom, 'Boutique Mama Ama');
      expect(env.etat.config.logo, isNotNull);
      // Ensuite vient l'étape 2 sur 3 (les deux questions).
      expect(env.etat.etape, EtapeAssistant.profil);

      // 0.36 : cette étape n'est plus dans le démarrage (elle est dans
      // Gestion → Ma boutique) ; on l'ouvre directement pour la vérifier.
      await tester.runAsync(() => env.etat.allerA(EtapeAssistant.contact));
      await attendre(tester);
      // 3. Contact : numéro mal tapé puis corrigé.
      await tester.enterText(
        find.byKey(const Key('champ-telephone')),
        '9012345',
      );
      await tester.pump();
      expect(find.textContaining('Il faut 8 chiffres'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('champ-telephone')),
        '90 12 34 56',
      );
      await toucher(tester, find.byKey(const Key('champ-ville')));
      await toucher(tester, find.text('Lomé').last);
      await tester.enterText(
        find.byKey(const Key('champ-quartier')),
        'Bè-Kpota',
      );
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.config.telephone, '+228 90 12 34 56');
      expect(env.etat.config.adresse, 'Bè-Kpota, Lomé');

      // 0.36 : cette étape n'est plus dans le démarrage (elle est dans
      // Gestion → Ma boutique) ; on l'ouvre directement pour la vérifier.
      await tester.runAsync(() => env.etat.allerA(EtapeAssistant.couleur));
      await attendre(tester);
      // 4. Couleur : prune.
      await toucher(tester, find.byKey(const Key('couleur-ff7a2e5c')));
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(env.etat.config.couleur, 0xFF7A2E5C);

      // 0.36 : cette étape n'est plus dans le démarrage (elle est dans
      // Gestion → Ma boutique) ; on l'ouvre directement pour la vérifier.
      await tester.runAsync(() => env.etat.allerA(EtapeAssistant.produits));
      await attendre(tester);
      // 5. Produits : riz et bière (grande bouteille).
      await toucher(tester, find.byKey(const Key('produit-alimentation.riz')));
      await toucher(
        tester,
        find.byKey(const Key('produit-boissons.biere_grande')),
      );
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      expect(
        env.etat.produits.map((p) => p.nom),
        containsAll(['Riz', 'Bière, grande bouteille']),
      );
      expect(env.etat.produits.every((p) => !p.aUnPrix), isTrue);

      // 0.36 : cette étape n'est plus dans le démarrage (elle est dans
      // Gestion → Ma boutique) ; on l'ouvre directement pour la vérifier.
      await tester.runAsync(() => env.etat.allerA(EtapeAssistant.prix));
      await attendre(tester);
      // 6. Prix : riz 600 F le kg, sac de 50 kg à 28 000 F ; bière 600 F, casier 7 000 F.
      await tester.enterText(
        find.byKey(const Key('prix-alimentation.riz')),
        '600',
      );
      await tester.enterText(
        find.byKey(const Key('prix-alimentation.riz-sac de 50 kg')),
        '28000',
      );
      await tester.enterText(
        find.byKey(const Key('prix-boissons.biere_grande')),
        '600',
      );
      await tester.enterText(
        find.byKey(const Key('prix-boissons.biere_grande-casier')),
        '7000',
      );
      await toucher(tester, find.byKey(const Key('bouton-continuer')));
      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(riz.prixUnitaire, 600);
      final conds = await tester.runAsync(
        () => env.journal.conditionnements(riz.id),
      );
      expect(
        conds!.firstWhere((c) => c.nom == 'sac de 50 kg').prixVente,
        28000,
      );

      // 0.36 : cette étape n'est plus dans le démarrage (elle est dans
      // Gestion → Ma boutique) ; on l'ouvre directement pour la vérifier.
      await tester.runAsync(() => env.etat.allerA(EtapeAssistant.recu));
      await attendre(tester);
      // 7. Reçu : aperçu + message.
      expect(find.byKey(const Key('apercu-recu')), findsOneWidget);
      expect(find.text('Boutique Mama Ama'), findsWidgets);
      await toucher(tester, find.byKey(const Key('bouton-continuer')));

      // 8. Code secret : trop facile refusé, puis deux codes différents, puis bon.
      await tester.enterText(find.byKey(const Key('champ-nom-patron')), 'Ama');
      await taperPin(tester, '123456');
      expect(find.byKey(const Key('pin-erreur')), findsOneWidget);
      await taperPin(tester, '482713');
      await taperPin(tester, '482814');
      expect(find.textContaining('différents'), findsOneWidget);
      await taperPin(tester, '482713');
      await taperPin(tester, '482713');
      expect(env.etat.patron!.nom, 'Ama');
      expect(
        await tester.runAsync(() => pinCorrect(env.etat.patron!, '482713')),
        isTrue,
      );

      // 9. Fin : raccourci puis Commencer.
      expect(env.etat.etape, EtapeAssistant.fin);
      await toucher(tester, find.byKey(const Key('bouton-raccourci')));
      expect(env.raccourcis, ['Boutique Mama Ama']);
      await toucher(tester, find.byKey(const Key('bouton-commencer-vendre')));
      expect(find.byType(AccueilVendeur), findsOneWidget);
      expect(find.text('Boutique Mama Ama'), findsOneWidget);
    },
  );

  testWidgets('sans aucun type choisi, on ne peut pas continuer', (
    tester,
  ) async {
    final env = await environnementDeTest(
      tester,
      etape: EtapeAssistant.typeBoutique,
    );
    await afficherApp(tester, env.etat);
    final bouton = tester.widget<FilledButton>(
      find.byKey(const Key('bouton-continuer')),
    );
    expect(bouton.onPressed, isNull);
  });

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    for (final etape in [
      EtapeAssistant.typeBoutique,
      EtapeAssistant.identite,
      EtapeAssistant.contact,
      EtapeAssistant.couleur,
      EtapeAssistant.produits,
      EtapeAssistant.prix,
      EtapeAssistant.recu,
      EtapeAssistant.codePatron,
      EtapeAssistant.fin,
    ]) {
      testWidgets('« ${etape.name} » sur ${e.key} : rien ne déborde', (
        tester,
      ) async {
        final env = await environnementDeTest(
          tester,
          etape: etape,
          preparer: (etat) async {
            await etat.enregistrerConfig(
              etat.config.copie(
                nom: 'Quincaillerie l\'Espoir',
                types: ['quincaillerie'],
              ),
            );
            await etat.ajouterDuCatalogue(
              etat.catalogue.produitsDe(['quincaillerie']).take(3),
            );
          },
        );
        await afficherApp(tester, env.etat, taille: taille, densite: densite);
        expect(tester.takeException(), isNull);
        final bouton = find.byKey(const Key('bouton-ecouter'));
        if (etape != EtapeAssistant.codePatron) {
          final r = tester.getRect(bouton);
          expect(r.bottom <= taille.height, isTrue);
        }
      });
    }
  }
}
