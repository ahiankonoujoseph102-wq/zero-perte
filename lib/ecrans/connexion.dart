import 'package:flutter/material.dart';

import '../app/etat_application.dart';
import '../domaine/utilisateurs.dart';
import '../theme/couleurs.dart';
import 'communs.dart';
import 'logo_boutique.dart';

/// Couleur de l'avatar d'une personne (stable, d'après son nom ; jamais vert ni rouge).
Color couleurAvatar(String nom, {int? position}) {
  const couleurs = [
    0xFF1E5AA8,
    0xFF5B3F9A,
    0xFF0E6B73,
    0xFF6D4C3D,
    0xFF283593,
    0xFF7A2E5C,
    0xFF37474F,
  ];
  final h = nom.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
  return Color(couleurs[(position ?? h) % couleurs.length]);
}

/// Avatar rond avec l'initiale.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.nom,
    this.taille = 72,
    this.bloque = false,
    this.position,
  });
  final String nom;
  final double taille;
  final bool bloque;

  /// Position dans une liste : deux voisins n'ont jamais la même couleur.
  final int? position;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: taille / 2,
    backgroundColor: bloque
        ? CouleursZp.ligne
        : couleurAvatar(nom, position: position),
    child: Text(
      nom.isEmpty ? '?' : nom.substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: taille * 0.45,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Écran « Qui êtes-vous ? » : chaque personne touche son visage puis tape son code.
class PageConnexion extends StatelessWidget {
  const PageConnexion({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    final personnes = etat.utilisateurs;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LogoBoutique(config: etat.config, taille: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      etat.config.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Qui êtes-vous ?',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const Text(
                'Touchez votre nom.',
                style: TextStyle(fontSize: 18, color: CouleursZp.texteDoux),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: personnes.length,
                  itemBuilder: (context, i) {
                    final u = personnes[i];
                    return Material(
                      color: CouleursZp.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(
                          color: CouleursZp.ligne,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        key: Key('connexion-${u.nom}'),
                        borderRadius: BorderRadius.circular(22),
                        onTap: u.actif
                            ? () => demanderPin(context, etat, u)
                            : () => annoncer(
                                context,
                                'Le compte de ${u.nom} est bloqué. Voyez le patron.',
                                erreur: true,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              children: [
                                Avatar(
                                  nom: u.nom,
                                  bloque: !u.actif,
                                  position: i,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  u.nom,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  !u.actif
                                      ? 'Bloqué'
                                      : (u.role == Role.patron
                                            ? 'Patron'
                                            : 'Vendeur'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: u.actif
                                        ? CouleursZp.texteDoux
                                        : CouleursZp.argentSort,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
