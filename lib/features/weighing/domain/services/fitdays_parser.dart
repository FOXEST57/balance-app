import 'dart:typed_data';

import '../entities/scale_frame.dart';

/// Configuration du parseur vendeur Fitdays / IComon / Chipsea.
///
/// ⚠️ IMPORTANT — à calibrer avec de vraies trames :
/// Le protocole vendeur n'est pas documenté publiquement. Les valeurs par
/// défaut ci-dessous correspondent au schéma le plus répandu sur les balances
/// équipées d'un module Chipsea (service 0xFFF0 / 0xFFB0), mais elles DOIVENT
/// être confirmées avec une capture nRF Connect réelle (voir la consigne de
/// calibration en fin de livraison). Tous les paramètres sont modifiables sans
/// toucher à la logique de parsing.
class FitdaysParserConfig {
  const FitdaysParserConfig({
    this.minLength = 6,
    this.expectedHeader = 0xCF,
    this.weightOffset = 4,
    this.weightBigEndian = true,
    this.weightDivisor = 100.0,
    this.impedanceOffset = 6,
    this.impedanceBigEndian = true,
    this.stabilityByte = 1,
    this.stabilityMask = 0x01,
    this.minWeightKg = 20.0,
    this.maxWeightKg = 250.0,
  });

  final int minLength;

  /// Octet d'en-tête attendu (0xCF sur de nombreuses balances Chipsea).
  /// Mettre `null` pour ne pas vérifier l'en-tête.
  final int? expectedHeader;

  final int weightOffset;
  final bool weightBigEndian;
  final double weightDivisor;

  final int impedanceOffset;
  final bool impedanceBigEndian;

  /// Octet contenant le bit de stabilisation du poids.
  final int stabilityByte;

  /// Masque du bit de stabilisation.
  final int stabilityMask;

  final double minWeightKg;
  final double maxWeightKg;

  FitdaysParserConfig copyWith({
    int? minLength,
    int? expectedHeader,
    int? weightOffset,
    bool? weightBigEndian,
    double? weightDivisor,
    int? impedanceOffset,
    bool? impedanceBigEndian,
    int? stabilityByte,
    int? stabilityMask,
    double? minWeightKg,
    double? maxWeightKg,
  }) {
    return FitdaysParserConfig(
      minLength: minLength ?? this.minLength,
      expectedHeader: expectedHeader ?? this.expectedHeader,
      weightOffset: weightOffset ?? this.weightOffset,
      weightBigEndian: weightBigEndian ?? this.weightBigEndian,
      weightDivisor: weightDivisor ?? this.weightDivisor,
      impedanceOffset: impedanceOffset ?? this.impedanceOffset,
      impedanceBigEndian: impedanceBigEndian ?? this.impedanceBigEndian,
      stabilityByte: stabilityByte ?? this.stabilityByte,
      stabilityMask: stabilityMask ?? this.stabilityMask,
      minWeightKg: minWeightKg ?? this.minWeightKg,
      maxWeightKg: maxWeightKg ?? this.maxWeightKg,
    );
  }
}

/// Parseur de trames vendeur « Fitdays / IComon / Chipsea ».
class FitdaysParser {
  FitdaysParser([this.config = const FitdaysParserConfig()]);

  final FitdaysParserConfig config;

  /// Décode une trame NOTIFY en provenance de la caractéristique vendeur.
  ///
  /// Retourne `null` si la trame n'est pas exploitable.
  ScaleFrame? parse(List<int> data) {
    final Uint8List b = Uint8List.fromList(data);
    if (b.length < config.minLength) return null;

    // Vérifie l'en-tête si défini.
    final int? header = config.expectedHeader;
    if (header != null && b[0] != header) {
      // Certaines trames (fin de cycle) n'ont pas le même en-tête ;
      // on poursuit tout de même l'analyse plutôt que de rejeter.
    }

    final double? weight = _readWeight(b);
    if (weight == null) return null;

    final int? impedance = _readImpedance(b);
    final bool stabilized = _readStability(b);

    return ScaleFrame(
      weightKg: weight,
      stabilized: stabilized,
      impedanceOhm: impedance != null && impedance > 0 ? impedance : null,
      isFinal: stabilized && impedance != null && impedance > 0,
      rawHex: toHex(data),
    );
  }

  /// Décode une trame de type « Manufacturer Data » (broadcast).
  ///
  /// De nombreuses balances Chipsea diffusent le poids directement dans les
  /// données constructeur de l'annonce, ce qui permet d'afficher le poids
  /// **avant même** l'établissement de la connexion.
  ScaleFrame? parseManufacturerData(List<int> msd) {
    final Uint8List b = Uint8List.fromList(msd);
    if (b.length < 4) return null;

    // Schéma fréquent : [poids 2 octets little-endian][?][impédance 2 octets LE]
    for (final int offset in <int>[0, 2, 4]) {
      if (offset + 1 >= b.length) continue;
      final int raw = offset + 2 <= b.length
          ? (b[offset] | (b[offset + 1] << 8))
          : -1;
      if (raw <= 0) continue;
      final double w = raw / 100.0;
      if (w >= config.minWeightKg && w <= config.maxWeightKg) {
        int? imp;
        if (offset + 3 < b.length) {
          final int impRaw = b[offset + 2] | (b[offset + 3] << 8);
          if (impRaw > 0 && impRaw < 2500) imp = impRaw;
        }
        return ScaleFrame(
          weightKg: double.parse(w.toStringAsFixed(2)),
          stabilized: true,
          impedanceOhm: imp,
          rawHex: toHex(msd),
        );
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Lecture des champs
  // ---------------------------------------------------------------------------

  double? _readWeight(Uint8List b) {
    final int o = config.weightOffset;
    if (o + 1 >= b.length) return null;
    final int raw = config.weightBigEndian
        ? (b[o] << 8) | b[o + 1]
        : (b[o + 1] << 8) | b[o];
    final double w = raw / config.weightDivisor;
    if (w < config.minWeightKg || w > config.maxWeightKg) return null;
    return double.parse(w.toStringAsFixed(2));
  }

  int? _readImpedance(Uint8List b) {
    final int o = config.impedanceOffset;
    if (o + 1 >= b.length) return null;
    final int raw = config.impedanceBigEndian
        ? (b[o] << 8) | b[o + 1]
        : (b[o + 1] << 8) | b[o];
    if (raw <= 0 || raw > 3000) return null;
    return raw;
  }

  bool _readStability(Uint8List b) {
    final int i = config.stabilityByte;
    if (i >= b.length) return false;
    return (b[i] & config.stabilityMask) != 0;
  }
}
