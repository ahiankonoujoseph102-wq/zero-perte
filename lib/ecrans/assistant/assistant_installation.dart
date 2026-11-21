import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/licence.dart';
import '../../domaine/verification_telephone.dart';
import '../../services/aide.dart';
import '../../services/telephone.dart';
import '../communs.dart' show ColonneCentree;
import '../../theme/couleurs.dart';
import '../accueil_vendeur.dart';
import 'etapes_boutique.dart';

/// Assistant d'installation : une étape par écran, une voix qui lit la consigne,
/// un bouton d'aide toujours visible. Il reprend là où il s'était arrêté.
class AssistantInstallation extends StatefulWidget {
  const AssistantInstallation({
    super.key,
    required this.etat,
    this.onDemonstration,
  });

  final EtatApplication etat;

  /// Ouvre la boutique de démonstration (avant l'activation) ; nul = pas de démo.
  final VoidCallback? onDemonstration;

  @override
  State<AssistantInstallation> createState() => _AssistantInstallationState();
}

class _AssistantInstallationState extends State<AssistantInstallation> {
  EtapeAssistant? _derniereLue;
  Future<_ResultatVerification>? _verification;

  EtatApplication get etat => widget.etat;

  /// Étapes visibles (sans « terminé ») pour la barre de progression.
  /// Étapes comptées dans la barre de progression (« fin » et « terminé » exclues).
  static final _etapes = EtapeAssistant.values
      .where((e) => e.index <= EtapeAssistant.codePatron.index)
      .toList();

  String? _erreurActivation;
  bool _activationEnCours = false;

  Future<void> _collerCode() async {
    setState(() {
      _activationEnCours = true;
      _erreurActivation = null;
    });
    try {
      final texte = await etat.services.lirePressePapiers();
      await etat.activer(texte ?? '');
      final l = etat.licence!;
      await etat.services.voix.dire(
        'Code accepté. Boutique ${l.nomBoutique}. ${l.telephones} téléphones. Touchez Continuer.',
      );
    } on ErreurCode catch (e) {
      _erreurActivation = e.probleme.message;
      await etat.services.voix.dire(e.probleme.message);
    } finally {
      if (mounted) setState(() => _activationEnCours = false);
    }
  }

  Future<_ResultatVerification> _verifier() async {
    final infos = await etat.services.telephone.infos();
    final voix = await etat.services.voix.francaisDisponible();
    return _ResultatVerification(
      infos,
      evaluerTelephone(infos, voixFrancaise: voix),
    );
  }

  String _texteALire(EtapeAssistant e) => switch (e) {
    EtapeAssistant.bienvenue =>
      'Bienvenue dans Zéro Perte. Nous allons préparer votre boutique ensemble, '
          'une étape à la fois. Touchez le bouton vert pour commencer.',
    EtapeAssistant.verification =>
      'Vérification du téléphone. Attendez quelques secondes. Si tout est vert, '
          'touchez Continuer. Si quelque chose est rouge, touchez Aide.',
    EtapeAssistant.activation =>
      'Code d\'activation. Ouvrez WhatsApp. Appuyez longtemps sur le message de Zéro Perte '
          'qui contient votre code, puis choisissez Copier. Revenez ici et touchez Coller le code.',
    _ => texteEtapeBoutique(e),
  };

  void _lireSiNouvelle(EtapeAssistant e) {
    if (_derniereLue == e) return;
    _derniereLue = e;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => etat.services.voix.dire(_texteALire(e)),
    );
  }

  Future<void> _aide(String etape, String diagnostic) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _FeuilleAide(
          etape: etape,
          diagnostic: diagnostic,
          ouvrir: etat.services.ouvrirLien,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        final e = etat.etape;
        _lireSiNouvelle(e);
        if (e == EtapeAssistant.verification) _verification ??= _verifier();
        final numero = (_etapes.indexOf(e) + 1).clamp(1, _etapes.length);
        return Scaffold(
          body: ColonneCentree(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Row(
                        children: [
                          const LogoZp(taille: 40),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Installation',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _BoutonAide(onTap: () => _aideDepuisEtape(e)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: numero / _etapes.length,
                        minHeight: 10,
                        backgroundColor: CouleursZp.ligne,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Étape $numero sur ${_etapes.length}',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontSize: 16,
                        color: CouleursZp.texteDoux,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (e.index >= EtapeAssistant.typeBoutique.index)
                      Expanded(child: pageEtapeBoutique(etat, e))
                    else ...[
                      Expanded(child: _contenu(e)),
                      const SizedBox(height: 12),
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: _barreBas(e),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _aideDepuisEtape(EtapeAssistant e) async {
    String diagnostic = 'inconnu';
    try {
      diagnostic = (await etat.services.telephone.infos()).diagnostic;
    } catch (_) {}
    if (!mounted) return;
    await _aide(e.name, diagnostic);
  }

  Widget _contenu(EtapeAssistant e) => switch (e) {
    EtapeAssistant.bienvenue => const _Bienvenue(),
    EtapeAssistant.verification => FutureBuilder<_ResultatVerification>(
      future: _verification,
      builder: (context, r) {
        if (r.hasError) {
          return const _Message(
            icone: Icons.error_rounded,
            couleur: CouleursZp.argentSort,
            titre: 'Vérification impossible',
            texte: 'Touchez « Aide » pour nous contacter.',
          );
        }
        if (!r.hasData) return const Center(child: CircularProgressIndicator());
        return _ListeControles(controles: r.data!.controles);
      },
    ),
    EtapeAssistant.activation => _Activation(
      licence: etat.licence,
      erreur: _erreurActivation,
      onDemonstration: widget.onDemonstration,
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _barreBas(EtapeAssistant e) {
    // Haut-parleur : compris même sans savoir lire.
    final ecouter = Semantics(
      button: true,
      label: 'Écouter',
      child: Tooltip(
        message: 'Écouter',
        child: OutlinedButton(
          key: const Key('bouton-ecouter'),
          onPressed: () => etat.services.voix.dire(_texteALire(e)),
          style: OutlinedButton.styleFrom(
            fixedSize: const Size(64, 64),
            minimumSize: const Size(64, 64),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            side: const BorderSide(color: CouleursZp.marque, width: 2),
            foregroundColor: CouleursZp.marque,
          ),
          child: const Icon(Icons.volume_up_rounded, size: 32),
        ),
      ),
    );
    Widget principal;
    if (e == EtapeAssistant.bienvenue) {
      principal = _BoutonPrincipal(
        cle: 'bouton-commencer',
        texte: 'Commencer',
        onPressed: () => etat.suivante(),
      );
    } else if (e == EtapeAssistant.activation) {
      principal = etat.licence == null
          ? _BoutonPrincipal(
              cle: 'bouton-coller-code',
              texte: 'Coller le code',
              onPressed: _activationEnCours ? null : _collerCode,
            )
          : _BoutonPrincipal(
              cle: 'bouton-continuer',
              texte: 'Continuer',
              onPressed: () => etat.suivante(),
            );
    } else {
      principal = FutureBuilder<_ResultatVerification>(
        future: _verification,
        builder: (context, r) {
          final ok = r.hasData && peutContinuer(r.data!.controles);
          final bloque = r.hasData && !ok;
          return _BoutonPrincipal(
            cle: 'bouton-continuer',
            texte: bloque ? 'Demander de l\'aide' : 'Continuer',
            couleur: bloque ? CouleursZp.argentSort : null,
            onPressed: !r.hasData && !r.hasError
                ? null
                : (ok
                      ? () => etat.suivante()
                      : () => _aide(
                          e.name,
                          r.data?.infos.diagnostic ?? 'inconnu',
                        )),
          );
        },
      );
    }
    return Row(
      children: [
        ecouter,
        const SizedBox(width: 12),
        Expanded(child: principal),
      ],
    );
  }
}

class _ResultatVerification {
  const _ResultatVerification(this.infos, this.controles);
  final InfosTelephone infos;
  final List<Controle> controles;
}

class _BoutonPrincipal extends StatelessWidget {
  const _BoutonPrincipal({
    required this.cle,
    required this.texte,
    this.onPressed,
    this.couleur,
  });

  final String cle;
  final String texte;
  final VoidCallback? onPressed;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: Key(cle),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: couleur ?? CouleursZp.marque,
        minimumSize: const Size(0, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          texte,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _BoutonAide extends StatelessWidget {
  const _BoutonAide({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const Key('bouton-aide'),
      onPressed: onTap,
      icon: const Icon(Icons.support_agent_rounded, size: 26),
      label: const Text(
        'Aide',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: CouleursZp.marquePale,
        foregroundColor: CouleursZp.marque,
      ),
    );
  }
}

class _Bienvenue extends StatelessWidget {
  const _Bienvenue();

  @override
  Widget build(BuildContext context) {
    return const _Message(
      icone: Icons.storefront_rounded,
      couleur: CouleursZp.marque,
      titre: 'Bienvenue dans Zéro Perte',
      texte:
          'Nous allons préparer votre boutique ensemble, une étape à la fois.\n\n'
          'Touchez « Écouter » pour entendre les explications.',
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.texte,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final court = c.maxHeight < 380;
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: court ? 88 : 140,
                  height: court ? 88 : 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: couleur.withValues(alpha: 0.12),
                  ),
                  child: Icon(icone, size: court ? 50 : 80, color: couleur),
                ),
                SizedBox(height: court ? 12 : 24),
                Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  texte,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    color: CouleursZp.texteDoux,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListeControles extends StatelessWidget {
  const _ListeControles({required this.controles});
  final List<Controle> controles;

  @override
  Widget build(BuildContext context) {
    final ok = peutContinuer(controles);
    return ListView(
      children: [
        Text(
          ok
              ? 'Votre téléphone est prêt'
              : 'Ce téléphone ne peut pas utiliser Zéro Perte',
          key: Key(ok ? 'verification-ok' : 'verification-bloquee'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: ok ? CouleursZp.texte : CouleursZp.argentSort,
          ),
        ),
        const SizedBox(height: 12),
        for (final c in controles) _TuileControle(controle: c),
      ],
    );
  }
}

class _TuileControle extends StatelessWidget {
  const _TuileControle({required this.controle});
  final Controle controle;

  @override
  Widget build(BuildContext context) {
    final (icone, couleur) = switch (controle.niveau) {
      NiveauControle.ok => (Icons.check_circle_rounded, CouleursZp.argentEntre),
      NiveauControle.attention => (Icons.warning_rounded, CouleursZp.credit),
      NiveauControle.bloquant => (Icons.cancel_rounded, CouleursZp.argentSort),
    };
    return Card(
      elevation: 0,
      color: CouleursZp.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: couleur.withValues(alpha: 0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icone,
              color: couleur,
              size: 36,
              key: Key('controle-${controle.cle}-${controle.niveau.name}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controle.titre,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controle.detail,
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
    );
  }
}

/// Feuille « Besoin d'aide ? » : deux numéros WhatsApp de l'assistance.
class _FeuilleAide extends StatelessWidget {
  const _FeuilleAide({
    required this.etape,
    required this.diagnostic,
    required this.ouvrir,
  });

  final String etape;
  final String diagnostic;
  final OuvreurDeLien ouvrir;

  @override
  Widget build(BuildContext context) {
    final message = messageAide(etape: etape, diagnostic: diagnostic);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Besoin d\'aide ?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Écrivez-nous sur WhatsApp. Votre message est déjà prêt.',
              style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 16),
            for (final numero in numerosAssistance) ...[
              FilledButton.icon(
                key: Key('aide-$numero'),
                onPressed: () async {
                  final ok = await ouvrir(lienWhatsApp(numero, message));
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'WhatsApp introuvable. Appelez le $numero.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_rounded, size: 28),
                label: Text(
                  numero,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 64),
                  backgroundColor: CouleursZp.marque,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Étape « Code d'activation ».
class _Activation extends StatelessWidget {
  const _Activation({
    required this.licence,
    required this.erreur,
    this.onDemonstration,
  });

  final Licence? licence;
  final String? erreur;
  final VoidCallback? onDemonstration;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    if (l != null) {
      return _Message(
        key: const Key('activation-reussie'),
        icone: Icons.verified_rounded,
        couleur: CouleursZp.argentEntre,
        titre: 'Boutique activée',
        texte: '${l.nomBoutique}\n${l.telephones} téléphones autorisés',
      );
    }
    return ListView(
      children: [
        const Text(
          'Code d\'activation',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        if (erreur != null)
          Container(
            key: const Key('activation-erreur'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CouleursZp.argentSort.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CouleursZp.argentSort, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_rounded,
                  color: CouleursZp.argentSort,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    erreur!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: CouleursZp.texte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (erreur != null) const SizedBox(height: 14),
        const _EtapeImagee(
          numero: 1,
          icone: Icons.chat_rounded,
          texte: 'Ouvrez WhatsApp et trouvez le message de Zéro Perte avec votre code.',
        ),
        const _EtapeImagee(
          numero: 2,
          icone: Icons.touch_app_rounded,
          texte: 'Appuyez longtemps sur le message, puis touchez « Copier ».',
        ),
        const _EtapeImagee(
          numero: 3,
          icone: Icons.content_paste_rounded,
          texte: 'Revenez ici et touchez « Coller le code ».',
        ),
        if (onDemonstration != null) ...[
          const SizedBox(height: 8),
          const Text(
            'Pas encore de code ?',
            style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const Key('bouton-demonstration'),
            onPressed: onDemonstration,
            icon: const Icon(Icons.play_circle_rounded, size: 28),
            label: const Text(
              'Voir une démonstration',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Une consigne numérotée avec une icône (pour les personnes qui lisent mal).
class _EtapeImagee extends StatelessWidget {
  const _EtapeImagee({
    required this.numero,
    required this.icone,
    required this.texte,
  });

  final int numero;
  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$numero',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: CouleursZp.marque,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 26,
            backgroundColor: CouleursZp.marquePale,
            child: Icon(icone, color: CouleursZp.marque, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 18, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
