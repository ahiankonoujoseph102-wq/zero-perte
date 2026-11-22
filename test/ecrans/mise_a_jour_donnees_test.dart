// Mise à jour sans perte : bases fabriquées par le VRAI code des versions
// 0.29.0, 0.30.0 et 0.31.0 (test/fixtures/mise_a_jour), ouvertes par cette
// version : migration (schéma 6), mêmes stocks, crédits, ventes et reçus,
// chaîne du journal intacte ; puis une vente, la synchronisation vers un
// autre appareil, et la sauvegarde / restauration.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/donnees/journal_local.dart';

import '../support/outils.dart';

void main() {
  for (final v in ['v0.29.0', 'v0.30.0', 'v0.31.0']) {
    testWidgets('mise à jour depuis $v : rien ne se perd', (tester) async {
      final attendu = jsonDecode(
        File('test/fixtures/mise_a_jour/$v.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final dossier = Directory.systemTemp.createTempSync('zp-maj');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final chemin = '${dossier.path}/base.db';
      File('test/fixtures/mise_a_jour/$v.db').copySync(chemin);

      final env = await environnementDeTest(tester, chemin: chemin);
      final etat = env.etat;
      await tester
          .runAsync(() async {
            final j = etat.journal;
            // Migration faite.
            // Seconde connexion à part (ne pas fermer celle de l'application).
            final db = await databaseFactoryFfi.openDatabase(
              chemin,
              options: OpenDatabaseOptions(
                singleInstance: false,
                readOnly: true,
              ),
            );
            expect(await db.getVersion(), 6);
            await db.close();
            // Mêmes chiffres qu'avant la mise à jour.
            expect({
              for (final p in etat.produits) p.nom: etat.stock(p.id),
            }, (attendu['stocks'] as Map).cast<String, int>());
            expect(await j.totalCredits(), attendu['credits']);
            final r = await j.resumeVentes(depuis: 0);
            expect(r.total, attendu['ventes']);
            expect(r.nombre, attendu['nombre_ventes']);
            expect([
              for (final v in await j.ventesDepuis(0)) v.donnees['recu'],
            ], attendu['recus']);
            var ops = await j.mesOperationsApres(0);
            expect(ops.length, attendu['operations']);
            expect(ops.last.empreinte, attendu['derniere_empreinte']);
            expect(verifierChaine(ops), isEmpty);
            // Une nouvelle vente (rangée compressée) continue la chaîne.
            final riz = etat.produits.firstWhere((p) => p.nom == 'Riz');
            final vente = await j.enregistrerVente(
              lignes: [LigneDemandee.quantite(produitId: riz.id, nombre: 1)],
              mode: ModePaiement.especes,
              montantRecu: 1000,
              auteurId: etat.auteurActuel,
            );
            expect(vente.recu, 'A-000005');
            ops = await j.mesOperationsApres(0);
            expect(verifierChaine(ops), isEmpty);
            await etat.rechargerTout();
            final stockApres = etat.stock(riz.id);
            expect(stockApres, (attendu['stocks'] as Map)['Riz'] - 1000);

            // Synchronisation vers un autre appareil (téléphone ou PC : même
            // format de fichier).
            final autre = await JournalLocal.ouvrir(
              fabrique: databaseFactoryFfi,
              chemin: inMemoryDatabasePath,
            );
            final recues = await autre.importerOperations(
              JournalLocal.operationsDepuisJson(
                JournalLocal.operationsVersJson(ops),
              ),
            );
            expect(recues, ops.length);
            expect((await autre.stocks())[riz.id], stockApres);
            expect(await autre.totalCredits(), attendu['credits']);
            await autre.fermer();

            // Sauvegarde puis restauration sur un appareil neuf.
            final fichier = await etat.creerSauvegarde('482713');
            return fichier;
          })
          .then((fichier) async {
            final neuf = await environnementDeTest(tester);
            await tester.runAsync(() async {
              final n = await neuf.etat.restaurerSauvegarde(fichier!, '482713');
              expect(n, greaterThan(0));
              final riz = neuf.etat.produits.firstWhere((p) => p.nom == 'Riz');
              expect(
                neuf.etat.stock(riz.id),
                (attendu['stocks'] as Map)['Riz'] - 1000,
              );
              expect(
                await neuf.etat.journal.totalCredits(),
                attendu['credits'],
              );
            });
          });
    });
  }
}
