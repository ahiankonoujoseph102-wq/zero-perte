// 0.37.2 : la photo d'un produit (et d'un client) peut venir de la galerie.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/app/etat_application.dart';
import 'package:zero_perte/ecrans/credit/clients.dart';
import 'package:zero_perte/ecrans/patron/produits.dart';

import '../ecrans/refonte_036_test.dart' show boutiqueVide;
import '../support/outils.dart';

void main() {
  for (final (nom, page, appareil, galerie) in [
    (
      'produit',
      (EtatApplication e) => PageFicheProduit(etat: e),
      'bouton-photo-produit',
      'bouton-galerie-produit',
    ),
    (
      'client',
      (EtatApplication e) => PageFicheEdition(etat: e),
      'bouton-appareil-client',
      'bouton-galerie-client',
    ),
  ]) {
    testWidgets('$nom : photo par l\'appareil photo OU par la galerie', (
      tester,
    ) async {
      final env = await environnementDeTest(tester, preparer: boutiqueVide);
      await afficherApp(tester, env.etat);
      Navigator.of(tester.element(find.byType(Scaffold).first))
          .push(MaterialPageRoute(builder: (_) => page(env.etat)));
      await attendre(tester, tours: 6);
      sourcesPhotoDemandees.clear();
      await toucher(tester, find.byKey(Key(galerie)));
      await toucher(tester, find.byKey(Key(appareil)));
      expect(sourcesPhotoDemandees, [
        SourcePhoto.galerie,
        SourcePhoto.appareil,
      ]);
      expect(tester.takeException(), isNull);
    });
  }
}
