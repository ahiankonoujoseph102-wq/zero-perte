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
    // 0.37 : boutons hauts (au moins 52 px, faciles à toucher), un seul
    // arrondi, transitions courtes et discrètes entre les pages.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(
          fontFamily: policeZp,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(borderRadius: FormesZp.arrondi),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: const RoundedRectangleBorder(borderRadius: FormesZp.arrondi),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        foregroundColor: CouleursZp.texte,
        side: const BorderSide(color: CouleursZp.ligne, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: policeZp,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(borderRadius: FormesZp.arrondi),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: policeZp,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CouleursZp.marque,
    ),
    cardTheme: const CardThemeData(
      color: CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: FormesZp.arrondi,
        side: BorderSide(color: CouleursZp.ligne),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: CouleursZp.surface,
      shape: RoundedRectangleBorder(borderRadius: FormesZp.arrondi),
    ),
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
      border: OutlineInputBorder(borderRadius: FormesZp.arrondi),
      enabledBorder: OutlineInputBorder(
        borderRadius: FormesZp.arrondi,
        borderSide: BorderSide(color: CouleursZp.ligne, width: 1.5),
      ),
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
        borderRadius: BorderRadius.all(Radius.circular(FormesZp.rayon)),
      ),
    ),
  );
}
