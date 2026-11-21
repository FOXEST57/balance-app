import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'ac27_parser.dart';
import 'fitdays_parser.dart';
import 'scale_driver.dart';
import 'standard_scale_parser.dart';

/// Pilote de **secours** : essaie successivement tous les parseurs connus
/// (Chipsea AC27, Fitdays brut, standard SIG) sur une balance qui n'a pas
/// été reconnue par un pilote spécifique.
///
/// Ce pilote est sélectionné en dernier recours et ne participe pas au
/// filtrage par nom (il est utilisé uniquement en mode « afficher tous les
/// appareils » ou quand aucun autre pilote ne correspond).
class GenericScaleDriver implements ScaleDriver {
  GenericScaleDriver()
    : _vendorParser = FitdaysParser(),
      _ac27Parser = Ac27Parser();

  final FitdaysParser _vendorParser;
  final Ac27Parser _ac27Parser;

  @override
  String get id => 'generic';

  @override
  String get displayName => 'Balance générique (essai automatique)';

  @override
  List<String> get knownNames => const <String>[];

  @override
  List<String> get serviceUuids => const <String>[];

  @override
  List<String> get notifyUuids => const <String>[
    ScaleUuids.vendorNotify1,
    ScaleUuids.vendorNotify2,
    ScaleUuids.vendorNotify3,
    ScaleUuids.weightMeasurementChar,
    ScaleUuids.bodyCompositionChar,
  ];

  @override
  String? get writeUuid => ScaleUuids.vendorWrite1;

  @override
  bool get needsHandshake => true;

  /// Le pilote générique ne reconnaît rien par lui-même : il est sélectionné
  /// manuellement quand l'utilisateur choisit « essayer de connecter ».
  @override
  bool matches(AdvertisementInfo adv) => false;

  @override
  ScaleFrame? parseManufacturerData(List<int> data) =>
      _vendorParser.parseManufacturerData(data);

  @override
  ScaleFrame? parse(String characteristicUuid, List<int> value) {
    final String uuid = characteristicUuid.toLowerCase();

    // 1) Trames AC27 (Chipsea).
    if (_ac27Parser.isValidFrame(value)) {
      return _ac27Parser.parse(value);
    }

    // 2) Services standards SIG.
    if (uuid == ScaleUuids.weightMeasurementChar) {
      return StandardScaleParser.parseWeightMeasurement(value);
    }
    if (uuid == ScaleUuids.bodyCompositionChar) {
      return StandardScaleParser.parseBodyComposition(value);
    }

    // 3) Fallback vendeur Fitdays brut.
    return _vendorParser.parse(value);
  }

  @override
  bool isResultFrame(List<int> value) => _ac27Parser.isResultFrame(value);

  @override
  List<List<int>> buildHandshake(UserProfile profile) =>
      _ac27Parser.buildHandshake(profile);

  @override
  List<int>? buildResultAcknowledgement() =>
      _ac27Parser.buildResultAcknowledgement();

  @override
  void resetSession() => _ac27Parser.resetSession();
}
