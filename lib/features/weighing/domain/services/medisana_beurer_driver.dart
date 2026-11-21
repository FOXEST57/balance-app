import 'dart:typed_data';

import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'scale_driver.dart';
import 'standard_scale_parser.dart';

/// Pilote pour la famille de balances **Medisana / Beurer / Sanitas**
/// (modèles BS444, BS430, BF700, BF800, SBF70, SBF72, etc.).
///
/// Ces balances implémentent le service standard `0x181D` (Weight Scale) mais
/// avec une **résolution de poids de 0,01 kg** au lieu des 0,005 kg du
/// standard SIG Bluetooth. C'est cette différence qui justifie un pilote
/// dédié : le parseur SIG standard donnerait des valeurs 2 fois trop faibles.
///
/// Référence open-source : projet openScale (github.com/oliexdev/openScale).
class MedisanaBeurerDriver implements ScaleDriver {
  const MedisanaBeurerDriver();

  @override
  String get id => 'medisana-beurer';

  @override
  String get displayName => 'Medisana / Beurer / Sanitas';

  @override
  List<String> get knownNames => const <String>[
    'Medisana',
    'BS444',
    'BS430',
    'BS440',
    'Beurer',
    'BF700',
    'BF710',
    'BF800',
    'BF950',
    'Sanitas',
    'SBF70',
    'SBF72',
    'SBF10',
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
    // Reconnaissance par nom d'annonce (prioritaire sur le SIG standard).
    final String name = adv.name.toLowerCase();
    for (final String kw in knownNames) {
      if (name.contains(kw.toLowerCase())) return true;
    }
    return false;
  }

  @override
  ScaleFrame? parseManufacturerData(List<int> data) => null;

  @override
  ScaleFrame? parse(String characteristicUuid, List<int> value) {
    final String uuid = characteristicUuid.toLowerCase();
    if (uuid == ScaleUuids.weightMeasurementChar) {
      return _parseWeight(value);
    }
    if (uuid == ScaleUuids.bodyCompositionChar) {
      return StandardScaleParser.parseBodyComposition(value);
    }
    return null;
  }

  /// Parse la mesure de poids avec la résolution spécifique Medisana (0,01 kg).
  ScaleFrame? _parseWeight(List<int> data) {
    final Uint8List b = Uint8List.fromList(data);
    if (b.length < 3) return null;

    final int flags = b[0];
    final bool imperial = (flags & 0x01) != 0;
    final int raw = b[1] | (b[2] << 8);

    // Résolution Medisana : 0,01 kg en SI, 0,01 lb en impérial.
    final double weightKg =
        imperial ? (raw * 0.01) * 0.45359237 : raw * 0.01;

    if (weightKg < 2 || weightKg > 400) return null;

    return ScaleFrame(
      weightKg: double.parse(weightKg.toStringAsFixed(2)),
      stabilized: true,
      rawHex: toHex(data),
    );
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
