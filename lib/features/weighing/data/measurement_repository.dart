import 'package:sqflite/sqflite.dart';

import '../domain/entities/weight_measurement.dart';
import 'app_database.dart';

/// Persistance et lecture de l'historique des pesées.
class MeasurementRepository {
  MeasurementRepository(this._db);

  final AppDatabase _db;

  /// Insère une mesure et renvoie l'entité complétée avec son identifiant.
  Future<WeightMeasurement> insert(WeightMeasurement measurement) async {
    final Database db = await _db.database;
    final int id = await db.insert('measurements', measurement.toMap());
    return measurement.copyWith(id: id);
  }

  /// Remplace une mesure existante, notamment pour y ajouter l'impédance reçue
  /// après le verrouillage du poids par la balance.
  Future<WeightMeasurement> update(WeightMeasurement measurement) async {
    final int? id = measurement.id;
    if (id == null) {
      throw ArgumentError.value(measurement, 'measurement', 'id requis');
    }
    final Database db = await _db.database;
    await db.update(
      'measurements',
      measurement.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return measurement;
  }

  /// Renvoie les mesures, de la plus récente à la plus ancienne.
  ///
  /// Si [profileId] est fourni, seules les pesées de ce profil sont renvoyées.
  Future<List<WeightMeasurement>> all({int? limit, int? profileId}) async {
    final Database db = await _db.database;
    final List<Map<String, Object?>> rows = await db.query(
      'measurements',
      where: profileId == null ? null : 'profile_id = ?',
      whereArgs: profileId == null ? null : <Object?>[profileId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(WeightMeasurement.fromMap).toList();
  }

  /// Dernière mesure enregistrée (ou null).
  Future<WeightMeasurement?> latest({int? profileId}) async {
    final List<WeightMeasurement> list = await all(
      limit: 1,
      profileId: profileId,
    );
    return list.isEmpty ? null : list.first;
  }

  /// Mesures comprises entre [from] et [to], triées chronologiquement.
  Future<List<WeightMeasurement>> range(
    DateTime from,
    DateTime to, {
    int? profileId,
  }) async {
    final Database db = await _db.database;
    final String where = profileId == null
        ? 'timestamp >= ? AND timestamp <= ?'
        : 'timestamp >= ? AND timestamp <= ? AND profile_id = ?';
    final List<Object?> args = <Object?>[
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
      ?profileId,
    ];
    final List<Map<String, Object?>> rows = await db.query(
      'measurements',
      where: where,
      whereArgs: args,
      orderBy: 'timestamp ASC',
    );
    return rows.map(WeightMeasurement.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final Database db = await _db.database;
    await db.delete('measurements', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Supprime toutes les mesures, ou uniquement celles d'un profil.
  Future<void> deleteAll({int? profileId}) async {
    final Database db = await _db.database;
    await db.delete(
      'measurements',
      where: profileId == null ? null : 'profile_id = ?',
      whereArgs: profileId == null ? null : <Object?>[profileId],
    );
  }
}
