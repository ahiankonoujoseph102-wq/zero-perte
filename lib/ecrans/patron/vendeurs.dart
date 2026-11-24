import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/utilisateurs.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
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
              ? const EtatVide(
                  icone: Icons.badge_rounded,
                  titre: 'Aucun vendeur pour l\'instant.',
                  explication:
                      'Donnez à chaque vendeur son propre code : vous savez qui a '
                      'vendu quoi, et il ne voit ni les bénéfices ni les réglages.',
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

/// Ajout d'un vendeur, ou nouveau code pour un vendeur existant.
///
/// Le code n'est JAMAIS choisi par une personne : l'application le tire au
/// hasard et l'affiche une seule fois au patron, qui le donne au vendeur en
/// privé. Ainsi personne ne peut apprendre, en essayant un code « déjà
/// pris », qu'il appartient à quelqu'un d'autre.
class PageNouveauVendeur extends StatefulWidget {
  const PageNouveauVendeur({super.key, required this.etat, this.existant});

  final EtatApplication etat;
  final Utilisateur? existant;

  @override
  State<PageNouveauVendeur> createState() => _PageNouveauVendeurState();
}

class _PageNouveauVendeurState extends State<PageNouveauVendeur> {
  late final _nom = TextEditingController(text: widget.existant?.nom ?? '');
  String? _erreur;
  bool _enCours = false;

  /// Code tiré au hasard, affiché une seule fois.
  String? _code;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  String get _prenom => widget.existant?.nom ?? _nom.text.trim();

  Future<void> _creerCode() async {
    if (_prenom.isEmpty) {
      setState(() => _erreur = 'Écrivez d\'abord le prénom.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final code = widget.existant == null
          ? (await widget.etat.ajouterVendeur(nom: _prenom)).code
          : await widget.etat.nouveauCodeVendeur(widget.existant!);
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return PageZp(
      titre: widget.existant == null
          ? 'Nouveau vendeur'
          : 'Code de ${widget.existant!.nom}',
      icone: Icons.person_add_rounded,
      bas: code != null
          ? GrosBouton(
              key: const Key('bouton-code-note'),
              texte: 'C\'est noté',
              icone: Icons.check_rounded,
              onPressed: () {
                annoncer(
                  context,
                  widget.existant == null
                      ? '$_prenom est ajouté.'
                      : 'Code changé.',
                );
                Navigator.of(context).pop();
              },
            )
          : GrosBouton(
              key: const Key('bouton-creer-code'),
              texte: widget.existant == null
                  ? 'Ajouter et créer son code'
                  : 'Créer un nouveau code',
              icone: Icons.password_rounded,
              onPressed: _enCours ? null : _creerCode,
            ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (code == null) ...[
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
                  onChanged: (_) => setState(() => _erreur = null),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              widget.existant == null
                  ? 'L\'application va créer un code secret de 4 chiffres '
                        'pour ce vendeur. Vous le lui donnerez en privé.'
                  : 'L\'ancien code de ${widget.existant!.nom} ne marchera '
                        'plus. L\'application va en créer un nouveau.',
              style: const TextStyle(fontSize: 18),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(
                _erreur!,
                key: const Key('erreur-vendeur'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CouleursZp.argentSortClair,
                ),
              ),
            ],
          ] else ...[
            Text(
              'Code secret de $_prenom',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: CouleursZp.surface,
                borderRadius: BorderRadius.circular(FormesZp.rayon),
                border: Border.all(color: CouleursZp.ligne, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code.split('').join(' '),
                  key: const Key('code-vendeur-cree'),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Consigne(
              Icons.visibility_off_rounded,
              'Donnez ce code au vendeur en privé. Personne d\'autre ne '
              'doit le voir.',
            ),
            const _Consigne(
              Icons.history_toggle_off_rounded,
              'Il ne sera plus jamais affiché. S\'il est oublié : « Changer '
              'le code ».',
            ),
            const _Consigne(
              Icons.login_rounded,
              'Pour entrer, le vendeur tape ce code : l\'application le '
              'reconnaît.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Consigne extends StatelessWidget {
  const _Consigne(this.icone, this.texte);

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 28, color: CouleursZp.texteDoux),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 18))),
        ],
      ),
    );
  }
}
