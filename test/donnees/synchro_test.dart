import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/synchro/synchro.dart';

void main() {
  sqfliteFfiInit();
  var heure = 1700000000000;
  int horloge() => heure += 1000;

  Future<JournalLocal> telephone() => JournalLocal.ouvrir(
    fabrique: databaseFactoryFfi,
    chemin: inMemoryDatabasePath,
    horloge: horloge,
  );

  late JournalLocal patron;
  late JournalLocal vendeur;
  late StockageMemoire drive;
  late String riz;
  late String kofi;

  setUp(() async {
    heure = 1700000000000;
    // Deux bases indépendantes (inMemoryDatabasePath partagerait la même).
    patron = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: 'file:patron?mode=memory&cache=private',
      horloge: horloge,
    );
    vendeur = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: 'file:vendeur?mode=memory&cache=private',
      horloge: horloge,
    );
    drive = StockageMemoire();
    // Le patron installe la boutique : riz 600 F/kg, 100 kg ; client Kofi.
    riz = await patron.definirProduit(
      nom: 'Riz',
      uniteBase: 'kg',
      prixUnitaire: 600,
      auteurId: 'p',
    );
    await patron.enregistrerArrivage(
      produitId: riz,
      nombre: 100,
      coutTotal: 50000,
      auteurId: 'p',
    );
    kofi = await patron.definirClient(
      nom: 'Kofi',
      telephone: '90112233',
      plafond: 5000,
      auteurId: 'p',
    );
  });

  tearDown(() async {
    await patron.fermer();
    await vendeur.fermer();
  });

  test('le vendeur récupère la boutique, vend 2 kg ; le patron voit la vente et le stock commun', () async {
    final sp = Synchroniseur(journal: patron, stockage: drive);
    final sv = Synchroniseur(journal: vendeur, stockage: drive);
    final r1 = await sp.synchroniser(maxAppareils: 2, nomAppareil: 'Ama');
    expect(r1.envoyees, greaterThan(0));
    expect(drive.fichiers.keys, contains('boutique.json'));

    // Nouveau téléphone : récupère tout, devient le 2e appareil (reçus « B »).
    await sv.recupererBoutique();
    final r2 = await sv.synchroniser(maxAppareils: 2, nomAppareil: 'Kossi');
    expect(vendeur.prefixeRecu, 'B');
    expect(r2.appareils, hasLength(2));
    expect((await vendeur.stocks())[riz], 100000);

    final v = await vendeur.enregistrerVente(
      lignes: [LigneDemandee.quantite(produitId: riz, nombre: 2)],
      mode: ModePaiement.especes,
      montantRecu: 1200,
      auteurId: 'v',
    );
    expect(v.recu, 'B-000001');
    await sv.synchroniser(maxAppareils: 2);
    final r3 = await sp.synchroniser(maxAppareils: 2);
    expect(r3.recues, 1);
    expect((await patron.stocks())[riz], 98000);
    expect((await patron.resumeVentes(depuis: 0)).total, 1200);
    expect(await patron.verifierMaChaine(), isEmpty);
  });

  test('plafond commun : Kofi prend 4 000 F chez le vendeur → refusé chez le patron au-delà', () async {
    final sp = Synchroniseur(journal: patron, stockage: drive);
    final sv = Synchroniseur(journal: vendeur, stockage: drive);
    await sp.synchroniser();
    await sv.recupererBoutique();
    await sv.synchroniser();
    await vendeur.enregistrerVente(
      lignes: [LigneDemandee.auMontant(produitId: riz, montant: 4000)],
      mode: ModePaiement.credit,
      clientId: kofi,
      auteurId: 'v',
    );
    await sv.synchroniser();
    await sp.synchroniser();
    expect(await patron.soldeClient(kofi), 4000);
    await expectLater(
      patron.enregistrerVente(
        lignes: [LigneDemandee.auMontant(produitId: riz, montant: 1500)],
        mode: ModePaiement.credit,
        clientId: kofi,
        auteurId: 'p',
      ),
      throwsA(
        isA<ErreurZeroPerte>().having(
          (e) => e.message,
          'message',
          contains('peut encore prendre 1 000 F'),
        ),
      ),
    );
  });

  test('licence de 2 appareils : un 3e est refusé', () async {
    final troisieme = await telephone();
    await Synchroniseur(
      journal: patron,
      stockage: drive,
    ).synchroniser(maxAppareils: 2);
    await Synchroniseur(
      journal: vendeur,
      stockage: drive,
    ).synchroniser(maxAppareils: 2);
    await expectLater(
      Synchroniseur(
        journal: troisieme,
        stockage: drive,
      ).synchroniser(maxAppareils: 2),
      throwsA(isA<ErreurLicencePleine>()),
    );
    await troisieme.fermer();
  });

  test(
    'téléphone perdu : le nouveau reprend son identité et continue ses reçus',
    () async {
      final sp = Synchroniseur(journal: patron, stockage: drive);
      await patron.enregistrerVente(
        lignes: [LigneDemandee.quantite(produitId: riz, nombre: 1)],
        mode: ModePaiement.especes,
        montantRecu: 600,
        auteurId: 'p',
      );
      await sp.synchroniser(maxAppareils: 2);
      final ancien = (await sp.appareils()).single;

      final neuf = await telephone();
      final sn = Synchroniseur(journal: neuf, stockage: drive);
      await sn.recupererBoutique(remplace: ancien);
      expect(neuf.telephoneId, patron.telephoneId);
      expect((await neuf.stocks())[riz], 99000);
      final v = await neuf.enregistrerVente(
        lignes: [LigneDemandee.quantite(produitId: riz, nombre: 1)],
        mode: ModePaiement.especes,
        montantRecu: 600,
        auteurId: 'p',
      );
      expect(v.recu, 'A-000002');
      expect(await neuf.verifierMaChaine(), isEmpty);
      // Il ne compte pas comme un appareil de plus.
      final r = await sn.synchroniser(maxAppareils: 1);
      expect(r.appareils, hasLength(1));
      await neuf.fermer();
    },
  );

  test('fichier trafiqué dans le Drive : refusé, rien n\'est écrit', () async {
    await Synchroniseur(journal: patron, stockage: drive).synchroniser();
    final nom = drive.fichiers.keys.firstWhere((n) => n.startsWith('ops-'));
    final texte = String.fromCharCodes(drive.fichiers[nom]!);
    drive.fichiers[nom] = texte.replaceFirst('600', '60').codeUnits;
    await expectLater(
      Synchroniseur(journal: vendeur, stockage: drive).recupererBoutique(),
      throwsA(isA<ErreurZeroPerte>()),
    );
    expect(await vendeur.nombreOperations(), 0);
  });

  test('deuxième synchronisation : rien n\'est renvoyé ni relu', () async {
    final sp = Synchroniseur(journal: patron, stockage: drive);
    await sp.synchroniser();
    final r = await sp.synchroniser();
    expect(r.envoyees, 0);
    expect(r.recues, 0);
  });
}
