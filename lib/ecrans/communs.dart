import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/etat_application.dart';
import '../domaine/utilisateurs.dart';
import '../donnees/journal_local.dart';
import '../theme/couleurs.dart';
import 'clavier_pin.dart';

/// Page standard de Zéro Perte : grande barre de titre avec bouton retour.
class PageZp extends StatelessWidget {
  const PageZp({
    super.key,
    required this.titre,
    required this.corps,
    this.actions,
    this.bas,
    this.icone,
  });

  final String titre;
  final IconData? icone;
  final Widget corps;
  final List<Widget>? actions;

  /// Zone fixe en bas (gros bouton), au-dessus du clavier.
  final Widget? bas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: CouleursZp.fond,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Row(
            children: [
              if (icone != null) ...[
                Icon(icone, size: 28),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: corps),
            if (bas != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: bas!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gros bouton plein, de la couleur donnée (vert pour encaisser, rouge pour sortir…).
class GrosBouton extends StatelessWidget {
  const GrosBouton({
    super.key,
    required this.texte,
    required this.onPressed,
    this.couleur,
    this.icone,
    this.hauteur = 64,
  });

  final String texte;
  final VoidCallback? onPressed;
  final Color? couleur;
  final IconData? icone;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: couleur,
        minimumSize: Size(0, hauteur),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 28),
              const SizedBox(width: 10),
            ],
            Text(
              texte,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image d'un produit : sa photo, sinon son pictogramme, sinon un carton.
class ImageProduit extends StatelessWidget {
  const ImageProduit({super.key, required this.produit, this.taille = 48});

  final Produit produit;
  final double taille;

  @override
  Widget build(BuildContext context) {
    if (produit.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(taille * 0.2),
        child: Image.memory(
          base64.decode(produit.photo!),
          width: taille,
          height: taille,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: taille,
      height: taille,
      child: Center(
        child: Text(
          produit.emoji ?? '📦',
          style: TextStyle(fontSize: taille * 0.8),
        ),
      ),
    );
  }
}

/// Demande le code secret de [u]. Renvoie vrai si le code est bon.
/// Après 5 erreurs, le code est bloqué 5 minutes.
Future<bool> demanderPin(
  BuildContext context,
  EtatApplication etat,
  Utilisateur u, {
  String? titre,
  bool connecter = true,
}) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _PageDemandePin(
        etat: etat,
        utilisateur: u,
        titre: titre,
        connecter: connecter,
      ),
    ),
  );
  return ok ?? false;
}

class _PageDemandePin extends StatefulWidget {
  const _PageDemandePin({
    required this.etat,
    required this.utilisateur,
    this.titre,
    required this.connecter,
  });

  final EtatApplication etat;
  final Utilisateur utilisateur;
  final String? titre;
  final bool connecter;

  @override
  State<_PageDemandePin> createState() => _PageDemandePinState();
}

class _PageDemandePinState extends State<_PageDemandePin> {
  String? _erreur;
  int _tour = 0;

  @override
  void initState() {
    super.initState();
    _verifierBlocage();
  }

  Future<void> _verifierBlocage() async {
    final fin = await widget.etat.pinBloqueJusqua(widget.utilisateur);
    if (fin != null && mounted) {
      final minutes = fin.difference(widget.etat.maintenant()).inMinutes + 1;
      setState(() => _erreur = 'Trop d\'erreurs. Réessayez dans $minutes min.');
    }
  }

  Future<void> _saisi(String pin) async {
    final u = widget.utilisateur;
    if (!u.actif) {
      setState(() => _erreur = 'Ce compte est bloqué. Voyez le patron.');
      return;
    }
    if (await widget.etat.verifierPin(u, pin, connecter: widget.connecter)) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final bloque = await widget.etat.pinBloqueJusqua(u);
    setState(() {
      _tour++;
      _erreur = bloque != null
          ? 'Trop d\'erreurs. Réessayez dans ${widget.etat.dureeBlocage.inMinutes} min.'
          : 'Code faux. Encore ${widget.etat.essaisRestants(u)} essai(s).';
    });
    await widget.etat.services.voix.dire(_erreur!);
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: widget.titre ?? widget.utilisateur.nom,
      icone: widget.utilisateur.role == Role.patron
          ? Icons.key_rounded
          : Icons.person_rounded,
      corps: Padding(
        padding: const EdgeInsets.all(16),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: SaisiePin(
            key: ValueKey(_tour),
            titre: 'Code secret de ${widget.utilisateur.nom}',
            erreur: _erreur,
            onComplet: _saisi,
          ),
        ),
      ),
    );
  }
}

/// Montre un message de réussite (vert) ou d'erreur (rouge) en bas de l'écran.
void annoncer(BuildContext context, String message, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: erreur
            ? CouleursZp.argentSort
            : CouleursZp.argentEntre,
        content: Row(
          children: [
            Icon(
              erreur ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Lit un nombre entier saisi (chiffres seulement), 0 si vide.
int lireEntier(String texte) =>
    int.tryParse(texte.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Message d'erreur métier lisible.
String messageErreur(Object e) =>
    e is ErreurZeroPerte ? e.message : 'Une erreur est survenue.';
