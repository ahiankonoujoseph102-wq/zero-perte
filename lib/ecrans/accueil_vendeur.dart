import 'package:flutter/material.dart';

import '../app/etat_application.dart';
import '../domaine/boutique.dart';
import '../domaine/utilisateurs.dart';
import '../theme/couleurs.dart';
import 'bouton_action.dart';
import 'caisse/ma_caisse.dart';
import 'caisse/saisie_montant.dart';
import 'credit/clients.dart';
import 'logo_boutique.dart';
import 'patron/arrivages.dart';
import 'patron/espace_patron.dart';
import 'patron/fournisseurs.dart';
import 'patron/inventaire.dart';
import 'patron/tableau.dart';
import 'patron/tableau_de_bord.dart';
import 'patron/vendeurs.dart';
import 'patron/rapports.dart';
import 'logo_zero_perte.dart';
import 'vente/devis.dart';
import 'vente/page_vendre.dart';
import 'vente/retour.dart';
import '../domaine/panier.dart';
import '../donnees/journal_local.dart' show OperationLue;

/// Largeur du menu fixe de gauche (tablette, PC).
const double largeurMenuGauche = 220;

/// Une entrée du menu principal (gros bouton sur téléphone, ligne du menu de
/// gauche sur tablette et PC).
class EntreeMenu {
  const EntreeMenu({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.couleur,
    required this.ouvrir,
    this.principale = false,
    this.surTelephone = true,
  });

  /// « vendre », « ma-caisse »… Les entrées principales ont la clé de test
  /// `bouton-cle` partout ; les autres `accueil-cle` (téléphone) et
  /// `menu-cle` (menu de gauche).
  final String cle;
  final IconData icone;

  /// Mot court.
  final String titre;
  final Color couleur;
  final Future<void> Function(BuildContext context) ouvrir;
  final bool principale;

  /// Faux : seulement dans le menu de gauche (sur téléphone, dans « Gestion »).
  final bool surTelephone;

  Key cleTelephone() => Key(principale ? 'bouton-$cle' : 'accueil-$cle');
  Key cleMenu() => Key(principale ? 'bouton-$cle' : 'menu-$cle');
}

Future<void> _ouvrir(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// Vendre : la première vente depuis la fermeture ouvre d'abord la caisse.
Future<void> ouvrirVente(BuildContext context, EtatApplication etat) =>
    ouvrirVenteAvec(context, etat);

/// Vendre avec un panier déjà rempli (devis transformé en vente).
Future<void> ouvrirVenteAvec(
  BuildContext context,
  EtatApplication etat, {
  Panier? panier,
  OperationLue? devis,
}) async {
  if (!await etat.caisseOuverte()) {
    if (!context.mounted) return;
    final ouverte = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => pageOuvrirCaisse(etat)));
    if (ouverte != true) return;
  }
  if (!context.mounted) return;
  await _ouvrir(context, PageVendre(etat: etat, panier: panier, devis: devis));
}

/// Menu selon le rôle : le vendeur ne voit que Vendre, Ma caisse et Clients ;
/// le patron voit tout.
List<EntreeMenu> menuPrincipal(EtatApplication etat) => [
  EntreeMenu(
    cle: 'vendre',
    icone: Icons.shopping_basket_rounded,
    titre: 'Vendre',
    couleur: CouleursZp.argentEntreClair,
    principale: true,
    ouvrir: (c) => ouvrirVente(c, etat),
  ),
  EntreeMenu(
    cle: 'ma-caisse',
    icone: Icons.point_of_sale_rounded,
    titre: 'Ma caisse',
    couleur: CouleursZp.marque,
    principale: true,
    ouvrir: (c) => _ouvrir(c, PageMaCaisse(etat: etat)),
  ),
  EntreeMenu(
    cle: 'credit',
    icone: Icons.groups_rounded,
    titre: 'Clients',
    couleur: CouleursZp.creditTexte,
    principale: true,
    ouvrir: (c) => _ouvrir(c, PageClients(etat: etat)),
  ),
  if (etat.voitTout) ...[
    EntreeMenu(
      cle: 'tableau',
      icone: Icons.insights_rounded,
      titre: 'Tableau',
      couleur: CouleursZp.argentEntreClair,
      ouvrir: (c) => _ouvrir(c, PageTableau(etat: etat)),
    ),
    EntreeMenu(
      cle: 'arrivages',
      icone: Icons.local_shipping_rounded,
      titre: 'Arrivages',
      couleur: const Color(0xFF4FB3E8),
      ouvrir: (c) => _ouvrir(c, PageArrivages(etat: etat)),
    ),
    EntreeMenu(
      cle: 'inventaire',
      icone: Icons.inventory_rounded,
      titre: 'Inventaire',
      couleur: const Color(0xFFB38CF0),
      ouvrir: (c) => _ouvrir(c, PageInventaires(etat: etat)),
    ),
    EntreeMenu(
      cle: 'rapports',
      icone: Icons.summarize_rounded,
      titre: 'Rapports',
      couleur: CouleursZp.argentEntreClair,
      surTelephone: false,
      ouvrir: (c) => _ouvrir(c, PageRapports(etat: etat)),
    ),
    EntreeMenu(
      cle: 'devis',
      icone: Icons.request_quote_rounded,
      titre: 'Devis',
      couleur: const Color(0xFF4FB3E8),
      surTelephone: false,
      ouvrir: (c) => _ouvrir(c, PageListeDevis(etat: etat)),
    ),
    EntreeMenu(
      cle: 'retours',
      icone: Icons.assignment_return_rounded,
      titre: 'Retours',
      couleur: CouleursZp.argentSortClair,
      surTelephone: false,
      ouvrir: (c) => _ouvrir(c, PageRetours(etat: etat)),
    ),
    EntreeMenu(
      cle: 'fournisseurs',
      icone: Icons.store_rounded,
      titre: 'Fournisseurs',
      couleur: const Color(0xFF4FB3E8),
      surTelephone: false,
      ouvrir: (c) => _ouvrir(c, PageFournisseurs(etat: etat)),
    ),
    EntreeMenu(
      cle: 'vendeurs',
      icone: Icons.badge_rounded,
      titre: 'Vendeurs',
      couleur: const Color(0xFFB38CF0),
      surTelephone: false,
      ouvrir: (c) => _ouvrir(c, PageVendeurs(etat: etat)),
    ),
    EntreeMenu(
      cle: 'espace-patron',
      icone: Icons.tune_rounded,
      titre: 'Gestion',
      couleur: CouleursZp.texteDoux,
      principale: true,
      ouvrir: (c) => _ouvrir(c, EspacePatron(etat: etat)),
    ),
  ],
];

/// Accueil après l'entrée par le code.
/// - Téléphone : gros boutons à grandes icônes, « Vendre » le plus gros.
/// - Tablette et PC : menu fixe à gauche ; à droite, le tableau de bord
///   (patron) ou les gros boutons (vendeur), et les pages ouvertes.
class AccueilVendeur extends StatelessWidget {
  const AccueilVendeur({
    super.key,
    required this.etat,
    required this.pied,
    this.maintenant,
  });

  final EtatApplication etat;

  /// Ligne du bas (version, état de la base).
  final Widget pied;

  /// Permet aux tests de fixer la date affichée.
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    final entrees = menuPrincipal(etat);
    final changer = etat.utilisateurs.isEmpty ? null : etat.deconnecter;
    if (MediaQuery.sizeOf(context).width >= 840) {
      return _AccueilGrandEcran(
        etat: etat,
        entrees: entrees,
        pied: pied,
        onChangerUtilisateur: changer,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, contraintes) {
              final bas = contraintes.maxHeight < 560;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // L'en-tête et le pied grossissent avec la taille du texte du
                  // téléphone, au plus ×1,3, pour laisser la place aux boutons.
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: _EnTete(
                      config: etat.config,
                      nomVendeur:
                          etat.utilisateurActuel?.nom ??
                          etat.patron?.nom ??
                          'Vendeur',
                      role: etat.utilisateurActuel?.role,
                      date: maintenant ?? DateTime.now(),
                      compact: bas,
                      onChangerUtilisateur: changer,
                    ),
                  ),
                  SizedBox(height: bas ? 10 : 14),
                  Expanded(
                    child: GrilleAccueil(
                      entrees: [
                        for (final e in entrees)
                          if (e.surTelephone) e,
                      ],
                      cle: (e) => e.cleTelephone(),
                    ),
                  ),
                  SizedBox(height: bas ? 6 : 10),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: pied,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// « Vendre » en très gros, puis les autres entrées deux par ligne.
class GrilleAccueil extends StatelessWidget {
  const GrilleAccueil({super.key, required this.entrees, required this.cle});

  final List<EntreeMenu> entrees;
  final Key Function(EntreeMenu) cle;

  @override
  Widget build(BuildContext context) {
    final vendre = entrees.first;
    final autres = entrees.skip(1).toList();
    final lignes = <List<EntreeMenu>>[
      for (var i = 0; i < autres.length; i += 2)
        autres.sublist(i, (i + 2).clamp(0, autres.length)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: lignes.length <= 1 ? 5 : 3,
          child: BoutonAction(
            key: cle(vendre),
            titre: vendre.titre,
            sousTitre: 'Encaisser une vente',
            icone: vendre.icone,
            couleur: CouleursZp.argentEntre,
            couleurClaire: CouleursZp.argentEntreClair,
            principal: true,
            // Patron (beaucoup de boutons) : icône à gauche du mot, plus lisible.
            horizontal: lignes.length > 1,
            onTap: () => vendre.ouvrir(context),
          ),
        ),
        for (final ligne in lignes) ...[
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in ligne.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: TuileMenu(entree: e, key: cle(e)),
                  ),
                ],
                if (ligne.length == 1) ...[
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Gros bouton sombre à grande icône de couleur (contraste fort, lisible au
/// soleil).
class TuileMenu extends StatelessWidget {
  const TuileMenu({super.key, required this.entree});

  final EntreeMenu entree;

  @override
  Widget build(BuildContext context) {
    final couleur = entree.couleur == CouleursZp.marque
        ? Theme.of(context).colorScheme.primary
        : entree.couleur;
    return Semantics(
      button: true,
      label: entree.titre,
      excludeSemantics: true,
      child: Material(
        color: CouleursZp.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: CouleursZp.ligne, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => entree.ouvrir(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: couleur.withValues(alpha: 0.18),
                      ),
                      child: Icon(entree.icone, size: 38, color: couleur),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entree.titre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: CouleursZp.texte,
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
  }
}

/// Tablette et PC : menu fixe à gauche, contenu à droite (les pages s'ouvrent
/// dans la partie droite ; le menu reste visible).
class _AccueilGrandEcran extends StatefulWidget {
  const _AccueilGrandEcran({
    required this.etat,
    required this.entrees,
    required this.pied,
    this.onChangerUtilisateur,
  });

  final EtatApplication etat;
  final List<EntreeMenu> entrees;
  final Widget pied;
  final VoidCallback? onChangerUtilisateur;

  @override
  State<_AccueilGrandEcran> createState() => _AccueilGrandEcranState();
}

class _AccueilGrandEcranState extends State<_AccueilGrandEcran> {
  final _navigateur = GlobalKey<NavigatorState>();
  String? _choisi;
  int _jeton = 0;

  Future<void> _choisir(EntreeMenu? e) async {
    final nav = _navigateur.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    final jeton = ++_jeton;
    setState(() => _choisi = e?.cle);
    if (e == null) return;
    await e.ouvrir(nav.context);
    // Retour à l'accueil (sauf si une autre entrée a été choisie entre-temps).
    if (mounted && jeton == _jeton) setState(() => _choisi = null);
  }

  Widget _accueil() => widget.etat.voitTout
      ? TableauDeBord(etat: widget.etat)
      : Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GrilleAccueil(
                    entrees: widget.entrees,
                    cle: (e) => Key('tuile-${e.cle}'),
                  ),
                ),
              ),
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    final u = etat.utilisateurActuel;
    final elements = <_LigneMenu>[
      if (etat.voitTout)
        _LigneMenu(
          cle: const Key('menu-accueil'),
          icone: Icons.dashboard_rounded,
          titre: 'Accueil',
          couleur: CouleursZp.marque,
          choisi: _choisi == null,
          onTap: () => _choisir(null),
        ),
      for (final e in widget.entrees)
        _LigneMenu(
          cle: e.cleMenu(),
          icone: e.icone,
          titre: e.titre,
          couleur: e.couleur,
          choisi: _choisi == e.cle,
          onTap: () => _choisir(e),
        ),
    ];
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('menu-gauche'),
            width: largeurMenuGauche,
            decoration: const BoxDecoration(
              color: CouleursZp.menu,
              border: Border(right: BorderSide(color: CouleursZp.ligne)),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    key: const Key('menu-logo'),
                    onTap: () => _choisir(null),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                      child: Row(
                        children: [
                          LogoBoutique(config: etat.config, taille: 42),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              etat.config.nom.isEmpty
                                  ? 'Ma boutique'
                                  : etat.config.nom,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: CouleursZp.ligne),
                  // Toutes les rubriques tiennent sans défiler (PC 1366×768,
                  // même avec un bandeau en haut) : la hauteur des lignes
                  // s'adapte à la place (32 à 50 points).
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final hauteur =
                            ((c.maxHeight - 16) / elements.length - 4).clamp(
                              32.0,
                              50.0,
                            );
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final e in elements) e.avecHauteur(hauteur),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: CouleursZp.ligne),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
                          child: Text(
                            (u?.nom ?? etat.patron?.nom ?? 'P').characters.first
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u?.nom ?? etat.patron?.nom ?? 'Patron',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                etat.voitTout ? 'Patron' : 'Vendeur',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CouleursZp.texteDoux,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onChangerUtilisateur != null)
                          IconButton(
                            key: const Key('bouton-changer-utilisateur'),
                            tooltip: 'Changer d\'utilisateur',
                            onPressed: widget.onChangerUtilisateur,
                            icon: const Icon(Icons.logout_rounded),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 12),
                        child: widget.pied,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: NavigatorPopHandler(
              onPopWithResult: (_) => _navigateur.currentState?.maybePop(),
              child: Navigator(
                key: _navigateur,
                onGenerateRoute: (_) =>
                    MaterialPageRoute(builder: (_) => _accueil()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneMenu extends StatelessWidget {
  const _LigneMenu({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.couleur,
    required this.choisi,
    required this.onTap,
    this.hauteur = 50,
  });

  final double hauteur;

  _LigneMenu avecHauteur(double h) => _LigneMenu(
    cle: cle,
    icone: icone,
    titre: titre,
    couleur: couleur,
    choisi: choisi,
    onTap: onTap,
    hauteur: h,
  );

  final Key cle;
  final IconData icone;
  final String titre;
  final Color couleur;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaire = Theme.of(context).colorScheme.primary;
    final teinte = couleur == CouleursZp.marque ? primaire : couleur;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: choisi ? primaire.withValues(alpha: 0.22) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: choisi
              ? BorderSide(color: primaire, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          key: cle,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: hauteur,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(icone, size: 26, color: teinte),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: choisi ? FontWeight.w700 : FontWeight.w600,
                      color: CouleursZp.texte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.config,
    required this.nomVendeur,
    required this.date,
    this.role,
    this.compact = false,
    this.onChangerUtilisateur,
  });

  final VoidCallback? onChangerUtilisateur;
  final ConfigBoutique config;
  final String nomVendeur;
  final Role? role;
  final DateTime date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LogoBoutique(config: config, taille: compact ? 44 : 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.nom.isEmpty ? 'Ma boutique' : config.nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CouleursZp.texte,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: CouleursZp.texteDoux,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        nomVendeur,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 17,
                      color: CouleursZp.texteDoux,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateCourte(date),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 17,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onChangerUtilisateur != null) ...[
          const SizedBox(width: 6),
          IconButton.outlined(
            key: const Key('bouton-changer-utilisateur'),
            onPressed: onChangerUtilisateur,
            tooltip: 'Changer d\'utilisateur',
            iconSize: 26,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ],
    );
  }
}

/// Logo Zéro Perte (anciennement le rond « ZP ») : voir [LogoZeroPerte].
class LogoZp extends StatelessWidget {
  const LogoZp({super.key, this.taille = 120});

  final double taille;

  @override
  Widget build(BuildContext context) => LogoZeroPerte(taille: taille);
}

const _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// « 21 nov. » : date courte pour l'en-tête.
String dateCourte(DateTime d) {
  final mois = _mois[d.month - 1];
  return '${d.day} ${mois.length <= 4 ? mois : '${mois.substring(0, mois.startsWith('juil') ? 4 : 3)}.'}';
}

/// « samedi 21 novembre » (sans bibliothèque externe).
String dateEnFrancais(DateTime d) =>
    '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
