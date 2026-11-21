import 'package:flutter/material.dart';

import 'couleurs.dart';

/// Police Atkinson Hyperlegible : conçue par le Braille Institute pour les
/// personnes qui lisent difficilement (lettres très différentes les unes des
/// autres : 0/O, 1/l/I, 6/b…). Licence libre OFL, fichiers dans assets/polices.
const String policeZp = 'AtkinsonHyperlegible';

/// Thème de Zéro Perte : grands textes, contrastes forts, coins arrondis.
ThemeData themeZeroPerte({Color couleurMarque = CouleursZp.marque}) {
  final principal = couleurBouton(couleurMarque);
  final schema = ColorScheme.fromSeed(
    seedColor: principal,
    brightness: Brightness.dark,
    primary: principal,
    onPrimary: Colors.white,
    surface: CouleursZp.surface,
    onSurface: CouleursZp.texte,
    error: CouleursZp.argentSort,
    outline: CouleursZp.ligne,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: schema,
    scaffoldBackgroundColor: CouleursZp.fond,
    canvasColor: CouleursZp.fond,
    dividerColor: CouleursZp.ligne,
    fontFamily: policeZp,
  );
  return base.copyWith(
    // `copyWith` remplace des styles entiers : la police et les couleurs sont donc
    // appliquées APRÈS, sinon ces styles perdraient la police Atkinson.
    textTheme: base.textTheme
        .copyWith(
          // Chiffres géants (totaux, caisse).
          displayLarge: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(fontSize: 18, height: 1.35),
          bodyMedium: const TextStyle(fontSize: 16, height: 1.35),
        )
        .apply(
          fontFamily: policeZp,
          bodyColor: CouleursZp.texte,
          displayColor: CouleursZp.texte,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CouleursZp.fond,
      foregroundColor: CouleursZp.texte,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(color: CouleursZp.surface),
    dialogTheme: const DialogThemeData(backgroundColor: CouleursZp.surface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CouleursZp.surface,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: CouleursZp.surface,
      selectedColor: CouleursZp.marqueFoncee,
      side: BorderSide(color: CouleursZp.ligne),
      labelStyle: TextStyle(fontFamily: policeZp, color: CouleursZp.texte),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: CouleursZp.surface,
      labelStyle: TextStyle(color: CouleursZp.texteDoux),
      hintStyle: TextStyle(color: CouleursZp.texteDoux),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CouleursZp.marqueFoncee,
      contentTextStyle: TextStyle(
        fontFamily: policeZp,
        fontSize: 18,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
