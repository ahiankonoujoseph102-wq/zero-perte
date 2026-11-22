/// Ajout d'un vendeur par QR code (0.35) :
/// - patron : « Ajouter mon vendeur » → prénom → QR code (10 minutes, une fois) ;
/// - vendeur : « Je suis vendeur » → il scanne → la boutique arrive, son code
///   à 4 chiffres s'affiche ;
/// - patron : « Mes appareils » → Retirer, « Couper tous les vendeurs ».
/// Code de secours (8 chiffres, avec « OUI » du patron) derrière le petit lien
/// « Pas d'appareil photo ? ».
library;

import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../app/etat_application.dart';
import '../synchro/invitation.dart';
import '../synchro/synchro.dart' show Appareil, ErreurLicencePleine;
import '../theme/couleurs.dart';
import 'assistant/etapes_boutique.dart' show decorationChamp;
import 'communs.dart';

// -----------------------------------------------------------------------------
// Dessin du QR code
// -----------------------------------------------------------------------------

/// QR code dessiné en noir sur blanc (bien lisible par l'appareil photo).
class DessinQr extends StatelessWidget {
  const DessinQr({super.key, required this.texte, this.taille = 260});

  final String texte;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final qr = QrImage(
      QrCode.fromData(data: texte, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Container(
      width: taille,
      height: taille,
      padding: EdgeInsets.all(taille * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(painter: _PeintreQr(qr), size: Size.infinite),
    );
  }
}

class _PeintreQr extends CustomPainter {
  _PeintreQr(this.qr);
  final QrImage qr;

  @override
  void paint(Canvas canvas, Size size) {
    final n = qr.moduleCount;
    final c = size.shortestSide / n;
    final p = Paint()..color = Colors.black;
    for (var x = 0; x < n; x++) {
      for (var y = 0; y < n; y++) {
        if (qr.isDark(y, x)) {
          canvas.drawRect(Rect.fromLTWH(x * c, y * c, c + 0.3, c + 0.3), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PeintreQr ancien) => ancien.qr != qr;
}

String _minutes(Duration d) {
  final s = d.inSeconds.clamp(0, 9999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Widget _titre(String t, {Key? key}) => Text(
  t,
  key: key,
  textAlign: TextAlign.center,
  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
);

Widget _texte(String t, {Color? couleur}) => Text(
  t,
  textAlign: TextAlign.center,
  style: TextStyle(fontSize: 19, color: couleur ?? CouleursZp.texteDoux),
);

Widget _cadreErreur(String t) => Container(
  key: const Key('erreur-vendeur-qr'),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: CouleursZp.argentSort.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: CouleursZp.argentSort),
  ),
  child: Row(
    children: [
      const Icon(Icons.error_rounded, color: CouleursZp.argentSort, size: 30),
      const SizedBox(width: 10),
      Expanded(child: Text(t, style: const TextStyle(fontSize: 18))),
    ],
  ),
);

Widget _attente(String t) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const SizedBox(height: 24),
    const CircularProgressIndicator(),
    const SizedBox(height: 20),
    _texte(t, couleur: CouleursZp.texte),
  ],
);

// -----------------------------------------------------------------------------
// Patron : « Ajouter mon vendeur »
// -----------------------------------------------------------------------------

enum _EtapeAjout { prenom, preparation, qr, code, fini, expire }

class PageAjouterMonVendeur extends StatefulWidget {
  const PageAjouterMonVendeur({
    super.key,
    required this.etat,
    this.horloge,
    this.attente = const Duration(seconds: 3),
  });

  final EtatApplication etat;

  /// Les tests fixent l'heure et le rythme des vérifications.
  final DateTime Function()? horloge;
  final Duration attente;

  @override
  State<PageAjouterMonVendeur> createState() => _PageAjouterMonVendeurState();
}

class _PageAjouterMonVendeurState extends State<PageAjouterMonVendeur> {
  final _prenom = TextEditingController();
  _EtapeAjout _etape = _EtapeAjout.prenom;
  String? _erreur;
  bool _licencePleine = false;
  PaquetInvitation? _paquet;
  QrInvitation? _qr;
  String? _code;
  DateTime? _fin;
  Timer? _tic;
  Timer? _veille;
  bool _verification = false;
  bool _dialogueOuvert = false;

  DateTime _maintenant() => (widget.horloge ?? DateTime.now)();

  @override
  void dispose() {
    _tic?.cancel();
    _veille?.cancel();
    _prenom.dispose();
    super.dispose();
  }

  Future<void> _preparer() async {
    final prenom = _prenom.text.trim();
    if (prenom.isEmpty) {
      setState(() => _erreur = 'Écrivez d\'abord le prénom du vendeur.');
      return;
    }
    setState(() {
      _etape = _EtapeAjout.preparation;
      _erreur = null;
      _licencePleine = false;
    });
    try {
      _paquet = await widget.etat.preparerInvitation(prenom);
      await _publierQr();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _etape = _EtapeAjout.prenom;
        _licencePleine = e is ErreurLicencePleine;
        _erreur = messageErreur(e);
      });
    }
  }

  void _demarrerMinuteries() {
    _fin = _maintenant().add(dureeInvitation);
    _tic?.cancel();
    _veille?.cancel();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_maintenant().isBefore(_fin!)) {
        _tic?.cancel();
        _veille?.cancel();
        setState(() => _etape = _EtapeAjout.expire);
      } else {
        setState(() {});
      }
    });
    _veille = Timer.periodic(widget.attente, (_) => _verifier());
  }

  Future<void> _publierQr() async {
    final p = _paquet!;
    setState(() {
      _etape = _EtapeAjout.preparation;
      _erreur = null;
    });
    try {
      final qr = await widget.etat.publierQr(p);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _code = null;
        _etape = _EtapeAjout.qr;
      });
      _demarrerMinuteries();
    } catch (e) {
      if (mounted) {
        setState(() {
          _etape = _EtapeAjout.expire;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  Future<void> _passerAuCode() async {
    final p = _paquet!;
    setState(() => _etape = _EtapeAjout.preparation);
    try {
      final code = await widget.etat.ouvrirCodeSecours(p);
      if (!mounted) return;
      setState(() {
        _code = code;
        _qr = null;
        _etape = _EtapeAjout.code;
      });
      _demarrerMinuteries();
    } catch (e) {
      if (mounted) {
        setState(() {
          _etape = _EtapeAjout.expire;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  bool _accepte = false;

  Future<void> _verifier() async {
    if (_verification || !mounted || _dialogueOuvert) return;
    if (_etape != _EtapeAjout.qr && _etape != _EtapeAjout.code) return;
    _verification = true;
    try {
      final etat = widget.etat;
      if (_etape == _EtapeAjout.qr) {
        if (await etat.invitationPrise(_qr!)) _fini();
        return;
      }
      final code = _code!;
      if (_accepte) {
        if (await etat.codeSecoursUtilise(code)) _fini();
        return;
      }
      final d = await etat.demandeRecue(_paquet!, code);
      if (d == null || !mounted) return;
      _dialogueOuvert = true;
      final oui = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Un téléphone veut entrer'),
          content: Text(
            'Téléphone : ${d.appareil.isEmpty ? 'inconnu' : d.appareil}\n\n'
            'Est-ce bien le téléphone de ${_paquet!.vendeurNom}, là, devant vous ?',
            style: const TextStyle(fontSize: 19),
          ),
          actions: [
            TextButton(
              key: const Key('demande-non'),
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('NON', style: TextStyle(fontSize: 20)),
            ),
            FilledButton(
              key: const Key('demande-oui'),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('OUI', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      );
      _dialogueOuvert = false;
      if (!mounted) return;
      if (oui == true) {
        await etat.accepterDemande(_paquet!, code, d);
        _accepte = true;
      } else {
        // NON : ce code ne servira plus ; un nouveau QR code est proposé.
        _tic?.cancel();
        _veille?.cancel();
        setState(() {
          _etape = _EtapeAjout.expire;
          _erreur = 'Refusé. Refaites un QR code pour le bon téléphone.';
        });
      }
    } catch (_) {
      // Pas de réseau un instant : on réessaie au prochain tour.
    } finally {
      _verification = false;
    }
  }

  void _fini() {
    _tic?.cancel();
    _veille?.cancel();
    if (mounted) setState(() => _etape = _EtapeAjout.fini);
  }

  @override
  Widget build(BuildContext context) {
    final nom = _paquet?.vendeurNom ?? _prenom.text.trim();
    final reste = _fin == null
        ? Duration.zero
        : _fin!.difference(_maintenant());
    return PageZp(
      titre: 'Ajouter mon vendeur',
      icone: Icons.person_add_alt_1_rounded,
      bas: switch (_etape) {
        _EtapeAjout.prenom => GrosBouton(
          key: const Key('bouton-continuer-vendeur'),
          texte: 'Continuer',
          icone: Icons.arrow_forward_rounded,
          onPressed: _preparer,
        ),
        _EtapeAjout.fini => GrosBouton(
          key: const Key('bouton-vendeur-termine'),
          texte: 'Terminé',
          icone: Icons.check_rounded,
          couleur: CouleursZp.argentEntre,
          onPressed: () => Navigator.of(context).pop(),
        ),
        _EtapeAjout.expire => GrosBouton(
          key: const Key('bouton-refaire-qr'),
          texte: 'Refaire un QR code',
          icone: Icons.qr_code_2_rounded,
          onPressed: _paquet == null ? null : _publierQr,
        ),
        _ => null,
      },
      corps: LayoutBuilder(
        builder: (context, c) {
          // Le QR code, le temps restant et le lien tiennent sans défiler
          // (petit écran : sans la phrase d'explication).
          final compact = c.maxHeight < 560;
          final tailleQr = min(
            c.maxWidth - 48,
            c.maxHeight - (compact ? 190 : 260),
          ).clamp(150.0, 340.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (_etape) {
                _EtapeAjout.prenom => [
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 72,
                    color: CouleursZp.marque,
                  ),
                  const SizedBox(height: 8),
                  _titre('Prénom du vendeur'),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('champ-prenom-vendeur'),
                    controller: _prenom,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 24),
                    decoration: decorationChamp(
                      'Prénom',
                      icone: Icons.badge_rounded,
                    ),
                    onSubmitted: (_) => _preparer(),
                  ),
                  const SizedBox(height: 14),
                  _texte(
                    'Ensuite Google demande votre accord : choisissez le compte '
                    'de la boutique, puis touchez « Continuer ».',
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 16),
                    _erreur!.isEmpty ? const SizedBox() : _erreurWidget(),
                  ],
                  if (_licencePleine) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('vers-mes-appareils'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PageMesAppareils(etat: widget.etat),
                        ),
                      ),
                      icon: const Icon(Icons.devices_rounded),
                      label: const Text(
                        'Voir mes appareils',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                    ),
                  ],
                ],
                _EtapeAjout.preparation => [
                  _attente('Préparation… (Internet nécessaire)'),
                ],
                _EtapeAjout.qr => [
                  _titre(
                    'Faites scanner ce QR code',
                    key: const Key('titre-qr'),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 6),
                    _texte(
                      'Sur le téléphone de $nom : « Je suis vendeur », '
                      'puis « Scanner le QR code ».',
                    ),
                  ],
                  SizedBox(height: compact ? 8 : 14),
                  Center(
                    child: DessinQr(
                      key: const Key('qr-invitation'),
                      texte: _qr!.texte,
                      taille: tailleQr,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _texte(
                    'Encore ${_minutes(reste)} · une seule fois',
                    couleur: CouleursZp.creditTexte,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    key: const Key('lien-pas-appareil-photo'),
                    onPressed: _passerAuCode,
                    child: const Text(
                      'Pas d\'appareil photo ?',
                      style: TextStyle(
                        fontSize: 17,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
                _EtapeAjout.code => [
                  _titre('Code à taper sur son téléphone'),
                  const SizedBox(height: 8),
                  _texte(
                    'Sur le téléphone de $nom : « Je suis vendeur », puis '
                    '« Pas d\'appareil photo ? », puis tapez :',
                  ),
                  const SizedBox(height: 18),
                  FittedBox(
                    child: Text(
                      codeSecoursLisible(_code!),
                      key: const Key('code-secours'),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _texte(
                    _accepte ? 'Envoi au téléphone de $nom…' : 'Ensuite, ce téléphone-ci vous demandera de dire OUI.',
                    couleur: CouleursZp.texte,
                  ),
                  const SizedBox(height: 8),
                  _texte(
                    'Encore ${_minutes(reste)} · une seule fois',
                    couleur: CouleursZp.creditTexte,
                  ),
                ],
                _EtapeAjout.fini => [
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 110,
                    color: CouleursZp.argentEntre,
                  ),
                  const SizedBox(height: 12),
                  _titre(
                    'Téléphone de $nom ajouté',
                    key: const Key('vendeur-ajoute'),
                  ),
                  const SizedBox(height: 10),
                  _texte(
                    'Son code secret s\'affiche sur son téléphone. '
                    'Vous le retrouvez dans Gestion, « Mes appareils ».',
                  ),
                ],
                _EtapeAjout.expire => [
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.timer_off_rounded,
                    size: 90,
                    color: CouleursZp.creditTexte,
                  ),
                  const SizedBox(height: 10),
                  _titre('Ce code n\'est plus valable'),
                  const SizedBox(height: 8),
                  _texte('Il a duré 10 minutes. Faites-en un nouveau.'),
                  if (_erreur != null) ...[
                    const SizedBox(height: 14),
                    _erreurWidget(),
                  ],
                ],
              },
            ),
          );
        },
      ),
    );
  }

  Widget _erreurWidget() => _cadreErreur(_erreur!);
}

// -----------------------------------------------------------------------------
// Vendeur : « Je suis vendeur »
// -----------------------------------------------------------------------------

enum _EtapeVendeur { accueil, code, attenteOui, chargement, fini }

class PageJeSuisVendeur extends StatefulWidget {
  const PageJeSuisVendeur({
    super.key,
    required this.etat,
    this.attente = const Duration(seconds: 3),
  });

  final EtatApplication etat;
  final Duration attente;

  @override
  State<PageJeSuisVendeur> createState() => _PageJeSuisVendeurState();
}

class _PageJeSuisVendeurState extends State<PageJeSuisVendeur> {
  late _EtapeVendeur _etape = widget.etat.scannerPossible
      ? _EtapeVendeur.accueil
      : _EtapeVendeur.code;
  final _code = TextEditingController();
  String? _erreur;
  PaquetInvitation? _paquet;
  DemandeParCode? _demande;
  String _modele = '';
  Timer? _veille;
  DateTime? _fin;
  bool _verification = false;

  @override
  void dispose() {
    _veille?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _scanner() async {
    setState(() => _erreur = null);
    try {
      final texte = await widget.etat.services.scannerQr!();
      if (texte == null || !mounted) return;
      setState(() => _etape = _EtapeVendeur.chargement);
      final p = await widget.etat.entrerParQr(texte);
      if (mounted) {
        setState(() {
          _paquet = p;
          _etape = _EtapeVendeur.fini;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _etape = _EtapeVendeur.accueil;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  Future<void> _envoyerCode() async {
    final code = codeSecoursNettoye(_code.text);
    if (code == null) {
      setState(
        () => _erreur = 'Le code a 8 chiffres. Vérifiez et recommencez.',
      );
      return;
    }
    setState(() {
      _erreur = null;
      _etape = _EtapeVendeur.chargement;
    });
    try {
      try {
        final i = await widget.etat.services.telephone.infos();
        _modele = '${i.fabricant} ${i.modele}'.trim();
      } catch (_) {}
      final d = await widget.etat.demanderParCode(code, _modele);
      if (!mounted) return;
      if (d == null) {
        setState(() {
          _etape = _EtapeVendeur.code;
          _erreur = 'Code faux ou expiré. Vérifiez avec le patron.';
        });
        return;
      }
      _demande = d;
      _fin = DateTime.now().add(dureeInvitation);
      setState(() => _etape = _EtapeVendeur.attenteOui);
      _veille = Timer.periodic(widget.attente, (_) => _verifierOui());
    } catch (e) {
      if (mounted) {
        setState(() {
          _etape = _EtapeVendeur.code;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  Future<void> _verifierOui() async {
    if (_verification || _etape != _EtapeVendeur.attenteOui) return;
    if (_fin != null && DateTime.now().isAfter(_fin!)) {
      _veille?.cancel();
      setState(() {
        _etape = _EtapeVendeur.code;
        _erreur = 'Le patron n\'a pas répondu à temps. Recommencez.';
      });
      return;
    }
    _verification = true;
    try {
      final p = await widget.etat.verifierReponse(_demande!);
      if (p != null && mounted) {
        _veille?.cancel();
        setState(() {
          _paquet = p;
          _etape = _EtapeVendeur.fini;
        });
      }
    } on ErreurRelais {
      // Réseau : on réessaie au prochain tour.
    } catch (e) {
      _veille?.cancel();
      if (mounted) {
        setState(() {
          _etape = _EtapeVendeur.code;
          _erreur = messageErreur(e);
        });
      }
    } finally {
      _verification = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Je suis vendeur',
      icone: Icons.badge_rounded,
      bas: switch (_etape) {
        _EtapeVendeur.accueil => GrosBouton(
          key: const Key('bouton-scanner-qr'),
          texte: 'Scanner le QR code',
          icone: Icons.qr_code_scanner_rounded,
          couleur: CouleursZp.argentEntre,
          onPressed: _scanner,
        ),
        _EtapeVendeur.code => GrosBouton(
          key: const Key('bouton-valider-code-secours'),
          texte: 'Valider',
          icone: Icons.check_rounded,
          onPressed: _envoyerCode,
        ),
        _EtapeVendeur.fini => GrosBouton(
          key: const Key('bouton-code-retenu'),
          texte: 'J\'ai retenu mon code',
          icone: Icons.check_rounded,
          couleur: CouleursZp.argentEntre,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        _ => null,
      },
      corps: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_etape) {
            _EtapeVendeur.accueil => [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 96,
                color: CouleursZp.argentEntre,
              ),
              const SizedBox(height: 10),
              _titre('Scannez le QR code du patron'),
              const SizedBox(height: 12),
              _texte(
                '1. Le patron touche « Ajouter mon vendeur » sur son téléphone.\n'
                '2. Touchez le bouton vert ci-dessous et visez son QR code.',
                couleur: CouleursZp.texte,
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 16),
                _cadreErreur(_erreur!),
              ],
              const SizedBox(height: 10),
              TextButton(
                key: const Key('lien-pas-appareil-photo'),
                onPressed: () => setState(() {
                  _erreur = null;
                  _etape = _EtapeVendeur.code;
                }),
                child: const Text(
                  'Pas d\'appareil photo ?',
                  style: TextStyle(
                    fontSize: 17,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            _EtapeVendeur.code => [
              const Icon(
                Icons.dialpad_rounded,
                size: 72,
                color: CouleursZp.marque,
              ),
              const SizedBox(height: 8),
              _titre('Tapez le code du patron'),
              const SizedBox(height: 8),
              _texte(
                'Le patron touche « Ajouter mon vendeur », puis '
                '« Pas d\'appareil photo ? » : 8 chiffres s\'affichent.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('champ-code-secours'),
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 9,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
                decoration: decorationChamp('Code à 8 chiffres'),
                onSubmitted: (_) => _envoyerCode(),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                _cadreErreur(_erreur!),
              ],
            ],
            _EtapeVendeur.attenteOui => [
              const Icon(
                Icons.phonelink_ring_rounded,
                size: 84,
                color: CouleursZp.marque,
              ),
              const SizedBox(height: 10),
              _titre('Montrez ce téléphone au patron'),
              const SizedBox(height: 10),
              _texte(
                'Sur son téléphone, il doit toucher OUI pour :\n'
                '${_modele.isEmpty ? 'ce téléphone' : _modele}',
                couleur: CouleursZp.texte,
              ),
              _attente('En attente du patron…'),
            ],
            _EtapeVendeur.chargement => [
              _attente(
                'Téléchargement de la boutique…\n'
                'Gardez Internet et ne fermez pas l\'application.',
              ),
            ],
            _EtapeVendeur.fini => _bienvenue(),
          },
        ),
      ),
    );
  }

  List<Widget> _bienvenue() {
    final p = _paquet!;
    return [
      const Icon(
        Icons.check_circle_rounded,
        size: 84,
        color: CouleursZp.argentEntre,
      ),
      const SizedBox(height: 8),
      _titre(
        'Bienvenue ${p.vendeurNom} !',
        key: const Key('bienvenue-vendeur'),
      ),
      if (p.nomBoutique.isNotEmpty) _texte('Boutique : ${p.nomBoutique}'),
      const SizedBox(height: 18),
      _texte('Votre code secret :', couleur: CouleursZp.texte),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: CouleursZp.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CouleursZp.argentEntre, width: 2),
        ),
        child: FittedBox(
          child: Text(
            p.codeVendeur.split('').join(' '),
            key: const Key('code-vendeur-recu'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _texte(
        'Apprenez-le par cœur. Ne le donnez à personne : '
        'chaque vente est faite à votre nom.',
      ),
    ];
  }
}

// -----------------------------------------------------------------------------
// Patron : « Mes appareils »
// -----------------------------------------------------------------------------

class PageMesAppareils extends StatefulWidget {
  const PageMesAppareils({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageMesAppareils> createState() => _PageMesAppareilsState();
}

class _PageMesAppareilsState extends State<PageMesAppareils> {
  late Future<({List<Appareil> actifs, Set<String> retires})?> _liste =
      _charger();
  bool _enCours = false;

  Future<({List<Appareil> actifs, Set<String> retires})?> _charger() async {
    return widget.etat.mesAppareils();
  }

  void _recharger() => setState(() {
    _liste = _charger();
  });

  Future<bool> _confirmer(String titre, String texte, String bouton) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(titre),
          content: Text(texte, style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Annuler', style: TextStyle(fontSize: 18)),
            ),
            FilledButton(
              key: const Key('confirmer-retrait'),
              style: FilledButton.styleFrom(
                backgroundColor: CouleursZp.argentSort,
              ),
              onPressed: () => Navigator.of(c).pop(true),
              child: Text(bouton, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _retirer(Appareil a) async {
    final nom = a.nom.isEmpty ? 'cet appareil' : a.nom;
    if (!await _confirmer(
      'Retirer $nom ?',
      'Il ne pourra plus vendre pour la boutique ni voir ses chiffres '
          '(au plus tard dans une heure). Les ventes qu\'il n\'a pas encore '
          'envoyées seront perdues.',
      'Retirer',
    )) {
      return;
    }
    await _agir(() async {
      await widget.etat.retirerAppareil(a);
      if (mounted) annoncer(context, '$nom est retiré.');
    });
  }

  Future<void> _couper() async {
    if (!await _confirmer(
      'Couper tous les vendeurs ?',
      'À utiliser si un téléphone est perdu ou volé. Tous les téléphones '
          'ajoutés par QR code sont retirés ; Google va vous demander votre '
          'accord. Il faudra refaire un QR code pour chaque vendeur. Les ventes '
          'qu\'ils n\'ont pas encore envoyées seront perdues.',
      'Tout couper',
    )) {
      return;
    }
    await _agir(() async {
      final n = await widget.etat.couperTousLesVendeurs();
      if (mounted) {
        annoncer(
          context,
          n == 0 ? 'Aucun téléphone à couper.' : '$n téléphone(s) coupé(s).',
        );
      }
    });
  }

  Future<void> _agir(Future<void> Function() action) async {
    setState(() => _enCours = true);
    try {
      await action();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
        _recharger();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    return PageZp(
      titre: 'Mes appareils',
      icone: Icons.devices_rounded,
      bas: etat.ajoutParQrPossible
          ? GrosBouton(
              key: const Key('bouton-ajouter-mon-vendeur-appareils'),
              texte: 'Ajouter mon vendeur',
              icone: Icons.qr_code_2_rounded,
              onPressed: _enCours
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PageAjouterMonVendeur(etat: etat),
                        ),
                      );
                      _recharger();
                    },
            )
          : null,
      corps: FutureBuilder(
        future: _liste,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done || _enCours) {
            return const Center(child: CircularProgressIndicator());
          }
          final l = s.data;
          if (l == null) {
            return const EtatVide(
              icone: Icons.cloud_off_rounded,
              titre: 'Le compte Google de la boutique n\'est pas relié.',
              explication: 'Reliez-le dans Gestion, « Appareils et Drive », puis revenez ici.',
            );
          }
          final max = etat.licence?.telephones;
          final avecQr = l.actifs.any(
            (a) => a.parInvitation && a.id != etat.idCeTelephone,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                max == null
                    ? '${l.actifs.length} appareil(s)'
                    : '${l.actifs.length} appareil(s) sur $max permis par la licence',
                key: const Key('compte-appareils'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final a in l.actifs) ...[
                _TuileAppareil(
                  appareil: a,
                  ceTelephone: a.id == etat.idCeTelephone,
                  onRetirer: _enCours ? null : () => _retirer(a),
                ),
                const SizedBox(height: 10),
              ],
              if (l.retires.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    '${l.retires.length} appareil(s) retiré(s) : ils ne comptent plus.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: CouleursZp.texteDoux,
                    ),
                  ),
                ),
              if (avecQr && etat.ajoutParQrPossible) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('bouton-couper-tous'),
                  onPressed: _enCours ? null : _couper,
                  icon: const Icon(Icons.gpp_bad_rounded),
                  label: const Text(
                    'Couper tous les vendeurs',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CouleursZp.argentSort,
                    side: const BorderSide(color: CouleursZp.argentSort),
                    minimumSize: const Size(0, 56),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Si un téléphone est perdu ou volé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: CouleursZp.texteDoux),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TuileAppareil extends StatelessWidget {
  const _TuileAppareil({
    required this.appareil,
    required this.ceTelephone,
    required this.onRetirer,
  });

  final Appareil appareil;
  final bool ceTelephone;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    final a = appareil;
    final d = DateTime.fromMillisecondsSinceEpoch(a.inscrit);
    String n(int v) => v.toString().padLeft(2, '0');
    return Container(
      key: Key('appareil-${a.prefixe}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CouleursZp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ceTelephone ? CouleursZp.marque : CouleursZp.ligne,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ceTelephone
                ? Icons.smartphone_rounded
                : Icons.phone_android_rounded,
            size: 40,
            color: ceTelephone ? CouleursZp.marque : CouleursZp.texte,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.nom.isEmpty ? 'Appareil' : a.nom,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ceTelephone
                      ? 'Ce téléphone · reçus ${a.prefixe}'
                      : '${a.parInvitation ? 'Ajouté par QR code' : 'Compte Google'}'
                            ' · reçus ${a.prefixe} · depuis le '
                            '${n(d.day)}/${n(d.month)}/${d.year}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: CouleursZp.texteDoux,
                  ),
                ),
              ],
            ),
          ),
          if (!ceTelephone)
            TextButton(
              key: Key('retirer-${a.prefixe}'),
              onPressed: onRetirer,
              style: TextButton.styleFrom(
                foregroundColor: CouleursZp.argentSort,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Retirer', style: TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Téléphone retiré par le patron
// -----------------------------------------------------------------------------

class PageAppareilRetire extends StatelessWidget {
  const PageAppareilRetire({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              key: const Key('page-appareil-retire'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phonelink_erase_rounded,
                  size: 96,
                  color: CouleursZp.argentSort,
                ),
                const SizedBox(height: 16),
                _titre('Ce téléphone a été retiré de la boutique'),
                const SizedBox(height: 12),
                _texte(
                  'Le patron l\'a retiré : on ne peut plus vendre avec. '
                  'Pour s\'en resservir dans une boutique, désinstallez puis '
                  'réinstallez Zéro Perte.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau du vendeur quand Google a coupé l'accès : ses ventes restent ici et
/// partiront dès qu'un nouveau QR code est scanné.
class BandeauAccesCoupe extends StatelessWidget {
  const BandeauAccesCoupe({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursZp.argentSort,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('bandeau-acces-coupe'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PageJeSuisVendeur(etat: etat)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.link_off_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ce téléphone n\'est plus relié à la boutique. Vos ventes sont '
                  'gardées. Touchez ici pour scanner un nouveau QR code.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
