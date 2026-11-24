// 0.37 : mise à jour depuis la 0.36.0 (base fabriquée par le VRAI code de la
// 0.36.0, test_perf/fabriquer_base_0360_test.dart) : profil, vente en gros,
// prix revendeur, produits comptés, vendeur, licence, tout est gardé.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/domaine/boutique.dart';
import 'package:zero_perte/domaine/operation.dart';

import '../support/outils.dart';

void main() {
  testWidgets('mise à jour depuis la 0.36.0 : rien ne se perd', (tester) async {
    final attendu = jsonDecode(
      File('test/fixtures/mise_a_jour/v0.36.0.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final dossier = Directory.systemTemp.createTempSync('zp-0360');
    addTearDown(() => dossier.deleteSync(recursive: true));
    final chemin = '${dossier.path}/base.db';
    File('test/fixtures/mise_a_jour/v0.36.0.db').copySync(chemin);
    final env = await environnementDeTest(tester, chemin: chemin);
    final etat = env.etat;
    await tester.runAsync(() async {
      final j = etat.journal;
      expect(etat.etape, EtapeAssistant.termine);
      expect(etat.installationTerminee, isTrue);
      expect(etat.licence, isNotNull);
      expect(etat.config.nom, attendu['boutique']);
      expect(etat.config.vente, FaconDeVendre.depuisCode(attendu['vente']));
      expect(etat.config.quiVend, QuiVend.depuisCode(attendu['qui_vend']));
      expect([for (final v in etat.vendeurs) v.nom], attendu['vendeurs']);
      expect(etat.vendeurs.single.id, attendu['vendeur_id']);
      expect({
        for (final p in etat.produits) p.nom: etat.stock(p.id),
      }, (attendu['stocks'] as Map).cast<String, int>());
      final conds = (attendu['conditionnements'] as Map).cast<String, List>();
      for (final p in etat.produits) {
        expect([
          for (final c in etat.grosDe(p.id))
            [c.nom, c.facteurMilliemes, c.prixVente],
        ], conds[p.nom]);
      }
      expect({
        for (final p in etat.produits)
          if (etat.estCompte(p.id)) p.nom,
      }, (attendu['comptes'] as List).toSet());
      expect(await j.totalCredits(), attendu['credits']);
      final r = await j.resumeVentes(depuis: 0);
      expect(r.total, attendu['ventes']);
      expect(r.nombre, attendu['nombre_ventes']);
      expect([
        for (final v in await j.ventesDepuis(0)) v.donnees['recu'],
      ], attendu['recus']);
      final ops = await j.mesOperationsApres(0);
      expect(ops.length, attendu['operations']);
      expect(ops.last.empreinte, attendu['derniere_empreinte']);
      expect(verifierChaine(ops), isEmpty);
      final db = await databaseFactoryFfi.openDatabase(
        chemin,
        options: OpenDatabaseOptions(singleInstance: false, readOnly: true),
      );
      expect(await db.getVersion(), 6);
      await db.close();
    });
    await afficherApp(tester, etat);
    expect(find.byKey(const Key('numero-etape')), findsNothing);
    expect(etat.installationTerminee, isTrue);
  });
}
