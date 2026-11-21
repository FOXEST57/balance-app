import 'activity_type.dart';

/// Une entrée d'activité (une séance ou l'agrégat de pas d'une journée).
///
/// Correspond à une ligne de la table `activity_entries`.
class ActivityEntry {
  const ActivityEntry({
    this.id,
    required this.day,
    this.steps,
    this.activeKcal,
    this.sessionMinutes,
    this.activityType,
    this.meetsGoal,
    this.note,
    required this.createdAt,
  });

  final int? id;

  /// Début de la journée (minuit local) en millisecondes depuis l'époque.
  final int day;

  /// Nombre de pas (pour les séances de marche/course ou l'agrégat journalier).
  final int? steps;

  /// Calories actives dépensées (kcal).
  final double? activeKcal;

  /// Durée de la séance en minutes.
  final int? sessionMinutes;

  /// Type d'activité.
  final ActivityType? activityType;

  /// 1 si cette journée a atteint l'objectif d'activité.
  final int? meetsGoal;

  final String? note;

  final int createdAt;

  ActivityEntry copyWith({
    int? id,
    int? day,
    int? steps,
    double? activeKcal,
    int? sessionMinutes,
    ActivityType? activityType,
    int? meetsGoal,
    String? note,
    int? createdAt,
  }) {
    return ActivityEntry(
      id: id ?? this.id,
      day: day ?? this.day,
      steps: steps ?? this.steps,
      activeKcal: activeKcal ?? this.activeKcal,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      activityType: activityType ?? this.activityType,
      meetsGoal: meetsGoal ?? this.meetsGoal,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    final Map<String, Object?> map = <String, Object?>{
      'day': day,
      'steps': steps,
      'active_kcal': activeKcal,
      'session_minutes': sessionMinutes,
      'activity_type': activityType?.name,
      'meets_goal': meetsGoal,
      'note': note,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  static ActivityEntry fromMap(Map<String, Object?> map) {
    return ActivityEntry(
      id: (map['id'] as num?)?.toInt(),
      day: (map['day'] as num).toInt(),
      steps: (map['steps'] as num?)?.toInt(),
      activeKcal: (map['active_kcal'] as num?)?.toDouble(),
      sessionMinutes: (map['session_minutes'] as num?)?.toInt(),
      activityType: ActivityType.fromName(map['activity_type'] as String?),
      meetsGoal: (map['meets_goal'] as num?)?.toInt(),
      note: map['note'] as String?,
      createdAt: (map['created_at'] as num).toInt(),
    );
  }

  /// Millisecondes depuis l'époque correspondant au minuit local de [date].
  static int dayStartOf(DateTime date) {
    final DateTime midnight = DateTime(date.year, date.month, date.day);
    return midnight.millisecondsSinceEpoch;
  }
}
