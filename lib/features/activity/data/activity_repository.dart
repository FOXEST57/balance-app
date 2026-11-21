import 'package:sqflite/sqflite.dart';

import '../../weighing/data/app_database.dart';
import '../domain/entities/activity_entry.dart';
import '../domain/entities/activity_type.dart';
import '../domain/repositories/i_activity_repository.dart';

/// Persistance et lecture des entrées d'activité (implémentation SQLite).
class ActivityRepository implements IActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  Future<Database> get _database async => _db.database;

  // --- CRUD ----------------------------------------------------------------

  @override
  Future<ActivityEntry> insert(ActivityEntry entry) async {
    final Database db = await _database;
    final int id = await db.insert('activity_entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  @override
  Future<void> update(ActivityEntry entry) async {
    final int? id = entry.id;
    if (id == null) {
      throw ArgumentError.value(entry, 'entry', 'id requis');
    }
    final Database db = await _database;
    await db.update(
      'activity_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final Database db = await _database;
    await db.delete('activity_entries', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // --- Requêtes -------------------------------------------------------------

  /// Toutes les entrées d'une journée donnée (triées par date de création).
  @override
  Future<List<ActivityEntry>> forDay(DateTime day) async {
    final int dayStart = ActivityEntry.dayStartOf(day);
    final int dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'activity_entries',
      where: 'day >= ? AND day < ?',
      whereArgs: <Object?>[dayStart, dayEnd],
      orderBy: 'created_at ASC',
    );
    return rows.map(ActivityEntry.fromMap).toList();
  }

  /// Toutes les entrées entre [from] (inclus) et [to] (exclu).
  @override
  Future<List<ActivityEntry>> between(DateTime from, DateTime to) async {
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'activity_entries',
      where: 'day >= ? AND day < ?',
      whereArgs: <Object?>[
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
      orderBy: 'day ASC',
    );
    return rows.map(ActivityEntry.fromMap).toList();
  }

  /// Retourne l'entrée « pas » pour une journée donnée (ou null).
  ///
  /// Cette entrée accumule les pas de la journée et est mise à jour
  /// par le service de comptage.
  @override
  Future<ActivityEntry?> stepsEntryForDay(DateTime day) async {
    final int dayStart = ActivityEntry.dayStartOf(day);
    final Database db = await _database;
    final List<Map<String, Object?>> rows = await db.query(
      'activity_entries',
      where: 'day = ? AND activity_type = ?',
      whereArgs: <Object?>[dayStart, ActivityType.steps.name],
      limit: 1,
    );
    return rows.isEmpty ? null : ActivityEntry.fromMap(rows.first);
  }

  /// Met à jour (ou crée) l'entrée « pas » de la journée avec de nouvelles
  /// valeurs. Renvoie l'entrée complétée.
  @override
  Future<ActivityEntry> upsertStepsForDay({
    required DateTime day,
    required int steps,
    required double kcal,
    required int minutes,
  }) async {
    final ActivityEntry? existing = await stepsEntryForDay(day);
    final ActivityEntry entry = ActivityEntry(
      id: existing?.id,
      day: ActivityEntry.dayStartOf(day),
      steps: steps,
      activeKcal: kcal,
      sessionMinutes: minutes,
      activityType: ActivityType.steps,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (existing == null) {
      return insert(entry);
    }
    await update(entry);
    return entry;
  }
}
