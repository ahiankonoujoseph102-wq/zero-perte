import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/boutique.dart';
import '../../domaine/quantites.dart';
import '../../domaine/utilisateurs.dart';
import '../../donnees/journal_local.dart';
import '../../services/raccourci.dart';
import '../../theme/couleurs.dart';
import '../clavier_pin.dart';
import '../logo_boutique.dart';
import '../recu/apercu_recu.dart';

/// Textes lus à voix haute pour les étapes de personnalisation.
String texteEtapeBoutique(EtapeAssistant e) => switch (e) {
  EtapeAssistant.typeBoutique => 'Que vendez-vous ? Touchez les images qui ressemblent à votre boutique. Vous pouvez en choisir plusieurs.',
  EtapeAssistant.identite => 'Le nom de votre boutique, et sa photo. Vous pouvez prendre une photo de la boutique ou de votre logo.',
  EtapeAssistant.contact => 'Votre numéro de téléphone et l\'adresse de la boutique. Ils seront écrits sur les reçus.',
  EtapeAssistant.couleur => 'Choisissez la couleur de votre boutique.',
  EtapeAssistant.produits => 'Touchez les produits que vous vendez. Vous pourrez en ajouter d\'autres plus tard.',
  EtapeAssistant.prix => 'Écrivez le prix de vente de chaque produit. Si vous ne savez pas encore, vous pourrez le faire plus tard.',
  EtapeAssistant.recu => 'Voici le reçu que recevront vos clients. Vous pouvez changer le message du bas.',
  EtapeAssistant.codePatron => 'Votre code secret de patron : quatre chiffres. Ne le donnez à personne, même pas à votre vendeur.',
  EtapeAssistant.fin => 'Votre boutique est prête. Touchez Commencer.',
  _ => '',
};

/// Page d'une étape de personnalisation : contenu + barre du bas (haut-parleur et bouton principal).
class PageEtapeBoutique extends StatelessWidget {
  const PageEtapeBoutique({
    super.key,
    required this.etat,
    required this.contenu,
    required this.libelle,
    required this.onPrincipal,
    this.cleBouton = 'bouton-continuer',
  });

  final EtatApplication etat;
  final Widget contenu;
  final String libelle;
  final VoidCallback? onPrincipal;
  final String cleBouton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: contenu),
        const SizedBox(height: 12),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Écouter',
                child: OutlinedButton(
                  key: const Key('bouton-ecouter'),
                  onPressed: () =>
                      etat.services.voix.dire(texteEtapeBoutique(etat.etape)),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(64, 64),
                    minimumSize: const Size(64, 64),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.volume_up_rounded, size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: Key(cleBouton),
                  onPressed: onPrincipal,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      libelle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

InputDecoration decorationChamp(
  String label, {
  IconData? icone,
  String? aide,
  String? erreur,
}) => InputDecoration(
  labelText: label,
  helperText: aide,
  errorText: erreur,
  prefixIcon: icone == null ? null : Icon(icone, size: 26),
  filled: true,
  fillColor: CouleursZp.surface,
  labelStyle: const TextStyle(fontSize: 18),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
);

const _styleChamp = TextStyle(fontSize: 22);

Text _titre(String t) => Text(
  t,
  style: const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
  ),
);

/// Choisit l'écran de l'étape.
Widget pageEtapeBoutique(EtatApplication etat, EtapeAssistant e) => switch (e) {
  EtapeAssistant.typeBoutique => EtapeTypes(etat: etat),
  EtapeAssistant.identite => EtapeIdentite(etat: etat),
  EtapeAssistant.contact => EtapeContact(etat: etat),
  EtapeAssistant.couleur => EtapeCouleur(etat: etat),
  EtapeAssistant.produits => EtapeProduits(etat: etat),
  EtapeAssistant.prix => EtapePrix(etat: etat),
  EtapeAssistant.recu => EtapeRecu(etat: etat),
  EtapeAssistant.codePatron => EtapeCodePatron(etat: etat),
  EtapeAssistant.fin => EtapeFin(etat: etat),
  _ => const SizedBox.shrink(),
};

// -----------------------------------------------------------------------------
// Type de boutique
// -----------------------------------------------------------------------------

class EtapeTypes extends StatefulWidget {
  const EtapeTypes({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeTypes> createState() => _EtapeTypesState();
}

class _EtapeTypesState extends State<EtapeTypes> {
  late final Set<String> _choix = {...widget.etat.config.types};

  @override
  Widget build(BuildContext context) {
    final cats = widget.etat.catalogue.categories;
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: _choix.isEmpty ? 'Choisissez au moins un type' : 'Continuer',
      onPrincipal: _choix.isEmpty
          ? null
          : () async {
              await widget.etat.enregistrerConfig(
                widget.etat.config.copie(types: _choix.toList()),
              );
              await widget.etat.suivante();
            },
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titre('Que vendez-vous ?'),
          const SizedBox(height: 4),
          const Text(
            'Touchez une ou plusieurs images.',
            style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                mainAxisExtent: 124,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: cats.length,
              itemBuilder: (context, i) {
                final c = cats[i];
                final choisi = _choix.contains(c.id);
                return TuileChoix(
                  cle: 'type-${c.id}',
                  emoji: c.emoji,
                  texte: c.nom,
                  choisi: choisi,
                  onTap: () => setState(
                    () => choisi ? _choix.remove(c.id) : _choix.add(c.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile avec une grande image (emoji), un nom, et une coche quand elle est choisie.
class TuileChoix extends StatelessWidget {
  const TuileChoix({
    super.key,
    required this.cle,
    required this.emoji,
    required this.texte,
    required this.choisi,
    required this.onTap,
  });

  final String cle;
  final String emoji;
  final String texte;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaire = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: choisi,
      label: texte,
      child: Material(
        color: choisi ? primaire.withValues(alpha: 0.10) : CouleursZp.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: choisi ? primaire : CouleursZp.ligne,
            width: choisi ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          key: Key(cle),
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 6),
                    Text(
                      texte,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              if (choisi)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: primaire,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Nom et logo
// -----------------------------------------------------------------------------

class EtapeIdentite extends StatefulWidget {
  const EtapeIdentite({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeIdentite> createState() => _EtapeIdentiteState();
}

class _EtapeIdentiteState extends State<EtapeIdentite> {
  late final _nom = TextEditingController(text: widget.etat.config.nom);
  late List<int>? _logo = widget.etat.config.logo;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _photo(SourcePhoto source) async {
    final octets = await widget.etat.services.prendrePhoto(source);
    if (octets != null) setState(() => _logo = octets);
  }

  @override
  Widget build(BuildContext context) {
    final apercu = widget.etat.config.copie(
      nom: _nom.text,
      logo: _logo,
      effacerLogo: _logo == null,
    );
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Continuer',
      onPrincipal: _nom.text.trim().isEmpty
          ? null
          : () async {
              await widget.etat.enregistrerConfig(
                apercu.copie(nom: _nom.text.trim()),
              );
              await widget.etat.suivante();
            },
      contenu: ListView(
        children: [
          _titre('Votre boutique'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('champ-nom'),
            controller: _nom,
            style: _styleChamp,
            textCapitalization: TextCapitalization.words,
            decoration: decorationChamp(
              'Nom de la boutique',
              icone: Icons.storefront_rounded,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Center(
            child: LogoBoutique(
              key: const Key('apercu-logo'),
              config: apercu,
              taille: 120,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _BoutonSecondaire(
                cle: 'photo-appareil',
                icone: Icons.photo_camera_rounded,
                texte: 'Prendre une photo',
                onTap: () => _photo(SourcePhoto.appareil),
              ),
              _BoutonSecondaire(
                cle: 'photo-galerie',
                icone: Icons.photo_library_rounded,
                texte: 'Choisir une photo',
                onTap: () => _photo(SourcePhoto.galerie),
              ),
              if (_logo != null)
                _BoutonSecondaire(
                  cle: 'photo-enlever',
                  icone: Icons.delete_outline_rounded,
                  texte: 'Enlever la photo',
                  onTap: () => setState(() => _logo = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sans photo, le logo montre les premières lettres du nom.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
          ),
        ],
      ),
    );
  }
}

class _BoutonSecondaire extends StatelessWidget {
  const _BoutonSecondaire({
    required this.cle,
    required this.icone,
    required this.texte,
    required this.onTap,
  });
  final String cle;
  final IconData icone;
  final String texte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: Key(cle),
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 26),
        const SizedBox(width: 8),
        Flexible(child: Text(texte, style: const TextStyle(fontSize: 17))),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Téléphone et adresse
// -----------------------------------------------------------------------------

class EtapeContact extends StatefulWidget {
  const EtapeContact({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeContact> createState() => _EtapeContactState();
}

class _EtapeContactState extends State<EtapeContact> {
  late final ConfigBoutique _c = widget.etat.config;
  late final _telephone = TextEditingController(text: _c.telephone);
  late final _quartier = TextEditingController(text: _c.quartier);
  late final _repere = TextEditingController(text: _c.repere);
  late final _autreVille = TextEditingController(
    text: villesTogo.contains(_c.ville) ? '' : _c.ville,
  );
  late String? _ville = _c.ville.isEmpty
      ? null
      : (villesTogo.contains(_c.ville) ? _c.ville : 'Autre');
  bool _telephoneTouche = false;

  @override
  void dispose() {
    for (final c in [_telephone, _quartier, _repere, _autreVille]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _villeChoisie =>
      _ville == 'Autre' ? _autreVille.text.trim() : (_ville ?? '');

  @override
  Widget build(BuildContext context) {
    final tel = normaliserTelephone(_telephone.text);
    final valide = tel != null && _villeChoisie.isNotEmpty;
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Continuer',
      onPrincipal: !valide
          ? null
          : () async {
              await widget.etat.enregistrerConfig(
                _c.copie(
                  telephone: tel,
                  ville: _villeChoisie,
                  quartier: _quartier.text.trim(),
                  repere: _repere.text.trim(),
                ),
              );
              await widget.etat.suivante();
            },
      contenu: ListView(
        children: [
          _titre('Téléphone et adresse'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('champ-telephone'),
            controller: _telephone,
            style: _styleChamp,
            keyboardType: TextInputType.phone,
            decoration: decorationChamp(
              'Numéro de la boutique',
              icone: Icons.phone_rounded,
              aide: 'Il sera écrit sur les reçus.',
              erreur: _telephoneTouche && tel == null
                  ? 'Il faut 8 chiffres, par ex. 90 12 34 56'
                  : null,
            ),
            onChanged: (_) => setState(() => _telephoneTouche = true),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('champ-ville'),
            initialValue: _ville,
            isExpanded: true,
            style: _styleChamp.copyWith(color: CouleursZp.texte),
            decoration: decorationChamp(
              'Ville',
              icone: Icons.location_city_rounded,
            ),
            items: [
              for (final v in [...villesTogo, 'Autre'])
                DropdownMenuItem(
                  value: v,
                  child: Text(v == 'Autre' ? 'Autre ville…' : v),
                ),
            ],
            onChanged: (v) => setState(() => _ville = v),
          ),
          if (_ville == 'Autre') ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('champ-autre-ville'),
              controller: _autreVille,
              style: _styleChamp,
              textCapitalization: TextCapitalization.words,
              decoration: decorationChamp('Nom de la ville'),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('champ-quartier'),
            controller: _quartier,
            style: _styleChamp,
            textCapitalization: TextCapitalization.words,
            decoration: decorationChamp('Quartier', icone: Icons.place_rounded),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('champ-repere'),
            controller: _repere,
            style: _styleChamp,
            decoration: decorationChamp(
              'Repère (facultatif)',
              icone: Icons.flag_rounded,
              aide: 'Par ex. : en face de la pharmacie',
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Couleur
// -----------------------------------------------------------------------------

class EtapeCouleur extends StatefulWidget {
  const EtapeCouleur({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeCouleur> createState() => _EtapeCouleurState();
}

class _EtapeCouleurState extends State<EtapeCouleur> {
  late int _couleur = widget.etat.config.couleur;

  @override
  Widget build(BuildContext context) {
    final apercu = widget.etat.config.copie(couleur: _couleur);
    final couleur = Color(_couleur);
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Continuer',
      onPrincipal: () async {
        await widget.etat.enregistrerConfig(apercu);
        await widget.etat.suivante();
      },
      contenu: ListView(
        children: [
          _titre('La couleur de votre boutique'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final c in paletteBoutique)
                Semantics(
                  button: true,
                  selected: c == _couleur,
                  child: InkWell(
                    key: Key('couleur-${c.toRadixString(16)}'),
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _couleur = c),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == _couleur
                              ? CouleursZp.texte
                              : Colors.white,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: c == _couleur
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 34,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Aperçu',
            style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CouleursZp.fond,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CouleursZp.ligne),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LogoBoutique(config: apercu, taille: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        apercu.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: couleur,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Fermer la caisse',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Le vert, le rouge et le jaune restent réservés à l\'argent : vert = l\'argent entre, rouge = il sort.',
                  style: TextStyle(fontSize: 15, color: CouleursZp.texteDoux),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Produits
// -----------------------------------------------------------------------------

class EtapeProduits extends StatefulWidget {
  const EtapeProduits({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeProduits> createState() => _EtapeProduitsState();
}

class _EtapeProduitsState extends State<EtapeProduits> {
  late final Set<String> _choix = {
    for (final p in widget.etat.produits)
      if (p.catalogueId != null) p.catalogueId!,
  };
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    final types = etat.config.types;
    final produits = etat.catalogue.produitsDe(types);
    return PageEtapeBoutique(
      etat: etat,
      libelle: _choix.isEmpty
          ? 'Passer (plus tard)'
          : 'Continuer (${_choix.length})',
      onPrincipal: _enCours
          ? null
          : () async {
              setState(() => _enCours = true);
              await etat.ajouterDuCatalogue(
                produits.where((p) => _choix.contains(p.id)),
              );
              await etat.suivante();
            },
      contenu: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _titre('Vos produits')),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Touchez ce que vous vendez.',
                style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
              ),
            ),
          ),
          for (final idType in types)
            if (etat.catalogue.categorie(idType) case final cat?) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: Text(
                    '${cat.emoji}  ${cat.nom}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: cat.produits.length,
                itemBuilder: (context, i) {
                  final p = cat.produits[i];
                  final choisi = _choix.contains(p.id);
                  return TuileChoix(
                    cle: 'produit-${p.id}',
                    emoji: p.emoji,
                    texte: p.nom,
                    choisi: choisi,
                    onTap: () => setState(
                      () => choisi ? _choix.remove(p.id) : _choix.add(p.id),
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Prix
// -----------------------------------------------------------------------------

class EtapePrix extends StatefulWidget {
  const EtapePrix({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapePrix> createState() => _EtapePrixState();
}

class _EtapePrixState extends State<EtapePrix> {
  final Map<String, TextEditingController> _prixBase = {};
  final Map<String, List<(Conditionnement, TextEditingController)>> _prixConds =
      {};
  late final Future<void> _chargement = _charger();
  bool _enCours = false;

  Future<void> _charger() async {
    for (final p in widget.etat.produits) {
      _prixBase[p.id] = TextEditingController(
        text: p.prixUnitaire > 0 ? '${p.prixUnitaire}' : '',
      );
      final conds = await widget.etat.journal.conditionnements(p.id);
      _prixConds[p.id] = [
        for (final c in conds)
          (
            c,
            TextEditingController(
              text: c.prixVente > 0 ? '${c.prixVente}' : '',
            ),
          ),
      ];
    }
  }

  @override
  void dispose() {
    for (final c in _prixBase.values) {
      c.dispose();
    }
    for (final l in _prixConds.values) {
      for (final (_, c) in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  int _lire(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _enregistrer() async {
    setState(() => _enCours = true);
    for (final p in widget.etat.produits) {
      await widget.etat.fixerPrix(p, _lire(_prixBase[p.id]!), {
        for (final (c, champ)
            in _prixConds[p.id] ??
                const <(Conditionnement, TextEditingController)>[])
          c: _lire(champ),
      });
    }
    await widget.etat.suivante();
  }

  @override
  Widget build(BuildContext context) {
    final produits = widget.etat.produits;
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Continuer',
      onPrincipal: _enCours ? null : _enregistrer,
      contenu: FutureBuilder<void>(
        future: _chargement,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              _titre('Vos prix de vente'),
              const SizedBox(height: 4),
              const Text(
                'En francs CFA. Vous pourrez les changer plus tard.',
                style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
              ),
              const SizedBox(height: 12),
              if (produits.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucun produit choisi : vous les ajouterez plus tard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              for (final p in produits)
                Card(
                  elevation: 0,
                  color: CouleursZp.surface,
                  surfaceTintColor: Colors.transparent,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: CouleursZp.ligne),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              p.emoji ?? '📦',
                              style: const TextStyle(fontSize: 34),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.nom,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _ChampPrix(
                          cle: 'prix-${p.catalogueId ?? p.id}',
                          controleur: _prixBase[p.id]!,
                          libelle: 'Prix pour 1 ${p.uniteBase}',
                        ),
                        for (final (c, champ)
                            in _prixConds[p.id] ??
                                const <
                                  (Conditionnement, TextEditingController)
                                >[])
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _ChampPrix(
                              cle: 'prix-${p.catalogueId ?? p.id}-${c.nom}',
                              controleur: champ,
                              libelle: 'Prix pour 1 ${c.nom}',
                              aide:
                                  '1 ${c.nom} = ${c.facteurMilliemes ~/ milliemesParUnite} ${p.uniteBase}'
                                  '${c.aVerifier ? ' (à vérifier)' : ''}',
                              aVerifier: c.aVerifier,
                            ),
                          ),
                      ],
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

class _ChampPrix extends StatelessWidget {
  const _ChampPrix({
    required this.cle,
    required this.controleur,
    required this.libelle,
    this.aide,
    this.aVerifier = false,
  });

  final String cle;
  final TextEditingController controleur;
  final String libelle;
  final String? aide;
  final bool aVerifier;

  @override
  Widget build(BuildContext context) => TextField(
    key: Key(cle),
    controller: controleur,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(9),
    ],
    style: _styleChamp.copyWith(fontWeight: FontWeight.w700),
    decoration: decorationChamp(libelle, aide: aide).copyWith(
      suffixText: 'F',
      suffixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      helperStyle: TextStyle(
        fontSize: 15,
        color: aVerifier ? CouleursZp.texteSurCredit : CouleursZp.texteDoux,
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Reçu
// -----------------------------------------------------------------------------

class EtapeRecu extends StatefulWidget {
  const EtapeRecu({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeRecu> createState() => _EtapeRecuState();
}

class _EtapeRecuState extends State<EtapeRecu> {
  late final _message = TextEditingController(
    text: widget.etat.config.messageRecu,
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.etat.config.copie(messageRecu: _message.text);
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Continuer',
      onPrincipal: () async {
        await widget.etat.enregistrerConfig(
          config.copie(
            messageRecu: _message.text.trim().isEmpty
                ? messageRecuParDefaut
                : _message.text.trim(),
          ),
        );
        await widget.etat.suivante();
      },
      contenu: ListView(
        children: [
          _titre('Le reçu de vos clients'),
          const SizedBox(height: 12),
          ApercuRecu(config: config, exemple: true),
          const SizedBox(height: 16),
          TextField(
            key: const Key('champ-message-recu'),
            controller: _message,
            style: _styleChamp,
            maxLength: 60,
            decoration: decorationChamp(
              'Message en bas du reçu',
              icone: Icons.chat_bubble_outline_rounded,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Code secret du patron
// -----------------------------------------------------------------------------

class EtapeCodePatron extends StatefulWidget {
  const EtapeCodePatron({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeCodePatron> createState() => _EtapeCodePatronState();
}

class _EtapeCodePatronState extends State<EtapeCodePatron> {
  late final _nom = TextEditingController(text: widget.etat.patron?.nom ?? '');
  String? _premier;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _saisi(String pin) async {
    if (_premier == null) {
      final probleme = problemePin(pin, longueur: longueurPinPatron);
      if (probleme != null) {
        setState(() => _erreur = probleme);
        await widget.etat.services.voix.dire(probleme);
        return;
      }
      setState(() {
        _premier = pin;
        _erreur = null;
      });
      await widget.etat.services.voix.dire(
        'Tapez encore le même code pour confirmer.',
      );
      return;
    }
    if (pin != _premier) {
      setState(() {
        _premier = null;
        _erreur = 'Les deux codes sont différents. Recommencez.';
      });
      await widget.etat.services.voix.dire(
        'Les deux codes sont différents. Recommencez.',
      );
      return;
    }
    try {
      await widget.etat.definirPatron(nom: _nom.text, pin: pin);
      await widget.etat.suivante();
    } on ErreurZeroPerte catch (e) {
      setState(() {
        _premier = null;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titre('Votre code secret'),
        const SizedBox(height: 10),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: TextField(
            key: const Key('champ-nom-patron'),
            controller: _nom,
            style: const TextStyle(fontSize: 20),
            textCapitalization: TextCapitalization.words,
            decoration: decorationChamp(
              'Votre prénom (patron)',
              icone: Icons.person_rounded,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: SaisiePin(
              key: ValueKey(_premier == null ? 'choisir' : 'confirmer'),
              titre: _premier == null
                  ? 'Choisissez 6 chiffres'
                  : 'Tapez encore le même code',
              erreur: _erreur,
              longueur: longueurPinPatron,
              onComplet: _saisi,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Fin
// -----------------------------------------------------------------------------

class EtapeFin extends StatefulWidget {
  const EtapeFin({super.key, required this.etat});
  final EtatApplication etat;
  @override
  State<EtapeFin> createState() => _EtapeFinState();
}

class _EtapeFinState extends State<EtapeFin> {
  bool? _raccourci;

  Future<void> _ajouterRaccourci() async {
    final png = await dessinerLogoPng(widget.etat.config);
    final ok = await widget.etat.services.creerRaccourci(
      widget.etat.config.nom,
      png,
    );
    setState(() => _raccourci = ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.etat.config;
    return PageEtapeBoutique(
      etat: widget.etat,
      libelle: 'Commencer',
      cleBouton: 'bouton-commencer-vendre',
      onPrincipal: () => widget.etat.allerA(EtapeAssistant.termine),
      contenu: ListView(
        children: [
          const SizedBox(height: 12),
          Center(child: LogoBoutique(config: c, taille: 120)),
          const SizedBox(height: 18),
          Text(
            c.nom,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre boutique est prête !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: CouleursZp.argentEntre),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.etat.produits.length} produits · ${formatFrancs(0)} vendus pour l\'instant',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const Key('bouton-raccourci'),
            onPressed: _raccourci == true ? null : _ajouterRaccourci,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 64),
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_to_home_screen_rounded, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _raccourci == true
                        ? 'Raccourci ajouté'
                        : 'Mettre « ${c.nom} » sur l\'écran du téléphone',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          if (_raccourci == false)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ce téléphone ne permet pas d\'ajouter le raccourci.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
              ),
            ),
        ],
      ),
    );
  }
}
