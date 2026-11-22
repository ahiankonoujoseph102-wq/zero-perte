// Un vendeur ne voit JAMAIS le prix d'achat ni le bénéfice : ni dans Vendre,
// ni à l'encaissement, ni sur le reçu, ni dans les ventes du jour, ni dans Ma
// caisse (fermeture comprise), ni dans Clients ; et il n'a accès à aucune page
// du patron (Tableau, Rapports, Produits et prix, Arrivages, Sauvegarde…).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';
import 'vente_test.dart' show boutiqueAvecStock, ouvrirLaCaisseSiDemande;

/// Tout le texte affiché à l'écran.
List<String> textesVisibles(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    w.data ?? w.textSpan?.toPlainText() ?? '',
  for (final w in tester.widgetList<RichText>(find.byType(RichText)))
    w.text.toPlainText(),
  for (final w in tester.widgetList<EditableText>(find.byType(EditableText)))
    w.controller.text,
];

void main() {
  const prixAchat = 337; // montant reconnaissable
  for (final e in {
    'téléphone': ecransDeTest['grand téléphone 6,5 pouces']!,
    'PC': ecransDeTest['PC 1366×768']!,
  }.entries) {
    final (taille, densite) = e.value;
    testWidgets('vendeur sur ${e.key} : ni prix d\'achat ni bénéfice', (
      tester,
    ) async {
      late int benefice;
      final env = await environnementDeTest(
        tester,
        preparer: (etat) async {
          await boutiqueAvecStock(etat);
          final savon = await etat.creerProduit(
            nom: 'Savon Lux',
            uniteBase: 'pièce',
            prixVente: 450,
            prixAchat: prixAchat,
            stockDepart: 20,
          );
          // Une vente du patron : il y a un bénéfice à cacher.
          await etat.journal.enregistrerVente(
            lignes: [LigneDemandee.quantite(produitId: savon.id, nombre: 3)],
            mode: ModePaiement.especes,
            montantRecu: 5000,
            auteurId: etat.auteurActuel,
          );
          benefice = (await etat.journal.beneficeEstime(depuis: 0)).benefice;
          await etat.ajouterVendeur(nom: 'Kossi', pin: '5913');
          etat.deconnecter();
        },
      );
      final interdits = [
        'énéfice',
        'achat',
        'Achat',
        'oût', // coût, Coût
        'marge',
        'Marge',
        formatFrancs(prixAchat),
        formatFrancs(benefice),
      ];
      final vus = <String>[];
      void verifier(String ecran) {
        vus.add(ecran);
        for (final t in textesVisibles(tester)) {
          for (final x in interdits) {
            expect(
              t.contains(x),
              isFalse,
              reason: '« $x » visible par le vendeur ($ecran) : « $t »',
            );
          }
        }
        expect(tester.takeException(), isNull, reason: ecran);
      }

      await afficherApp(tester, env.etat, taille: taille, densite: densite);
      await taperCode(tester, '5913');
      expect(env.etat.voitTout, isFalse);
      verifier('accueil');
      // Aucune page du patron.
      for (final cle in [
        'tableau',
        'rapports',
        'arrivages',
        'inventaire',
        'espace-patron',
        'vendeurs',
        'fournisseurs',
      ]) {
        for (final k in ['bouton-$cle', 'accueil-$cle', 'menu-$cle']) {
          expect(find.byKey(Key(k)), findsNothing, reason: k);
        }
      }
      expect(find.byKey(const Key('resume-du-jour')), findsNothing);

      // Vendre → encaisser → reçu.
      await toucher(tester, find.byKey(const Key('bouton-vendre')));
      await ouvrirLaCaisseSiDemande(tester);
      verifier('Vendre');
      final savon = env.etat.produits.firstWhere((p) => p.nom == 'Savon Lux');
      await toucher(tester, find.byKey(Key('vendre-${savon.id}')));
      if (find.byKey(const Key('choix-base')).evaluate().isNotEmpty) {
        await toucher(tester, find.byKey(const Key('choix-base')));
      }
      verifier('panier');
      await toucher(tester, find.byKey(const Key('bouton-encaisser')));
      verifier('encaissement');
      final billet = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('rapide-'),
      );
      await toucher(tester, billet.first);
      await toucher(tester, find.byKey(const Key('bouton-valider-vente')));
      verifier('reçu');
      await toucher(tester, find.byKey(const Key('bouton-nouvelle-vente')));

      // Ventes du jour et détail d'une vente.
      await toucher(tester, find.byKey(const Key('bouton-ventes-du-jour')));
      verifier('ventes du jour');
      final vente = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('vente-A-'),
      );
      if (vente.evaluate().isNotEmpty) {
        await toucher(tester, vente.first);
        verifier('détail d\'une vente');
      }

      // Ma caisse, puis la fermeture (comptage à l'aveugle).
      for (final el in find.byType(Navigator).evaluate().toList()) {
        final st = (el as StatefulElement).state as NavigatorState;
        if (st.mounted) st.popUntil((r) => r.isFirst);
      }
      await attendre(tester, tours: 4);
      await toucher(tester, find.byKey(const Key('bouton-ma-caisse')));
      verifier('Ma caisse');
      if (find.byKey(const Key('bouton-fermer-caisse')).evaluate().isNotEmpty) {
        await toucher(tester, find.byKey(const Key('bouton-fermer-caisse')));
        verifier('fermeture de la caisse');
      }

      // Clients.
      for (final el in find.byType(Navigator).evaluate().toList()) {
        final st = (el as StatefulElement).state as NavigatorState;
        if (st.mounted) st.popUntil((r) => r.isFirst);
      }
      await attendre(tester, tours: 4);
      await toucher(tester, find.byKey(const Key('bouton-credit')));
      verifier('Clients');
      expect(find.byKey(const Key('bouton-exporter-clients')), findsNothing);
      expect(vus.length, greaterThanOrEqualTo(8));
    });
  }
}
