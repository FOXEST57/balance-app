import 'dart:typed_data';

import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'scale_driver.dart';

/// Pilote pour les balances **Huawei AH100 / AH108** et les balances **Honor**
/// basées sur le même protocole.
///
/// Ces balances n'implémentent pas les services SIG standard. Elles utilisent
/// un service vendeur `0xFEE0` et diffusent le poids directement dans les
/// données constructeur (manufacturer data) des paquets d'annonce BLE, avant
/// même toute connexion.
///
/// Référence open-source : rétro-ingénierie disponible dans openScale et
/// divers projets communautaires.
class HuaweiAhDriver implements ScaleDriver {
  const HuaweiAhDriver();

  @override
  String get id => 'huawei-ah';

  @override
  String get displayName => 'Huawei AH100 / Honor';

  @override
  List<String> get knownNames => const <String>[
    'AH100',
    'AH108',
    'Huawei',
    'Honor',
    'HUAWEI Scale',
    'HONOR Scale',
  ];

  /// Service vendeur Huawei utilisé par les balances AH100/AH108.
  static const String vendorService =
      '0000fee0-0000-1000-8000-00805f9b34fb';

  @override
  List<String> get serviceUuids => const <String>[vendorService];

  @override
  List<String> get notifyUuids => const <String>[
    // Caractéristique de mesure de poids (valeur exacte variable par modèle).
    '0000fee1-0000-1000-8000-00805f9b34fb',
    '0000fee2-0000-1000-8000-00805f9b34fb',
  ];

  @override
  String? get writeUuid => null;

  @override
  bool get needsHandshake => false;

  @override
  bool matches(AdvertisementInfo adv) {
    // Reconnaissance par nom.
    final String name = adv.name.toLowerCase();
    for (final String kw in knownNames) {
      if (name.contains(kw.toLowerCase())) return true;
    }
    // Reconnaissance par service vendeur.
    for (final String uuid in adv.serviceUuids) {
      if (uuid.toLowerCase() == vendorService) return true;
    }
    return false;
  }

  @override
  ScaleFrame? parseManufacturerData(List<int> data) {
    final Uint8List b = Uint8List.fromList(data);
    if (b.length < 4) return null;

    // Sur AH100, le poids est codé sur 2 octets (little-endian) en unités de
    // 0,01 kg, généralement à partir de l'octet 2.
    // Le format exact varie légèrement entre les modèles ; on tente plusieurs
    // offsets et on garde celui qui donne une valeur plausible (2-400 kg).
    const List<int> offsets = <int>[2, 0, 4];
    for (final int offset in offsets) {
      if (offset + 1 >= b.length) continue;
      final int raw = b[offset] | (b[offset + 1] << 8);
      final double weightKg = raw * 0.01;
      if (weightKg >= 2 && weightKg <= 400) {
        return ScaleFrame(
          weightKg: double.parse(weightKg.toStringAsFixed(2)),
          stabilized: true,
          rawHex: toHex(data),
        );
      }
    }
    return null;
  }

  @override
  ScaleFrame? parse(String characteristicUuid, List<int> value) {
    // Les mesures GATT suivent un format similaire aux données constructeur.
    return parseManufacturerData(value);
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
