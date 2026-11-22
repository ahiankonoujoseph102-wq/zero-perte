// Contenu des opérations rangé compressé (schéma 6) : texte retrouvé à
// l'identique, anciennes lignes lisibles, empreintes, sauvegarde et
// synchronisation inchangées (toujours en texte).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_perte/domaine/operation.dart';
import 'package:zero_perte/donnees/journal_local.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('compression : même texte, plus de 2,5 fois plus petit pour une vente', () {
    final vente = {
      'lignes': [
        for (var i = 0; i < 3; i++)
          {
            'au_montant': false,
            'conditionnement': null,
            'cout_total': null,
            'nombre': 2,
            'prix_total': 1900,
            'produit': '3d8ae0fa-bb33-4e04-ab9e-2c53224e94d$i',
            'quantite_milliemes': 2000,
          },
      ],
      'mode_paiement': 'especes',
      'monnaie_rendue': 4300,
      'montant_recu': 10000,
      'numero_recu': 12,
      'recu': 'A-000012',
      'reference_paiement': null,
      'total': 5700,
    };
    final range = stockerDonnees(vente);
    final texte = jsonCanonique(vente);
    expect(texteDonnees(range), texte);
    expect(lireDonnees(range), vente);
    expect(range.length * 5 ~/ 2, lessThan(utf8.encode(texte).length));
    // Ancienne ligne (texte) : lue telle quelle.
    expect(texteDonnees(texte), texte);
  });

  test('journal : empreintes valides, sauvegarde et synchronisation en texte', () async {
    final j = await JournalLocal.ouvrir(
      fabrique: databaseFactoryFfi,
      chemin: inMemoryDatabasePath,
    );
    final id = await j.definirProduit(
      nom: 'Riz',
      uniteBase: 'kg',
      prixUnitaire: 600,
      auteurId: 'patron',
    );
    await j.enregistrerVente(
      lignes: [LigneDemandee.quantite(produitId: id, nombre: 2)],
      mode: ModePaiement.especes,
      montantRecu: 2000,
      auteurId: 'patron',
    );
    final ops = await j.mesOperationsApres(0);
    expect(ops, hasLength(2));
    for (final op in ops) {
      expect(op.empreinteValide, isTrue, reason: op.type);
    }
    // Synchronisation : contenu en texte (lisible par les anciennes versions).
    final sync = jsonDecode(utf8.decode(JournalLocal.operationsVersJson(ops)));
    for (final o in (sync['operations'] as List)) {
      expect(o['donnees'], isA<String>());
    }
    expect(
      JournalLocal.operationsDepuisJson(JournalLocal.operationsVersJson(ops))
          .map((o) => o.empreinte),
      ops.map((o) => o.empreinte),
    );
    // Sauvegarde : même format qu'avant (contenu en texte).
    final sauvegarde = jsonDecode(utf8.decode(await j.exporterJournal()));
    for (final o in (sauvegarde['operations'] as List)) {
      expect(o['donnees'], isA<String>());
    }
    await j.fermer();
  });
}
