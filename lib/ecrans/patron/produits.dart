import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/quantites.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../communs.dart';

/// Unités proposées (on peut en taper une autre).
const List<String> unitesCourantes = [
  'pièce',
  'kg',
  'litre',
  'paquet',
  'boîte',
  'sachet',
  'bouteille',
  'tas',
  'mètre',
  'bol',
  // Pour qui vend seulement en gros (0.36) : le carton est l'unité.
  'carton',
  'sac',
  'casier',
  'bidon',
];

String _quantite(int milliemes) {
  final u = milliemes / milliemesParUnite;
  return u == u.roundToDouble() ? '${u.round()}' : u.toStringAsFixed(1);
}

/// Gestion → « Produits et prix » (patron seul) : ajouter, modifier, changer
/// un prix, masquer un produit qui ne se vend plus.
class PageProduits extends StatefulWidget {
  const PageProduits({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageProduits> createState() => _PageProduitsState();
}

class _PageProduitsState extends State<PageProduits> {
  late Future<List<Produit>> _liste = widget.etat.tousLesProduits();
  final _recherche = TextEditingController();
  bool _masques = false;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _ouvrir(Produit? p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageFicheProduit(etat: widget.etat, produit: p),
      ),
    );
    if (mounted) {
      setState(() {
        _liste = widget.etat.tousLesProduits();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Produits et prix',
      icone: Icons.sell_rounded,
      bas: GrosBouton(
        key: const Key('bouton-ajouter-produit'),
        texte: 'Ajouter un produit',
        icone: Icons.add_rounded,
        onPressed: () => _ouvrir(null),
      ),
      corps: FutureBuilder<List<Produit>>(
        future: _liste,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cherche = _recherche.text.trim().toLowerCase();
          final tous = s.data!;
          final nbMasques = tous.where((p) => !p.actif).length;
          final liste = [
            for (final p in tous)
              if (p.actif != _masques &&
                  (cherche.isEmpty || p.nom.toLowerCase().contains(cherche)))
                p,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  key: const Key('recherche-produits'),
                  controller: _recherche,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Chercher un produit',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('filtre-en-vente'),
                      label: Text('En vente (${tous.length - nbMasques})'),
                      selected: !_masques,
                      onSelected: (_) => setState(() => _masques = false),
                    ),
                    ChoiceChip(
                      key: const Key('filtre-masques'),
                      label: Text('Masqués ($nbMasques)'),
                      selected: _masques,
                      onSelected: (_) => setState(() => _masques = true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: liste.isEmpty
                    ? EtatVide(
                        icone: Icons.sell_rounded,
                        titre: _masques
                            ? 'Aucun produit masqué.'
                            : 'Aucun produit trouvé.',
                        explication: _masques
                            ? 'Un produit qui ne se vend plus peut être masqué : '
                                  'il disparaît de « Vendre », son historique reste.'
                            : 'Touchez « Ajouter un produit » : nom, prix, et le '
                                  'stock de départ si vous le connaissez.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: liste.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _LigneProduit(
                          produit: liste[i],
                          stock: widget.etat.stockLisible(liste[i]),
                          onTap: () => _ouvrir(liste[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LigneProduit extends StatelessWidget {
  const _LigneProduit({
    required this.produit,
    required this.stock,
    required this.onTap,
  });

  final Produit produit;

  /// Stock lisible (« 3 cartons de 24 et 5 boîtes », « pas encore compté »).
  final String stock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    return Material(
      color: CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CouleursZp.ligne),
      ),
      child: ListTile(
        key: Key('produit-${p.id}'),
        onTap: onTap,
        leading: ImageProduit(produit: p, taille: 44),
        title: Text(
          p.nom,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: p.actif ? CouleursZp.texte : CouleursZp.texteDoux,
          ),
        ),
        subtitle: Text(
          p.aUnPrix
              ? '${formatFrancs(p.prixUnitaire)} / ${p.uniteBase} · stock : $stock'
              : 'Vendu en gros seulement · stock : $stock',
          style: const TextStyle(fontSize: 15),
        ),
        trailing: p.actif
            ? const Icon(Icons.chevron_right_rounded)
            : const Text(
                'Masqué',
                style: TextStyle(color: CouleursZp.texteDoux),
              ),
      ),
    );
  }
}

/// Fiche d'un produit : nouveau (produit nul) ou modification.
class PageFicheProduit extends StatefulWidget {
  const PageFicheProduit({super.key, required this.etat, this.produit});

  final EtatApplication etat;
  final Produit? produit;

  @override
  State<PageFicheProduit> createState() => _PageFicheProduitState();
}

/// Une nouvelle vente en gros (carton, sac…) saisie dans la fiche.
class _NouvelEmballage {
  final nom = TextEditingController();
  final unites = TextEditingController();
  final prix = TextEditingController();

  /// Prix « revendeur » (facultatif) : un peu moins cher pour les revendeurs.
  final revendeur = TextEditingController();
}

class _PageFicheProduitState extends State<PageFicheProduit> {
  Produit? get _p => widget.produit;
  late final _nom = TextEditingController(text: _p?.nom ?? '');
  late final _unite = TextEditingController(text: _p?.uniteBase ?? 'pièce');
  late final _prix = TextEditingController(
    text: (_p?.prixUnitaire ?? 0) > 0 ? '${_p!.prixUnitaire}' : '',
  );
  late final _achat = TextEditingController(
    text: _p?.prixAchat == null ? '' : '${_p!.prixAchat}',
  );
  late final _seuil = TextEditingController(
    text: (_p?.seuilAlerteMilliemes ?? 0) > 0
        ? _quantite(_p!.seuilAlerteMilliemes)
        : '',
  );
  final _stock = TextEditingController();
  String? _photo;
  bool _photoEffacee = false;
  final List<_NouvelEmballage> _nouveaux = [];
  final Map<String, TextEditingController> _prixEmballages = {};
  List<Conditionnement> _emballages = const [];
  Map<String, Conditionnement> _revendeurs = const {};
  final Map<String, TextEditingController> _prixRevendeurs = {};
  List<(DateTime, int)> _historique = const [];
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _photo = _p?.photo;
    final p = _p;
    if (p != null) _charger(p);
  }

  Future<void> _charger(Produit p) async {
    final e = await widget.etat.journal.conditionnements(p.id);
    final h = await widget.etat.journal.historiquePrix(p.id);
    if (!mounted) return;
    setState(() {
      // Les prix « revendeur » sont montrés à côté de leur vente en gros.
      _emballages = [
        for (final c in e)
          if (!estPrixRevendeur(c)) c,
      ];
      _revendeurs = {
        for (final c in e)
          if (estPrixRevendeur(c)) c.nom: c,
      };
      _historique = h;
      for (final c in _emballages) {
        _prixEmballages[c.id] = TextEditingController(text: '${c.prixVente}');
        final r = _revendeurs[nomRevendeur(c.nom)];
        _prixRevendeurs[c.id] = TextEditingController(
          text: r == null || r.prixVente == 0 ? '' : '${r.prixVente}',
        );
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_nom, _unite, _prix, _achat, _seuil, _stock]) {
      c.dispose();
    }
    for (final c in [..._prixEmballages.values, ..._prixRevendeurs.values]) {
      c.dispose();
    }
    for (final n in _nouveaux) {
      n.nom.dispose();
      n.unites.dispose();
      n.prix.dispose();
      n.revendeur.dispose();
    }
    super.dispose();
  }

  int? _entier(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _photographier() async {
    final octets = await widget.etat.services.prendrePhoto(
      SourcePhoto.appareil,
    );
    if (octets != null && mounted) {
      setState(() {
        _photo = base64.encode(octets);
        _photoEffacee = false;
      });
    }
  }

  Future<void> _enregistrer() async {
    final etat = widget.etat;
    final seuil = double.tryParse(_seuil.text.replaceAll(',', '.').trim());
    final seuilMilliemes = seuil == null
        ? 0
        : (seuil * milliemesParUnite).round();
    setState(() => _occupe = true);
    try {
      final p = _p;
      if (p == null) {
        await etat.creerProduit(
          nom: _nom.text,
          uniteBase: _unite.text,
          prixVente: _entier(_prix) ?? 0,
          prixAchat: _entier(_achat),
          seuilAlerteMilliemes: seuilMilliemes,
          photo: _photo,
          conditionnements: [
            for (final n in _nouveaux) ...[
              (n.nom.text, _entier(n.unites) ?? 0, _entier(n.prix) ?? 0),
              if ((_entier(n.revendeur) ?? 0) > 0 &&
                  n.nom.text.trim().isNotEmpty)
                (
                  nomRevendeur(n.nom.text.trim()),
                  _entier(n.unites) ?? 0,
                  _entier(n.revendeur)!,
                ),
            ],
          ],
          stockDepart: _entier(_stock) ?? 0,
        );
      } else {
        await etat.modifierProduit(
          p,
          nom: _nom.text,
          uniteBase: _unite.text,
          prixVente: _entier(_prix),
          prixAchat: _entier(_achat),
          seuilAlerteMilliemes: seuilMilliemes,
          photo: _photo,
          effacerPhoto: _photoEffacee,
        );
        for (final c in _emballages) {
          final prix = _entier(_prixEmballages[c.id]!);
          if (prix != null && prix != c.prixVente) {
            await etat.changerPrixConditionnement(p, c, prix);
          }
          // Prix revendeur : ajouté, changé, ou retiré (0 = plus proposé).
          final rev = _entier(_prixRevendeurs[c.id]!) ?? 0;
          final existant = _revendeurs[nomRevendeur(c.nom)];
          if (existant != null) {
            if (rev != existant.prixVente) {
              await etat.changerPrixConditionnement(p, existant, rev);
            }
          } else if (rev > 0 && c.facteurMilliemes % milliemesParUnite == 0) {
            await etat.ajouterConditionnement(
              p,
              nom: nomRevendeur(c.nom),
              unites: c.facteurMilliemes ~/ milliemesParUnite,
              prix: rev,
            );
          }
        }
        for (final n in _nouveaux) {
          if (n.nom.text.trim().isEmpty) continue;
          await etat.ajouterConditionnement(
            p,
            nom: n.nom.text,
            unites: _entier(n.unites) ?? 0,
            prix: _entier(n.prix) ?? 0,
          );
          final rev = _entier(n.revendeur) ?? 0;
          if (rev > 0) {
            await etat.ajouterConditionnement(
              p,
              nom: nomRevendeur(n.nom.text.trim()),
              unites: _entier(n.unites) ?? 0,
              prix: rev,
            );
          }
        }
      }
      if (!mounted) return;
      annoncer(context, '« ${_nom.text.trim()} » est enregistré.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _masquer(bool masquer) async {
    final p = _p!;
    try {
      await widget.etat.masquerProduit(p, masquer: masquer);
      if (!mounted) return;
      annoncer(
        context,
        masquer
            ? '« ${p.nom} » est masqué : il n\'apparaît plus dans « Vendre ».'
            : '« ${p.nom} » est de nouveau en vente.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    }
  }

  Widget _champNombre(
    String cle,
    TextEditingController c,
    String label, {
    String? aide,
    bool virgule = false,
  }) => TextField(
    key: Key(cle),
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: virgule),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(virgule ? r'[0-9.,]' : r'[0-9]'),
      ),
    ],
    style: const TextStyle(fontSize: 20),
    decoration: decorationChamp(label, aide: aide),
  );

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final apercu = Produit(
      id: '',
      nom: '',
      uniteBase: '',
      prixUnitaire: 0,
      seuilAlerteMilliemes: 0,
      emoji: p?.emoji,
      photo: _photoEffacee ? null : _photo,
    );
    const espace = SizedBox(height: 14);
    return PageZp(
      titre: p == null ? 'Nouveau produit' : p.nom,
      icone: Icons.sell_rounded,
      bas: GrosBouton(
        key: const Key('bouton-enregistrer-produit'),
        texte: 'Enregistrer',
        icone: Icons.check_rounded,
        onPressed: _occupe ? null : _enregistrer,
      ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ImageProduit(produit: apercu, taille: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('bouton-photo-produit'),
                      onPressed: _photographier,
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Photo'),
                    ),
                    if (_photo != null && !_photoEffacee)
                      TextButton(
                        onPressed: () => setState(() => _photoEffacee = true),
                        child: const Text('Enlever la photo'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          espace,
          TextField(
            key: const Key('champ-nom-produit'),
            controller: _nom,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20),
            decoration: decorationChamp('Nom du produit'),
          ),
          espace,
          TextField(
            key: const Key('champ-unite-produit'),
            controller: _unite,
            style: const TextStyle(fontSize: 20),
            decoration: decorationChamp(
              'Se vend à l\'unité de',
              aide: 'pièce, kg, litre, paquet…',
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final u in unitesCourantes)
                ChoiceChip(
                  label: Text(u),
                  selected: _unite.text.trim() == u,
                  onSelected: (_) => setState(() => _unite.text = u),
                ),
            ],
          ),
          espace,
          _champNombre(
            'champ-prix-vente',
            _prix,
            'Prix au détail (F pour 1 ${_unite.text.trim().isEmpty ? 'unité' : _unite.text.trim()})',
          ),
          espace,
          _champNombre(
            'champ-prix-achat',
            _achat,
            'Prix d\'achat (F, facultatif)',
            aide: 'Sert au bénéfice estimé avant le premier arrivage.',
          ),
          espace,
          _champNombre(
            'champ-seuil',
            _seuil,
            'Alerte stock bas (facultatif)',
            aide: 'Vous êtes prévenu quand il en reste moins que ce nombre.',
            virgule: true,
          ),
          if (p == null) ...[
            espace,
            _champNombre(
              'champ-stock-depart',
              _stock,
              'Stock de départ (facultatif)',
              aide: 'Ce qui est déjà dans la boutique.',
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Vente en gros (carton, sac, casier…)',
            key: Key('titre-vente-en-gros'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Facultatif. Le stock se calcule tout seul : vendre 1 carton enlève '
            'tout ce qu\'il contient.',
            style: TextStyle(fontSize: 15, color: CouleursZp.texteDoux),
          ),
          for (final c in _emballages)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '1 ${c.nom} = ${decrireUnites(c.facteurMilliemes, _unite.text.trim().isEmpty ? 'unité' : _unite.text.trim())}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _champNombre(
                          'prix-emballage-${c.id}',
                          _prixEmballages[c.id]!,
                          'Prix de gros (F)',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _champNombre(
                          'prix-revendeur-${c.id}',
                          _prixRevendeurs[c.id]!,
                          'Revendeur (F)',
                          aide: 'facultatif',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          for (final (i, n) in _nouveaux.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: Key('nouvel-emballage-nom-$i'),
                          controller: n.nom,
                          decoration: decorationChamp('Nom (carton, sac…)'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: _champNombre(
                          'nouvel-emballage-unites-$i',
                          n.unites,
                          'Combien de ${(_unite.text.trim().isEmpty ? 'unités' : pluriel(_unite.text.trim(), 2))} dedans',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _champNombre(
                          'nouvel-emballage-prix-$i',
                          n.prix,
                          'Prix de gros (F)',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _champNombre(
                          'nouvel-emballage-revendeur-$i',
                          n.revendeur,
                          'Revendeur (F)',
                          aide: 'facultatif',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('bouton-ajouter-emballage'),
              onPressed: () =>
                  setState(() => _nouveaux.add(_NouvelEmballage())),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Ajouter une vente en gros',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          if (p != null && _historique.length > 1) ...[
            const SizedBox(height: 12),
            const Text(
              'Historique des prix',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            for (final (quand, prix) in _historique.reversed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${quand.day.toString().padLeft(2, '0')}/'
                  '${quand.month.toString().padLeft(2, '0')}/${quand.year} : '
                  '${formatFrancs(prix)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Les ventes déjà faites gardent leur prix.',
              style: TextStyle(fontSize: 14, color: CouleursZp.texteDoux),
            ),
          ],
          if (p != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: Key(
                p.actif ? 'bouton-masquer-produit' : 'bouton-remettre-produit',
              ),
              onPressed: () => _masquer(p.actif),
              icon: Icon(
                p.actif
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              label: Text(
                p.actif
                    ? 'Masquer ce produit (il ne se vend plus)'
                    : 'Remettre ce produit en vente',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
