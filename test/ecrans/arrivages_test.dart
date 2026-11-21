import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/ecrans/patron/espace_patron.dart';

import 'package:zero_perte/ecrans/communs.dart' show demanderPin;

import '../support/outils.dart';

void main() {
  testWidgets(
    'espace patron : code secret, puis arrivage de 2 sacs de riz → stock 100 kg',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      await afficherApp(tester, env.etat);

      // Le patron est entré avec son code : « Gestion » s'ouvre directement.
      await toucher(tester, find.byKey(const Key('bouton-espace-patron')));
      expect(find.byType(EspacePatron), findsOneWidget);

      await toucher(tester, find.byKey(const Key('patron-arrivages')));
      expect(find.textContaining('En stock : 0 kg'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('arrivage-alimentation.riz')));
      // Par défaut : le plus grand conditionnement (sac de 50 kg).
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('unite-sac de 50 kg')))
            .selected,
        isTrue,
      );
      await toucher(tester, find.byKey(const Key('plus')));
      expect(find.text('2'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('champ-cout')), '50000');
      await tester.pump();
      expect(find.textContaining('Soit 25'), findsOneWidget); // 25 000 F le sac
      await toucher(
        tester,
        find.byKey(const Key('bouton-enregistrer-arrivage')),
      );

      final riz = env.etat.produits.firstWhere((p) => p.nom == 'Riz');
      expect(env.etat.stock(riz.id), 100000); // 2 × 50 kg
      expect(
        find.textContaining('Arrivage enregistré : 2 sacs de 50 kg de Riz'),
        findsOneWidget,
      );
      expect(find.textContaining('En stock : 2 sacs de 50 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'accord du patron : 5 codes faux → bloqué 5 minutes, même le bon code est refusé',
    (tester) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      await afficherApp(tester, env.etat);
      // L'accord du patron (code demandé) sert aux retours et aux gros montants.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('demander-accord'),
                onPressed: () async {
                  if (await demanderPin(
                        context,
                        env.etat,
                        env.etat.patron!,
                        titre: 'Accord du patron',
                      ) &&
                      context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EspacePatron(etat: env.etat),
                      ),
                    );
                  }
                },
                child: const Text('Accord'),
              ),
            ),
          ),
        ),
      );
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('demander-accord')));
      for (var i = 0; i < 4; i++) {
        await taperPin(tester, '111111');
      }
      expect(find.textContaining('Encore 1 essai'), findsOneWidget);
      await taperPin(tester, '111111');
      expect(find.textContaining('Trop d\'erreurs'), findsOneWidget);
      await taperPin(tester, '482713'); // bon code, mais bloqué
      expect(find.byType(EspacePatron), findsNothing);

      // 6 minutes plus tard : débloqué.
      env.etat.maintenant = () =>
          DateTime.now().add(const Duration(minutes: 6));
      await taperPin(tester, '482713');
      expect(find.byType(EspacePatron), findsOneWidget);
    },
  );

  for (final e in ecransDeTest.entries) {
    final (taille, densite) = e.value;
    testWidgets('formulaire d\'arrivage sur ${e.key} : rien ne déborde', (
      tester,
    ) async {
      final env = await environnementDeTest(
        tester,
        preparer: boutiqueInstallee,
      );
      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => EspacePatron(etat: env.etat)));
      await attendre(tester);
      await toucher(tester, find.byKey(const Key('patron-arrivages')));
      await toucher(tester, find.byKey(const Key('arrivage-alimentation.riz')));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('bouton-enregistrer-arrivage')),
        findsOneWidget,
      );
    });
  }
}
