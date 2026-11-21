import '../entities/activity_type.dart';

/// Calcul des calories dépensées à partir du poids, de la durée et du MET.
class CalorieCalculator {
  CalorieCalculator._();

  /// Calories = MET × poids(kg) × durée(heures).
  static double fromDuration({
    required ActivityType type,
    required double weightKg,
    required int minutes,
  }) {
    if (minutes <= 0 || weightKg <= 0) return 0;
    return type.met * weightKg * (minutes / 60.0);
  }

  /// Estimation des calories depuis un nombre de pas.
  ///
  /// Hypothèse : ~0.04 kcal par pas pour un adulte moyen, ajustée au poids.
  /// 1 pas ≈ 0.0005 × poids(kg) kcal (base 70 kg → 0.035 kcal/pas).
  static double fromSteps({required int steps, required double weightKg}) {
    if (steps <= 0 || weightKg <= 0) return 0;
    return steps * 0.0005 * weightKg;
  }

  /// Minutes d'activité estimées depuis un nombre de pas.
  ///
  /// Hypothèse : ~100 pas/minute en marche normale.
  static int minutesFromSteps(int steps) {
    if (steps <= 0) return 0;
    return (steps / 100.0).round();
  }
}
