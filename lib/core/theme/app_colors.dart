import 'package:flutter/material.dart';

/// Palette « Neo-Minimalist Sci-Fi » de l'application.
///
/// Toutes les couleurs sont centralisées ici afin de garantir la cohérence
/// visuelle et de respecter le design system demandé.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Fonds
  // ---------------------------------------------------------------------------
  /// Fond sombre profond principal (presque noir, OLED-friendly).
  static const Color background = Color(0xFF0A0E17);

  /// Surface légèrement plus claire utilisée pour les cartes opaques.
  static const Color surface = Color(0xFF111827);

  /// Surface secondaire (gris bleuté très sombre).
  static const Color surfaceAlt = Color(0xFF161E2E);

  // ---------------------------------------------------------------------------
  // Glassmorphism
  // ---------------------------------------------------------------------------
  /// Bordure fine translucide : blanc à 10 %.
  static const Color glassBorder = Color(0x1AFFFFFF);

  /// Remplissage verre : blanc à 6 %.
  static const Color glassFill = Color(0x0FFFFFFF);

  /// Reflet haut de carte : blanc à 8 %.
  static const Color glassHighlight = Color(0x14FFFFFF);

  // ---------------------------------------------------------------------------
  // Accents néon
  // ---------------------------------------------------------------------------
  /// Cyan électrique : poids / Bluetooth (accent principal).
  static const Color cyan = Color(0xFF00F0FF);

  /// Émeraude néon : masse musculaire.
  static const Color emerald = Color(0xFF00FFA3);

  /// Ambre / Corail : masse grasse.
  static const Color coral = Color(0xFFFF6B6B);

  /// Ambre : eau corporelle / objectif.
  static const Color amber = Color(0xFFFFC24B);

  /// Violet : masse osseuse / éléments secondaires.
  static const Color violet = Color(0xFF9D6BFF);

  // ---------------------------------------------------------------------------
  // Texte
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF9BA7B8);
  static const Color textMuted = Color(0xFF5D6B7E);

  // ---------------------------------------------------------------------------
  // États
  // ---------------------------------------------------------------------------
  static const Color danger = Color(0xFFFF4D6D);
  static const Color success = Color(0xFF00FFA3);
  static const Color warning = Color(0xFFFFC24B);
}
