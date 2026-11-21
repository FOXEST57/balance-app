import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/entities/user_profile.dart';
import '../domain/entities/weight_measurement.dart';

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

  /// Nom du profil par défaut (l'utilisateur le renommera).
  static const String primaryProfileName = 'Mon profil';

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
    // Aucun profil ni mesure seedée : l'application démarre vierge.
    // Le profil par défaut est créé par ProfilesNotifier au premier lancement.
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
  }

  /// v2 -> v3 : introduction du multi-profils, du tour de taille, et suppression
  /// des pesées BLE produites par l'ancien décodage erroné.
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
  }

  // ---------------------------------------------------------------------------
  // Données du profil principal
  // ---------------------------------------------------------------------------

  /// Insère un profil générique vierge et renvoie son identifiant.
  /// Utilisé uniquement par les migrations pour les utilisateurs existants.
  Future<int> _insertPrimaryProfile(
    Database db, {
    Map<String, Object?>? legacy,
  }) async {
    final UserProfile source = legacy == null
        ? const UserProfile(
            name: primaryProfileName,
            isActive: true,
            sex: Sex.male,
            age: 30,
            heightCm: 175,
            activityLevel: ActivityLevel.moderate,
            targetWeightKg: 70,
          )
        : UserProfile.fromMap(<String, Object?>{
            ...legacy,
            'name': primaryProfileName,
          });

    final int id = await db.insert('profiles', <String, Object?>{
      ...source.toMap(),
      'name': primaryProfileName,
      'is_active': 1,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
