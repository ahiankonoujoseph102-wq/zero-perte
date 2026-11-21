import 'dart:io';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/domaine/licence.dart';

// Données de test produites par outils/licence.sh (OpenSSL) avec une clé JETABLE,
// dont la clé privée a été détruite. Ce test prouve que l'application accepte les
// signatures faites sur GitHub Actions avec OpenSSL.
const clePubliqueTest = 'bTbX4S7szORvKgHF/5VT1JzJquzDFJOhEXRlbPp6/Sc=';
const codeLicence =
    'ZP1.eyJiIjoiYnEtdGVzdC0wMDAxIiwiZCI6IjIwMjYtMTEtMjEiLCJpIjoiYy0wMDAxIiwibiI6IkJvdXRpcXVlIE1hbWEgQW1hIiwidCI6MiwidHlwZSI6ImxpY2VuY2UiLCJ2IjoxfQ.ARSNhxO_qMmCC_KCw4V16CXyY04MzbDW_r4IYrnkMfMFlVPSpwOq1lbDrVIOXVcHCStEsDlIQZqgJJrRLgveBA';
const codeExtension =
    'ZP1.eyJiIjoiYnEtdGVzdC0wMDAxIiwiZCI6IjIwMjYtMTEtMjIiLCJpIjoiYy0wMDAyIiwibiI6IkJvdXRpcXVlIE1hbWEgQW1hIiwidCI6MSwidHlwZSI6ImV4dGVuc2lvbiIsInYiOjF9.Ie1M16vqTIJSJfTpIUwWnyZfwF_-PMmP1_KzOA0xxrqsxIPY8ftdcYdbEAlpenhJtEWy3RY4yvzQW9SFkkoUAw';

final cle = lireClePublique(clePubliqueTest);

void main() {
  test('chemin du workflow 4 (jq puis OpenSSL), nom avec apostrophe', () async {
    // Clé jetable distincte (clé privée détruite).
    final c = await verifierCode(
      'ZP1.eyJiIjoiYnEtMDEyMzQ1Njc4OWFiIiwiZCI6IjIwMjYtMTEtMjEiLCJpIjoiYy14IiwibiI6IlF1aW5jYWlsbGVyaWUgbCdFc3BvaXIiLCJ0IjoyLCJ0eXBlIjoibGljZW5jZSIsInYiOjF9.9jTXFZjgnggVy0gHL-9MzVl-wNmmM4ShYSFw-xpekKLUOhwaKbsXl0dqxltQ7_6Z4hy9ZJYSv2GJ1sppLU2PBw',
      lireClePublique('7GqlnWg/syLCrPCaChWr7ANR8mAdJQ1tvoaiQnK77qA='),
    );
    expect(c.nomBoutique, 'Quincaillerie l\'Espoir');
    expect(c.boutiqueId, 'bq-0123456789ab');
    // Avec la mauvaise clé : refusé.
    expect(() => verifierCode(c.texte, cle), throwsA(isA<ErreurCode>()));
  });

  test('code valide : boutique, nom, 2 téléphones', () async {
    final c = await verifierCode(codeLicence, cle);
    expect(c.boutiqueId, 'bq-test-0001');
    expect(c.nomBoutique, 'Boutique Mama Ama');
    expect(c.telephones, 2);
    expect(c.type, TypeCode.licence);
  });

  test('le message WhatsApp entier peut être collé (avec retours à la ligne)', () async {
    final message =
        'Bonjour Mama Ama,\nvoici votre code Zéro Perte :\n'
        '${codeLicence.substring(0, 60)}\n${codeLicence.substring(60)}\nMerci !';
    final c = await verifierCode(message, cle);
    expect(c.codeId, 'c-0001');
  });

  test('un seul caractère changé : refusé', () async {
    // On remplace « Mama Ama » par « Mama Amb » dans la charge.
    final parts = codeLicence.split('.');
    final charge = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final fausse = base64Url
        .encode(utf8.encode(charge.replaceAll('Ama', 'Amb')))
        .replaceAll('=', '');
    expect(
      () => verifierCode('ZP1.$fausse.${parts[2]}', cle),
      throwsA(
        isA<ErreurCode>().having(
          (e) => e.probleme,
          'problème',
          ProblemeCode.signatureFausse,
        ),
      ),
    );
  });

  test('2 téléphones → 4 téléphones avec 2 codes « téléphone en plus » (ici 1 + licence 2 = 3)', () async {
    final base = await verifierCode(codeLicence, cle);
    final ext = await verifierCode(codeExtension, cle);
    final avant = calculerLicence([base])!;
    expect(avant.telephones, 2);
    controlerNouveauCode(ext, avant); // accepté
    final apres = calculerLicence([base, ext])!;
    expect(apres.telephones, 3);
  });

  test('même code utilisé deux fois : refusé', () async {
    final base = await verifierCode(codeLicence, cle);
    expect(
      () => controlerNouveauCode(base, calculerLicence([base])),
      throwsA(
        isA<ErreurCode>().having(
          (e) => e.probleme,
          'problème',
          ProblemeCode.dejaUtilise,
        ),
      ),
    );
  });

  test('extension avant la licence : refusée', () async {
    final ext = await verifierCode(codeExtension, cle);
    expect(
      () => controlerNouveauCode(ext, null),
      throwsA(
        isA<ErreurCode>().having(
          (e) => e.probleme,
          'problème',
          ProblemeCode.extensionSansLicence,
        ),
      ),
    );
  });

  test('texte sans code, ou clé absente : messages clairs', () {
    expect(() => lireCode('Bonjour'), throwsA(isA<ErreurCode>()));
    expect(
      () => verifierCode(codeLicence, null),
      throwsA(
        isA<ErreurCode>().having(
          (e) => e.probleme,
          'problème',
          ProblemeCode.cleAbsente,
        ),
      ),
    );
    expect(lireClePublique('ABSENTE'), isNull);
  });

  test('la clé publique officielle est présente et valide (32 octets)', () {
    final texte = File('assets/licence/cle_publique.txt').readAsStringSync();
    expect(texte.trim(), isNot('ABSENTE'));
    expect(lireClePublique(texte), hasLength(32));
  });
}
