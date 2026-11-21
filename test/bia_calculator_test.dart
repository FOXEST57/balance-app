// Tests unitaires du moteur BIA (aucune dépendance plateforme : exécutable
// hors appareil, contrairement aux widgets qui requièrent BLE / sqflite).

import 'package:balance/features/weighing/domain/entities/user_profile.dart';
import 'package:balance/features/weighing/domain/services/bia_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const UserProfile homme = UserProfile(
    sex: Sex.male,
    age: 30,
    heightCm: 180,
    activityLevel: ActivityLevel.moderate,
    targetWeightKg: 75,
  );

  group('BiaCalculator.compute', () {
    test('IMC = poids / taille²', () {
      final c = BiaCalculator.compute(weightKg: 80, profile: homme);
      // 80 / (1.80²) = 24.69
      expect(c.bmi, closeTo(24.69, 0.05));
    });

    test('sans impédance ni % manuel, gras et muscle restent inconnus', () {
      final c = BiaCalculator.compute(weightKg: 80, profile: homme);
      expect(c.fatPercent, isNull);
      expect(c.fatMassKg, isNull);
      expect(c.musclePercent, isNull);
      expect(c.muscleMassKg, isNull);
      // Les autres grandeurs restent calculées.
      expect(c.waterPercent, inInclusiveRange(10, 75));
      expect(c.bmrKcal, greaterThan(0));
    });

    test('les masses en kg sont cohérentes avec les pourcentages', () {
      final c = BiaCalculator.compute(
        weightKg: 80,
        profile: homme,
        impedanceOhm: 500,
      );
      expect(c.fatMassKg, closeTo(80 * c.fatPercent! / 100, 1e-9));
      expect(c.waterMassKg, closeTo(80 * c.waterPercent / 100, 1e-9));
      // muscle + gras ne dépasse jamais le poids total
      expect(c.muscleMassKg! + c.fatMassKg!, lessThanOrEqualTo(80 + 1e-9));
    });

    test('un % de gras manuel est prioritaire sur les équations', () {
      const p = UserProfile(
        sex: Sex.female,
        age: 40,
        heightCm: 165,
        activityLevel: ActivityLevel.light,
        targetWeightKg: 60,
        manualFatPercent: 25,
      );
      final c = BiaCalculator.compute(weightKg: 60, profile: p);
      expect(c.fatPercent, 25);
      expect(c.fatMassKg, closeTo(15, 1e-9));
    });

    test('les pourcentages restent dans des bornes réalistes', () {
      final c = BiaCalculator.compute(
        weightKg: 80,
        profile: homme,
        impedanceOhm: 500,
      );
      expect(c.fatPercent, inInclusiveRange(2, 70));
      expect(c.waterPercent, inInclusiveRange(10, 75));
      expect(c.bmrKcal, greaterThan(0));
    });
  });
}
