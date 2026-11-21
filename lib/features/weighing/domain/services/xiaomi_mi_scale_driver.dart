import 'dart:typed_data';

import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'scale_driver.dart';
import 'standard_scale_parser.dart';

/// Pilote pour les balances **Xiaomi Mi Body Composition Scale** (v1 & v2)
/// et les balances Mi Scale standard.
///
/// Protocole documenté (issu de projets open-source : openScale, xiaomi-mi-scale) :
///  - service `0x181D` (Weight Scale), caractéristique `0x2A9D` en NOTIFY ;
///  - trame de 13 octets : `[ctrl][unit][00][00][année BE][mois][jour][h][m][s][poids LE ×100]` ;
///  - le poids est aussi diffusé dans le **service data** `0x181D` (avant connexion) ;
///  - la v2 (composition corporelle) ajoute l'impédance dans des octets supplémentaires.
///
/// Aucun handshake nécessaire : la balance notifie ses mesures automatiquement.
class XiaomiMiScaleDriver implements ScaleDriver {
  const XiaomiMiScaleDriver();

  /// Octet de contrôle : poids stabilisé.
  static const int _ctrlStabilized = 0x20;

  /// Unités.
  static const int _unitKg = 0x03;
  static const int _unitLb = 0x02;
  static const int _unitJin = 0x0B;

  @override
  String get id => 'xiaomi-mi';

  @override
  String get displayName => 'Xiaomi Mi Scale / Mi Body Composition';

  @override
  List<String> get knownNames => const <String>[
    'MIBCS',
    'Mi Scale',
    'MiScale',
    'MI SCALE',
    'XMTZC',
    'Xiaomi',
    'NUN4048',
  ];

  @override
  List<String> get serviceUuids => const <String>[
    ScaleUuids.weightScaleService,
  ];

  @override
  List<String> get notifyUuids => const <String>[
    ScaleUuids.weightMeasurementChar,
  ];

  @override
  String? get writeUuid => null;

  @override
  bool get needsHandshake => false;

  @override
  bool matches(AdvertisementInfo adv) {
    final String lower = adv.name.toLowerCase();
    for (final String kw in knownNames) {
      if (lower.contains(kw.toLowerCase())) return true;
    }
    // Xiaomi company ID = 0x038F.
    if (adv.manufacturerData.containsKey(0x038F)) return true;
    return false;
  }

  @override
  ScaleFrame? parseManufacturerData(List<int> data) => _parseMiFrame(data);

  @override
  ScaleFrame? parse(String characteristicUuid, List<int> value) {
    final String uuid = characteristicUuid.toLowerCase();
    if (uuid == ScaleUuids.weightMeasurementChar) {
      final ScaleFrame? mi = _parseMiFrame(value);
      if (mi != null) return mi;
    }
    // Fallback : interprétation standard SIG au cas où.
    return StandardScaleParser.parseWeightMeasurement(value);
  }

  @override
  bool isResultFrame(List<int> value) {
    final ScaleFrame? f = _parseMiFrame(value);
    return f != null && f.isFinal;
  }

  @override
  List<List<int>> buildHandshake(UserProfile profile) => const <List<int>>[];

  @override
  List<int>? buildResultAcknowledgement() => null;

  @override
  void resetSession() {}

  // ---------------------------------------------------------------------------
  // Décodage d'une trame Mi Scale (service data 0x181D ou notification 0x2A9D).
  // ---------------------------------------------------------------------------

  ScaleFrame? _parseMiFrame(List<int> data) {
    final Uint8List b = Uint8List.fromList(data);
    // Trame minimale : ctrl + unit + 2 réservés + 6 horodatage + 2 poids = 12.
    if (b.length < 12) return null;

    final int ctrl = b[0];
    final int unit = b[1];

    // Le poids est aux 2 derniers octets de la partie horodatée+poids.
    // Position standard : octets 11-12 (indices 11 et 12) si 13 octets.
    // Pour des trames plus courtes, on prend les 2 derniers octets.
    final int weightLo = b.length >= 13 ? b[11] : b[b.length - 2];
    final int weightHi = b.length >= 13 ? b[12] : b[b.length - 1];
    final int raw = weightLo | (weightHi << 8);
    if (raw == 0) return null;

    double weightKg;
    switch (unit) {
      case _unitLb:
        weightKg = raw * 0.01 * 0.45359237;
        break;
      case _unitJin:
        weightKg = raw * 0.005 * 0.5; // 1 jin = 0.5 kg
        break;
      case _unitKg:
      default:
        weightKg = raw * 0.01;
    }

    if (weightKg < 2 || weightKg > 300) return null;

    final bool stabilized = (ctrl & _ctrlStabilized) != 0;

    // Mi Body Composition Scale v2 : l'impédance peut être présente dans des
    // octets supplémentaires (après le poids). Format variable : on essaie
    // de lire 2 octets après le poids comme impédance brute.
    int? impedance;
    if (b.length >= 15) {
      final int impRaw = b[13] | (b[14] << 8);
      if (impRaw > 0 && impRaw < 3000) impedance = impRaw;
    }

    return ScaleFrame(
      weightKg: double.parse(weightKg.toStringAsFixed(2)),
      stabilized: stabilized,
      impedanceOhm: impedance,
      isFinal: stabilized && impedance != null,
      rawHex: toHex(data),
    );
  }
}
