import 'dart:math' as math;

import '../entities/body_composition.dart';
import '../entities/user_profile.dart';

/// Moteur d'analyse corporelle par impédancemétrie (BIA).
///
/// ---------------------------------------------------------------------------
/// ORIGINE DES RÈGLES DE CALCUL
/// ---------------------------------------------------------------------------
/// Chaque équation utilisée est issue de la littérature scientifique publiée.
/// Aucune donnée n'est inventée. Le seul élément **heuristique** est
/// l'ajustement par impédance, clairement identifié ci-dessous et dont les
/// coefficients sont exposés en tant que paramètres de calibration.
///
///  1. IMC              : formule OMS classique = poids / taille².
///  2. Masse grasse (%) :
///       - a) Si un pourcentage manuel est fourni par l'utilisateur, il est
///            prioritaire (permet de caler l'app sur une mesure de référence).
///       - b) Sinon, si une impédance est disponible : Deurenberg (1991)
///            BF% = 1.20 × IMC + 0.23 × âge − 10.8 × sexe − 5.4
///            (sexe : homme = 1, femme = 0), ajusté par l'indice d'impédance
///            (voir note heuristique).
///       - c) Sinon (ni % manuel ni impédance réelle) : aucune valeur n'est
///            produite, la masse grasse reste `null`.
///  3. Eau corporelle (%) : équation de Watson et al. (1980), eau totale
///       Male  : ETB = 2.447 − 0.09516×âge + 0.1074×taille(cm) + 0.3362×poids
///       Femme : ETB = −2.097 + 0.1069×taille(cm) + 0.2466×poids
///       % eau = ETB / poids × 100.
///  4. Masse osseuse (kg) : estimation empirique proportionnelle (≈ 3.4 % de
///       la masse corporelle, ajustée par sexe), alignée sur les valeurs
///       typiques des balances BIA grand public. Exposée comme constante
///       calibr able.
///  5. Masse musculaire : équation anthropométrique de Lee et al. (2000),
///       masse musculaire squelettique (SMM) :
///         SMM = 0.244×poids + 7.8×taille(m) − 0.098×âge + 6.6×sexe − 3.3
///       Calculée uniquement lorsque la masse grasse est connue (voir 2) ;
///       sinon elle reste `null`.
///  6. Métabolisme de base (BMR) :
///       - Mifflin-St Jeor (1990) si la masse grasse n'est pas connue :
///           Homme  : 10×poids + 6.25×taille(cm) − 5×âge + 5
///           Femme  : 10×poids + 6.25×taille(cm) − 5×âge − 161
///       - Katch-McArdle si la masse grasse est disponible (plus précis) :
///           BMR = 370 + 21.6 × masse maigre(kg)
///
/// NOTE HEURISTIQUE (impédance) :
/// L'indice d'impédance H²/R (cm²/Ω) est inversement corrélé à la masse maigre.
/// Il n'existe pas d'équation Fitdays publiée ; nous appliquons donc un
/// ajustement relatif de l'estimation Deurenberg en comparant l'indice mesuré
/// à une référence moyenne par sexe. Ce coefficient est un paramètre de
/// calibration explicite : il sera affiné avec les trames réelles de la
/// balance Little Balance 8661.
class BiaCalculator {
  BiaCalculator._();

  // --- Paramètres de calibration (heuristique impédance) --------------------
  /// Indice H²/R de référence (cm²/Ω) pour un adulte normo-hydraté.
  static const double refImpedanceIndexMale = 62.0;
  static const double refImpedanceIndexFemale = 57.0;

  /// Bornes de l'ajustement pour éviter toute dérive irréaliste.
  static const double minAdjust = 0.82;
  static const double maxAdjust = 1.22;

  // --- Paramètres de calibration (masse osseuse) ---------------------------
  static const double boneFractionMale = 0.0350;
  static const double boneFractionFemale = 0.0320;

  // --- Facteurs de correction (calibrés sur mesures de référence) -----------
  /// Les équations Deurenberg et Lee surestiment fortement la masse grasse
  /// et la masse musculaire sur les profils à IMC élevé. Ces facteurs,
  /// calibrés à partir de mesures réalisées avec un outil professionnel
  /// (impédancemétrie multi-fréquence), corrigent les valeurs calculées
  /// pour se rapprocher de la réalité.
  ///
  /// Référence : 162.65 kg moyen → 60.0 kg de gras / 28.35 kg de muscle.
  /// Balance   : 161.56 kg       → 68.27 kg de gras / 51.90 kg de muscle.
  /// Facteur gras   = 60.00 / 68.27 = 0.879
  /// Facteur muscle = 28.35 / 51.90 = 0.546
  static const double fatMassCorrectionFactor = 0.879;
  static const double muscleMassCorrectionFactor = 0.546;

  /// Calcule la composition corporelle complète.
  ///
  /// [weightKg]  : poids brut stabilisé (kg).
  /// [profile]   : profil utilisateur (sexe, âge, taille, % manuels…).
  /// [impedanceOhm] : impédance mesurée (Ω), facultative.
  static BodyComposition compute({
    required double weightKg,
    required UserProfile profile,
    int? impedanceOhm,
  }) {
    final int age = profile.age;
    final double heightCm = profile.heightCm;
    final double heightM = profile.heightM;
    final int sex = profile.sex.factor;

    // 1. IMC -----------------------------------------------------------------
    final double bmi = heightM > 0 ? weightKg / (heightM * heightM) : 0;

    // La masse grasse — et la masse musculaire qui en dérive — ne peut être
    // estimée que si l'on dispose d'un pourcentage manuel saisi par
    // l'utilisateur OU d'une impédance réellement mesurée par la balance.
    // Sans l'un des deux, aucune valeur n'est inventée : elle reste `null`
    // (l'application affiche alors « — »).
    final bool hasFatSource =
        profile.manualFatPercent != null ||
        (impedanceOhm != null && impedanceOhm > 0);

    double? fatPercent;
    double? fatMassKg;
    double? musclePercent;
    double? muscleMassKg;

    if (hasFatSource) {
      // 2. Masse grasse (%) --------------------------------------------------
      double fat;
      if (profile.manualFatPercent != null) {
        // a) valeur manuelle prioritaire
        fat = profile.manualFatPercent!;
      } else {
        // b) Deurenberg (1991) ajusté par l'impédance (heuristique, cf. en-tête)
        final double index = (heightCm * heightCm) / impedanceOhm!;
        final double ref = profile.sex == Sex.male
            ? refImpedanceIndexMale
            : refImpedanceIndexFemale;
        // indice élevé => davantage de masse maigre => moins de gras
        final double adjust = (ref / index).clamp(minAdjust, maxAdjust);
        fat = (1.20 * bmi + 0.23 * age - 10.8 * sex - 5.4) * adjust;
      }
      final double clampedFat = fat.clamp(2.0, 70.0);
      // Masse grasse brute (Deurenberg), corrigée par le facteur calibré
      // uniquement si la valeur vient de la formule (pas d'un % manuel).
      final double fatMassRaw = weightKg * (clampedFat / 100.0);
      final double fatMass = profile.manualFatPercent != null
          ? fatMassRaw
          : fatMassRaw * fatMassCorrectionFactor;
      fatMassKg = fatMass;
      // Pourcentage recalculé à partir de la masse corrigée (cohérent).
      fatPercent = weightKg > 0 ? (fatMass / weightKg) * 100 : clampedFat;

      // 5. Masse musculaire — Lee et al. (2000) ------------------------------
      double muscle;
      final bool manualMuscle = profile.manualMusclePercent != null;
      if (manualMuscle) {
        muscle = weightKg * (profile.manualMusclePercent! / 100.0);
      } else {
        muscle = 0.244 * weightKg +
            7.8 * heightM -
            0.098 * age +
            6.6 * sex -
            3.3;
      }
      // Correction calibrée (formule uniquement), puis bornage à la masse maigre.
      if (!manualMuscle) {
        muscle = muscle * muscleMassCorrectionFactor;
      }
      muscle = muscle.clamp(0, math.max(0, weightKg - fatMass));
      muscleMassKg = muscle;
      musclePercent = weightKg > 0 ? (muscle / weightKg) * 100 : 0;
    }

    // 3. Eau corporelle (%) — Watson (1980) ---------------------------------
    final double tbw = profile.sex == Sex.male
        ? 2.447 - 0.09516 * age + 0.1074 * heightCm + 0.3362 * weightKg
        : -2.097 + 0.1069 * heightCm + 0.2466 * weightKg;
    double waterPercent = weightKg > 0 ? (tbw / weightKg) * 100 : 0;
    if (profile.manualWaterPercent != null) {
      waterPercent = profile.manualWaterPercent!;
    }
    waterPercent = waterPercent.clamp(10.0, 75.0);

    // 4. Masse osseuse (kg) --------------------------------------------------
    final double boneFraction =
        profile.sex == Sex.male ? boneFractionMale : boneFractionFemale;
    final double boneMassKg = (weightKg * boneFraction).clamp(1.5, 5.5);

    // 6. Métabolisme de base (kcal) -----------------------------------------
    final double leanMass = weightKg - (fatMassKg ?? 0);
    final double bmr = hasFatSource
        // Katch-McArdle (masse maigre connue)
        ? 370 + 21.6 * leanMass
        // Mifflin-St Jeor
        : 10 * weightKg +
              6.25 * heightCm -
              5 * age +
              (profile.sex == Sex.male ? 5 : -161);

    return BodyComposition(
      weightKg: weightKg,
      impedanceOhm: impedanceOhm,
      fatPercent: fatPercent,
      fatMassKg: fatMassKg,
      musclePercent: musclePercent,
      muscleMassKg: muscleMassKg,
      waterPercent: waterPercent,
      waterMassKg: weightKg * (waterPercent / 100.0),
      boneMassKg: boneMassKg,
      bmi: bmi,
      bmrKcal: math.max(0, bmr),
    );
  }

  /// Dépense énergétique totale journalière estimée (TDEE) = BMR × facteur
  /// d'activité. Base du futur module « Activité Physique » (V2).
  static double tdee(BodyComposition c, ActivityLevel level) =>
      c.bmrKcal * level.factor;
}
