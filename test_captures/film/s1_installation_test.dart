// Scène 1 : installation par le patron, de la bienvenue à l'accueil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/domaine/licence_test.dart' show codeLicence;
import '../../test/support/faux_relais_invitations.dart';
import '../../test/support/outils.dart';
import 'film.dart';

void main() {
  setUpAll(chargerPolices);
  testWidgets('scène 1 : installation', (tester) async {
    final env = await environnementDeTest(
      tester,
      relais: FauxRelaisInvitations(),
      lecteur: FauxLecteurQr(),
    );
    env.pressePapiers.texte =
        'Bonjour, voici votre code :\n$codeLicence\nMerci';
    final f = Film(tester, '01_installation');
    await f.ouvrir(env.etat);
    await f.image(3);
    await f.cle('bouton-commencer');
    await f.vivre(1);
    await f.cle('bouton-coller-code', pause: 2.5);
    await f.cle('bouton-continuer');
    await f.ecrire(find.byKey(const Key('champ-nom')), 'Boutique Mama Ama');
    await f.cle('bouton-continuer');
    await f.cle('vente-les_deux', pause: 0.6);
    await f.cle('qui-un', pause: 1.2);
    await f.cle('bouton-continuer');
    await f.ecrire(find.byKey(const Key('champ-nom-patron')), 'Ama');
    for (final c in '482713482713'.split('')) {
      await f.cle('pin-$c', pause: 0.15);
    }
    await f.vivre(1);
    await f.image(3);
    await f.cle('bouton-commencer-vendre', pause: 3);
    f.finir();
  });
}
