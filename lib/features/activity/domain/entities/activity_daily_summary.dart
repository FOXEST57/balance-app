import 'activity_entry.dart';
import 'activity_type.dart';

/// Agrégat d'activité pour une journée, calculé à partir des `ActivityEntry`.
class ActivityDailySummary {
  const ActivityDailySummary({
    required this.day,
    required this.steps,
    required this.kcal,
    required this.minutes,
    required this.entries,
  });

  final DateTime day;
  final int steps;
  final double kcal;
  final int minutes;
  final List<ActivityEntry> entries;

  /// Construit le résumé à partir des entrées d'une même journée.
  factory ActivityDailySummary.fromEntries(
    DateTime day,
    List<ActivityEntry> entries,
  ) {
    int steps = 0;
    double kcal = 0;
    int minutes = 0;
    for (final ActivityEntry e in entries) {
      // Les pas viennent uniquement des entrées de type `steps` pour éviter
      // le double comptage avec les séances manuelles.
      if (e.activityType == ActivityType.steps) {
        steps += e.steps ?? 0;
      }
      kcal += e.activeKcal ?? 0;
      if (e.activityType != ActivityType.steps) {
        minutes += e.sessionMinutes ?? 0;
      }
    }
    return ActivityDailySummary(
      day: day,
      steps: steps,
      kcal: kcal,
      minutes: minutes,
      entries: entries,
    );
  }

  /// Résumé vide (journée sans activité enregistrée).
  factory ActivityDailySummary.empty(DateTime day) => ActivityDailySummary(
        day: day,
        steps: 0,
        kcal: 0,
        minutes: 0,
        entries: const <ActivityEntry>[],
      );
}
