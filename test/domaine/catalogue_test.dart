import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/catalogue.dart';

/// Emoji ajoutés après Unicode Emoji 5.0 (2017) : invisibles (carrés vides) sur
/// Android 8. Plages des emoji 11 à 15 dans les blocs utilisés.
bool emojiRecent(String e) => e.runes.any(
  (r) =>
      (r >= 0x1F9C1 && r <= 0x1F9CF) || // 🧁… (emoji 11-12)
      (r >= 0x1F9E7 && r <= 0x1F9FF) || // 🧧 🧱 🧼… (emoji 11)
      (r >= 0x1FA70 && r <= 0x1FAFF) || // 🩰… 🫗 (emoji 12 à 15)
      (r >= 0x1F6D5 && r <= 0x1F6DF) || // 🛕 🛞… (emoji 12 à 14)
      (r >= 0x1F6F9 && r <= 0x1F6FF) || // 🛹 🛺… (emoji 11 à 13)
      (r >= 0x1F94D && r <= 0x1F94F) || // 🥍 🥎 🥏 (emoji 11)
      (r >= 0x1F96C && r <= 0x1F97F) || // 🥬 🥭… (emoji 11+)
      (r >= 0x1F998 && r <= 0x1F9BF),
); // 🦘… (emoji 11+)

void main() {
  final catalogue = Catalogue.depuisJson(
    File('assets/catalogues/catalogues.json').readAsStringSync(),
  );

  test('26 types de boutiques, produits sans doublon d\'identifiant', () {
    expect(catalogue.categories.length, 26);
    final ids = [
      for (final c in catalogue.categories)
        for (final p in c.produits) p.id,
    ];
    expect(ids.toSet().length, ids.length);
    expect(ids.length, greaterThan(150));
  });

  test('aucun emoji trop récent pour Android 8 (sinon : carré vide)', () {
    final fautifs = [
      for (final c in catalogue.categories) ...[
        if (emojiRecent(c.emoji)) '${c.nom} ${c.emoji}',
        for (final p in c.produits)
          if (emojiRecent(p.emoji)) '${p.nom} ${p.emoji}',
      ],
    ];
    expect(fautifs, isEmpty);
  });

  test('sac de maïs : 40 bols, marqué « à vérifier »', () {
    final mais = catalogue
        .categorie('cereales')!
        .produits
        .firstWhere((p) => p.id == 'cereales.mais');
    expect(mais.unite, 'bol');
    expect(mais.auMontant, isTrue);
    expect(mais.conditionnements.single.unites, 40);
    expect(mais.conditionnements.single.aVerifier, isTrue);
  });

  test('bière en casier : emballage consigné', () {
    final b = catalogue
        .categorie('boissons')!
        .produits
        .firstWhere((p) => p.id == 'boissons.biere_grande');
    expect(b.emballage, isNotNull);
  });

  test(
    'pas de doublon de nom quand on choisit deux types (œufs, eau en sachet)',
    () {
      final noms = catalogue
          .produitsDe(['alimentation', 'boucherie'])
          .map((p) => p.nom)
          .toList();
      expect(noms.where((n) => n == 'Œufs').length, 1);
    },
  );
}
