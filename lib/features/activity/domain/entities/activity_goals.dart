/// Objectifs quotidiens d'activité.
class ActivityGoals {
  const ActivityGoals({
    this.steps = 10000,
    this.kcal = 300,
    this.minutes = 30,
  });

  /// Objectif de pas par jour (défaut 10 000).
  final int steps;

  /// Objectif de calories actives par jour (kcal, défaut 300).
  final int kcal;

  /// Objectif de minutes d'activité par jour (défaut 30).
  final int minutes;

  ActivityGoals copyWith({
    int? steps,
    int? kcal,
    int? minutes,
  }) {
    return ActivityGoals(
      steps: steps ?? this.steps,
      kcal: kcal ?? this.kcal,
      minutes: minutes ?? this.minutes,
    );
  }

  /// Sérialisation pour la table `settings` (clé/valeur).
  String serialize() => '$steps;$kcal;$minutes';

  static ActivityGoals deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return const ActivityGoals();
    final List<String> parts = raw.split(';');
    if (parts.length < 3) return const ActivityGoals();
    return ActivityGoals(
      steps: int.tryParse(parts[0]) ?? 10000,
      kcal: int.tryParse(parts[1]) ?? 300,
      minutes: int.tryParse(parts[2]) ?? 30,
    );
  }
}
