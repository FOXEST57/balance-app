import 'package:flutter/material.dart';

/// Types d'activité physique supportés, avec leur valeur MET
/// (Metabolic Equivalent of Task) utilisée pour estimer les calories dépensées.
///
/// Calories = MET × poids(kg) × durée(heures).
enum ActivityType {
  walking('Marche', Icons.directions_walk_rounded, 3.5),
  running('Course', Icons.directions_run_rounded, 8.0),
  cycling('Vélo', Icons.pedal_bike_rounded, 7.5),
  swimming('Natation', Icons.pool_rounded, 8.0),
  strengthTraining('Musculation', Icons.fitness_center_rounded, 5.0),
  yoga('Yoga', Icons.self_improvement_rounded, 3.0),
  hiking('Randonnée', Icons.terrain_rounded, 6.0),
  dancing('Danse', Icons.music_note_rounded, 5.0),
  steps('Pas (auto)', Icons.directions_walk_rounded, 3.5);

  const ActivityType(this.label, this.icon, this.met);

  final String label;
  final IconData icon;

  /// Valeur MET (kcal/kg/heure).
  final double met;

  static ActivityType fromName(String? name) {
    return ActivityType.values.firstWhere(
      (ActivityType t) => t.name == name,
      orElse: () => ActivityType.walking,
    );
  }
}
