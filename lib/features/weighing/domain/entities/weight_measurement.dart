import 'body_composition.dart';

/// Origine d'une mesure enregistrée.
enum MeasurementSource {
  /// Mesure reçue en direct depuis la balance Bluetooth.
  ble,

  /// Mesure générée par le mode Simulation (tests sans monter sur la balance).
  simulation,

  /// Mesure saisie manuellement par l'utilisateur.
  manual;

  String get label {
    switch (this) {
      case MeasurementSource.ble:
        return 'Balance BLE';
      case MeasurementSource.simulation:
        return 'Simulation';
      case MeasurementSource.manual:
        return 'Saisie manuelle';
    }
  }

  static MeasurementSource fromName(String? name) {
    return MeasurementSource.values.firstWhere(
      (MeasurementSource s) => s.name == name,
      orElse: () => MeasurementSource.manual,
    );
  }
}

/// Une pesée complète enregistrée dans l'historique.
class WeightMeasurement {
  const WeightMeasurement({
    this.id,
    this.profileId,
    required this.timestamp,
    required this.composition,
    required this.source,
    this.waistCm,
    this.note,
  });

  /// Identifiant en base (null tant que la ligne n'est pas insérée).
  final int? id;

  /// Profil auquel appartient la pesée.
  final int? profileId;
  final DateTime timestamp;

  /// Toute la composition corporelle (poids + impédance + dérivés).
  final BodyComposition composition;

  final MeasurementSource source;

  /// Tour de taille mesuré au mètre ruban (cm), facultatif.
  final double? waistCm;

  final String? note;

  double get weightKg => composition.weightKg;

  int? get impedanceOhm => composition.impedanceOhm;

  WeightMeasurement copyWith({
    int? id,
    int? profileId,
    BodyComposition? composition,
    double? waistCm,
  }) => WeightMeasurement(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    timestamp: timestamp,
    composition: composition ?? this.composition,
    source: source,
    waistCm: waistCm ?? this.waistCm,
    note: note,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'profile_id': profileId,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'weight_kg': weightKg,
    'impedance_ohm': impedanceOhm,
    'fat_percent': composition.fatPercent,
    'fat_kg': composition.fatMassKg,
    'muscle_percent': composition.musclePercent,
    'muscle_kg': composition.muscleMassKg,
    'water_percent': composition.waterPercent,
    'water_kg': composition.waterMassKg,
    'bone_kg': composition.boneMassKg,
    'bmi': composition.bmi,
    'bmr_kcal': composition.bmrKcal,
    'waist_cm': waistCm,
    'source': source.name,
    'note': note,
  };

  factory WeightMeasurement.fromMap(Map<String, Object?> map) {
    return WeightMeasurement(
      id: (map['id'] as num?)?.toInt(),
      profileId: (map['profile_id'] as num?)?.toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
      ),
      composition: BodyComposition(
        weightKg: (map['weight_kg'] as num).toDouble(),
        impedanceOhm: (map['impedance_ohm'] as num?)?.toInt(),
        fatPercent: (map['fat_percent'] as num?)?.toDouble(),
        fatMassKg: (map['fat_kg'] as num?)?.toDouble(),
        musclePercent: (map['muscle_percent'] as num?)?.toDouble(),
        muscleMassKg: (map['muscle_kg'] as num?)?.toDouble(),
        waterPercent: (map['water_percent'] as num).toDouble(),
        waterMassKg: (map['water_kg'] as num).toDouble(),
        boneMassKg: (map['bone_kg'] as num).toDouble(),
        bmi: (map['bmi'] as num).toDouble(),
        bmrKcal: (map['bmr_kcal'] as num).toDouble(),
      ),
      waistCm: (map['waist_cm'] as num?)?.toDouble(),
      source: MeasurementSource.fromName(map['source'] as String?),
      note: map['note'] as String?,
    );
  }
}
