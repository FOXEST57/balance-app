import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'scale_driver.dart';
import 'standard_scale_parser.dart';

/// Pilote pour les balances conformes aux services **Bluetooth SIG** :
/// Weight Scale (`0x181D`) et Body Composition (`0x181B`).
///
/// Ce pilote couvre de nombreuses balances premium qui implémentent
/// correctement les standards : Polar Balance, Garmin Index, certaines
/// Withings (mode BLE), Omron, etc. Aucun handshake n'est nécessaire :
/// la balance notifie directement ses mesures.
class StandardSigScaleDriver implements ScaleDriver {
  const StandardSigScaleDriver();

  @override
  String get id => 'sig';

  @override
  String get displayName => 'Balance standard Bluetooth (SIG)';

  @override
  List<String> get knownNames => const <String>[
    'Polar',
    'Garmin',
    'Index',
    'Omron',
    'Withings',
    'Nokia',
    'Eufy',
  ];

  @override
  List<String> get serviceUuids => const <String>[
    ScaleUuids.weightScaleService,
    ScaleUuids.bodyCompositionService,
  ];

  @override
  List<String> get notifyUuids => const <String>[
    ScaleUuids.weightMeasurementChar,
    ScaleUuids.bodyCompositionChar,
  ];

  @override
  String? get writeUuid => null;

  @override
  bool get needsHandshake => false;

  @override
  bool matches(AdvertisementInfo adv) {
    for (final String uuid in adv.serviceUuids) {
      if (serviceUuids.contains(uuid.toLowerCase())) return true;
    }
    return false;
  }

  @override
  ScaleFrame? parseManufacturerData(List<int> data) => null;

  @override
  ScaleFrame? parse(String characteristicUuid, List<int> value) {
    final String uuid = characteristicUuid.toLowerCase();
    if (uuid == ScaleUuids.weightMeasurementChar) {
      return StandardScaleParser.parseWeightMeasurement(value);
    }
    if (uuid == ScaleUuids.bodyCompositionChar) {
      return StandardScaleParser.parseBodyComposition(value);
    }
    return null;
  }

  @override
  bool isResultFrame(List<int> value) => false;

  @override
  List<List<int>> buildHandshake(UserProfile profile) => const <List<int>>[];

  @override
  List<int>? buildResultAcknowledgement() => null;

  @override
  void resetSession() {}
}
