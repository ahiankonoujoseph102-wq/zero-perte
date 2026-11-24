/// « Nouveau produit » pendant la vente (0.36) : on démarre sans inventaire.
/// Le nom et le prix suffisent ; le carton (vente en gros) est facultatif.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/etat_application.dart';
import '../../domaine/boutique.dart';
import '../../donnees/journal_local.dart' show Produit;
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../communs.dart';

const _unitesDetail = [
  'pièce',
  'boîte',
  'bol',
  'bouteille',
  'sachet',
  'kg',
  'litre',
];
const _unitesGros = ['carton', 'sac', 'casier', 'bidon', 'paquet', 'balle'];

/// Ouvre la fiche courte ; rend le produit créé (nul si annulé).
Future<Produit?> demanderNouveauProduit(
  BuildContext context,
  EtatApplication etat, {
  String nom = '',
}) => showModalBottomSheet<Produit>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: _FicheNouveauProduit(etat: etat, nom: nom),
  ),
);

class _FicheNouveauProduit extends StatefulWidget {
  const _FicheNouveauProduit({required this.etat, required this.nom});
  final EtatApplication etat;
  final String nom;

  @override
  State<_FicheNouveauProduit> createState() => _FicheNouveauProduitState();
}

class _FicheNouveauProduitState extends State<_FicheNouveauProduit> {
  late final _nom = TextEditingController(text: widget.nom);
  final _prix = TextEditingController();
  final _nomGros = TextEditingController();
  final _nombreGros = TextEditingController();
  final _prixGros = TextEditingController();
  late final bool _grosSeulement =
      widget.etat.config.vente == FaconDeVendre.gros;
  late final bool _proposerGros =
      widget.etat.config.vente != FaconDeVendre.detail && !_grosSeulement;
  late String _unite = _grosSeulement ? 'carton' : 'pièce';
  bool _avecGros = false;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    for (final c in [_nom, _prix, _nomGros, _nombreGros, _prixGros]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _entier(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _valider() async {
    final prix = _entier(_prix) ?? 0;
    final gros = <(String, int, int)>[];
    if (_avecGros) {
      final n = _entier(_nombreGros) ?? 0;
      final pg = _entier(_prixGros) ?? 0;
      if (_nomGros.text.trim().isEmpty || n <= 1 || pg <= 0) {
        setState(
          () => _erreur = 'Pour la vente en gros : le nom (carton…), combien dedans, et le prix.',
        );
        return;
      }
      gros.add((_nomGros.text.trim(), n, pg));
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final p = await widget.etat.creerProduit(
        nom: _nom.text,
        uniteBase: _unite,
        prixVente: prix,
        conditionnements: gros,
        pendantLaVente: true,
      );
      if (mounted) Navigator.of(context).pop(p);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  Widget _champNombre(String cle, TextEditingController c, String label) =>
      TextField(
        key: Key(cle),
        controller: c,
        keyboardType: TextInputType.number,
        // 9 chiffres au plus (999 999 999 F) : un chiffre de trop tapé par
        // erreur ne fait pas un prix absurde (audit 0.37).
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        style: const TextStyle(fontSize: 22),
        decoration: decorationChamp(label),
      );

  @override
  Widget build(BuildContext context) {
    final unites = _grosSeulement ? _unitesGros : _unitesDetail;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nouveau produit',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Le nom et le prix suffisent. Le stock se compte plus tard.',
              style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('nouveau-produit-nom'),
              controller: _nom,
              autofocus: widget.nom.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 22),
              decoration: decorationChamp('Nom (ex. Lait Bonnet Rouge)'),
            ),
            const SizedBox(height: 10),
            Text(
              _grosSeulement ? 'Vous le vendez par :' : 'Vous le vendez à :',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final u in unites)
                  ChoiceChip(
                    key: Key('nouveau-produit-unite-$u'),
                    label: Text(u, style: const TextStyle(fontSize: 18)),
                    selected: _unite == u,
                    onSelected: (_) => setState(() => _unite = u),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _champNombre(
              'nouveau-produit-prix',
              _prix,
              'Prix pour 1 $_unite (F)',
            ),
            if (_proposerGros) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('nouveau-produit-avec-gros'),
                contentPadding: EdgeInsets.zero,
                value: _avecGros,
                onChanged: (v) => setState(() => _avecGros = v),
                title: const Text(
                  'Vendu aussi en gros (carton, sac…)',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              if (_avecGros) ...[
                TextField(
                  key: const Key('nouveau-produit-gros-nom'),
                  controller: _nomGros,
                  style: const TextStyle(fontSize: 20),
                  decoration: decorationChamp('Nom (carton, sac, casier…)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _champNombre(
                        'nouveau-produit-gros-nombre',
                        _nombreGros,
                        'Combien de $_unite dedans',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _champNombre(
                        'nouveau-produit-gros-prix',
                        _prixGros,
                        'Prix de gros (F)',
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(
                _erreur!,
                key: const Key('nouveau-produit-erreur'),
                style: const TextStyle(
                  fontSize: 17,
                  color: CouleursZp.argentSortClair,
                ),
              ),
            ],
            const SizedBox(height: 14),
            GrosBouton(
              key: const Key('bouton-creer-produit-vente'),
              texte: 'Ajouter et vendre',
              icone: Icons.add_shopping_cart_rounded,
              couleur: CouleursZp.argentEntre,
              onPressed: _enCours ? null : _valider,
            ),
          ],
        ),
      ),
    );
  }
}
