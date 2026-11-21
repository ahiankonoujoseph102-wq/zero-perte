import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/boutique.dart';
import 'package:zero_perte/domaine/utilisateurs.dart';

void main() {
  test('initiales du logo', () {
    expect(const ConfigBoutique(nom: 'Boutique Mama Ama').initiales, 'MA');
    expect(const ConfigBoutique(nom: "Quincaillerie l'Espoir").initiales, 'QE');
    expect(const ConfigBoutique(nom: 'Chez Kodjo').initiales, 'K');
    expect(const ConfigBoutique(nom: '').initiales, 'ZP');
  });

  test('téléphone togolais normalisé', () {
    expect(normaliserTelephone('90123456'), '+228 90 12 34 56');
    expect(normaliserTelephone('+228 90 12 34 56'), '+228 90 12 34 56');
    expect(normaliserTelephone('0022890123456'), '+228 90 12 34 56');
    expect(normaliserTelephone('9012345'), isNull);
  });

  test('aucune couleur de boutique n\'est verte, rouge ou ambre', () {
    for (final c in paletteBoutique) {
      final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
      expect(
        g > r + 40 && g > b + 40,
        isFalse,
        reason: 'vert : ${c.toRadixString(16)}',
      );
      expect(
        r > g + 80 && r > b + 80,
        isFalse,
        reason: 'rouge/ambre : ${c.toRadixString(16)}',
      );
    }
  });

  test('PIN : 4 chiffres, pas trop facile', () {
    expect(problemePin('4827'), isNull);
    expect(problemePin('1234'), isNotNull);
    expect(problemePin('0000'), isNotNull);
    expect(problemePin('48a7'), isNotNull);
    expect(problemePin('482'), isNotNull);
  });

  test(
    'PIN haché avec un sel : deux sels différents → deux hachages différents',
    () async {
      final s1 = nouveauSel(), s2 = nouveauSel();
      expect(await hacherPin('4827', s1), isNot(await hacherPin('4827', s2)));
      expect(await hacherPin('4827', s1), await hacherPin('4827', s1));
    },
  );
}
