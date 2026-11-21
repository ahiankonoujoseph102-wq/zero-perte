import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/domaine/calculs.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/domaine/boutique.dart';
import 'package:zero_perte/domaine/utilisateurs.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/donnees/schema.dart';

void main() {
  sqfliteFfiInit();

  late JournalLocal j;
  var heure = 1700000000000;

  setUp(() async {
    heure = 1700000000000;
    j = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: inMemoryDatabasePath,
      prefixeRecu: 'A',
      horloge: () => heure += 1000,
    );
  });

  tearDown(() => j.fermer());

  /// Riz : 650 F le bol ; sac de 40 bols vendu 23 000 F ; acheté 21 000 F le sac.
  Future<({String riz, String sac})> preparerRiz() async {
    final riz = await j.definirProduit(
      nom: 'Riz parfumé',
      uniteBase: 'bol',
      prixUnitaire: 650,
      auteurId: 'patron',
    );
    final sac = await j.definirConditionnement(
      produitId: riz,
      nom: 'sac',
      facteurMilliemes: 40000,
      prixVente: 23000,
      auteurId: 'patron',
    );
    await j.enregistrerArrivage(
      produitId: riz,
      conditionnementId: sac,
      nombre: 2,
      coutTotal: 42000,
      auteurId: 'patron',
    );
    return (riz: riz, sac: sac);
  }

  test('scénario complet : arrivage, ventes, vente au montant, annulation, stock et bénéfice', () async {
    final p = await preparerRiz();
    expect(await j.stockMilliemes(p.riz), 80000); // 2 sacs = 80 bols

    // Vente 1 : 5 bols en espèces, le client donne 5 000 F.
    final v1 = await j.enregistrerVente(
      lignes: [LigneDemandee.quantite(produitId: p.riz, nombre: 5)],
      mode: ModePaiement.especes,
      montantRecu: 5000,
      auteurId: 'vendeur',
    );
    expect(v1.recu, 'A-000001');
    expect(v1.total, 3250);
    expect(v1.monnaie!.aRendre, 1750);

    // Vente 2 : 1 sac payé par Flooz.
    final v2 = await j.enregistrerVente(
      lignes: [
        LigneDemandee.quantite(
          produitId: p.riz,
          conditionnementId: p.sac,
          nombre: 1,
        ),
      ],
      mode: ModePaiement.flooz,
      referencePaiement: '4821',
      auteurId: 'vendeur',
    );
    expect(v2.recu, 'A-000002');
    expect(v2.total, 23000);

    // Vente 3 : « donne pour 100 F » de riz.
    final v3 = await j.enregistrerVente(
      lignes: [LigneDemandee.auMontant(produitId: p.riz, montant: 100)],
      mode: ModePaiement.especes,
      montantRecu: 100,
      auteurId: 'vendeur',
    );
    expect(v3.recu, 'A-000003');

    // Stock : 80 − 5 − 40 − 0,154 bol (100 F ÷ 650 F) = 34,846 bols.
    expect(await j.stockMilliemes(p.riz), 80000 - 5000 - 40000 - 154);

    // Annulation de la vente 1 (motif obligatoire) : les 5 bols reviennent.
    await j.annulerVente(
      venteOperationId: v1.operation.id,
      motif: 'erreur de produit',
      auteurId: 'vendeur',
    );
    expect(await j.stockMilliemes(p.riz), 80000 - 40000 - 154);
    expect(
      () => j.annulerVente(
        venteOperationId: v1.operation.id,
        motif: 'encore',
        auteurId: 'vendeur',
      ),
      throwsA(isA<ErreurZeroPerte>()),
    );

    // Bénéfice : coût d'un bol = 42 000 F / 80 bols = 525 F.
    //   vente 2 : 23 000 − 40 × 525 (21 000) = 2 000 F
    //   vente 3 : 100 − 0,154 × 525 (81 F) = 19 F
    //   vente 1 annulée : 0
    final b = await j.beneficeEstime();
    expect(b.ventes, 23100);
    expect(b.couts, 21081);
    expect(b.benefice, 2019);
    expect(b.lignesSansCout, 0);

    // Le journal est une chaîne intacte de 7 opérations numérotées 1 à 7.
    final ops = await j.operationsDuTelephone(j.telephoneId);
    expect(ops.map((o) => o.numero), [1, 2, 3, 4, 5, 6, 7]);
    expect(await j.verifierMaChaine(), isEmpty);
  });

  test('caisse espèces : fonds, ventes, dépense, retrait du patron, consigne → écart', () async {
    final p = await preparerRiz();
    await j.enregistrerFondsDeCaisse(5000, auteurId: 'patron');
    await j.enregistrerVente(
      lignes: [LigneDemandee.quantite(produitId: p.riz, nombre: 10)],
      mode: ModePaiement.especes,
      montantRecu: 10000,
      auteurId: 'vendeur',
    ); // 6 500 F
    await j.enregistrerVente(
      lignes: [LigneDemandee.quantite(produitId: p.riz, nombre: 2)],
      mode: ModePaiement.mixx,
      auteurId: 'vendeur',
    ); // 1 300 F en Mobile Money : pas dans la caisse espèces
    await j.enregistrerDepense(1500, motif: 'transport', auteurId: 'vendeur');
    await j.enregistrerRetraitPatron(3000, auteurId: 'patron');
    await j.enregistrerEmballage(
      emballage: 'casier',
      quantite: -1,
      consigne: 2000,
      auteurId: 'vendeur',
    );

    final especes = await j.mouvementsCaisse(ModePaiement.especes);
    // 5 000 + 6 500 + 2 000 (consigne) − 1 500 − 3 000 = 9 000 F
    expect(especes.attendu, 9000);
    expect(fermerCaisse(especes, compte: 8500).ecart, -500);

    final mixx = await j.mouvementsCaisse(ModePaiement.mixx);
    expect(mixx.attendu, 1300);
  });

  test(
    'espèces insuffisantes : la vente est refusée et rien n\'est écrit',
    () async {
      final p = await preparerRiz();
      final avant = (await j.operationsDuTelephone(j.telephoneId)).length;
      await expectLater(
        j.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: p.riz, nombre: 5)],
          mode: ModePaiement.especes,
          montantRecu: 3000,
          auteurId: 'vendeur',
        ),
        throwsA(isA<ErreurZeroPerte>()),
      );
      expect((await j.operationsDuTelephone(j.telephoneId)).length, avant);
      expect(await j.stockMilliemes(p.riz), 80000);
    },
  );

  test(
    'nouveau prix = nouvelle version, l\'ancien reste dans l\'historique',
    () async {
      final p = await preparerRiz();
      await j.definirProduit(
        produitId: p.riz,
        nom: 'Riz parfumé',
        uniteBase: 'bol',
        prixUnitaire: 700,
        auteurId: 'patron',
      );
      expect((await j.produit(p.riz)).prixUnitaire, 700);
      final versions = await j.baseBrutePourTests.query(
        'produits_versions',
        where: 'produit_id = ?',
        whereArgs: [p.riz],
      );
      expect(versions.map((v) => v['prix_unitaire']), containsAll([650, 700]));
    },
  );

  test('perte déclarée : stock diminué, motif obligatoire', () async {
    final p = await preparerRiz();
    await j.enregistrerPerte(
      produitId: p.riz,
      milliemes: 2000,
      motif: 'mangé par les rats',
      auteurId: 'vendeur',
    );
    expect(await j.stockMilliemes(p.riz), 78000);
    expect(
      () => j.enregistrerPerte(
        produitId: p.riz,
        milliemes: 1000,
        motif: ' ',
        auteurId: 'vendeur',
      ),
      throwsA(isA<ErreurZeroPerte>()),
    );
  });

  test(
    'vente avant tout arrivage : coût inconnu, exclue du bénéfice',
    () async {
      final sucre = await j.definirProduit(
        nom: 'Sucre',
        uniteBase: 'paquet',
        prixUnitaire: 800,
        auteurId: 'patron',
      );
      await j.enregistrerVente(
        lignes: [LigneDemandee.quantite(produitId: sucre, nombre: 1)],
        mode: ModePaiement.especes,
        montantRecu: 1000,
        auteurId: 'vendeur',
      );
      final b = await j.beneficeEstime();
      expect(b.lignesSansCout, 1);
      expect(b.benefice, 0);
    },
  );

  test(
    'l\'historique ne peut être NI modifié NI effacé, même directement en SQL',
    () async {
      await preparerRiz();
      final db = j.baseBrutePourTests;
      final refusParZeroPerte = throwsA(
        predicate((e) => e.toString().contains('Zero Perte')),
      );
      const modifications = {
        'operations': 'UPDATE operations SET auteur_id = \'pirate\'',
        'mouvements_stock':
            'UPDATE mouvements_stock SET quantite_milliemes = 999999',
        'produits_versions': 'UPDATE produits_versions SET prix_unitaire = 1',
      };
      for (final e in modifications.entries) {
        await expectLater(
          db.rawUpdate(e.value),
          refusParZeroPerte,
          reason: e.key,
        );
        await expectLater(
          db.rawDelete('DELETE FROM ${e.key}'),
          refusParZeroPerte,
          reason: e.key,
        );
      }
      expect(await j.verifierMaChaine(), isEmpty);
    },
  );

  test('chaque téléphone a son identifiant, son préfixe et sa propre suite de reçus', () async {
    final dossier = await Directory.systemTemp.createTemp('zp_test_');
    final telA = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: '${dossier.path}/a.db',
      prefixeRecu: 'A',
    );
    final telB = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: '${dossier.path}/b.db',
      prefixeRecu: 'B',
    );
    expect(telB.telephoneId, isNot(telA.telephoneId));
    for (final tel in [telA, telB]) {
      final riz = await tel.definirProduit(
        nom: 'Riz',
        uniteBase: 'bol',
        prixUnitaire: 650,
        auteurId: 'patron',
      );
      final v = await tel.enregistrerVente(
        lignes: [LigneDemandee.quantite(produitId: riz, nombre: 1)],
        mode: ModePaiement.flooz,
        auteurId: 'vendeur',
      );
      expect(v.recu, '${tel.prefixeRecu}-000001');
    }
    // Rouvrir la base garde le même identifiant de téléphone.
    final idA = telA.telephoneId;
    await telA.fermer();
    final telA2 = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: '${dossier.path}/a.db',
    );
    expect(telA2.telephoneId, idA);
    expect(telA2.prefixeRecu, 'A');
    await telA2.fermer();
    await telB.fermer();
    await dossier.delete(recursive: true);
  });

  test('types inconnus conservés dans le journal (version plus récente)', () async {
    // Une opération d'un type futur ne casse rien : elle reste dans le journal.
    await expectLater(
      JournalLocal.projeter(
        j.baseBrutePourTests,
        const Operation(
          id: 'x',
          telephoneId: 't',
          numero: 1,
          type: 'futur.type',
          auteurId: 'a',
          heureTelephone: 0,
          donnees: {},
          empreintePrecedente: '',
          empreinte: '',
        ),
      ),
      completes,
    );
    expect(TypeOperation.vente, 'vente');
  });

  test('mise à niveau v1 → v2 : les données d\'avant sont gardées', () async {
    final dossier = await Directory.systemTemp.createTemp('zp_migr_');
    final chemin = '${dossier.path}/ancienne.db';
    // Base créée par la version 0.2.0 (schéma 1).
    final v1 = await databaseFactoryFfi.openDatabase(
      chemin,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in [...creationTables, ...creationDeclencheurs]) {
            await db.execute(sql);
          }
        },
      ),
    );
    await v1.close();
    // Ouverture par la nouvelle version : migration automatique.
    final j2 = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: chemin,
    );
    final id = await j2.definirProduit(
      nom: 'Riz',
      uniteBase: 'bol',
      prixUnitaire: 650,
      emoji: '🍚',
      auMontant: true,
      catalogueId: 'cereales.riz_local',
      auteurId: 'patron',
    );
    final p = await j2.produit(id);
    expect(p.emoji, '🍚');
    expect(p.auMontant, isTrue);
    expect((await j2.baseBrutePourTests.getVersion()), versionSchema);
    await j2.fermer();
    await dossier.delete(recursive: true);
  });

  test(
    'configuration de la boutique : la dernière version l\'emporte',
    () async {
      expect(await j.configuration(), isNull);
      await j.configurerBoutique(
        const ConfigBoutique(nom: 'Boutique Mama Ama', ville: 'Lomé'),
        auteurId: 'patron',
      );
      await j.configurerBoutique(
        const ConfigBoutique(
          nom: 'Boutique Mama Ama',
          ville: 'Lomé',
          quartier: 'Bè',
          logo: [1, 2, 3],
        ),
        auteurId: 'patron',
      );
      final c = await j.configuration();
      expect(c!.quartier, 'Bè');
      expect(c.logo, [1, 2, 3]);
      expect(c.adresse, 'Bè, Lomé');
    },
  );

  test(
    'utilisateurs : PIN haché, jamais en clair ; blocage = nouvelle version',
    () async {
      final sel = nouveauSel();
      final patron = Utilisateur(
        id: 'u1',
        nom: 'Ama',
        role: Role.patron,
        sel: sel,
        hachage: await hacherPin('4827', sel),
      );
      await j.definirUtilisateur(patron, auteurId: 'u1');
      final ops = await j.operationsDuTelephone(j.telephoneId);
      expect(ops.last.donnees.toString(), isNot(contains('4827')));
      final lus = await j.utilisateurs();
      expect(await pinCorrect(lus.single, '4827'), isTrue);
      expect(await pinCorrect(lus.single, '4828'), isFalse);

      await j.definirUtilisateur(
        Utilisateur(
          id: 'u2',
          nom: 'Kossi',
          role: Role.vendeur,
          sel: sel,
          hachage: 'x',
        ),
        auteurId: 'u1',
      );
      await j.definirUtilisateur(
        Utilisateur(
          id: 'u2',
          nom: 'Kossi',
          role: Role.vendeur,
          sel: sel,
          hachage: 'x',
          actif: false,
        ),
        auteurId: 'u1',
      );
      final tous = await j.utilisateurs();
      expect(tous.map((u) => u.nom), ['Ama', 'Kossi']);
      expect(tous.last.actif, isFalse);
    },
  );

  test(
    'liste des produits : version actuelle, triés par nom, inactifs masqués',
    () async {
      final a = await j.definirProduit(
        nom: 'Sucre',
        uniteBase: 'paquet',
        prixUnitaire: 800,
        auteurId: 'p',
      );
      await j.definirProduit(
        nom: 'Huile',
        uniteBase: 'litre',
        prixUnitaire: 1200,
        auteurId: 'p',
      );
      await j.definirProduit(
        produitId: a,
        nom: 'Sucre',
        uniteBase: 'paquet',
        prixUnitaire: 850,
        auteurId: 'p',
      );
      final liste = await j.produits();
      expect(liste.map((p) => '${p.nom} ${p.prixUnitaire}'), [
        'Huile 1200',
        'Sucre 850',
      ]);
      await j.definirProduit(
        produitId: a,
        nom: 'Sucre',
        uniteBase: 'paquet',
        prixUnitaire: 850,
        actif: false,
        auteurId: 'p',
      );
      expect((await j.produits()).map((p) => p.nom), ['Huile']);
    },
  );

  test('ventes du jour : une vente annulée apparaît avec son motif', () async {
    final riz = await j.definirProduit(
      nom: 'Riz',
      uniteBase: 'kg',
      prixUnitaire: 600,
      auteurId: 'p',
    );
    final v = await j.enregistrerVente(
      lignes: [LigneDemandee.quantite(produitId: riz, nombre: 2)],
      mode: ModePaiement.especes,
      montantRecu: 1200,
      auteurId: 'v',
    );
    expect((await j.ventesDepuis(0)).single.annulee, isFalse);
    await j.annulerVente(
      venteOperationId: v.operation.id,
      motif: 'Retour du client',
      auteurId: 'v',
    );
    final liste = await j.ventesDepuis(0);
    expect(liste.single.annulee, isTrue);
    expect(liste.single.motifAnnulation, 'Retour du client');
    expect(liste.single.recu, 'A-000001');
  });
}
