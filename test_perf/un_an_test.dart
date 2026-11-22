// Tenue dans le temps : boutique d'essai avec 1 an d'activité
// (200 ventes par jour = 73 000 ventes, 300 produits, 200 clients dont 50 à
// crédit). Mesure les temps et les tailles.
// Lancement (1 seul cœur, pour s'approcher d'un petit téléphone) :
//   taskset -c 0 flutter test test_perf/un_an_test.dart
// La base fabriquée est gardée dans $ZP_PERF_DIR (réutilisée si présente).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/tableau.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../test/support/outils.dart';

final jours = int.parse(Platform.environment['ZP_PERF_JOURS'] ?? '365');
const ventesParJour = 200;

Future<T> chrono<T>(String nom, Future<T> Function() f, List<String> r) async {
  final w = Stopwatch()..start();
  final x = await f();
  r.add('$nom : ${w.elapsedMilliseconds} ms');
  return x;
}

void main() {
  testWidgets('une année de boutique', (tester) async {
    final dossier = Platform.environment['ZP_PERF_DIR'] ?? '/tmp/zp-perf';
    Directory(dossier).createSync(recursive: true);
    final chemin = '$dossier/un_an.db';
    final existe = File(chemin).existsSync();
    final debutAnnee = DateTime(2025, 11, 22, 8).millisecondsSinceEpoch;
    var maintenant = debutAnnee;
    final env = await environnementDeTest(
      tester,
      etape: existe ? null : EtapeAssistant.termine,
      chemin: chemin,
      horloge: () => maintenant,
    );
    final etat = env.etat;
    final r = <String>[];
    await tester.runAsync(() async {
      if (!existe) {
        final w = Stopwatch()..start();
        await boutiqueInstallee(etat);
        final patron = etat.patron!.id;
        // 300 produits : le catalogue, puis des variantes.
        final cat = [for (final c in etat.catalogue.categories) ...c.produits];
        await etat.ajouterDuCatalogue(cat);
        var i = 0;
        while (etat.produits.length < 300) {
          final c = cat[i % cat.length];
          await etat.journal.definirProduit(
            nom: '${c.nom} ${i ~/ cat.length + 2}',
            uniteBase: c.unite,
            prixUnitaire: 100,
            emoji: c.emoji,
            auteurId: patron,
          );
          i++;
          if (i % 50 == 0) await etat.rechargerProduits();
        }
        await etat.rechargerProduits();
        final rnd = Random(7);
        for (final p in etat.produits) {
          await etat.journal.definirProduit(
            produitId: p.id,
            nom: p.nom,
            uniteBase: p.uniteBase,
            prixUnitaire: 100 + rnd.nextInt(40) * 50,
            emoji: p.emoji,
            catalogueId: p.catalogueId,
            auMontant: p.auMontant,
            auteurId: patron,
          );
        }
        await etat.rechargerProduits();
        // 200 clients, dont 50 à crédit.
        final clients = <String>[];
        for (var k = 0; k < 200; k++) {
          clients.add(
            await etat.enregistrerClient(
              nom: 'Client $k',
              telephone: '+2289${(1000000 + k).toString().padLeft(7, '0')}',
              plafond: 50000,
            ),
          );
        }
        // Une année de ventes (1 à 4 produits par vente).
        final produits = etat.produits.where((p) => !p.auMontant).toList();
        for (var j = 0; j < jours; j++) {
          for (var v = 0; v < ventesParJour; v++) {
            maintenant = debutAnnee + j * 86400000 + v * 180000;
            final n = 1 + rnd.nextInt(4);
            final credit = rnd.nextInt(40) == 0;
            final lignes = [
              for (var l = 0; l < n; l++)
                LigneDemandee.quantite(
                  produitId: produits[rnd.nextInt(produits.length)].id,
                  nombre: 1 + rnd.nextInt(3),
                ),
            ];
            try {
              await etat.journal.enregistrerVente(
                lignes: lignes,
                mode: credit ? ModePaiement.credit : ModePaiement.especes,
                montantRecu: credit ? null : 1000000,
                clientId: credit ? clients[rnd.nextInt(50)] : null,
                auteurId: patron,
              );
            } on ErreurZeroPerte {
              // Plafond du client atteint : il paie en espèces.
              await etat.journal.enregistrerVente(
                lignes: lignes,
                mode: ModePaiement.especes,
                montantRecu: 1000000,
                auteurId: patron,
              );
            }
          }
        }
        r.add('Fabrication de l\'année : ${w.elapsed.inSeconds} s');
      }
      maintenant = debutAnnee + (jours - 1) * 86400000 + 11 * 3600000;
      final taille =
          File(chemin).lengthSync() +
          (File('$chemin-wal').existsSync()
              ? File('$chemin-wal').lengthSync()
              : 0);
      r.add('Taille de la base : ${(taille / 1048576).toStringAsFixed(1)} Mo');

      // Démarrage : ouvrir la base et charger l'état.
      await etat.journal.fermer();
      await chrono('Démarrage (base + état)', () async {
        final j = await JournalLocal.ouvrir(
          fabrique: databaseFactoryFfi,
          chemin: chemin,
          horloge: () => maintenant,
        );
        await j.produits();
        await j.stocks();
        await j.fermer();
      }, r);
      final j2 = await JournalLocal.ouvrir(
        fabrique: databaseFactoryFfi,
        chemin: chemin,
        horloge: () => maintenant,
      );
      await chrono('Ouvrir Vendre (produits + stocks)', () async {
        await j2.produits();
        await j2.stocks();
      }, r);
      final ps = (await j2.produits()).where((p) => !p.auMontant).toList();
      final patronId = (await j2.utilisateurs())
          .firstWhere((u) => u.role.name == 'patron')
          .id;
      await chrono('Encaisser une vente', () async {
        await j2.enregistrerVente(
          lignes: [
            LigneDemandee.quantite(produitId: ps.first.id, nombre: 2),
            LigneDemandee.quantite(produitId: ps.last.id, nombre: 1),
          ],
          mode: ModePaiement.especes,
          montantRecu: 1000000,
          auteurId: patronId,
        );
        await j2.produits();
        await j2.stocks();
      }, r);
      await j2.fermer();
    });
    // Le reste passe par l'état de l'application (comme les écrans).
    final env2 = await environnementDeTest(
      tester,
      chemin: chemin,
      horloge: () => maintenant,
    );
    await tester.runAsync(() async {
      final e = env2.etat;
      for (final p in Periode.values) {
        await chrono('Tableau (${p.libelle})', () => e.tableau(p), r);
      }
      await chrono('Ventes du jour', () => e.ventesDuJour(), r);
      await chrono(
        'Inventaire (300 produits)',
        () => e.faireInventaire({for (final p in e.produits) p.id: 1000}),
        r,
      );
      final sauvegarde = await chrono(
        'Sauvegarde',
        () => e.creerSauvegarde('482713'),
        r,
      );
      r.add(
        'Taille de la sauvegarde : '
        '${(sauvegarde.length / 1048576).toStringAsFixed(1)} Mo',
      );
      final ops = await chrono(
        'Lire les opérations à synchroniser',
        () => e.journal.mesOperationsApres(0),
        r,
      );
      final json = JournalLocal.operationsVersJson(ops);
      r.add(
        'Opérations : ${ops.length} ; envoyées à la première '
        'synchronisation : ${(json.length / 1048576).toStringAsFixed(1)} Mo',
      );
    });
    // ignore: avoid_print
    print('\n=== MESURE UN AN ===\n${r.join('\n')}\n');
  }, timeout: Timeout.none);
}
