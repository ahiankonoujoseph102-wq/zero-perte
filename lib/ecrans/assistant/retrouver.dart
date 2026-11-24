import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/utilisateurs.dart';
import '../../synchro/synchro.dart';
import '../../theme/couleurs.dart';
import '../clavier_pin.dart';
import '../communs.dart';

/// « J'ai déjà une boutique » : téléphone neuf, perdu ou cassé. On retrouve
/// tout depuis le Google Drive de la boutique, ou depuis un fichier de sauvegarde.
class PageRetrouverBoutique extends StatefulWidget {
  const PageRetrouverBoutique({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageRetrouverBoutique> createState() => _PageRetrouverBoutiqueState();
}

class _PageRetrouverBoutiqueState extends State<PageRetrouverBoutique> {
  bool _enCours = false;
  List<Appareil>? _appareils;
  List<int>? _fichier;
  String? _erreur;
  int _tour = 0;

  EtatApplication get etat => widget.etat;

  Future<void> _drive() async {
    setState(() => _enCours = true);
    try {
      if (!await etat.connecterSynchro()) {
        if (mounted) {
          annoncer(context, 'Connexion Google annulée.', erreur: true);
        }
        return;
      }
      final a = await etat.appareilsSynchro() ?? const [];
      if (a.isEmpty) {
        if (mounted) {
          annoncer(
            context,
            'Aucune boutique dans ce compte Google.',
            erreur: true,
          );
        }
        return;
      }
      setState(() => _appareils = a);
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _depuisDrive(Appareil? remplace) async {
    setState(() => _enCours = true);
    try {
      final n = await etat.retrouverBoutiqueDepuisDrive(remplace: remplace);
      await etat.synchroniser();
      if (!mounted) return;
      annoncer(context, 'Boutique retrouvée ($n opérations).');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _choisirFichier() async {
    final f = await etat.services.choisirFichier?.call();
    if (f == null || !mounted) return;
    setState(() {
      _fichier = f;
      _erreur = null;
    });
  }

  Future<void> _code(String code) async {
    setState(() => _enCours = true);
    try {
      final n = await etat.retrouverBoutiqueDepuisFichier(_fichier!, code);
      if (!mounted) return;
      annoncer(context, 'Boutique retrouvée ($n opérations).');
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _enCours = false;
        _tour++;
        _erreur = messageErreur(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fichier != null) {
      return PageZp(
        titre: 'Code du patron',
        icone: Icons.key_rounded,
        corps: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Le code secret du patron au moment de la sauvegarde.',
                style: TextStyle(fontSize: 17),
              ),
              Expanded(
                child: SaisiePin(
                  key: ValueKey(_tour),
                  titre: _ancien
                      ? 'Code du patron (4 chiffres)'
                      : 'Code du patron (6 chiffres)',
                  erreur: _erreur,
                  longueur: _ancien ? longueurPin : longueurPinPatron,
                  onComplet: _code,
                ),
              ),
              TextButton(
                key: const Key('code-ancien-4'),
                onPressed: () => setState(() {
                  _tour++;
                  _ancien = !_ancien;
                }),
                child: Text(
                  _ancien
                      ? 'Code à 6 chiffres'
                      : 'Ancienne sauvegarde (code à 4 chiffres)',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final appareils = _appareils;
    return PageZp(
      titre: 'Retrouver',
      icone: Icons.restore_rounded,
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (appareils == null) ...[
            const Text(
              'Nouveau téléphone, ou téléphone perdu ou cassé ? Retrouvez vos produits, ventes, clients et vendeurs.',
              style: TextStyle(fontSize: 19),
            ),
            const SizedBox(height: 16),
            _GrandChoix(
              cle: 'retrouver-drive',
              icone: Icons.cloud_download_rounded,
              titre: 'Depuis le compte Google',
              texte: 'Avec le compte Google de la boutique',
              onTap: _enCours || etat.services.connecterDrive == null
                  ? null
                  : _drive,
            ),
            const SizedBox(height: 12),
            _GrandChoix(
              cle: 'retrouver-fichier',
              icone: Icons.folder_open_rounded,
              titre: 'Depuis un fichier',
              texte: 'Fichier de sauvegarde « .zps »',
              onTap: _enCours || etat.services.choisirFichier == null
                  ? null
                  : _choisirFichier,
            ),
          ] else ...[
            const Text(
              'Ce téléphone remplace-t-il un ancien appareil ?',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'S\'il remplace un téléphone perdu ou cassé, il continue ses numéros de reçus.',
              style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 12),
            for (final a in appareils)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GrandChoix(
                  cle: 'remplacer-${a.prefixe}',
                  icone: Icons.phonelink_erase_rounded,
                  titre: 'Remplace : ${a.nom.isEmpty ? 'appareil' : a.nom}',
                  texte: 'Reçus « ${a.prefixe} »',
                  onTap: _enCours ? null : () => _depuisDrive(a),
                ),
              ),
            _GrandChoix(
              cle: 'nouvel-appareil',
              icone: Icons.add_to_home_screen_rounded,
              titre: 'Non, c\'est un appareil en plus',
              texte: 'Il compte dans la licence',
              onTap: _enCours ? null : () => _depuisDrive(null),
            ),
          ],
          if (_enCours)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  bool _ancien = false;
}

class _GrandChoix extends StatelessWidget {
  const _GrandChoix({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.texte,
    required this.onTap,
  });

  final String cle;
  final IconData icone;
  final String titre;
  final String texte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: CouleursZp.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FormesZp.rayon),
          side: BorderSide(color: couleur, width: 2),
        ),
        child: InkWell(
          key: Key(cle),
          borderRadius: BorderRadius.circular(FormesZp.rayon),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icone, size: 44, color: couleur),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        texte,
                        style: const TextStyle(
                          fontSize: 16,
                          color: CouleursZp.texteDoux,
                        ),
                      ),
                    ],
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
