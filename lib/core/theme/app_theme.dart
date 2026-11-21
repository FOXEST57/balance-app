import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Thème global de l'application.
///
/// Typographie : Space Grotesk (police géométrique moderne).
/// Les chiffres sont rendus en « tabular figures » pour éviter que la valeur
/// affichée ne « saute » horizontalement pendant la pesée en direct.
class AppTheme {
  AppTheme._();

  /// Fonctionnalité de chiffres tabulaires réutilisable.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static ThemeData dark() {
    final ThemeData base = ThemeData.dark(useMaterial3: true);

    final TextTheme textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.cyan,
        onPrimary: Colors.black,
        secondary: AppColors.emerald,
        onSecondary: Colors.black,
        surface: AppColors.surface,
        error: AppColors.coral,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: GoogleFonts.spaceGrotesk(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFill,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.4),
        ),
      ),
    );
  }

  /// Style de chiffre tabulaire réutilisable (jauge, KPI, graphiques).
  static TextStyle numeric(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: tabularFigures,
    );
  }
}
