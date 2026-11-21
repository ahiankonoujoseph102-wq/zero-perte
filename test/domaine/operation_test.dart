import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/operation.dart';

Operation _op({
  required int numero,
  required String precedente,
  Map<String, Object?> donnees = const {'montant': 1000},
}) {
  const id = 'id';
  final empreinte = calculerEmpreinte(
    id: '$id$numero',
    telephoneId: 'tel',
    numero: numero,
    type: TypeOperation.depense,
    auteurId: 'vendeur',
    heureTelephone: 1000 + numero,
    donnees: donnees,
    empreintePrecedente: precedente,
  );
  return Operation(
    id: '$id$numero',
    telephoneId: 'tel',
    numero: numero,
    type: TypeOperation.depense,
    auteurId: 'vendeur',
    heureTelephone: 1000 + numero,
    donnees: donnees,
    empreintePrecedente: precedente,
    empreinte: empreinte,
  );
}

void main() {
  test('JSON canonique : clés triées, même texte quel que soit l\'ordre', () {
    expect(
      jsonCanonique({
        'b': 1,
        'a': 'x',
        'c': [true, null],
      }),
      '{"a":"x","b":1,"c":[true,null]}',
    );
    expect(
      jsonCanonique({'a': 'x', 'b': 1}),
      jsonCanonique({'b': 1, 'a': 'x'}),
    );
  });

  test('nombre à virgule refusé', () {
    expect(() => jsonCanonique({'montant': 12.5}), throwsArgumentError);
  });

  test('identifiants uniques au format UUID v4', () {
    final ids = {for (var i = 0; i < 1000; i++) nouvelIdentifiant()};
    expect(ids.length, 1000);
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(ids.first),
      isTrue,
    );
  });

  test('chaîne intacte : aucun problème', () {
    final a = _op(numero: 1, precedente: '');
    final b = _op(numero: 2, precedente: a.empreinte);
    final c = _op(numero: 3, precedente: b.empreinte);
    expect(verifierChaine([a, b, c]), isEmpty);
  });

  test('opération supprimée : trou détecté', () {
    final a = _op(numero: 1, precedente: '');
    final b = _op(numero: 2, precedente: a.empreinte);
    final c = _op(numero: 3, precedente: b.empreinte);
    final problemes = verifierChaine([a, c]);
    expect(problemes, isNotEmpty);
    expect(problemes.first, contains('manquante'));
  });

  test('montant modifié : falsification détectée', () {
    final a = _op(numero: 1, precedente: '');
    final falsifiee = Operation(
      id: a.id,
      telephoneId: a.telephoneId,
      numero: a.numero,
      type: a.type,
      auteurId: a.auteurId,
      heureTelephone: a.heureTelephone,
      donnees: const {'montant': 100}, // 1 000 F devenu 100 F
      empreintePrecedente: a.empreintePrecedente,
      empreinte: a.empreinte,
    );
    expect(verifierChaine([falsifiee]).single, contains('modifié'));
  });
}
