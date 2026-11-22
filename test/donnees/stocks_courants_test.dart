// Stock courant tenu par la base (schéma 6) : toujours égal à la somme des
// mouvements, y compris après la migration d'une base existante.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/donnees/journal_local.dart';
import 'package:zero_perte/donnees/schema.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<Map<String, int>> somme(Database db) async => {
    for (final l in await db.rawQuery(
      'SELECT produit_id AS p, SUM(quantite_milliemes) AS s '
      'FROM mouvements_stock GROUP BY produit_id',
    ))
      l['p'] as String: l['s'] as int,
  };

  test('migration 5 → 6 : le stock courant reprend tout l\'historique', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // Base « version 5 » minimale : mouvements existants, puis migration 6.
    await db.execute('''
CREATE TABLE mouvements_stock (
  operation_id TEXT NOT NULL, ligne INTEGER NOT NULL, produit_id TEXT NOT NULL,
  quantite_milliemes INTEGER NOT NULL, nature TEXT NOT NULL,
  prix_total INTEGER NOT NULL DEFAULT 0, cout_total INTEGER,
  PRIMARY KEY (operation_id, ligne))''');
    for (var i = 0; i < 50; i++) {
      await db.insert('mouvements_stock', {
        'operation_id': 'o$i',
        'ligne': 0,
        'produit_id': 'p${i % 3}',
        'quantite_milliemes': i.isEven ? 5000 : -1000,
        'nature': 'test',
      });
    }
    await db.execute(
      'CREATE TABLE produits_versions (operation_id TEXT PRIMARY KEY)',
    );
    for (final sql in migrations[6]!) {
      await db.execute(sql);
    }
    Future<Map<String, int>> courants() async => {
      for (final l in await db.rawQuery(
        'SELECT produit_id AS p, quantite_milliemes AS s FROM stocks_courants',
      ))
        l['p'] as String: l['s'] as int,
    };
    expect(await courants(), await somme(db));
    // Nouveaux mouvements (dont un nouveau produit) : tenus à jour.
    await db.insert('mouvements_stock', {
      'operation_id': 'x1',
      'ligne': 0,
      'produit_id': 'p1',
      'quantite_milliemes': -2500,
      'nature': 'vente',
    });
    await db.insert('mouvements_stock', {
      'operation_id': 'x2',
      'ligne': 0,
      'produit_id': 'p9',
      'quantite_milliemes': 7000,
      'nature': 'arrivage',
    });
    expect(await courants(), await somme(db));
    await db.close();
  });

  test(
    'base neuve : ventes et arrivages → stocks() = somme des mouvements',
    () async {
      final j = await JournalLocal.ouvrir(
        fabrique: databaseFactoryFfi,
        chemin: inMemoryDatabasePath,
      );
      expect(await j.stocks(), isEmpty);
      await j.fermer();
    },
  );
}
