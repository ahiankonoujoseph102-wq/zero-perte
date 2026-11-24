import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/quantites.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../communs.dart';

/// Liste des produits avec leur stock ; toucher un produit pour enregistrer un arrivage.
class PageArrivages extends StatelessWidget {
  const PageArrivages({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final produits = etat.produits;
        return PageZp(
          titre: 'Arrivage',
          icone: Icons.local_shipping_rounded,
          corps: produits.isEmpty
              ? const EtatVide(
                  icone: Icons.local_shipping_rounded,
                  couleur: CouleursZp.ciel,
                  titre: 'Pas encore de produit.',
                  explication:
                      'Vendez une première fois avec « Vendre » → « Nouveau '
                      'produit », ou ajoutez-le dans Gestion → « Produits et '
                      'prix ». Il apparaîtra ici.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: produits.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return const Text(
                        'Touchez le produit qui vient d\'arriver.',
                        style: TextStyle(
                          fontSize: 18,
                          color: CouleursZp.texteDoux,
                        ),
                      );
                    }
                    final p = produits[i - 1];
                    return _LigneStock(etat: etat, produit: p);
                  },
                ),
        );
      },
    );
  }
}

class _LigneStock extends StatelessWidget {
  const _LigneStock({required this.etat, required this.produit});

  final EtatApplication etat;
  final Produit produit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CouleursZp.ligne),
      ),
      child: InkWell(
        key: Key('arrivage-${produit.catalogueId ?? produit.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FormulaireArrivage(etat: etat, produit: produit),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ImageProduit(produit: produit, taille: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produit.nom,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    FutureBuilder<List<Conditionnement>>(
                      future: etat.journal.conditionnements(produit.id),
                      builder: (context, c) => Text(
                        'En stock : ${etat.stockLisible(produit)}',
                        style: TextStyle(
                          fontSize: 17,
                          color: etat.stock(produit.id) <= 0
                              ? CouleursZp.argentSort
                              : CouleursZp.texteDoux,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_rounded, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulaire d'arrivage : unité (sac, carton… ou unité de base), nombre, prix payé.
class FormulaireArrivage extends StatefulWidget {
  const FormulaireArrivage({
    super.key,
    required this.etat,
    required this.produit,
  });

  final EtatApplication etat;
  final Produit produit;

  @override
  State<FormulaireArrivage> createState() => _FormulaireArrivageState();
}

class _FormulaireArrivageState extends State<FormulaireArrivage> {
  // « 10 cartons » met le stock à jour (le prix revendeur n'est pas une
  // autre façon de recevoir : il n'est pas proposé ici).
  late final Future<List<Conditionnement>> _conds = widget.etat.journal
      .conditionnements(widget.produit.id)
      .then(
        (l) => [
          for (final c in l)
            if (!estPrixRevendeur(c)) c,
        ],
      );
  Conditionnement? _unite; // nul = unité de base
  bool _uniteChoisie = false;
  int _nombre = 1;
  final _cout = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _cout.dispose();
    super.dispose();
  }

  String get _nomUnite => _unite?.nom ?? widget.produit.uniteBase;

  Future<void> _enregistrer() async {
    setState(() => _enCours = true);
    try {
      await widget.etat.enregistrerArrivage(
        produit: widget.produit,
        conditionnement: _unite,
        nombre: _nombre,
        coutTotal: lireEntier(_cout.text),
      );
      if (!mounted) return;
      annoncer(
        context,
        'Arrivage enregistré : $_nombre ${pluriel(_nomUnite, _nombre)} de ${widget.produit.nom}.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final cout = lireEntier(_cout.text);
    return PageZp(
      titre: p.nom,
      bas: GrosBouton(
        key: const Key('bouton-enregistrer-arrivage'),
        texte: 'Enregistrer l\'arrivage',
        icone: Icons.check_rounded,
        onPressed: _enCours || _nombre <= 0 ? null : _enregistrer,
      ),
      corps: FutureBuilder<List<Conditionnement>>(
        future: _conds,
        builder: (context, s) {
          final conds = s.data ?? const <Conditionnement>[];
          if (!_uniteChoisie && conds.isNotEmpty) {
            // Par défaut, le plus grand conditionnement (on reçoit des sacs, des cartons…).
            _unite =
                (conds.toList()..sort(
                      (a, b) =>
                          b.facteurMilliemes.compareTo(a.facteurMilliemes),
                    ))
                    .first;
            _uniteChoisie = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  ImageProduit(produit: p, taille: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'En stock : ${widget.etat.stockLisible(p)}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Qu\'est-ce qui est arrivé ?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in [null, ...conds])
                    ChoiceChip(
                      key: Key('unite-${c?.nom ?? p.uniteBase}'),
                      label: Text(
                        c?.nom ?? p.uniteBase,
                        style: const TextStyle(fontSize: 18),
                      ),
                      selected: _unite?.id == c?.id,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      onSelected: (_) => setState(() {
                        _unite = c;
                        _uniteChoisie = true;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Combien ?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              CompteurGeant(
                valeur: _nombre,
                unite: pluriel(_nomUnite, _nombre),
                onChange: (v) => setState(() => _nombre = v),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('champ-cout'),
                controller: _cout,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                decoration: decorationChamp(
                  'Prix payé au total',
                  icone: Icons.payments_rounded,
                  aide: cout > 0 && _nombre > 0
                      ? 'Soit ${formatFrancs(diviserArrondi(cout, _nombre))} pour 1 $_nomUnite'
                      : 'Sert à calculer votre bénéfice.',
                ).copyWith(suffixText: 'F'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Grand compteur « − 3 + » pour les gros doigts.
class CompteurGeant extends StatelessWidget {
  const CompteurGeant({
    super.key,
    required this.valeur,
    required this.unite,
    required this.onChange,
    this.minimum = 1,
  });

  final int valeur;
  final String unite;
  final ValueChanged<int> onChange;
  final int minimum;

  @override
  Widget build(BuildContext context) {
    Widget bouton(String cle, IconData icone, VoidCallback? f) => SizedBox(
      width: 72,
      height: 72,
      child: FilledButton.tonal(
        key: Key(cle),
        onPressed: f == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                f();
              },
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: Icon(icone, size: 40),
      ),
    );
    return Row(
      children: [
        bouton(
          'moins',
          Icons.remove_rounded,
          valeur > minimum ? () => onChange(valeur - 1) : null,
        ),
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$valeur',
                  key: const Key('compteur'),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                unite,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: CouleursZp.texteDoux,
                ),
              ),
            ],
          ),
        ),
        bouton('plus', Icons.add_rounded, () => onChange(valeur + 1)),
      ],
    );
  }
}
