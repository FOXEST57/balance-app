import 'package:sqflite/sqflite.dart';

import '../domain/repositories/i_settings_repository.dart';
import 'app_database.dart';

/// Clé : identifiant BLE de la dernière balance utilisée (reconnexion auto).
const String kLastScaleIdKey = 'last_scale_id';

/// Clé : nom de la dernière balance utilisée (affichage).
const String kLastScaleNameKey = 'last_scale_name';

/// Clé : la reconnexion automatique est-elle activée ?
const String kAutoConnectEnabledKey = 'auto_connect_enabled';

/// Clé : le rappel de pesée quotidien est-il activé ?
const String kReminderEnabledKey = 'reminder_enabled';

/// Clé : heure du rappel de pesée (format "HH:MM").
const String kReminderTimeKey = 'reminder_time';

/// Clé : jour de la semaine du rappel (1=lundi … 7=dimanche).
const String kReminderDayOfWeekKey = 'reminder_day_of_week';

/// Clé : fréquence du rappel ("weekly" | "biweekly" | "monthly").
const String kReminderRepeatKey = 'reminder_repeat';

/// Petit magasin clé/valeur persistant (implémentation SQLite, table `settings`).
class SettingsRepository implements ISettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    final Database db = await _db.database;
    await db.insert('settings', <String, Object?>{'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
