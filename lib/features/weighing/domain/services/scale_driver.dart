import '../entities/scale_frame.dart';
import '../entities/user_profile.dart';
import 'chipsea_driver.dart';
import 'generic_scale_driver.dart';
import 'huawei_ah_driver.dart';
import 'medisana_beurer_driver.dart';
import 'standard_sig_driver.dart';
import 'xiaomi_mi_scale_driver.dart';

/// Informations issues de l'annonce BLE d'un périphérique, utilisées pour
/// identifier quel pilote ([ScaleDriver]) doit prendre en charge la balance.
class AdvertisementInfo {
  const AdvertisementInfo({
    required this.name,
    required this.serviceUuids,
    required this.manufacturerData,
  });

  /// Nom diffusé par le périphérique (vide si absent).
  final String name;

  /// Liste des UUID de services présents dans l'annonce (en minuscules).
  final List<String> serviceUuids;

  /// Données constructeur : clé = company ID, valeur = octets bruts.
  final Map<int, List<int>> manufacturerData;

  /// Recherche une donnée constructeur par son company ID.
  List<int>? manufacturerDataForCompany(int companyId) =>
      manufacturerData[companyId];
}

/// Abstraction d'un pilote de balance Bluetooth.
///
/// Chaque implémentation correspond à un protocole (ou une famille de
/// balances) et fournit :
///  - les critères de reconnaissance à partir de l'annonce BLE ;
///  - le décodage des données constructeur (poids diffusé avant connexion) ;
///  - le décodage des notifications GATT ;
///  - le cas échéant, le handshake à envoyer après connexion.
///
/// Cette architecture rend l'ajout d'une nouvelle balance trivial : il suffit
/// d'implémenter cette interface et d'enregistrer le pilote dans
/// [ScaleDriverRegistry].
abstract class ScaleDriver {
  /// Identifiant unique du pilote (ex. `chipsea`, `xiaomi-mi`, `sig`).
  String get id;

  /// Nom affiché à l'utilisateur (ex. « Fitdays / Chipsea »).
  String get displayName;

  /// Noms d'annonce reconnus (pour le filtrage au scan).
  List<String> get knownNames;

  /// UUID de services GATT reconnus (pour le filtrage au scan).
  List<String> get serviceUuids;

  /// UUID des caractéristiques auxquelles s'abonner en NOTIFY.
  List<String> get notifyUuids;

  /// UUID de la caractéristique d'écriture (pour le handshake), ou `null`.
  String? get writeUuid;

  /// Vrai si un handshake doit être envoyé après l'abonnement aux notifications.
  bool get needsHandshake;

  /// Vrai si ce pilote peut prendre en charge le périphérique décrit.
  bool matches(AdvertisementInfo adv);

  /// Décode le poids diffusé dans les données constructeur (avant connexion).
  ScaleFrame? parseManufacturerData(List<int> data);

  /// Décode une notification GATT reçue sur [characteristicUuid].
  ScaleFrame? parse(String characteristicUuid, List<int> value);

  /// Vrai si la trame est une trame de résultat final (impédance) qui appelle
  /// un accusé de réception.
  bool isResultFrame(List<int> value);

  /// Construit les trames de handshake à envoyer après connexion.
  List<List<int>> buildHandshake(UserProfile profile);

  /// Construit la trame d'accusé de réception du résultat, ou `null`.
  List<int>? buildResultAcknowledgement();

  /// Réinitialise l'état interne du pilote (nouvelle connexion).
  void resetSession();
}

/// Registre des pilotes de balance disponibles.
///
/// L'ordre des pilotes dans [_drivers] définit la priorité : les pilotes
/// spécifiques (Chipsea, Xiaomi) sont testés avant le pilote générique SIG
/// et le pilote de secours.
class ScaleDriverRegistry {
  ScaleDriverRegistry._();

  static final List<ScaleDriver> _drivers = <ScaleDriver>[
    ChipseaFitdaysDriver(),
    XiaomiMiScaleDriver(),
    MedisanaBeurerDriver(),
    HuaweiAhDriver(),
    StandardSigScaleDriver(),
    GenericScaleDriver(),
  ];

  /// Tous les pilotes enregistrés.
  static List<ScaleDriver> get all => List<ScaleDriver>.unmodifiable(_drivers);

  /// Recherche le premier pilote capable de prendre en charge [adv].
  static ScaleDriver? find(AdvertisementInfo adv) {
    for (final ScaleDriver d in _drivers) {
      if (d.matches(adv)) return d;
    }
    return null;
  }

  /// Retourne le pilote par son identifiant, ou `null`.
  static ScaleDriver? byId(String id) {
    for (final ScaleDriver d in _drivers) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Tous les noms d'annonce reconnus (union des [knownNames] de tous les
  /// pilotes), utilisés pour le filtrage au scan.
  static List<String> allKnownNames() {
    final Set<String> names = <String>{};
    for (final ScaleDriver d in _drivers) {
      names.addAll(d.knownNames);
    }
    return names.toList();
  }

  /// Tous les UUID de services reconnus (union).
  static List<String> allServiceUuids() {
    final Set<String> uuids = <String>{};
    for (final ScaleDriver d in _drivers) {
      uuids.addAll(d.serviceUuids);
    }
    return uuids.toList();
  }
}
