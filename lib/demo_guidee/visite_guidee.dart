import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestTarget;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app/etat_application.dart';
import '../donnees/journal_local.dart' show ModePaiement;
import '../domaine/panier.dart';
import '../services/voix.dart';
import '../theme/couleurs.dart';
import 'afi_v2.dart';
import 'avatar.dart';
import 'script_visite.dart';
import 'voix_demo.dart';

/// Afi en médaillon (version 2) au lieu de l'Afi actuelle. FAUX tant que le
/// propriétaire n'a pas validé : seules les captures d'essai l'activent.
bool afiMedaillonVisite = false;

/// Commande la visite guidée depuis l'extérieur (bandeau de la démo).
class ControleurVisite extends ChangeNotifier {
  bool _visible = true;
  bool get visible => _visible;

  /// Relance la visite depuis le début.
  void relancer() {
    _visible = true;
    _numero++;
    notifyListeners();
  }

  void quitter() {
    _visible = false;
    notifyListeners();
  }

  int _numero = 0;

  /// Change à chaque relance.
  int get numero => _numero;
}

/// Démonstration guidée : Afi parle (voix enregistrée, sinon voix de
/// synthèse), les sous-titres s'affichent, chaque bouton est entouré et
/// montré par une flèche, et la visite touche elle-même les boutons pour
/// avancer dans la boutique de démonstration. Fonctionne sans Internet.
class VisiteGuidee extends StatefulWidget {
  const VisiteGuidee({
    super.key,
    required this.etat,
    required this.controleur,
    required this.navigateur,
    required this.voix,
    required this.child,
    this.lecteur = const SansLecteur(),
    this.voixEnregistree,
    this.dureeParole = dureeEstimee,
    this.pauseEntrePhrases = const Duration(milliseconds: 700),
    this.anime = true,
  });

  final EtatApplication etat;
  final ControleurVisite controleur;
  final GlobalKey<NavigatorState> navigateur;
  final Voix voix;
  final LecteurVoixDemo lecteur;

  /// Voix enregistrée (nul : lue dans les assets).
  final Future<VoixEnregistree>? voixEnregistree;

  /// Durée d'une phrase dite par la voix de synthèse.
  final Duration Function(String texte) dureeParole;
  final Duration pauseEntrePhrases;

  /// Faux dans les captures (avatar immobile).
  final bool anime;
  final Widget child;

  @override
  State<VisiteGuidee> createState() => EtatVisite();
}

class EtatVisite extends State<VisiteGuidee> {
  final _cleContenu = GlobalKey();
  final _clePile = GlobalKey();
  final _clePanneau = GlobalKey(debugLabel: 'visite-panneau');
  final ValueNotifier<double> _bouche = ValueNotifier(0);

  late final List<ChapitreVisite> _chapitres = chapitresVisite(
    salutation: phraseSalutation(widget.etat.maintenant()),
  );
  VoixEnregistree _enregistree = const VoixEnregistree();

  int _chapitre = 0;
  int _etape = 0;
  bool _enPause = false;
  bool _fini = false;
  int _generation = 0;
  int _numeroControleur = 0;
  Rect? _cible;
  Expression _expression = Expression.sourire;
  String _sousTitre = '';
  Timer? _minuterieBouche;

  /// Étapes dont le bouton n'a pas été trouvé (vérifié par les tests).
  final List<String> ciblesManquantes = [];

  /// Nombre d'étapes jouées (pour les tests).
  int etapesJouees = 0;

  bool get termine => _fini;

  /// Bouton entouré en ce moment (pour les tests).
  Rect? get cibleMontree => _cible;
  int get chapitre => _chapitre;
  int get etape => _etape;
  List<ChapitreVisite> get chapitres => _chapitres;

  ControleurVisite get _c => widget.controleur;

  @override
  void initState() {
    super.initState();
    _c.addListener(_surControleur);
    _numeroControleur = _c.numero;
    WidgetsBinding.instance.addPostFrameCallback((_) => _demarrer());
  }

  @override
  void dispose() {
    _generation++;
    _c.removeListener(_surControleur);
    _minuterieBouche?.cancel();
    _bouche.dispose();
    widget.voix.arreter();
    widget.lecteur.arreter();
    super.dispose();
  }

  void _surControleur() {
    if (!mounted) return;
    if (!_c.visible) {
      _arreterTout();
      setState(() {});
      return;
    }
    if (_c.numero != _numeroControleur) {
      _numeroControleur = _c.numero;
      _lancer(0);
    }
    setState(() {});
  }

  Future<void> _demarrer() async {
    _enregistree = await (widget.voixEnregistree ?? VoixEnregistree.charger());
    await _preparerBoutique();
    if (mounted && _c.visible) _lancer(0);
  }

  /// La boutique de démonstration doit avoir : la caisse ouverte, et un
  /// client (Kofi) qui a pris à crédit.
  Future<void> _preparerBoutique() async {
    final e = widget.etat;
    if (!e.estDemo) return;
    try {
      if (!await e.caisseOuverte()) await e.ouvrirCaisse(10000);
      if ((await e.journal.clients()).every((c) => c.nom != 'Kofi')) {
        final id = await e.enregistrerClient(
          nom: 'Kofi',
          telephone: '90112233',
          plafond: 10000,
        );
        final huile = e.produits
            .where((p) => p.catalogueId == 'alimentation.huile')
            .firstOrNull;
        if (huile != null) {
          final p = Panier()
            ..ajouter(
              LignePanier(
                produitId: huile.id,
                nomProduit: huile.nom,
                uniteBase: huile.uniteBase,
                nombre: 2,
                prixUnitaire: huile.prixUnitaire,
              ),
            )
            ..choisirClient(id, 'Kofi');
          await e.vendre(p, mode: ModePaiement.credit, clientId: id);
        }
      }
    } catch (_) {
      // La visite continue même si la préparation échoue.
    }
  }

  // ---------------------------------------------------------------------------
  // Déroulé
  // ---------------------------------------------------------------------------

  Future<void> _lancer(int chapitre) async {
    _arreterTout();
    final g = ++_generation;
    setState(() {
      _enPause = false;
      _fini = false;
    });
    for (var c = chapitre; c < _chapitres.length; c++) {
      if (g != _generation || !mounted) return;
      setState(() {
        _chapitre = c;
        _etape = 0;
      });
      final etapes = _chapitres[c].etapes;
      for (var i = 0; i < etapes.length; i++) {
        if (g != _generation || !mounted) return;
        setState(() => _etape = i);
        await _jouerEtape(etapes[i], g);
      }
    }
    if (g == _generation && mounted) {
      setState(() {
        _fini = true;
        _cible = null;
        _expression = Expression.auRevoir;
      });
    }
  }

  Future<void> _jouerEtape(EtapeVisite e, int g) async {
    if (e.revenirAccueil) {
      _revenirAccueil();
      await _attendre(const Duration(milliseconds: 450));
      if (g != _generation) return;
    }
    Element? cible;
    if (e.cibles.isNotEmpty) {
      cible = await _chercher(e.cibles, g);
      if (g != _generation) return;
      if (cible == null) ciblesManquantes.add('${e.phrase} ${e.cibles}');
      // Le bouton a pu défiler pour se montrer : on mesure sa place une fois
      // l'écran redessiné.
      if (cible != null) {
        await _attendre(const Duration(milliseconds: 120));
        if (g != _generation) return;
      }
    }
    if (!mounted) return;
    setState(() {
      _cible = cible == null || !cible.mounted ? null : _rectDe(cible);
      _expression = e.expression;
      _sousTitre = e.texte;
    });
    etapesJouees++;
    await _dire(e, g);
    if (g != _generation || !mounted) return;
    await _attendre(widget.pauseEntrePhrases);
    if (g != _generation || !mounted) return;
    if (e.toucher && cible != null && cible.mounted) {
      _toucher(cible);
      await _attendre(const Duration(milliseconds: 650));
    }
    if (mounted && g == _generation) setState(() => _cible = null);
  }

  Future<void> _attendre(Duration d) => Future<void>.delayed(d);

  // ---------------------------------------------------------------------------
  // Voix et bouche
  // ---------------------------------------------------------------------------

  Future<void> _dire(EtapeVisite e, int g) async {
    final rec = _enregistree.phrases[e.phrase];
    if (rec != null) {
      final debut = DateTime.now();
      _animerBouche((ms) => rec.boucheA(ms), debut);
      final ok = await widget.lecteur.jouer(rec.fichier);
      _arreterBouche();
      if (ok || g != _generation) return;
    }
    // Voix de synthèse de l'appareil (sous-titres toujours affichés).
    unawaited(widget.voix.dire(e.texte));
    _animerBouche(boucheSimulee, DateTime.now());
    await _attendre(widget.dureeParole(e.texte));
    _arreterBouche();
  }

  void _animerBouche(double Function(int ms) f, DateTime debut) {
    _minuterieBouche?.cancel();
    if (!widget.anime) return;
    _minuterieBouche = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _bouche.value = f(DateTime.now().difference(debut).inMilliseconds);
    });
  }

  void _arreterBouche() {
    _minuterieBouche?.cancel();
    _minuterieBouche = null;
    _bouche.value = 0;
  }

  void _arreterTout() {
    _generation++;
    _arreterBouche();
    widget.voix.arreter();
    widget.lecteur.arreter();
  }

  // ---------------------------------------------------------------------------
  // Boutons : trouver, entourer, toucher
  // ---------------------------------------------------------------------------

  /// Cherche le bouton (plusieurs essais : la page peut être en train de
  /// s'ouvrir).
  Future<Element?> _chercher(List<String> cles, int g) async {
    for (var essai = 0; essai < 60; essai++) {
      final e = _trouver(cles);
      if (e != null) return e;
      await _attendre(const Duration(milliseconds: 150));
      if (g != _generation) return null;
    }
    return null;
  }

  Element? _trouver(List<String> cles) {
    final racine = _clePile.currentContext as Element?;
    if (racine == null) return null;
    for (final cle in cles) {
      final candidats = <Element>[];
      void visiter(Element el) {
        final k = el.widget.key;
        if (k is ValueKey<String>) {
          final v = k.value;
          final ok = cle.endsWith('*')
              ? v.startsWith(cle.substring(0, cle.length - 1))
              : v == cle;
          if (ok) candidats.add(el);
        }
        el.visitChildElements(visiter);
      }

      racine.visitChildElements(visiter);
      for (final el in candidats) {
        if (_visible(el)) return el;
      }
    }
    return null;
  }

  /// Vrai si l'élément est vraiment à l'écran (pas caché sous une autre
  /// page) : on le fait défiler si besoin, puis on teste un toucher en son
  /// centre.
  bool _visible(Element el) {
    final ro = el.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize || ro.size.isEmpty) {
      return false;
    }
    try {
      // Le bouton est amené vers le haut de la zone qui défile : le
      // panneau d'Afi a la place de se mettre en dessous.
      Scrollable.ensureVisible(el, alignment: 0.2);
    } catch (_) {}
    final pile = _clePile.currentContext?.findRenderObject() as RenderBox?;
    final contenu = _cleContenu.currentContext?.findRenderObject();
    if (pile == null) return false;
    final centre = ro.localToGlobal(ro.size.center(Offset.zero));
    final local = pile.globalToLocal(centre);
    if (!(Offset.zero & pile.size).contains(local)) return false;
    // L'élément de la visite elle-même (bouton « Quitter ») est toujours
    // visible ; pour la boutique, on teste le toucher sous la visite. Le
    // centre peut tomber dans un vide (entre deux billets d'une zone sur deux
    // lignes) : on essaie aussi d'autres points de l'élément.
    if (contenu is RenderBox && _estDescendant(ro, contenu)) {
      for (final (fx, fy) in const [
        (0.5, 0.5),
        (0.25, 0.25),
        (0.75, 0.25),
        (0.25, 0.75),
        (0.75, 0.75),
        (0.12, 0.5),
        (0.5, 0.2),
      ]) {
        final point = ro.localToGlobal(
          Offset(ro.size.width * fx, ro.size.height * fy),
        );
        final r = BoxHitTestResult();
        contenu.hitTest(r, position: contenu.globalToLocal(point));
        if (r.path.any((h) => h.target == ro || _estDescendant(h.target, ro))) {
          return true;
        }
      }
      return false;
    }
    return true;
  }

  bool _estDescendant(HitTestTarget t, RenderObject parent) {
    if (t is! RenderObject) return false;
    RenderObject? o = t;
    while (o != null) {
      if (identical(o, parent)) return true;
      o = o.parent;
    }
    return false;
  }

  Rect? _rectDe(Element el) {
    final ro = el.renderObject;
    final pile = _clePile.currentContext?.findRenderObject() as RenderBox?;
    if (ro is! RenderBox || !ro.attached || pile == null) return null;
    final h = pile.globalToLocal(ro.localToGlobal(Offset.zero));
    return h & ro.size;
  }

  /// Touche le bouton à la place de la personne (appelle son action).
  void _toucher(Element el) {
    VoidCallback? action;
    void chercher(Element e) {
      if (action != null) return;
      final w = e.widget;
      if (w is ButtonStyleButton && w.onPressed != null) {
        action = w.onPressed;
      } else if (w is IconButton && w.onPressed != null) {
        action = w.onPressed;
      } else if (w is InkResponse && w.onTap != null) {
        action = w.onTap;
      } else if (w is GestureDetector && w.onTap != null) {
        action = w.onTap;
      } else if (w is ListTile && w.onTap != null) {
        action = w.onTap;
      } else if (w is ActionChip && w.onPressed != null) {
        action = w.onPressed;
      } else if (w is ChoiceChip && w.onSelected != null) {
        final f = w.onSelected!;
        action = () => f(true);
      }
      if (action == null) e.visitChildElements(chercher);
    }

    chercher(el);
    action?.call();
  }

  /// Ferme toutes les pages ouvertes (et les fenêtres) : retour à l'accueil.
  void _revenirAccueil() {
    final racine = _clePile.currentContext as Element?;
    final navigateurs = <NavigatorState>[];
    void visiter(Element el) {
      if (el is StatefulElement && el.state is NavigatorState) {
        navigateurs.add(el.state as NavigatorState);
      }
      el.visitChildElements(visiter);
    }

    racine?.visitChildElements(visiter);
    final principal = widget.navigateur.currentState;
    principal?.popUntil((r) => r.isFirst);
    for (final n in navigateurs.reversed) {
      if (n.mounted) n.popUntil((r) => r.isFirst);
    }
  }

  // ---------------------------------------------------------------------------
  // Boutons de la visite
  // ---------------------------------------------------------------------------

  void _pause() {
    if (_enPause) {
      // Reprendre : on rejoue le groupe en cours depuis son début.
      _lancer(debutDuGroupe(_chapitres, _chapitre));
    } else {
      _arreterTout();
      setState(() => _enPause = true);
    }
  }

  void _rejouer() => _lancer(debutDuGroupe(_chapitres, _chapitre));

  void _suivant() {
    final s = groupeSuivant(_chapitres, _chapitre);
    _lancer(s >= _chapitres.length ? _chapitres.length - 1 : s);
  }

  void _quitter() {
    _arreterTout();
    _c.quitter();
  }

  // ---------------------------------------------------------------------------
  // Affichage
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _c.visible;
    return Stack(
      key: _clePile,
      children: [
        AbsorbPointer(
          absorbing: visible && !_enPause && !_fini,
          child: KeyedSubtree(key: _cleContenu, child: widget.child),
        ),
        if (visible) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PeintreCible(cible: _cible)),
            ),
          ),
          _panneau(context),
        ],
      ],
    );
  }

  Widget _panneau(BuildContext context) {
    // Taille de la zone de la visite (sous les bandeaux) : c'est dans cette
    // zone qu'est mesurée la place du bouton montré.
    final ecran = MediaQuery.sizeOf(context);
    final zone = _clePile.currentContext?.findRenderObject();
    final taille = zone is RenderBox && zone.hasSize ? zone.size : ecran;
    final grand = ecran.width >= 700;
    final cible = _cible;
    // Le panneau se met à l'opposé du bouton montré, du côté où il y a le
    // plus de place.
    // Le panneau va du côté où il tient sans toucher le bouton (le plus
    // spacieux d'abord). S'il ne tient d'aucun côté, il se met en bas : le
    // haut du bouton (son titre, son montant) reste visible.
    final boite = _clePanneau.currentContext?.findRenderObject();
    final hauteurPanneau =
        (boite is RenderBox && boite.hasSize ? boite.size.height : 170.0) + 8;
    final placeHaut = cible?.top ?? 0;
    final placeBas = cible == null ? 0 : taille.height - cible.bottom;
    final tientHaut = placeHaut >= hauteurPanneau;
    final tientBas = placeBas >= hauteurPanneau;
    final enHaut =
        cible != null && tientHaut && (!tientBas || placeHaut > placeBas);
    final aGauche =
        !grand || cible == null || cible.center.dx > taille.width / 2;
    final largeur = grand ? 520.0 : taille.width;
    // Petit écran (4 pouces, sous les bandeaux) : panneau compact pour
    // laisser la place au bouton montré.
    final compact = !grand && taille.height < 480;
    final tailleAvatar = grand
        ? 120.0
        : (compact ? 58.0 : (taille.height < 600 ? 74.0 : 92.0));
    // Direction du bras d'Afi vers le bouton.
    double? geste;
    if (cible != null) {
      final xAfi = aGauche
          ? 16 + tailleAvatar * 0.75
          : taille.width - 16 - largeur + tailleAvatar * 0.75;
      final yAfi = enHaut
          ? 16 + tailleAvatar * 0.9
          : taille.height - 16 - tailleAvatar * 0.6;
      geste = math.atan2(cible.center.dy - yAfi, cible.center.dx - xAfi);
    }
    final ch = _chapitres[_chapitre];
    final panneau = Material(
      key: const Key('visite-panneau'),
      color: CouleursZp.surface,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(grand ? 20 : 18),
        side: const BorderSide(color: CouleursZp.creditClair, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (afiMedaillonVisite)
                    MedaillonAfi(
                      key: const Key('visite-avatar'),
                      taille: tailleAvatar,
                      bouche: _bouche,
                      humeur: switch (_expression) {
                        Expression.neutre => Humeur.neutre,
                        Expression.sourire => Humeur.sourire,
                        _ => Humeur.joie,
                      },
                      auRevoir: _fini || _expression == Expression.auRevoir,
                      cible: geste == null
                          ? null
                          : Offset(math.cos(geste), math.sin(geste)),
                      anime: widget.anime,
                    )
                  else
                    AvatarAfi(
                      key: const Key('visite-avatar'),
                      taille: tailleAvatar,
                      bouche: _bouche,
                      expression: _fini ? Expression.auRevoir : _expression,
                      geste: geste,
                      anime: widget.anime,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fini
                              ? 'Visite terminée'
                              : 'Chapitre ${_chapitre + 1} sur ${_chapitres.length} · ${ch.titre}',
                          key: const Key('visite-chapitre'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CouleursZp.creditClair,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _enPause
                              ? 'Pause. Touchez « Reprendre » pour continuer.'
                              : (_fini
                                    ? 'Touchez « Quitter » pour essayer vous-même, ou « Rejouer ».'
                                    : _sousTitre),
                          key: const Key('visite-sous-titre'),
                          maxLines: grand ? 5 : (compact ? 3 : 4),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: grand ? 19 : (compact ? 15 : 17),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        if (_enregistree.mentionIA)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Voix générée par intelligence artificielle',
                              key: Key('visite-mention-ia'),
                              style: TextStyle(
                                fontSize: 11,
                                color: CouleursZp.texteDoux,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _bouton(
                    compact,
                    'visite-pause',
                    _enPause ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    _enPause ? 'Reprendre' : 'Pause',
                    _fini ? null : _pause,
                  ),
                  _bouton(
                    compact,
                    'visite-rejouer',
                    Icons.replay_rounded,
                    'Rejouer',
                    _rejouer,
                  ),
                  _bouton(
                    compact,
                    'visite-suivant',
                    Icons.skip_next_rounded,
                    'Suivant',
                    _fini ? null : _suivant,
                  ),
                  _bouton(
                    compact,
                    'visite-quitter',
                    Icons.close_rounded,
                    'Quitter',
                    _quitter,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Positioned(
      left: aGauche ? 8 : null,
      right: aGauche ? (grand ? null : 8) : 8,
      top: enHaut ? 8 : null,
      bottom: enHaut ? null : 8,
      width: grand ? largeur : null,
      child: SafeArea(
        child: KeyedSubtree(key: _clePanneau, child: panneau),
      ),
    );
  }

  Widget _bouton(
    bool compact,
    String cle,
    IconData icone,
    String texte,
    VoidCallback? f,
  ) => Expanded(
    child: TextButton(
      key: Key(cle),
      onPressed: f,
      style: TextButton.styleFrom(
        minimumSize: Size(0, compact ? 44 : 52),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        foregroundColor: CouleursZp.texte,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: compact ? 22 : 26),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(texte, style: TextStyle(fontSize: compact ? 13 : 14)),
          ),
        ],
      ),
    ),
  );
}

/// Assombrit l'écran sauf le bouton montré, l'entoure d'or et pose une
/// flèche au-dessus (ou au-dessous).
class _PeintreCible extends CustomPainter {
  const _PeintreCible({required this.cible});
  final Rect? cible;

  @override
  void paint(Canvas canvas, Size size) {
    final c = cible;
    if (c == null) return;
    final trou = RRect.fromRectAndRadius(
      c.inflate(6),
      const Radius.circular(14),
    );
    final voile = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(trou),
    );
    canvas.drawPath(voile, Paint()..color = const Color(0x8C000000));
    canvas.drawRRect(
      trou,
      Paint()
        ..color = CouleursZp.creditClair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Flèche : au-dessus du bouton s'il y a la place, sinon au-dessous.
    final dessus = c.top > 70;
    final x = c.center.dx;
    final pointe = dessus ? c.top - 10 : c.bottom + 10;
    final sens = dessus ? -1.0 : 1.0;
    final fleche = Path()
      ..moveTo(x, pointe)
      ..lineTo(x - 16, pointe + sens * 22)
      ..lineTo(x - 6, pointe + sens * 22)
      ..lineTo(x - 6, pointe + sens * 46)
      ..lineTo(x + 6, pointe + sens * 46)
      ..lineTo(x + 6, pointe + sens * 22)
      ..lineTo(x + 16, pointe + sens * 22)
      ..close();
    canvas.drawPath(fleche, Paint()..color = CouleursZp.creditClair);
    canvas.drawPath(
      fleche,
      Paint()
        ..color = const Color(0xFF0B1730)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PeintreCible old) => old.cible != cible;
}
