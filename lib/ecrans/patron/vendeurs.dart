import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/utilisateurs.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../clavier_pin.dart';
import '../communs.dart';
import '../connexion.dart';

/// Gestion des vendeurs par le patron : ajouter, bloquer, débloquer, changer le code.
class PageVendeurs extends StatelessWidget {
  const PageVendeurs({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final vendeurs = etat.vendeurs;
        return PageZp(
          titre: 'Vendeurs',
          icone: Icons.groups_rounded,
          bas: GrosBouton(
            key: const Key('bouton-ajouter-vendeur'),
            texte: 'Ajouter un vendeur',
            icone: Icons.person_add_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PageNouveauVendeur(etat: etat)),
            ),
          ),
          corps: vendeurs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucun vendeur pour l\'instant.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vendeurs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final v = vendeurs[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CouleursZp.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: CouleursZp.ligne),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Avatar(nom: v.nom, taille: 52, bloque: !v.actif),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.nom,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      v.actif ? 'Peut vendre' : 'Bloqué',
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: v.actif
                                            ? CouleursZp.argentEntre
                                            : CouleursZp.argentSort,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: Key('bloquer-${v.nom}'),
                                onPressed: () async {
                                  await etat.bloquer(v, bloque: v.actif);
                                  if (context.mounted) {
                                    annoncer(
                                      context,
                                      v.actif
                                          ? '${v.nom} est bloqué.'
                                          : '${v.nom} peut de nouveau vendre.',
                                    );
                                  }
                                },
                                icon: Icon(
                                  v.actif
                                      ? Icons.block_rounded
                                      : Icons.lock_open_rounded,
                                ),
                                label: Text(
                                  v.actif ? 'Bloquer' : 'Débloquer',
                                  style: const TextStyle(fontSize: 17),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  foregroundColor: v.actif
                                      ? CouleursZp.argentSort
                                      : null,
                                ),
                              ),
                              OutlinedButton.icon(
                                key: Key('changer-code-${v.nom}'),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PageNouveauVendeur(
                                      etat: etat,
                                      existant: v,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.password_rounded),
                                label: const Text(
                                  'Changer le code',
                                  style: TextStyle(fontSize: 17),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Ajout d'un vendeur (prénom + code choisi par le vendeur), ou changement de son code.
class PageNouveauVendeur extends StatefulWidget {
  const PageNouveauVendeur({super.key, required this.etat, this.existant});

  final EtatApplication etat;
  final Utilisateur? existant;

  @override
  State<PageNouveauVendeur> createState() => _PageNouveauVendeurState();
}

class _PageNouveauVendeurState extends State<PageNouveauVendeur> {
  late final _nom = TextEditingController(text: widget.existant?.nom ?? '');
  String? _premier;
  String? _erreur;
  int _tour = 0;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _saisi(String pin) async {
    if (_nom.text.trim().isEmpty) {
      setState(() => _erreur = 'Écrivez d\'abord le prénom.');
      return;
    }
    if (_premier == null) {
      final p = problemePin(pin);
      setState(() {
        _tour++;
        _erreur = p;
        if (p == null) _premier = pin;
      });
      return;
    }
    if (pin != _premier) {
      setState(() {
        _tour++;
        _premier = null;
        _erreur = 'Les deux codes sont différents. Recommencez.';
      });
      return;
    }
    try {
      if (widget.existant == null) {
        await widget.etat.ajouterVendeur(nom: _nom.text, pin: pin);
      } else {
        await widget.etat.changerPin(widget.existant!, pin);
      }
      if (!mounted) return;
      annoncer(
        context,
        widget.existant == null
            ? '${_nom.text.trim()} est ajouté.'
            : 'Code changé.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _tour++;
        _premier = null;
        _erreur = messageErreur(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: widget.existant == null
          ? 'Nouveau vendeur'
          : 'Code de ${widget.existant!.nom}',
      icone: Icons.person_add_rounded,
      corps: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.existant == null)
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: TextField(
                  key: const Key('champ-nom-vendeur'),
                  controller: _nom,
                  style: const TextStyle(fontSize: 22),
                  textCapitalization: TextCapitalization.words,
                  decoration: decorationChamp(
                    'Prénom du vendeur',
                    icone: Icons.person_rounded,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Le vendeur choisit lui-même son code, sans le montrer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
            ),
            Expanded(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: SaisiePin(
                  key: ValueKey(_tour),
                  titre: _premier == null
                      ? 'Code du vendeur (4 chiffres)'
                      : 'Encore le même code',
                  erreur: _erreur,
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
