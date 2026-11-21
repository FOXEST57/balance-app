import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/entities/body_composition.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/weight_measurement.dart';
import '../domain/services/bia_calculator.dart';

/// Accès à la base de données locale (SQLite via sqflite).
///
/// Tables :
///  - `profiles`       : profils BIA (plusieurs profils possibles, un seul
///    marqué actif) ;
///  - `measurements`   : historique des pesées + composition corporelle, chaque
///    ligne étant rattachée à un profil et pouvant porter un tour de taille ;
///  - `activity_entries` : **préparée pour la V2** (module Activité Physique
///    & Dépense journalière) — schéma déjà en place pour éviter une migration
///    lourde ultérieure.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'balance_cardio.db';
  static const int _dbVersion = 4;

  /// Nom du profil principal livré avec l'application.
  static const String primaryProfileName = 'Pascal';

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final String dir = await getDatabasesPath();
    final String path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createProfilesTable(db);
    await _createMeasurementsTable(db);
    await _createActivityTable(db);
    await _createSettingsTable(db);
    await _seedPrimaryProfile(db);
  }

  Future<void> _createProfilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        sex TEXT NOT NULL,
        age INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        activity_level INTEGER NOT NULL,
        target_weight_kg REAL NOT NULL,
        manual_fat_percent REAL,
        manual_muscle_percent REAL,
        manual_water_percent REAL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createMeasurementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER REFERENCES profiles(id) ON DELETE CASCADE,
        timestamp INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        impedance_ohm INTEGER,
        fat_percent REAL,
        fat_kg REAL,
        muscle_percent REAL,
        muscle_kg REAL,
        water_percent REAL NOT NULL,
        water_kg REAL NOT NULL,
        bone_kg REAL NOT NULL,
        bmi REAL NOT NULL,
        bmr_kcal REAL NOT NULL,
        waist_cm REAL,
        source TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_measurements_timestamp ON measurements(timestamp DESC)',
    );
  }

  Future<void> _createActivityTable(Database db) async {
    // Table créée dès maintenant (vide) pour préparer le module V2.
    await db.execute('''
      CREATE TABLE activity_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day INTEGER NOT NULL,
        steps INTEGER,
        active_kcal REAL,
        session_minutes INTEGER,
        activity_type TEXT,
        meets_goal INTEGER,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_activity_day ON activity_entries(day DESC)',
    );
  }

  /// Table clé/valeur des préférences (balance à reconnecter, options…).
  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Migrations
  // ---------------------------------------------------------------------------

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _migrateToProfiles(db);
    }
    if (oldVersion < 4) {
      await _migrateToOptionalFatMuscle(db);
    }
  }

  /// v3 -> v4 : la masse grasse et la masse musculaire deviennent facultatives
  /// (une pesée peut ne comporter que le poids et le tour de taille), et une
  /// table `settings` est ajoutée pour mémoriser la balance à reconnecter.
  Future<void> _migrateToOptionalFatMuscle(Database db) async {
    const List<String> copyable = <String>[
      'id',
      'profile_id',
      'timestamp',
      'weight_kg',
      'impedance_ohm',
      'fat_percent',
      'fat_kg',
      'muscle_percent',
      'muscle_kg',
      'water_percent',
      'water_kg',
      'bone_kg',
      'bmi',
      'bmr_kcal',
      'waist_cm',
      'source',
      'note',
    ];

    // SQLite ne permet pas de retirer une contrainte NOT NULL : on recrée la
    // table. Les colonnes copiées sont détectées dynamiquement pour rester
    // compatible avec les schémas antérieurs (v1/v2).
    final List<Map<String, Object?>> info = await db.rawQuery(
      'PRAGMA table_info(measurements)',
    );
    final Set<String> existing = info
        .map((Map<String, Object?> row) => row['name']! as String)
        .toSet();
    final List<String> columns = copyable
        .where(existing.contains)
        .toList(growable: false);
    final String columnList = columns.join(', ');

    await db.execute('DROP TABLE IF EXISTS measurements_v4');
    await db.execute('''
      CREATE TABLE measurements_v4 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER REFERENCES profiles(id) ON DELETE CASCADE,
        timestamp INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        impedance_ohm INTEGER,
        fat_percent REAL,
        fat_kg REAL,
        muscle_percent REAL,
        muscle_kg REAL,
        water_percent REAL NOT NULL,
        water_kg REAL NOT NULL,
        bone_kg REAL NOT NULL,
        bmi REAL NOT NULL,
        bmr_kcal REAL NOT NULL,
        waist_cm REAL,
        source TEXT NOT NULL,
        note TEXT
      )
    ''');
    if (columns.isNotEmpty) {
      await db.execute(
        'INSERT INTO measurements_v4 ($columnList) SELECT $columnList FROM measurements',
      );
    }
    await db.execute('DROP TABLE measurements');
    await db.execute('ALTER TABLE measurements_v4 RENAME TO measurements');
    await db.execute(
      'CREATE INDEX idx_measurements_timestamp ON measurements(timestamp DESC)',
    );
    await _createSettingsTable(db);

    // Les deux dernières pesées importées n'ont ni masse grasse ni masse
    // musculaire : on efface les valeurs estimées par défaut.
    await db.update(
      'measurements',
      <String, Object?>{
        'fat_percent': null,
        'fat_kg': null,
        'muscle_percent': null,
        'muscle_kg': null,
      },
      where: 'timestamp IN (?, ?)',
      whereArgs: <Object?>[
        DateTime(2026, 11, 13, 8).millisecondsSinceEpoch,
        DateTime(2026, 11, 20, 8).millisecondsSinceEpoch,
      ],
    );
  }

  /// v2 -> v3 : introduction du multi-profils, du tour de taille, suppression des
  /// pesées BLE produites par l'ancien décodage erroné, et import de
  /// l'historique du profil Pascal.
  Future<void> _migrateToProfiles(Database db) async {
    await _createProfilesTable(db);

    // Reprise de l'ancien profil unique (table `user_profile`).
    Map<String, Object?>? legacy;
    try {
      final List<Map<String, Object?>> rows = await db.query(
        'user_profile',
        where: 'id = 1',
        limit: 1,
      );
      legacy = rows.isEmpty ? null : rows.first;
    } on DatabaseException {
      legacy = null;
    }

    final int profileId = await _insertPrimaryProfile(db, legacy: legacy);

    await db.execute('DROP TABLE IF EXISTS user_profile');

    await db.execute('ALTER TABLE measurements ADD COLUMN profile_id INTEGER');
    await db.execute('ALTER TABLE measurements ADD COLUMN waist_cm REAL');
    await db.update('measurements', <String, Object?>{
      'profile_id': profileId,
    });

    // Les pesées BLE enregistrées provenaient du décodage erroné de l'AC27.
    await db.delete(
      'measurements',
      where: 'source = ?',
      whereArgs: <Object?>[MeasurementSource.ble.name],
    );

    await _insertPrimaryMeasurements(db, profileId);
  }

  // ---------------------------------------------------------------------------
  // Données du profil principal
  // ---------------------------------------------------------------------------

  /// Insère le profil principal et renvoie son identifiant.
  Future<int> _insertPrimaryProfile(
    Database db, {
    Map<String, Object?>? legacy,
  }) async {
    final UserProfile source = legacy == null
        ? const UserProfile(
            name: primaryProfileName,
            isActive: true,
            sex: Sex.male,
            age: 56,
            heightCm: 188,
            activityLevel: ActivityLevel.moderate,
            targetWeightKg: 161.1,
          )
        : UserProfile.fromMap(<String, Object?>{
            ...legacy,
            'age': 56,
            'height_cm': 188.0,
          });

    final int id = await db.insert('profiles', <String, Object?>{
      ...source.toMap(),
      'name': primaryProfileName,
      'is_active': 1,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> _seedPrimaryProfile(Database db) async {
    final int id = await _insertPrimaryProfile(db);
    await _insertPrimaryMeasurements(db, id);
  }

  /// Historique transmis par l'utilisateur. Les pesées sans masse grasse ni
  /// masse musculaire sont estimées par les équations BIA du profil.
  static final List<_SeedMeasurement> _seedMeasurements = <_SeedMeasurement>[
    _SeedMeasurement(
      date: DateTime(2025, 11, 12, 8),
      weightKg: 176.6,
      waistCm: 157,
      fatMassKg: 65.4,
      muscleMassKg: 30.33,
    ),
    _SeedMeasurement(
      date: DateTime(2025, 12, 12, 8),
      weightKg: 165.5,
      waistCm: 146,
      fatMassKg: 66.8,
      muscleMassKg: 29.2,
    ),
    _SeedMeasurement(
      date: DateTime(2026, 9, 28, 8),
      weightKg: 174.6,
      waistCm: 154,
      fatMassKg: 63.62,
      muscleMassKg: 30.17,
    ),
    _SeedMeasurement(
      date: DateTime(2026, 10, 30, 8),
      weightKg: 162.2,
      waistCm: 146,
      fatMassKg: 58.8,
      muscleMassKg: 28.5,
    ),
    _SeedMeasurement(date: DateTime(2026, 11, 13, 8), weightKg: 162.3, waistCm: 144),
    _SeedMeasurement(date: DateTime(2026, 11, 20, 8), weightKg: 161.1, waistCm: 144),
  ];

  Future<void> _insertPrimaryMeasurements(Database db, int profileId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: <Object?>[profileId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final UserProfile profile = UserProfile.fromMap(rows.first);

    for (final _SeedMeasurement seed in _seedMeasurements) {
      final WeightMeasurement measurement = WeightMeasurement(
        profileId: profileId,
        timestamp: seed.date,
        waistCm: seed.waistCm,
        source: MeasurementSource.manual,
        composition: _seedComposition(
          weightKg: seed.weightKg,
          profile: profile,
          fatMassKg: seed.fatMassKg,
          muscleMassKg: seed.muscleMassKg,
        ),
      );
      await db.insert('measurements', measurement.toMap());
    }
  }

  /// Compose une composition corporelle : les masses fournies par l'utilisateur
  /// sont conservées telles quelles, les valeurs absentes (eau, os, IMC,
  /// métabolisme) proviennent des équations documentées de [BiaCalculator].
  ///
  /// Lorsque la masse grasse **et** la masse musculaire sont absentes, aucune
  /// estimation n'est produite : ces deux grandeurs restent `null` plutôt que
  /// d'afficher des valeurs incohérentes avec les autres pesées.
  static BodyComposition _seedComposition({
    required double weightKg,
    required UserProfile profile,
    double? fatMassKg,
    double? muscleMassKg,
  }) {
    final BodyComposition auto = BiaCalculator.compute(
      weightKg: weightKg,
      profile: profile,
    );
    if (fatMassKg == null || muscleMassKg == null) {
      return BodyComposition(
        weightKg: weightKg,
        impedanceOhm: null,
        fatPercent: null,
        fatMassKg: null,
        musclePercent: null,
        muscleMassKg: null,
        waterPercent: auto.waterPercent,
        waterMassKg: auto.waterMassKg,
        boneMassKg: auto.boneMassKg,
        bmi: auto.bmi,
        bmrKcal: auto.bmrKcal,
      );
    }

    final double fatMass = fatMassKg;
    final double leanMass = math.max(0, weightKg - fatMass);
    final double muscleMass = muscleMassKg.clamp(0, leanMass).toDouble();

    return BodyComposition(
      weightKg: weightKg,
      impedanceOhm: null,
      fatPercent: weightKg > 0 ? fatMass / weightKg * 100 : 0,
      fatMassKg: fatMass,
      musclePercent: weightKg > 0 ? muscleMass / weightKg * 100 : 0,
      muscleMassKg: muscleMass,
      waterPercent: auto.waterPercent,
      waterMassKg: auto.waterMassKg,
      boneMassKg: auto.boneMassKg,
      bmi: auto.bmi,
      // Katch-McArdle : masse grasse connue.
      bmrKcal: 370 + 21.6 * leanMass,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// Description d'une pesée importée manuellement.
class _SeedMeasurement {
  const _SeedMeasurement({
    required this.date,
    required this.weightKg,
    required this.waistCm,
    this.fatMassKg,
    this.muscleMassKg,
  });

  final DateTime date;
  final double weightKg;
  final double waistCm;
  final double? fatMassKg;
  final double? muscleMassKg;
}
