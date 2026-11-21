import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../services/partage.dart';
import '../../theme/couleurs.dart';
import '../caisse/fermeture.dart' show dateEtHeure;
import '../clavier_pin.dart';
import '../communs.dart';

/// Clé du réglage local : heure de la dernière sauvegarde envoyée.
const cleDerniereSauvegarde = 'sauvegarde.derniere';

/// Sauvegarde manuelle : un fichier chiffré avec le code du patron, à garder
/// hors du téléphone (WhatsApp du patron, Google Drive, clé USB…).
class PageSauvegarde extends StatefulWidget {
  const PageSauvegarde({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageSauvegarde> createState() => _PageSauvegardeState();
}

class _PageSauvegardeState extends State<PageSauvegarde> {
  late Future<String?> _derniere = widget.etat.journal.lireParametre(
    cleDerniereSauvegarde,
  );
  bool _demandeCode = false;
  bool _enCours = false;
  String? _erreur;
  int _tour = 0;

  Future<void> _codeSaisi(String pin) async {
    final patron = widget.etat.patron;
    if (patron == null) return;
    if (!await widget.etat.verifierPin(patron, pin, connecter: false)) {
      setState(() {
        _tour++;
        _erreur = 'Code faux.';
      });
      return;
    }
    setState(() {
      _demandeCode = false;
      _enCours = true;
    });
    try {
      final fichier = await widget.etat.creerSauvegarde(pin);
      final r = await widget.etat.services.partagerFichier(
        fichier,
        widget.etat.nomSauvegarde(),
      );
      if (r == ResultatPartage.echec) {
        if (mounted) {
          annoncer(
            context,
            'La sauvegarde n\'a pas pu être envoyée.',
            erreur: true,
          );
        }
        return;
      }
      await widget.etat.journal.ecrireParametre(
        cleDerniereSauvegarde,
        '${widget.etat.maintenant().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      annoncer(context, 'Sauvegarde créée. Gardez-la bien.');
      setState(() {
        _derniere = widget.etat.journal.lireParametre(cleDerniereSauvegarde);
      });
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_demandeCode) {
      return PageZp(
        titre: 'Sauvegarde',
        icone: Icons.backup_rounded,
        corps: Padding(
          padding: const EdgeInsets.all(16),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: SaisiePin(
              key: ValueKey(_tour),
              titre: 'Code secret du patron',
              erreur: _erreur,
              onComplet: _codeSaisi,
            ),
          ),
        ),
      );
    }
    return PageZp(
      titre: 'Sauvegarde',
      icone: Icons.backup_rounded,
      bas: GrosBouton(
        key: const Key('bouton-creer-sauvegarde'),
        texte: _enCours ? 'Préparation…' : 'Créer une sauvegarde',
        icone: Icons.backup_rounded,
        onPressed: _enCours
            ? null
            : () => setState(() {
                _erreur = null;
                _demandeCode = true;
              }),
      ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.backup_rounded, size: 72, color: CouleursZp.marque),
          const SizedBox(height: 8),
          const Text(
            'Si le téléphone est perdu, volé ou cassé, la sauvegarde permet de tout retrouver : produits, ventes, caisse, vendeurs.',
            style: TextStyle(fontSize: 19),
          ),
          const SizedBox(height: 12),
          const _Point(
            Icons.lock_rounded,
            'Le fichier est fermé avec votre code secret de patron : il faudra ce code pour le rouvrir.',
          ),
          const _Point(
            Icons.send_rounded,
            'Envoyez-le à votre propre WhatsApp ou dans Google Drive, pas sur ce téléphone seulement.',
          ),
          const _Point(
            Icons.event_repeat_rounded,
            'Faites-en une chaque semaine.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: _derniere,
            builder: (context, s) {
              final ms = int.tryParse(s.data ?? '');
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CouleursZp.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CouleursZp.ligne),
                ),
                child: Text(
                  ms == null
                      ? 'Aucune sauvegarde pour l\'instant.'
                      : 'Dernière sauvegarde : le ${dateEtHeure(ms)}',
                  key: const Key('derniere-sauvegarde'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ms == null
                        ? CouleursZp.argentSort
                        : CouleursZp.argentEntre,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icone, this.texte);
  final IconData icone;
  final String texte;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 28, color: CouleursZp.marque),
        const SizedBox(width: 10),
        Expanded(child: Text(texte, style: const TextStyle(fontSize: 17))),
      ],
    ),
  );
}
