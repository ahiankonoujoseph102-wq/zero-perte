import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/donnees/journal_local.dart';

void main() {
  sqfliteFfiInit();
  late JournalLocal j;
  late String riz;
  var heure = 1700000000000;

  setUp(() async {
    heure = 1700000000000;
    j = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: inMemoryDatabasePath,
      horloge: () => heure += 1000,
    );
    riz = await j.definirProduit(
      nom: 'Riz',
      uniteBase: 'kg',
      prixUnitaire: 600,
      auteurId: 'p',
    );
    await j.enregistrerArrivage(
      produitId: riz,
      nombre: 100,
      coutTotal: 50000,
      auteurId: 'p',
    );
  });

  tearDown(() => j.fermer());

  Future<VenteEnregistree> aCredit(String client, int kg) => j.enregistrerVente(
    lignes: [LigneDemandee.quantite(produitId: riz, nombre: kg)],
    mode: ModePaiement.credit,
    clientId: client,
    auteurId: 'p',
  );

  test('Kofi (plafond 5 000 F) prend 3 kg à crédit (1 800 F), rembourse 1 000 F → doit 800 F', () async {
    final kofi = await j.definirClient(
      nom: 'Kofi',
      telephone: '90 11 22 33',
      plafond: 5000,
      auteurId: 'p',
    );
    await aCredit(kofi, 3);
    expect(await j.soldeClient(kofi), 1800);
    // Le crédit n'entre dans AUCUNE caisse.
    for (final m in ModePaiement.caisses) {
      expect((await j.mouvementsCaisse(m)).attendu, 0);
    }

    await j.enregistrerRemboursement(
      clientId: kofi,
      montant: 1000,
      mode: ModePaiement.especes,
      auteurId: 'p',
    );
    expect(await j.soldeClient(kofi), 800);
    final especes = await j.mouvementsCaisse(ModePaiement.especes);
    expect(especes.remboursementsCredits, 1000);
    expect(especes.attendu, 1000);

    final h = await j.historiqueCredit(kofi);
    expect(
      [for (final m in h) (m.nature, m.montant)],
      [('remboursement', -1000), ('vente', 1800)],
    );
    expect(h.last.recu, 'A-000001');
    expect((await j.client(kofi))!.disponible, 4200);
  });

  test(
    'plafond : 5 000 F, déjà 4 200 F → 3 kg (1 800 F) refusés, 1 kg accepté',
    () async {
      final ama = await j.definirClient(
        telephone: '90000001',
        nom: 'Ama',
        plafond: 5000,
        auteurId: 'p',
      );
      await aCredit(ama, 7); // 4 200 F
      await expectLater(
        aCredit(ama, 3),
        throwsA(
          isA<ErreurZeroPerte>().having(
            (e) => e.message,
            'message',
            'Plafond dépassé : Ama peut encore prendre 800 F à crédit.',
          ),
        ),
      );
      await aCredit(ama, 1); // 600 F : total 4 800 F
      expect(await j.soldeClient(ama), 4800);
      // Le stock a bien diminué de 8 kg seulement.
      expect((await j.stocks())[riz], 92000);
    },
  );

  test('vente à crédit annulée : la dette disparaît, le riz revient', () async {
    final kofi = await j.definirClient(
      telephone: '90000002',
      nom: 'Kofi',
      plafond: 10000,
      auteurId: 'p',
    );
    final v = await aCredit(kofi, 2);
    await j.annulerVente(
      venteOperationId: v.operation.id,
      motif: 'Retour du client',
      auteurId: 'p',
    );
    expect(await j.soldeClient(kofi), 0);
    expect((await j.stocks())[riz], 100000);
  });

  test('remboursement trop grand, ou à crédit : refusé', () async {
    final kofi = await j.definirClient(
      telephone: '90000003',
      nom: 'Kofi',
      plafond: 10000,
      auteurId: 'p',
    );
    await aCredit(kofi, 1); // 600 F
    await expectLater(
      j.enregistrerRemboursement(
        clientId: kofi,
        montant: 1000,
        mode: ModePaiement.especes,
        auteurId: 'p',
      ),
      throwsA(isA<ErreurZeroPerte>()),
    );
    expect(
      () => j.enregistrerRemboursement(
        clientId: kofi,
        montant: 100,
        mode: ModePaiement.credit,
        auteurId: 'p',
      ),
      throwsA(isA<ErreurZeroPerte>()),
    );
  });

  test(
    'vente à crédit sans client : refusée ; fiche modifiée : dernière version',
    () async {
      expect(
        () => j.enregistrerVente(
          lignes: [LigneDemandee.quantite(produitId: riz, nombre: 1)],
          mode: ModePaiement.credit,
          auteurId: 'p',
        ),
        throwsA(isA<ErreurZeroPerte>()),
      );
      final id = await j.definirClient(
        telephone: '90000004',
        nom: 'Afi',
        plafond: 2000,
        auteurId: 'p',
      );
      await j.definirClient(
        telephone: '90000005',
        clientId: id,
        nom: 'Afi Mensah',
        plafond: 8000,
        auteurId: 'p',
      );
      final liste = await j.clients();
      expect(liste, hasLength(1));
      expect(liste.single.nom, 'Afi Mensah');
      expect(liste.single.plafond, 8000);
      expect(await j.verifierMaChaine(), isEmpty);
    },
  );
}
