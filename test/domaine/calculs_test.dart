import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/argent.dart';
import 'package:zero_perte/domaine/calculs.dart';
import 'package:zero_perte/domaine/quantites.dart';
import 'package:zero_perte/domaine/recu.dart';

/// « 12 500 F » avec les espaces insécables utilisés par l'application.
String f(String texte) =>
    texte.replaceAll(' F', '${espaceAvantF}F').replaceAll(' ', espaceMilliers);

void main() {
  group('Format « 12 500 F »', () {
    test('milliers séparés, jamais de virgule', () {
      expect(formatFrancs(0), f('0 F'));
      expect(formatFrancs(500), f('500 F'));
      expect(formatFrancs(12500), f('12 500 F'));
      expect(formatFrancs(1250000), f('1 250 000 F'));
      expect(formatFrancs(-3000), f('-3 000 F'));
    });
  });

  group('Monnaie à rendre', () {
    test('total 3 250 F, client donne 5 000 F → rendre 1 750 F', () {
      final m = calculerMonnaie(total: 3250, recu: 5000);
      expect(m.suffisant, isTrue);
      expect(m.aRendre, 1750);
      final d = decomposerEnCoupures(m.aRendre);
      expect(d.coupures, {
        1000: 1,
        500: 1,
        250: 1,
      }); // 1 billet de 1 000, pièces de 500 et 250
      expect(d.reste, 0);
    });
    test('client ne donne pas assez : il manque 750 F', () {
      final m = calculerMonnaie(total: 3250, recu: 2500);
      expect(m.suffisant, isFalse);
      expect(m.aRendre, 0);
      expect(m.manque, 750);
    });
    test('grosse monnaie : 18 650 F', () {
      final d = decomposerEnCoupures(18650);
      expect(d.coupures, {
        10000: 1,
        5000: 1,
        2000: 1,
        1000: 1,
        500: 1,
        100: 1,
        50: 1,
      });
    });
    test('montants négatifs refusés', () {
      expect(() => calculerMonnaie(total: -1, recu: 0), throwsArgumentError);
    });
  });

  group('Stock = somme des mouvements', () {
    test(
      'arrivage 2 sacs (80 bols), ventes 5 + 3 bols, perte 1 bol → 71 bols',
      () {
        final mouvements = [80000, -5000, -3000, -1000];
        expect(stockDepuisMouvements(mouvements), 71000);
      },
    );
    test('une annulation de vente remet le stock', () {
      expect(stockDepuisMouvements([10000, -2000, 2000]), 10000);
    });
  });

  group('Conditionnements sac → bol', () {
    const sac = Conditionnement.unites(
      id: 's',
      nom: 'sac',
      unites: 40,
      prixVente: 23000,
    );
    test('2 sacs = 80 bols', () {
      expect(versMilliemes(2, sac), 80000);
    });
    test('85 bols = 2 sacs + 5 bols', () {
      final r = repartirStock(85000, [sac]);
      expect(r.parts.single.conditionnement.nom, 'sac');
      expect(r.parts.single.nombre, 2);
      expect(r.resteMilliemes, 5000);
    });
    test('casier de 12 + pack de 6 : 31 bouteilles = 2 casiers + 1 pack + 1 bouteille', () {
      const casier = Conditionnement.unites(
        id: 'c',
        nom: 'casier',
        unites: 12,
        prixVente: 6000,
      );
      const pack = Conditionnement.unites(
        id: 'p',
        nom: 'pack',
        unites: 6,
        prixVente: 3100,
      );
      final r = repartirStock(31000, [pack, casier]);
      expect(r.parts.map((p) => '${p.nombre} ${p.conditionnement.nom}'), [
        '2 casier',
        '1 pack',
      ]);
      expect(r.resteMilliemes, 1000);
    });
  });

  group('Vente au montant « donne pour 100 F »', () {
    test('100 F de riz à 175 F le bol → 0,571 bol (571 millièmes)', () {
      expect(quantitePourMontant(montant: 100, prixUnitaire: 175), 571);
    });
    test('200 F de sucre à 800 F le paquet → 1/4 de paquet', () {
      expect(quantitePourMontant(montant: 200, prixUnitaire: 800), 250);
    });
    test('produit sans prix refusé', () {
      expect(
        () => quantitePourMontant(montant: 100, prixUnitaire: 0),
        throwsArgumentError,
      );
    });
  });

  group('Écart de caisse (comptage aveugle)', () {
    const mouvements = MouvementsCaisse(
      fondsDeCaisse: 5000,
      ventes: 48250,
      remboursementsCredits: 2000,
      depenses: 1500,
      retraitsPatron: 10000,
    );
    test('attendu = 5 000 + 48 250 + 2 000 − 1 500 − 10 000 = 43 750 F', () {
      expect(mouvements.attendu, 43750);
    });
    test('le vendeur compte 42 750 F → il manque 1 000 F', () {
      final r = fermerCaisse(mouvements, compte: 42750);
      expect(r.ecart, -1000);
      expect(r.etat, EtatCaisse.manque);
    });
    test('caisse juste', () {
      expect(fermerCaisse(mouvements, compte: 43750).etat, EtatCaisse.juste);
    });
    test('surplus de 250 F', () {
      final r = fermerCaisse(mouvements, compte: 44000);
      expect(r.ecart, 250);
      expect(r.etat, EtatCaisse.surplus);
    });
  });

  group('Bénéfice estimé', () {
    test(
      'sac acheté 23 000 F (40 bols), 5 bols vendus 650 F → bénéfice 375 F',
      () {
        final cout = coutPourQuantite(
          milliemes: 5000,
          coutAchat: 23000,
          milliemesAchetes: 40000,
        );
        expect(cout, 2875);
        final lignes = [LigneVendue(prixVente: 5 * 650, coutAchat: cout)];
        expect(beneficeEstime(lignes), 375);
      },
    );
    test('vente à perte : bénéfice négatif', () {
      expect(
        beneficeEstime(const [LigneVendue(prixVente: 1000, coutAchat: 1200)]),
        -200,
      );
    });
  });

  group('Emballages consignés', () {
    test('24 casiers arrivés, 5 partis chez des clients, 3 ramenés → 22 en boutique', () {
      expect(soldeEmballages([24, -5, 3]), 22);
    });
  });

  group('Reçus : préfixe par téléphone, sans trou', () {
    test('format', () {
      expect(formatNumeroRecu('A', 42), 'A-000042');
      expect(formatNumeroRecu('P', 1), 'P-000001');
    });
    test('préfixe invalide refusé', () {
      expect(() => formatNumeroRecu('a', 1), throwsArgumentError);
      expect(() => formatNumeroRecu('ABC', 1), throwsArgumentError);
    });
    test('trous détectés', () {
      expect(numerosManquants([1, 2, 3, 5, 6, 9]), [4, 7, 8]);
      expect(numerosManquants([1, 2, 3]), isEmpty);
    });
  });

  group('Stock lisible', () {
    const sac = Conditionnement.unites(
      id: 's',
      nom: 'sac de 50 kg',
      unites: 50,
      prixVente: 28000,
    );
    test('85 kg avec des sacs de 50 kg → « 1 sac de 50 kg + 35 kg »', () {
      expect(decrireStock(85000, 'kg', [sac]), '1 sac de 50 kg + 35 kg');
    });
    test('pluriels : 2 sacs, 3 bols, 1 bol, 0,6 bol, 2 casiers, 2 bureaux', () {
      expect(decrireStock(100000, 'kg', [sac]), '2 sacs de 50 kg');
      expect(decrireUnites(3000, 'bol'), '3 bols');
      expect(decrireUnites(1000, 'bol'), '1 bol');
      expect(decrireUnites(571, 'bol'), '0,6 bol');
      expect(decrireUnites(34846, 'bol'), '34,8 bols');
      expect(pluriel('casier', 2), 'casiers');
      expect(pluriel('bureau', 2), 'bureaux');
    });
    test('stock nul ou négatif', () {
      expect(decrireStock(0, 'bol', [sac]), '0 bol');
      expect(decrireStock(-2000, 'bol', [sac]), '-2 bols');
    });
  });
}
