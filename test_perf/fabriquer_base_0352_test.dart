// Fabrique test/fixtures/mise_a_jour/v0.35.2.db avec le VRAI code de la 0.35.2
// (lancé une seule fois, AVANT la refonte 0.36) :
//   flutter test test_perf/fabriquer_base_0352_test.dart
// Boutique remplie : produits avec « emballages » (carton, sac), vendeur,
// arrivages, ventes au détail et au carton, crédit client, caisse fermée avec
// un manque, licence activée, installation terminée.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../test/domaine/licence_test.dart' show codeLicence;
import '../test/support/outils.dart';

void main() {
  testWidgets('fabriquer la base 0.35.2', (tester) async {
    final dossier = Directory.systemTemp.createTempSync('zp-0352');
    final chemin = '${dossier.path}/base.db';
    var t = DateTime(2026, 11, 20, 8).millisecondsSinceEpoch;
    final env = await environnementDeTest(tester, chemin: chemin, horloge: () => t);
    final etat = env.etat;
    final attendu = await tester.runAsync(() async {
      etat.maintenant = () => DateTime.fromMillisecondsSinceEpoch(t);
      await etat.activer(codeLicence);
      await etat.enregistrerConfig(etat.config.copie(nom: 'Boutique Mama Ama', telephone: '90112233', ville: 'Lomé'));
      await etat.definirPatron(nom: 'Ama', pin: '482713');
      final lait = await etat.creerProduit(nom: 'Lait', uniteBase: 'boîte', prixVente: 550, prixAchat: 450,
          conditionnements: [('carton de 24', 24, 12000)]);
      final savon = await etat.creerProduit(nom: 'Savon', uniteBase: 'morceau', prixVente: 250, prixAchat: 190,
          conditionnements: [('carton de 40', 40, 9000)]);
      final pain = await etat.creerProduit(nom: 'Pain', uniteBase: 'pièce', prixVente: 100);
      final conds = await etat.journal.conditionnements(lait.id);
      await etat.enregistrerArrivage(produit: lait, conditionnement: conds.first, nombre: 3, coutTotal: 32400);
      await etat.enregistrerArrivage(produit: savon, nombre: 50, coutTotal: 9500);
      final v = await etat.ajouterVendeur(nom: 'Kossi', pin: '5927');
      final client = await etat.enregistrerClient(nom: 'Yawa', telephone: '91002233', plafond: 50000);
      await etat.allerA(EtapeAssistant.termine);
      await etat.ouvrirCaisse(5000);
      Future<void> vente(List<LignePanier> l, ModePaiement m, {int? recu, String? cl}) async {
        t += 60000;
        final p = Panier();
        for (final x in l) {
          p.ajouter(x);
        }
        await etat.vendre(p, mode: m, montantRecu: recu, clientId: cl);
      }
      LignePanier ligne(p, c, int n) => LignePanier(produitId: p.id, nomProduit: p.nom, uniteBase: p.uniteBase,
          conditionnement: c, nombre: n, prixUnitaire: c?.prixVente ?? p.prixUnitaire);
      await vente([ligne(lait, null, 2), ligne(pain, null, 3)], ModePaiement.especes, recu: 2000);
      await vente([ligne(lait, conds.first, 1)], ModePaiement.especes, recu: 12000);
      await vente([ligne(savon, null, 4)], ModePaiement.mixx);
      await vente([ligne(savon, null, 10)], ModePaiement.credit, cl: client);
      t += 60000;
      // Caisse fermée avec 1 000 F de moins que prévu (espèces).
      final e = await etat.etatCaisse();
      await etat.fermerCaisse({ModePaiement.especes: e.attendus[ModePaiement.especes]! - 1000,
          ModePaiement.flooz: 0, ModePaiement.mixx: 1000});
      final j = etat.journal;
      final ops = await j.mesOperationsApres(0);
      final r = await j.resumeVentes(depuis: 0);
      return {
        'version': '0.35.2',
        'stocks': {for (final p in etat.produits) p.nom: etat.stock(p.id)},
        'conditionnements': {
          for (final p in etat.produits)
            p.nom: [for (final c in await j.conditionnements(p.id)) [c.nom, c.facteurMilliemes, c.prixVente]],
        },
        'credits': await j.totalCredits(),
        'ventes': r.total,
        'nombre_ventes': r.nombre,
        'operations': ops.length,
        'derniere_empreinte': ops.last.empreinte,
        'recus': [for (final v in await j.ventesDepuis(0)) v.donnees['recu']],
        'vendeurs': [for (final u in etat.vendeurs) u.nom],
        'vendeur_id': v.vendeur.id,
        'boutique': etat.config.nom,
      };
    });
    File(chemin).copySync('test/fixtures/mise_a_jour/v0.35.2.db');
    File('test/fixtures/mise_a_jour/v0.35.2.json').writeAsStringSync(jsonEncode(attendu));
    dossier.deleteSync(recursive: true);
  });
}
