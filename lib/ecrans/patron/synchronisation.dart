import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../synchro/synchro.dart';
import '../../theme/couleurs.dart';
import '../caisse/fermeture.dart' show dateEtHeure;
import '../communs.dart';

/// Espace patron → « Appareils et Drive » : le compte Google de la boutique,
/// la dernière synchronisation, les appareils de la boutique.
class PageSynchronisation extends StatefulWidget {
  const PageSynchronisation({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageSynchronisation> createState() => _PageSynchronisationState();
}

class _PageSynchronisationState extends State<PageSynchronisation> {
  late Future<_Etat> _etat = _charger();

  Future<_Etat> _charger() async {
    final j = widget.etat.journal;
    return _Etat(
      compte: widget.etat.compteSynchro ?? await j.lireParametre('sync.compte'),
      derniere: int.tryParse(await j.lireParametre('sync.derniere') ?? ''),
      erreur: await j.lireParametre('sync.erreur'),
      appareils: await widget.etat.appareilsSynchro(),
    );
  }

  void _recharger() {
    setState(() {
      _etat = _charger();
    });
  }

  Future<void> _connecter() async {
    final ok = await widget.etat.connecterSynchro();
    if (!mounted) return;
    if (!ok) {
      annoncer(
        context,
        'Connexion Google impossible ou annulée.',
        erreur: true,
      );
      return;
    }
    await _synchroniser();
  }

  Future<void> _synchroniser() async {
    final r = await widget.etat.synchroniser();
    if (!mounted) return;
    annoncer(
      context,
      r == null
          ? 'La synchronisation n\'a pas pu se faire.'
          : 'À jour : ${r.envoyees} envoyée(s), ${r.recues} reçue(s).',
      erreur: r == null,
    );
    _recharger();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.etat,
      builder: (context, _) => FutureBuilder<_Etat>(
        future: _etat,
        builder: (context, s) {
          final e = s.data;
          final connecte = e?.compte != null;
          return PageZp(
            titre: 'Appareils et Drive',
            icone: Icons.cloud_sync_rounded,
            bas: GrosBouton(
              key: Key(
                connecte ? 'bouton-synchroniser' : 'bouton-connecter-drive',
              ),
              texte: widget.etat.synchroEnCours
                  ? 'Synchronisation…'
                  : (connecte
                        ? 'Synchroniser maintenant'
                        : 'Connecter le compte Google'),
              icone: connecte ? Icons.sync_rounded : Icons.login_rounded,
              onPressed: widget.etat.synchroEnCours || e == null
                  ? null
                  : (connecte ? _synchroniser : _connecter),
            ),
            corps: e == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Icon(
                        Icons.cloud_sync_rounded,
                        size: 64,
                        color: CouleursZp.marque,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Les appareils de la boutique (téléphone, tablette ou PC) s\'échangent les ventes par le Google Drive de la boutique. '
                        'Vous voyez les ventes des autres appareils avec 0 à 30 minutes de retard.',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      _Ligne(
                        icone: Icons.account_circle_rounded,
                        texte: e.compte ?? 'Pas encore connecté',
                        cle: 'compte-drive',
                      ),
                      if (e.derniere != null)
                        _Ligne(
                          icone: Icons.update_rounded,
                          texte:
                              'Dernière fois : le ${dateEtHeure(e.derniere!)}',
                          cle: 'derniere-synchro',
                        ),
                      if ((e.erreur ?? '').isNotEmpty)
                        _Ligne(
                          icone: Icons.error_rounded,
                          texte: e.erreur!,
                          couleur: CouleursZp.argentSort,
                          cle: 'erreur-synchro',
                        ),
                      if (e.appareils != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Appareils de la boutique (${e.appareils!.length}'
                          '${widget.etat.licence == null ? '' : ' sur ${widget.etat.licence!.telephones}'})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final a in e.appareils!)
                          _Ligne(
                            icone: a.id == widget.etat.journal.telephoneId
                                ? Icons.smartphone_rounded
                                : Icons.devices_other_rounded,
                            texte:
                                '${a.nom.isEmpty ? 'Appareil' : a.nom} · reçus ${a.prefixe}'
                                '${a.id == widget.etat.journal.telephoneId ? ' (celui-ci)' : ''}',
                            cle: 'appareil-${a.prefixe}',
                          ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Etat {
  const _Etat({
    required this.compte,
    required this.derniere,
    required this.erreur,
    required this.appareils,
  });
  final String? compte;
  final int? derniere;
  final String? erreur;
  final List<Appareil>? appareils;
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.texte,
    required this.cle,
    this.couleur,
  });
  final IconData icone;
  final String texte;
  final String cle;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(icone, color: couleur ?? CouleursZp.marque, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texte,
            key: Key(cle),
            style: TextStyle(fontSize: 17, color: couleur),
          ),
        ),
      ],
    ),
  );
}
