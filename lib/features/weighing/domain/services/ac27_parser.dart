import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';

/// Parseur des trames Fitdays AC 27 observées sur le service vendeur FFB0.
///
/// Les trames font 20 octets : `AC 27 [payload 16 octets] [type] [checksum]`.
/// Le checksum vérifie les 5 bits de poids faible de la somme des octets 2 à 18.
class Ac27Parser {
  static const int frameLength = 20;
  static const int typeBalance = 0xd0;
  static const int typeWeight = 0xd5;
  static const int typeResult = 0xd6;
  static const int lockedMask = 0x80;

  /// Seuils en unités brutes : 1 unité = 1 gramme (trames réelles de la
  /// Little Balance 8661 : `0x648C` = 25740 → 25,74 kg).
  static const int minWeightRaw = 2000;
  static const int maxWeightRaw = 250000;
  static const double weightRawUnitsPerKg = 1000.0;
  static const int plateauFrames = 5;
  static const Duration plateauDuration = Duration(seconds: 1);

  int? _plateauRawWeight;
  int _plateauCount = 0;
  DateTime? _plateauStartedAt;
  double? _lastLockedWeightKg;

  /// True uniquement pour une trame AC27 complète dont le checksum est valide.
  bool isValidFrame(List<int> data) {
    if (data.length != frameLength || data[0] != 0xac || data[1] != 0x27) {
      return false;
    }
    var sum = 0;
    for (var i = 2; i <= 18; i++) {
      sum += data[i];
    }
    return (sum & 0x1f) == (data[19] & 0x1f);
  }

  bool isResultFrame(List<int> data) =>
      isValidFrame(data) && data[18] == typeResult;

  /// Décode le poids D5 et le résultat d'impédance D6.
  ///
  /// Les messages D0 ne représentent que la charge du pied gauche : ils sont
  /// validés mais volontairement ignorés pour ne pas les confondre avec le poids
  /// total. Les poids non verrouillés sont marqués stables après un plateau
  /// répété afin de couvrir les balances qui n'envoient pas le bit de verrouillage.
  ScaleFrame? parse(List<int> data, {DateTime? receivedAt}) {
    if (!isValidFrame(data)) return null;

    switch (data[18]) {
      case typeBalance:
        return null;
      case typeWeight:
        return _parseWeight(data, receivedAt ?? DateTime.now());
      case typeResult:
        return _parseResult(data);
      default:
        return null;
    }
  }

  /// Construit les écritures Fitdays à envoyer après l'abonnement à FFB2.
  ///
  /// Le profil est envoyé en kg, puis le marqueur DF01, puis le profil à nouveau.
  List<List<int>> buildHandshake(UserProfile profile, {DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<int> profileFrame = _buildProfileFrame(profile, timestamp);
    final List<int> marker = <int>[
      0xac,
      0x27,
      0x01,
      ...List<int>.filled(15, 0),
      0xdf,
      0xe0,
    ];
    return <List<int>>[profileFrame, marker, List<int>.from(profileFrame)];
  }

  List<int> buildResultAcknowledgement() => <int>[
    0xac,
    0x27,
    0x04,
    0xd6,
    ...List<int>.filled(14, 0),
    0xdf,
    0xb9,
  ];

  void resetSession() {
    _plateauRawWeight = null;
    _plateauCount = 0;
    _plateauStartedAt = null;
    _lastLockedWeightKg = null;
  }

  ScaleFrame? _parseWeight(List<int> data, DateTime receivedAt) {
    final int rawWeight =
        ((data[3] << 16) | (data[4] << 8) | data[5]) & 0x3ffff;
    if (rawWeight == 0) {
      resetSession();
      return ScaleFrame(
        weightKg: 0,
        stabilized: false,
        isUnloaded: true,
        rawHex: toHex(data),
      );
    }
    if (rawWeight < minWeightRaw || rawWeight > maxWeightRaw) {
      _plateauRawWeight = null;
      _plateauCount = 0;
      _plateauStartedAt = null;
      return null;
    }

    final double weightKg =
        ((rawWeight / weightRawUnitsPerKg) * 100).truncateToDouble() / 100;
    final bool locked = (data[2] & lockedMask) != 0;
    if (rawWeight == _plateauRawWeight) {
      _plateauCount++;
    } else {
      _plateauRawWeight = rawWeight;
      _plateauCount = 1;
      _plateauStartedAt = receivedAt;
    }

    final DateTime? plateauStart = _plateauStartedAt;
    final bool repeatedPlateau =
        _plateauCount >= plateauFrames &&
        plateauStart != null &&
        receivedAt.difference(plateauStart) >= plateauDuration;
    final bool stabilized = locked || repeatedPlateau;

    if (stabilized) _lastLockedWeightKg = weightKg;
    return ScaleFrame(
      weightKg: weightKg,
      stabilized: stabilized,
      rawHex: toHex(data),
    );
  }

  ScaleFrame? _parseResult(List<int> data) {
    if (data[2] != 0x01) return null;

    var weightKg = _lastLockedWeightKg;
    if ((data[7] & lockedMask) != 0) {
      final int rawWeight =
          ((data[8] << 16) | (data[9] << 8) | data[10]) & 0x3ffff;
      if (rawWeight >= minWeightRaw && rawWeight <= maxWeightRaw) {
        weightKg =
            ((rawWeight / weightRawUnitsPerKg) * 100).truncateToDouble() / 100;
      }
    }
    if (weightKg == null) return null;

    final int rawImpedance = (data[4] << 8) | data[5];
    if (rawImpedance <= 0) return null;

    final double impedance = rawImpedance < 1500
        ? rawImpedance.toDouble()
        : ((rawImpedance - 1000 - 4 * weightKg) / 6).clamp(0, 3000);

    return ScaleFrame(
      weightKg: weightKg,
      stabilized: true,
      impedanceOhm: impedance.round(),
      isFinal: true,
      rawHex: toHex(data),
    );
  }

  List<int> _buildProfileFrame(UserProfile profile, DateTime timestamp) {
    final List<int> frame = List<int>.filled(frameLength, 0);
    frame[0] = 0xac;
    frame[1] = 0x27;

    final int epochSeconds =
        timestamp.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    frame[2] = (epochSeconds >> 24) & 0xff;
    frame[3] = (epochSeconds >> 16) & 0xff;
    frame[4] = (epochSeconds >> 8) & 0xff;
    frame[5] = epochSeconds & 0xff;
    frame[6] = 0x08;
    frame[7] = 0x00;
    frame[9] = profile.heightCm.round().clamp(0, 255).toInt();
    frame[12] = profile.age.clamp(0, 255).toInt();
    frame[13] = profile.sex == Sex.male ? 0x01 : 0x02;
    frame[16] = 0x03;
    frame[18] = typeBalance;

    var sum = 0;
    for (var i = 2; i <= 18; i++) {
      sum += frame[i];
    }
    frame[19] = sum & 0xff;
    return frame;
  }
}
