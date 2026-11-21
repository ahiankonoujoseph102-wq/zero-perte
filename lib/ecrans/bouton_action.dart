import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/couleurs.dart';

/// Gros bouton d'action : une grande icône + un mot.
/// Le contenu se réduit automatiquement pour tenir sur les petits écrans et avec
/// les grandes tailles de texte, sans jamais déborder.
class BoutonAction extends StatelessWidget {
  const BoutonAction({
    super.key,
    required this.titre,
    required this.icone,
    required this.couleur,
    required this.couleurClaire,
    required this.onTap,
    this.sousTitre,
    this.couleurTexte = Colors.white,
    this.horizontal = false,
    this.principal = false,
  });

  final String titre;
  final String? sousTitre;
  final IconData icone;
  final Color couleur;
  final Color couleurClaire;
  final Color couleurTexte;
  final VoidCallback onTap;

  /// Icône à gauche du texte (boutons larges et bas).
  final bool horizontal;

  /// Bouton principal (Vendre) : plus grand, avec une étiquette secondaire.
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(principal ? 32 : 26);
    final tailleIcone = principal ? 96.0 : 64.0;
    final tailleTitre = principal ? 48.0 : 30.0;

    final contenu = horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PastilleIcone(
                icone: icone,
                taille: tailleIcone * 0.7,
                couleur: couleurTexte,
              ),
              const SizedBox(width: 18),
              Text(titre, style: _styleTitre(tailleTitre)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PastilleIcone(
                icone: icone,
                taille: tailleIcone,
                couleur: couleurTexte,
              ),
              SizedBox(height: principal ? 14 : 10),
              Text(
                titre,
                style: _styleTitre(tailleTitre),
                textAlign: TextAlign.center,
              ),
              if (sousTitre != null) ...[
                const SizedBox(height: 4),
                Text(
                  sousTitre!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: couleurTexte.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          );

    return Semantics(
      button: true,
      label: titre,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: rayon,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [couleurClaire, couleur],
          ),
          boxShadow: [
            BoxShadow(
              color: couleur.withValues(alpha: 0.22),
              blurRadius: principal ? 18 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: rayon,
            splashColor: Colors.white.withValues(alpha: 0.18),
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: contenu),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _styleTitre(double taille) => TextStyle(
    fontSize: taille,
    fontWeight: FontWeight.w700,
    color: couleurTexte,
    letterSpacing: 0.3,
    height: 1.1,
  );
}

/// Icône posée sur un disque translucide : plus lisible et plus chaleureux.
class _PastilleIcone extends StatelessWidget {
  const _PastilleIcone({
    required this.icone,
    required this.taille,
    required this.couleur,
  });

  final IconData icone;
  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille * 1.45,
      height: taille * 1.45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            (couleur == Colors.white ? Colors.white : CouleursZp.texteSurCredit)
                .withValues(alpha: 0.16),
      ),
      alignment: Alignment.center,
      child: Icon(icone, size: taille, color: couleur),
    );
  }
}
