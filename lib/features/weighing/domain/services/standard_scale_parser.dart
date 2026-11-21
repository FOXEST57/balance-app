import 'dart:typed_data';

import '../entities/scale_frame.dart';

/// Coordonnées GATT standards utiles à la lecture d'une balance.
class ScaleUuids {
  ScaleUuids._();

  /// Service standard « Weight Scale » (Bluetooth SIG).
  static const String weightScaleService =
      '0000181d-0000-1000-8000-00805f9b34fb';

  /// Caractéristique « Weight Measurement » (0x2A9D).
  static const String weightMeasurementChar =
      '00002a9d-0000-1000-8000-00805f9b34fb';

  /// Service standard « Body Composition » (Bluetooth SIG).
  static const String bodyCompositionService =
      '0000181b-0000-1000-8000-00805f9b34fb';

  /// Caractéristique « Body Composition Measurement » (0x2A9C).
  static const String bodyCompositionChar =
      '00002a9c-0000-1000-8000-00805f9b34fb';

  /// UUID vendeurs fréquents sur les balances Fitdays / IComon / Chipsea.
  static const String vendorServicePrimary =
      '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String vendorServiceSecondary =
      '0000ffb0-0000-1000-8000-00805f9b34fb';

  /// Caractéristiques NOTIFY vendeurs connues.
  static const String vendorNotify1 = '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String vendorNotify2 = '0000fff4-0000-1000-8000-00805f9b34fb';

  /// Notification AC27 confirmée sur la Little Balance : poids et résultats.
  static const String vendorNotify3 = '0000ffb2-0000-1000-8000-00805f9b34fb';

  /// Caractéristique d'écriture AC27 confirmée sur la Little Balance.
  static const String vendorWrite1 = '0000ffb1-0000-1000-8000-00805f9b34fb';

  /// Noms d'annonce (advertising) courants à filtrer au scan.
  static const List<String> knownNames = <String>[
    'Fitdays',
    'IComon',
    'Icomon',
    'iComon',
    'Little Balance',
    'BALANCE',
    'LB-',
    '8661',
    'Cardio',
    'SC-Scale',
    'SinoScale',
    'Chipsea',
    'Scale',
  ];
}

/// Parseur des trames standards Bluetooth SIG.
///
/// Ces formats sont **normés** (Weight Scale / Body Composition), donc fiables
/// si votre balance les expose. Le parseur vendeur (Fitdays) sert de secours.
class StandardScaleParser {
  StandardScaleParser._();

  /// Parse « Weight Measurement » (0x2A9D).
  ///
  /// Format : [flags(1)] [poids(2, uint16)] [timestamp(7)?] [userID(1)?] [IMC+taille(4)?]
  /// Le poids est en unités de 0,005 kg si l'unité SI (bit 0 = 0).
  static ScaleFrame? parseWeightMeasurement(List<int> data) {
    final Uint8List b = Uint8List.fromList(data);
    if (b.length < 3) return null;

    final int flags = b[0];
    final bool imperial = (flags & 0x01) != 0; // bit 0 : 1 = livres impériales
    final int raw = b[1] | (b[2] << 8);

    // Unité SI : résolution 0,005 kg. Impérial : 0,01 lb.
    double weightKg = imperial ? (raw * 0.01) * 0.45359237 : raw * 0.005;

    if (weightKg < 2 || weightKg > 400) return null;

    // Le flag de stabilisation standard correspond au bit « measurement units »…
    // Le SIG ne définit pas de bit de stabilisation : la dernière trame reçue
    // est considérée comme stable dès lors qu'elle est répétée. On marque donc
    // stable = true (la logique de stabilisation applicative gère le reste).
    return ScaleFrame(
      weightKg: double.parse(weightKg.toStringAsFixed(2)),
      stabilized: true,
      rawHex: toHex(data),
    );
  }

  /// Parse « Body Composition Measurement » (0x2A9C).
  ///
  /// Format (extrait) : [flags(1)] [bodyFat%(2, 0.1%)] [timestamp(7)?] [userID(1)?]
  /// [BMR(2)?] [muscle%(2, 0.1%)?] … [impedance(2, 0.1Ω) en fin de trame]
  static ScaleFrame? parseBodyComposition(List<int> data) {
    final Uint8List b = Uint8List.fromList(data);
    if (b.length < 4) return null;

    final int flags = b[0];
    int i = 1;

    // Masse grasse (2 octets, 0,1 %) — on avance la tête de lecture; le
    // pourcentage est recalculé côté BIA à partir du poids réel.
    i += 2;

    final bool hasTimestamp = (flags & 0x01) != 0;
    final bool hasUserId = (flags & 0x02) != 0;
    final bool hasBmr = (flags & 0x08) != 0;
    final bool hasMuscle = (flags & 0x1000) != 0; // bit muscle %

    if (hasTimestamp) i += 7;
    if (hasUserId) i += 1;
    if (hasBmr && i + 1 < b.length) i += 2;
    if (hasMuscle && i + 1 < b.length) {
      // muscle% (0,1 %)
      i += 2;
    }

    // L'impédance est placée en fin de trame (2 octets, 0,1 Ω).
    int? impedance;
    if (i + 1 < b.length) {
      final int impRaw = b[i] | (b[i + 1] << 8);
      if (impRaw > 0) impedance = (impRaw * 0.1).round();
    }

    // La masse grasse seule ne suffit pas : le poids viendra de l'autre
    // caractéristique. On ne renvoie donc pas de trame ici si poids inconnu ;
    // le service BLE combine les deux sources.
    return ScaleFrame(
      weightKg: 0,
      stabilized: true,
      isFinal: true,
      impedanceOhm: impedance,
      rawHex: toHex(data),
    );
  }
}
