import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'ac27_parser.dart';
import 'fitdays_parser.dart';
import 'scale_driver.dart';
import 'standard_scale_parser.dart';

/// Pilote pour les balances équipées d'un module **Chipsea** :
/// Fitdays, IComon, Little Balance, de nombreuses Renpho, Sinocare, etc.
///
/// Protocole : service vendeur `0xFFF0` / `0xFFB0`, caractéristiques NOTIFY
/// `0xFFF1`/`0xFFF4` (poids brut) et `0xFFB2` (trames AC27 avec impédance),
/// écriture sur `0xFFB1` (handshake profil + accusé de réception).
class ChipseaFitdaysDriver implements ScaleDriver {
  ChipseaFitdaysDriver({FitdaysParserConfig? vendorConfig})
    : _vendorParser = FitdaysParser(vendorConfig ?? const FitdaysParserConfig()),
      _ac27Parser = Ac27Parser();

  final FitdaysParser _vendorParser;
  final Ac27Parser _ac27Parser;

  @override
  String get id => 'chipsea';

  @override
  String get displayName => 'Fitdays / Chipsea (Little Balance, IComon, Renpho…)';

  @override
  List<String> get knownNames => const <String>[
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
    'Renpho',
    'RENPHO',
    'Sinocare',
    'Picooc',
    'Yunmai',
    'OKOK',
  ];

  @override
  List<String> get serviceUuids => const <String>[
    ScaleUuids.vendorServicePrimary,
    ScaleUuids.vendorServiceSecondary,
  ];

  @override
  List<String> get notifyUuids => const <String>[
    ScaleUuids.vendorNotify1,
    ScaleUuids.vendorNotify2,
    ScaleUuids.vendorNotify3,
  ];

  @override
  String? get writeUuid => ScaleUuids.vendorWrite1;

  @override
  bool get needsHandshake => true;

  @override
  bool matches(AdvertisementInfo adv) {
    final String lower = adv.name.toLowerCase();
    for (final String kw in knownNames) {
      if (lower.contains(kw.toLowerCase())) return true;
    }
    for (final String uuid in adv.serviceUuids) {
      if (serviceUuids.contains(uuid.toLowerCase())) return true;
    }
    return false;
  }

  @override
  ScaleFrame? parseManufacturerData(List<int> data) =>
      _vendorParser.parseManufacturerData(data);

  @override
  ScaleFrame? parse(String characteristicUuid, List<int> value) {
    final String uuid = characteristicUuid.toLowerCase();
    if (uuid == ScaleUuids.vendorNotify3) {
      if (_ac27Parser.isValidFrame(value)) {
        // La première trame AC27 valide déclenche le handshake côté service.
      }
      return _ac27Parser.parse(value);
    }
    // Autres caractéristiques vendeurs (FFF1, FFF4) : trames poids brut.
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
