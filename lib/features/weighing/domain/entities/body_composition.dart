/// Résultat d'une analyse corporelle (BIA).
///
/// Toutes les masses sont exprimées en **kilogrammes** avec une précision
/// de 2 décimales à l'affichage. Les pourcentages sont conservés afin de
/// pouvoir afficher les deux valeurs côte à côte (ex. « 18.50 % • 13.87 kg »).
class BodyComposition {
  const BodyComposition({
    required this.weightKg,
    required this.fatPercent,
    required this.fatMassKg,
    required this.musclePercent,
    required this.muscleMassKg,
    required this.waterPercent,
    required this.waterMassKg,
    required this.boneMassKg,
    required this.bmi,
    required this.bmrKcal,
    this.impedanceOhm,
  });

  final double weightKg;

  /// Masse grasse : `null` lorsque la pesée ne comporte ni pourcentage manuel
  /// ni impédance exploitable. Aucune valeur n'est alors inventée.
  final double? fatPercent;
  final double? fatMassKg;

  /// Masse musculaire : `null` dans les mêmes conditions que [fatPercent].
  final double? musclePercent;
  final double? muscleMassKg;

  final double waterPercent;
  final double waterMassKg;

  /// Masse osseuse : donnée directement en kg (pas de conversion %).
  final double boneMassKg;

  final double bmi;

  /// Métabolisme de base en kcal/jour.
  final double bmrKcal;

  final int? impedanceOhm;

  /// Masse maigre = poids − masse grasse (égale au poids si inconnue).
  double get leanMassKg => weightKg - (fatMassKg ?? 0);
}
