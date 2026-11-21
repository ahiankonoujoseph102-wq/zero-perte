import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/panier.dart';
import 'package:zero_perte/domaine/quantites.dart';

const sac = Conditionnement.unites(
  id: 's',
  nom: 'sac de 50 kg',
  unites: 50,
  prixVente: 28000,
);

LignePanier riz(int n, {Conditionnement? c}) => LignePanier(
  produitId: 'riz',
  nomProduit: 'Riz',
  uniteBase: 'kg',
  conditionnement: c,
  nombre: n,
  prixUnitaire: c?.prixVente ?? 600,
);

void main() {
  test(
    '3 kg de riz à 600 F + 1 sac à 28 000 F + sucre pour 100 F = 29 900 F',
    () {
      final p = Panier()
        ..ajouter(riz(3))
        ..ajouter(riz(1, c: sac))
        ..ajouter(
          const LignePanier(
            produitId: 'sucre',
            nomProduit: 'Sucre',
            uniteBase: 'paquet',
            montant: 100,
            prixUnitaire: 800,
          ),
        );
      expect(p.lignes.map((l) => l.prix), [1800, 28000, 100]);
      expect(p.total, 29900);
      expect(p.lignes[0].libelle, '3 kg · Riz');
      expect(p.lignes[1].libelle, '1 sac de 50 kg · Riz');
      expect(p.lignes[2].libelle, 'Sucre pour 100 F');
    },
  );

  test('le même article se regroupe : 1 kg + 2 kg = 3 kg (pas 2 lignes)', () {
    final p = Panier()
      ..ajouter(riz(1))
      ..ajouter(riz(2));
    expect(p.lignes.single.nombre, 3);
    // Mais 1 kg et 1 sac restent deux lignes.
    p.ajouter(riz(1, c: sac));
    expect(p.lignes.length, 2);
  });

  test('− jusqu\'à 0 : la ligne disparaît', () {
    final p = Panier()..ajouter(riz(2));
    p.changer(0, -1);
    expect(p.lignes.single.nombre, 1);
    p.changer(0, -1);
    expect(p.vide, isTrue);
    expect(p.total, 0);
  });
}
