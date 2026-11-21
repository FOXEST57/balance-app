/// Une trame décodée provenant de la balance.
///
/// Une même trame peut contenir :
///  - une mesure de poids « en direct » (non stabilisée) : [stabilized] = false ;
///  - une mesure verrouillée et stable : [stabilized] = true (déclenche
///    l'enregistrement automatique) ;
///  - une impédance (Ω) exploitée pour la BIA sur la trame finale.
class ScaleFrame {
  const ScaleFrame({
    required this.weightKg,
    required this.stabilized,
    required this.rawHex,
    this.impedanceOhm,
    this.isFinal = false,
    this.isUnloaded = false,
  });

  /// Poids brut en kilogrammes.
  final double weightKg;

  /// Vrai lorsque la balance a verrouillé la mesure (poids stable).
  final bool stabilized;

  /// Impédance mesurée en Ohms (null si non disponible sur cette trame).
  final int? impedanceOhm;

  /// Vrai pour la trame finale contenant l'impédance (fin de cycle BIA).
  final bool isFinal;

  /// Vrai lorsque la balance signale explicitement qu'elle est déchargée.
  final bool isUnloaded;

  /// Représentation hexadécimale de la trame brute, utile au diagnostic et
  /// à la calibration du parseur (affichée dans l'écran Pesée en direct).
  final String rawHex;

  ScaleFrame copyWith({
    double? weightKg,
    bool? stabilized,
    int? impedanceOhm,
    bool? isFinal,
    bool? isUnloaded,
  }) {
    return ScaleFrame(
      weightKg: weightKg ?? this.weightKg,
      stabilized: stabilized ?? this.stabilized,
      impedanceOhm: impedanceOhm ?? this.impedanceOhm,
      isFinal: isFinal ?? this.isFinal,
      isUnloaded: isUnloaded ?? this.isUnloaded,
      rawHex: rawHex,
    );
  }

  @override
  String toString() =>
      'ScaleFrame(weight=$weightKg kg, impedance=$impedanceOhm Ω, '
      'stabilized=$stabilized, final=$isFinal, raw=$rawHex)';
}

/// Convertit une liste d'octets en chaîne hexadécimale lisible
/// (ex. « CF 16 05 00 »).
String toHex(List<int> bytes) => bytes
    .map((int b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
