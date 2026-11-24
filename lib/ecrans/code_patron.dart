import 'package:flutter/material.dart';

import '../app/etat_application.dart';
import '../domaine/utilisateurs.dart';
import '../theme/couleurs.dart';
import 'clavier_pin.dart';
import 'communs.dart';

/// Montré UNE fois aux boutiques installées avant la version 0.17 : le patron
/// remplace son code de 4 chiffres par un code de 6 chiffres (décision Q8).
/// Il tape d'abord son code actuel, pour qu'un vendeur ne puisse pas le faire.
class PageNouveauCodePatron extends StatefulWidget {
  const PageNouveauCodePatron({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageNouveauCodePatron> createState() => _PageNouveauCodePatronState();
}

enum _Etape { ancien, nouveau, confirmer }

class _PageNouveauCodePatronState extends State<PageNouveauCodePatron> {
  _Etape _etape = _Etape.ancien;
  String? _nouveau;
  String? _erreur;
  int _tour = 0;
  bool _enCours = false;

  Utilisateur get _patron => widget.etat.patron!;

  Future<void> _saisi(String pin) async {
    if (_enCours) return;
    switch (_etape) {
      case _Etape.ancien:
        setState(() => _enCours = true);
        final bon = await widget.etat.verifierPin(_patron, pin);
        setState(() {
          _enCours = false;
          _tour++;
          if (bon) {
            _etape = _Etape.nouveau;
            _erreur = null;
          } else {
            _erreur = 'Code faux.';
          }
        });
      case _Etape.nouveau:
        final p = problemePin(pin, longueur: longueurPinPatron);
        setState(() {
          _tour++;
          _erreur = p;
          if (p == null) {
            _nouveau = pin;
            _etape = _Etape.confirmer;
          }
        });
      case _Etape.confirmer:
        if (pin != _nouveau) {
          setState(() {
            _tour++;
            _etape = _Etape.nouveau;
            _nouveau = null;
            _erreur = 'Les deux codes sont différents. Recommencez.';
          });
          return;
        }
        setState(() => _enCours = true);
        try {
          await widget.etat.changerPin(_patron, pin);
          await widget.etat.services.voix.dire('Nouveau code enregistré.');
        } catch (e) {
          setState(() {
            _enCours = false;
            _tour++;
            _etape = _Etape.nouveau;
            _erreur = messageErreur(e);
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (titre, longueur) = switch (_etape) {
      _Etape.ancien => ('Votre code actuel (4 chiffres)', _patron.longueurCode),
      _Etape.nouveau => ('Nouveau code : 6 chiffres', longueurPinPatron),
      _Etape.confirmer => ('Tapez encore le nouveau code', longueurPinPatron),
    };
    return PageZp(
      titre: 'Nouveau code du patron',
      icone: Icons.key_rounded,
      corps: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('explication-code-6'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CouleursZp.marquePale,
                borderRadius: BorderRadius.circular(FormesZp.rayon),
              ),
              child: Text(
                '${_patron.nom}, le code du patron passe à 6 chiffres : '
                'il protège la caisse et la sauvegarde. Ne le donnez à personne.',
                style: const TextStyle(fontSize: 17),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: SaisiePin(
                  key: ValueKey(_tour),
                  titre: titre,
                  erreur: _erreur,
                  longueur: longueur,
                  onComplet: _saisi,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
