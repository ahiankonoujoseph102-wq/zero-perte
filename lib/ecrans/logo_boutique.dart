import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domaine/boutique.dart';

/// Logo de la boutique : sa photo dans un cercle, ou ses initiales sur sa couleur.
class LogoBoutique extends StatelessWidget {
  const LogoBoutique({super.key, required this.config, this.taille = 56});

  final ConfigBoutique config;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final couleur = Color(config.couleur);
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: couleur,
        // Liseré clair : le logo se voit sur le fond bleu nuit comme sur l'en-tête
        // coloré du reçu.
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: taille >= 40 ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: couleur.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        image: config.logo == null
            ? null
            : DecorationImage(
                image: MemoryImage(Uint8List.fromList(config.logo!)),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: config.logo != null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: EdgeInsets.all(taille * 0.12),
                child: Text(
                  config.initiales,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: taille * 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }
}
