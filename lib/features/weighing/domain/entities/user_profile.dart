/// Sexe biologique — facteur indispensable aux équations BIA.
enum Sex {
  male,
  female;

  String get label => this == Sex.male ? 'Homme' : 'Femme';

  /// Valeur numérique utilisée dans les équations (Homme = 1, Femme = 0).
  int get factor => this == Sex.male ? 1 : 0;

  static Sex fromName(String? name) =>
      name == Sex.female.name ? Sex.female : Sex.male;
}

/// Niveau d'activité — sert au calcul de la dépense énergétique totale (TDEE)
/// et préparera le module « Activité Physique » de la V2.
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sédentaire';
      case ActivityLevel.light:
        return 'Légère';
      case ActivityLevel.moderate:
        return 'Modérée';
      case ActivityLevel.active:
        return 'Active';
      case ActivityLevel.veryActive:
        return 'Très active';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Peu ou pas d\'exercice';
      case ActivityLevel.light:
        return '1 à 3 séances / semaine';
      case ActivityLevel.moderate:
        return '3 à 5 séances / semaine';
      case ActivityLevel.active:
        return '6 à 7 séances / semaine';
      case ActivityLevel.veryActive:
        return 'Athlète / travail physique';
    }
  }

  /// Facteur multiplicateur appliqué au métabolisme de base (BMR -> TDEE).
  double get factor {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  static ActivityLevel fromIndex(int? index) {
    if (index == null || index < 0 || index >= ActivityLevel.values.length) {
      return ActivityLevel.moderate;
    }
    return ActivityLevel.values[index];
  }
}

/// Profil utilisateur, indispensable aux calculs d'impédancemétrie (BIA).
///
/// Les pourcentages manuels (facultatifs) permettent d'ajuster/forcer les
/// valeurs lorsqu'un utilisateur dispose de mesures de référence.
class UserProfile {
  const UserProfile({
    this.id,
    this.name = 'Mon profil',
    this.isActive = false,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.activityLevel,
    required this.targetWeightKg,
    this.manualFatPercent,
    this.manualMusclePercent,
    this.manualWaterPercent,
  });

  /// Identifiant en base (null tant que la ligne n'est pas insérée).
  final int? id;

  /// Nom du profil, affiché dans le sélecteur de profils.
  final String name;

  /// Vrai pour le profil actuellement sélectionné dans l'application.
  final bool isActive;

  final Sex sex;
  final int age;
  final double heightCm;
  final ActivityLevel activityLevel;

  /// Objectif de poids (accompagnement à la perte de poids).
  final double targetWeightKg;

  /// Pourcentages saisis manuellement (prioritaires s'ils sont renseignés).
  final double? manualFatPercent;
  final double? manualMusclePercent;
  final double? manualWaterPercent;

  bool get isComplete => age > 0 && heightCm > 0 && targetWeightKg > 0;

  double get heightM => heightCm / 100.0;

  UserProfile copyWith({
    int? id,
    String? name,
    bool? isActive,
    Sex? sex,
    int? age,
    double? heightCm,
    ActivityLevel? activityLevel,
    double? targetWeightKg,
    double? manualFatPercent,
    double? manualMusclePercent,
    double? manualWaterPercent,
    bool clearManual = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      manualFatPercent: clearManual ? null : (manualFatPercent ?? this.manualFatPercent),
      manualMusclePercent:
          clearManual ? null : (manualMusclePercent ?? this.manualMusclePercent),
      manualWaterPercent:
          clearManual ? null : (manualWaterPercent ?? this.manualWaterPercent),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'name': name,
        'is_active': isActive ? 1 : 0,
        'sex': sex.name,
        'age': age,
        'height_cm': heightCm,
        'activity_level': activityLevel.index,
        'target_weight_kg': targetWeightKg,
        'manual_fat_percent': manualFatPercent,
        'manual_muscle_percent': manualMusclePercent,
        'manual_water_percent': manualWaterPercent,
      };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        id: (map['id'] as num?)?.toInt(),
        name: (map['name'] as String?) ?? 'Mon profil',
        isActive: ((map['is_active'] as num?)?.toInt() ?? 0) == 1,
        sex: Sex.fromName(map['sex'] as String?),
        age: (map['age'] as num?)?.toInt() ?? 30,
        heightCm: (map['height_cm'] as num?)?.toDouble() ?? 175,
        activityLevel: ActivityLevel.fromIndex((map['activity_level'] as num?)?.toInt()),
        targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble() ?? 70,
        manualFatPercent: (map['manual_fat_percent'] as num?)?.toDouble(),
        manualMusclePercent: (map['manual_muscle_percent'] as num?)?.toDouble(),
        manualWaterPercent: (map['manual_water_percent'] as num?)?.toDouble(),
      );

  /// Profil par défaut proposé au premier lancement.
  static const UserProfile defaults = UserProfile(
    sex: Sex.male,
    age: 30,
    heightCm: 175,
    activityLevel: ActivityLevel.moderate,
    targetWeightKg: 70,
  );
}
