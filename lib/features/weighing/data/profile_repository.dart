import 'package:sqflite/sqflite.dart';

import '../domain/entities/user_profile.dart';
import '../domain/repositories/i_profile_repository.dart';
import 'app_database.dart';

/// Persistance des profils utilisateur (implémentation SQLite).
class ProfileRepository implements IProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  /// Tous les profils, le profil actif en premier.
  @override
  Future<List<UserProfile>> all() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'profiles',
      orderBy: 'is_active DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(UserProfile.fromMap).toList();
  }

  /// Profil actuellement sélectionné (ou null si aucun profil).
  @override
  Future<UserProfile?> loadActive() async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'profiles',
      where: 'is_active = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) return UserProfile.fromMap(rows.first);
    final List<Map<String, Object?>> fallback = await db.query(
      'profiles',
      orderBy: 'id ASC',
      limit: 1,
    );
    return fallback.isEmpty ? null : UserProfile.fromMap(fallback.first);
  }

  /// Crée ou met à jour un profil et renvoie sa version persistée.
  @override
  Future<UserProfile> save(UserProfile profile) async {
    final Database db = await _db.database;
    final Map<String, Object?> values = profile.toMap()
      ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    final int? id = profile.id;
    if (id == null) {
      final int inserted = await db.insert('profiles', values);
      return profile.copyWith(id: inserted);
    }
    values.remove('id');
    await db.update(
      'profiles',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return profile;
  }

  /// Définit [id] comme profil actif et désactive les autres.
  @override
  Future<void> setActive(int id) async {
    final Database db = await _db.database;
    await db.transaction((Transaction txn) async {
      await txn.update('profiles', <String, Object?>{'is_active': 0});
      await txn.update(
        'profiles',
        <String, Object?>{'is_active': 1},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  /// Supprime un profil. Les pesées rattachées sont supprimées par la
  /// contrainte `ON DELETE CASCADE`.
  @override
  Future<void> delete(int id) async {
    final Database db = await _db.database;
    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        'profiles',
        columns: <String>['is_active'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      final bool wasActive =
          rows.isNotEmpty && ((rows.first['is_active'] as num?)?.toInt() ?? 0) == 1;

      await txn.delete('profiles', where: 'id = ?', whereArgs: <Object?>[id]);

      if (wasActive) {
        final List<Map<String, Object?>> remaining = await txn.query(
          'profiles',
          columns: <String>['id'],
          orderBy: 'id ASC',
          limit: 1,
        );
        if (remaining.isNotEmpty) {
          await txn.update(
            'profiles',
            <String, Object?>{'is_active': 1},
            where: 'id = ?',
            whereArgs: <Object?>[(remaining.first['id'] as num).toInt()],
          );
        }
      }
    });
  }
}
