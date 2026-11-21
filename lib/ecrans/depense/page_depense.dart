import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/quantites.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../communs.dart';
import '../patron/arrivages.dart' show CompteurGeant;

/// Bouton « Dépense » : de l'argent est sorti, ou de la marchandise est perdue.
class PageChoixDepense extends StatelessWidget {
  const PageChoixDepense({
    super.key,
    required this.etat,
    this.ouvrirDepenseArgent,
  });

  final EtatApplication etat;

  /// Formulaire de dépense d'argent (étape B9) ; nul = pas encore disponible.
  final WidgetBuilder? ouvrirDepenseArgent;

  @override
  Widget build(BuildContext context) {
    Widget choix(
      String cle,
      IconData icone,
      String titre,
      String texte,
      VoidCallback onTap,
    ) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: CouleursZp.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: CouleursZp.argentSort, width: 2),
          ),
          child: InkWell(
            key: Key(cle),
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Icon(icone, size: 64, color: CouleursZp.argentSort),
                    const SizedBox(height: 8),
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      texte,
                      style: const TextStyle(
                        fontSize: 18,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return PageZp(
      titre: 'Dépense',
      icone: Icons.payments_rounded,
      corps: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            choix(
              'choix-depense-argent',
              Icons.payments_rounded,
              'De l\'argent',
              'est sorti de la caisse',
              () {
                final f = ouvrirDepenseArgent;
                if (f == null) {
                  annoncer(context, '« Dépense d\'argent » arrive bientôt.');
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: f));
                }
              },
            ),
            choix(
              'choix-perte',
              Icons.broken_image_rounded,
              'De la marchandise',
              'est perdue ou abîmée',
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => PagePerte(etat: etat))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Motifs de perte proposés.
const List<(String, IconData)> motifsPerte = [
  ('Cassé', Icons.heart_broken_rounded),
  ('Périmé', Icons.event_busy_rounded),
  ('Pourri', Icons.coronavirus_rounded),
  ('Mangé par les rats ou insectes', Icons.pest_control_rounded),
  ('Volé', Icons.no_backpack_rounded),
  ('Mouillé', Icons.water_drop_rounded),
];

/// Perte déclarée : produit, quantité, motif. La marchandise sort du stock.
class PagePerte extends StatefulWidget {
  const PagePerte({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<PagePerte> createState() => _PagePerteState();
}

class _PagePerteState extends State<PagePerte> {
  Produit? _produit;
  List<Conditionnement> _conds = const [];
  Conditionnement? _unite;
  int _nombre = 1;
  String? _motif;
  bool _enCours = false;

  Future<void> _choisirProduit(Produit p) async {
    final conds = await widget.etat.journal.conditionnements(p.id);
    setState(() {
      _produit = p;
      _conds = conds;
      _unite = null;
      _nombre = 1;
    });
  }

  Future<void> _enregistrer() async {
    setState(() => _enCours = true);
    try {
      await widget.etat.declarerPerte(
        produit: _produit!,
        conditionnement: _unite,
        nombre: _nombre,
        motif: _motif!,
      );
      if (!mounted) return;
      annoncer(
        context,
        'Perte enregistrée : $_nombre ${pluriel(_unite?.nom ?? _produit!.uniteBase, _nombre)} de ${_produit!.nom}.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _produit;
    if (p == null) {
      final produits = widget.etat.produits;
      return PageZp(
        titre: 'Quel produit ?',
        icone: Icons.broken_image_rounded,
        corps: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 132,
            mainAxisExtent: 120,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: produits.length,
          itemBuilder: (context, i) {
            final pr = produits[i];
            return Material(
              color: CouleursZp.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: CouleursZp.ligne),
              ),
              child: InkWell(
                key: Key('perte-${pr.catalogueId ?? pr.id}'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => _choisirProduit(pr),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ImageProduit(produit: pr, taille: 44),
                    Text(
                      pr.nom,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return PageZp(
      titre: 'Perte : ${p.nom}',
      icone: Icons.broken_image_rounded,
      bas: GrosBouton(
        key: const Key('bouton-enregistrer-perte'),
        texte: 'Enregistrer la perte',
        icone: Icons.check_rounded,
        couleur: CouleursZp.argentSort,
        onPressed: _motif == null || _enCours ? null : _enregistrer,
      ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_conds.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in [null, ..._conds])
                  ChoiceChip(
                    key: Key('perte-unite-${c?.nom ?? p.uniteBase}'),
                    label: Text(
                      c?.nom ?? p.uniteBase,
                      style: const TextStyle(fontSize: 18),
                    ),
                    selected: _unite?.id == c?.id,
                    onSelected: (_) => setState(() => _unite = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          CompteurGeant(
            valeur: _nombre,
            unite: pluriel(_unite?.nom ?? p.uniteBase, _nombre),
            onChange: (v) => setState(() => _nombre = v),
          ),
          const SizedBox(height: 18),
          const Text(
            'Pourquoi ?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (m, icone) in motifsPerte)
                ChoiceChip(
                  key: Key('motif-perte-$m'),
                  avatar: Icon(icone),
                  label: Text(m, style: const TextStyle(fontSize: 17)),
                  selected: _motif == m,
                  onSelected: (_) => setState(() => _motif = m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
