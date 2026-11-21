import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/entities/scale_frame.dart';
import '../domain/entities/user_profile.dart';
import '../domain/services/ac27_parser.dart';
import '../domain/services/fitdays_parser.dart';
import '../domain/services/generic_scale_driver.dart';
import '../domain/services/scale_driver.dart';

/// État de la liaison Bluetooth avec la balance.
enum ScaleConnectionStatus {
  idle,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

/// Un appareil découvert lors du scan.
class DiscoveredScale {
  const DiscoveredScale({
    required this.remoteId,
    required this.name,
    required this.rssi,
    required this.isLikelyScale,
    this.driverId,
    this.liveWeightKg,
    this.liveImpedanceOhm,
  });

  final String remoteId;
  final String name;
  final int rssi;

  /// Vrai si l'appareil correspond aux critères « balance » (nom ou service).
  final bool isLikelyScale;

  /// Identifiant du pilote détecté pour cette balance (null si non reconnu).
  final String? driverId;

  /// Poids déjà lisible dans les données constructeur (avant connexion).
  final double? liveWeightKg;
  final int? liveImpedanceOhm;

  DiscoveredScale copyWith({
    String? name,
    int? rssi,
    String? driverId,
    double? liveWeightKg,
    int? liveImpedanceOhm,
  }) {
    return DiscoveredScale(
      remoteId: remoteId,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isLikelyScale: isLikelyScale,
      driverId: driverId ?? this.driverId,
      liveWeightKg: liveWeightKg ?? this.liveWeightKg,
      liveImpedanceOhm: liveImpedanceOhm ?? this.liveImpedanceOhm,
    );
  }
}

/// Service BLE dédié à la balance impédancemètre.
///
/// Responsabilités :
///  - scanner (filtré « balances » ou tous les périphériques) ;
///  - se connecter et activer les notifications (NOTIFY) ;
///  - décoder les trames (standard SIG + vendeur Fitdays/IComon) ;
///  - exposer un flux de trames décodées ([frames]) ;
///  - fournir un **mode Simulation** pour tester sans matériel.
///
/// ⚠️ Licence flutter_blue_plus : `License.nonprofit` correspond à un usage
/// personnel / associatif. Pour un usage commercial, remplacer par
/// `License.commercial` (voir la licence du package).
class ScaleService {
  ScaleService({FitdaysParserConfig? vendorConfig})
    : _vendorParser = FitdaysParser(
        vendorConfig ?? const FitdaysParserConfig(),
      );

  static const License _license = License.nonprofit;

  final FitdaysParser _vendorParser;
  final Ac27Parser _ac27Parser = Ac27Parser();

  /// Pilote actuellement utilisé pour la balance connectée.
  ScaleDriver? _activeDriver;

  final StreamController<ScaleFrame> _framesCtrl =
      StreamController<ScaleFrame>.broadcast();
  final StreamController<ScaleConnectionStatus> _statusCtrl =
      StreamController<ScaleConnectionStatus>.broadcast();
  final StreamController<Map<String, DiscoveredScale>> _scanCtrl =
      StreamController<Map<String, DiscoveredScale>>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  final List<StreamSubscription<List<int>>> _notifySubs =
      <StreamSubscription<List<int>>>[];

  final Map<String, DiscoveredScale> _found = <String, DiscoveredScale>{};

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  UserProfile? _profile;
  Future<void>? _handshakeFuture;
  bool _handshakeStarted = false;
  Timer? _simTimer;
  ScaleConnectionStatus _status = ScaleConnectionStatus.idle;
  String? _lastScanError;

  /// Flux des trames décodées (poids en temps réel, stabilisation, impédance).
  Stream<ScaleFrame> get frames => _framesCtrl.stream;

  /// Flux des changements d'état de connexion.
  Stream<ScaleConnectionStatus> get status => _statusCtrl.stream;

  /// Flux des appareils découverts (clé = identifiant distant).
  Stream<Map<String, DiscoveredScale>> get scanResults => _scanCtrl.stream;

  ScaleConnectionStatus get currentStatus => _status;

  String? get lastScanError => _lastScanError;

  Map<String, DiscoveredScale> get discoveredScales =>
      Map<String, DiscoveredScale>.unmodifiable(_found);

  // ---------------------------------------------------------------------------
  // Support / adaptateur
  // ---------------------------------------------------------------------------

  Future<bool> isSupported() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  Future<bool> isAdapterOn() async {
    try {
      return await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Scan
  // ---------------------------------------------------------------------------

  /// Démarre un scan.
  ///
  /// [showAllDevices] : si vrai, tous les périphériques BLE sont remontés
  /// (permet de sélectionner manuellement sa balance si le filtrage par nom
  /// échoue). Sinon, seuls les appareils « probables balances » sont affichés.
  ///
  /// [timeout] : durée du scan (réduite pour les tentatives automatiques).
  Future<void> startScan({
    bool showAllDevices = false,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    _lastScanError = null;
    _found.clear();
    _scanCtrl.add(<String, DiscoveredScale>{});
    _setStatus(ScaleConnectionStatus.scanning);

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen(
      (List<ScanResult> results) => _onScanResults(results, showAllDevices),
      onError: (Object e) {
        _setStatus(ScaleConnectionStatus.error);
      },
    );

    try {
      final bool useFineLocation = await _ensureScanPermissions();
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        throw StateError(
          'Active le Bluetooth du téléphone, puis relance la recherche.',
        );
      }
      await FlutterBluePlus.startScan(
        timeout: timeout,
        continuousUpdates: true,
        androidUsesFineLocation: useFineLocation,
      );
    } catch (error) {
      _lastScanError = error.toString().replaceFirst('Bad state: ', '');
      _setStatus(ScaleConnectionStatus.error);
      await _scanSub?.cancel();
      _scanSub = null;
      rethrow;
    }

    // À la fin du scan, on repasse en idle si toujours en train de scanner.
    await FlutterBluePlus.isScanning.where((bool s) => !s).first;
    if (_status == ScaleConnectionStatus.scanning) {
      _setStatus(ScaleConnectionStatus.idle);
    }
  }

  Future<bool> _ensureScanPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;

    final int sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final bool useFineLocation = sdkInt < 31;
    final List<Permission> permissions = useFineLocation
        ? <Permission>[Permission.locationWhenInUse]
        : <Permission>[Permission.bluetoothScan, Permission.bluetoothConnect];
    final Map<Permission, PermissionStatus> statuses = await permissions
        .request();

    if (statuses.values.every((PermissionStatus status) => status.isGranted)) {
      return useFineLocation;
    }

    final bool permanentlyDenied = statuses.values.any(
      (PermissionStatus status) => status.isPermanentlyDenied,
    );
    throw StateError(
      permanentlyDenied
          ? 'Autorisation « Appareils à proximité » refusée définitivement. '
                'Ouvre Paramètres > Applications > Balance 8661 > Autorisations '
                'et autorise les appareils à proximité.'
          : 'Autorise « Appareils à proximité » pour que Balance 8661 puisse '
                'rechercher la balance Bluetooth.',
    );
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // ignore
    }
    await _scanSub?.cancel();
    _scanSub = null;
    if (_status == ScaleConnectionStatus.scanning) {
      _setStatus(ScaleConnectionStatus.idle);
    }
  }

  void _onScanResults(List<ScanResult> results, bool showAll) {
    for (final ScanResult r in results) {
      final String id = r.device.remoteId.str;
      final String name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : 'Appareil inconnu');

      final List<String> advServices = r.advertisementData.serviceUuids
          .map((Guid g) => g.str128.toLowerCase())
          .toList();

      final AdvertisementInfo advInfo = AdvertisementInfo(
        name: name,
        serviceUuids: advServices,
        manufacturerData: r.advertisementData.manufacturerData,
      );

      final ScaleDriver? driver = ScaleDriverRegistry.find(advInfo);
      final String? driverId = driver?.id;

      final bool likely = driver != null || _looksLikeScale(name, advServices);
      if (!showAll && !likely) continue;

      // Les données constructeur sont décodées par le pilote détecté ; sinon
      // on essaie le parseur Fitdays générique (poids diffusé en clair).
      double? liveW;
      int? liveImp;
      final ScaleFrame? parsedFrame = _parseAdvertisementData(driver, r);
      if (parsedFrame != null) {
        liveW = parsedFrame.weightKg;
        liveImp = parsedFrame.impedanceOhm;
      }

      final DiscoveredScale? existing = _found[id];
      _found[id] = DiscoveredScale(
        remoteId: id,
        name:
            existing?.name.isNotEmpty == true &&
                existing!.name != 'Appareil inconnu'
            ? existing.name
            : name,
        rssi: r.rssi,
        isLikelyScale: likely,
        driverId: driverId ?? existing?.driverId,
        liveWeightKg: liveW ?? existing?.liveWeightKg,
        liveImpedanceOhm: liveImp ?? existing?.liveImpedanceOhm,
      );
    }
    _scanCtrl.add(Map<String, DiscoveredScale>.from(_found));
  }

  /// Tente de décoder le poids depuis les données constructeur ou le service
  /// data de l'annonce, en utilisant le pilote détecté ou le parseur Fitdays.
  ScaleFrame? _parseAdvertisementData(
    ScaleDriver? driver,
    ScanResult r,
  ) {
    // 1) Données constructeur.
    for (final MapEntry<int, List<int>> entry
        in r.advertisementData.manufacturerData.entries) {
      final ScaleFrame? f = driver?.parseManufacturerData(entry.value) ??
          _vendorParser.parseManufacturerData(entry.value);
      if (f != null && f.weightKg > 0) return f;
    }
    // 2) Service data (ex. Mi Scale diffuse le poids dans le service 0x181D).
    for (final MapEntry<Guid, List<int>> entry
        in r.advertisementData.serviceData.entries) {
      final ScaleFrame? f = driver?.parseManufacturerData(entry.value) ??
          _vendorParser.parseManufacturerData(entry.value);
      if (f != null && f.weightKg > 0) return f;
    }
    return null;
  }

  bool _looksLikeScale(String name, List<String> advServices) {
    final String lower = name.toLowerCase();
    for (final String kw in ScaleDriverRegistry.allKnownNames()) {
      if (lower.contains(kw.toLowerCase())) return true;
    }
    for (final String uuid in advServices) {
      if (ScaleDriverRegistry.allServiceUuids().contains(uuid)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Connexion
  // ---------------------------------------------------------------------------

  Future<void> connect(
    DiscoveredScale scale, {
    UserProfile profile = UserProfile.defaults,
  }) async {
    await stopScan();
    _setStatus(ScaleConnectionStatus.connecting);

    // Sélection du pilote : celui détecté au scan, sinon le pilote générique.
    final ScaleDriver driver =
        ScaleDriverRegistry.byId(scale.driverId ?? '') ?? GenericScaleDriver();
    _activeDriver = driver;
    driver.resetSession();

    _profile = profile;
    _handshakeFuture = null;
    _handshakeStarted = false;
    _writeCharacteristic = null;

    try {
      final BluetoothDevice device = BluetoothDevice.fromId(scale.remoteId);
      _device = device;

      await device.connect(
        license: _license,
        timeout: const Duration(seconds: 20),
      );

      _connSub?.cancel();
      _connSub = device.connectionState.listen((BluetoothConnectionState s) {
        if (s == BluetoothConnectionState.disconnected &&
            _status == ScaleConnectionStatus.connected) {
          _setStatus(ScaleConnectionStatus.disconnected);
        }
      });

      await _subscribeToCharacteristics(device, driver);
      _setStatus(ScaleConnectionStatus.connected);
    } catch (_) {
      _setStatus(ScaleConnectionStatus.error);
      rethrow;
    }
  }

  Future<void> _subscribeToCharacteristics(
    BluetoothDevice device,
    ScaleDriver driver,
  ) async {
    final List<BluetoothService> services = await device.discoverServices();
    BluetoothCharacteristic? writeChar;
    final Set<String> notifyUuids =
        driver.notifyUuids.map((String s) => s.toLowerCase()).toSet();

    for (final BluetoothService service in services) {
      for (final BluetoothCharacteristic ch in service.characteristics) {
        final String uuid = ch.characteristicUuid.str128.toLowerCase();

        // Caractéristique d'écriture (handshake / accusé de réception).
        final String? writeUuid = driver.writeUuid?.toLowerCase();
        if (writeUuid != null && uuid == writeUuid && ch.properties.write) {
          writeChar = ch;
        }

        final bool canNotify = ch.properties.notify || ch.properties.indicate;
        if (!canNotify) continue;

        // On s'abonne aux caractéristiques du pilote, ou à toutes les
        // caractéristiques notifiantes si le pilote n'en spécifie pas.
        final bool shouldSubscribe =
            notifyUuids.isEmpty || notifyUuids.contains(uuid);
        if (!shouldSubscribe) continue;

        await ch.setNotifyValue(true);
        final StreamSubscription<List<int>> sub = ch.onValueReceived.listen(
          (List<int> value) => _onCharacteristicData(driver, ch, value),
        );
        _notifySubs.add(sub);
      }
    }

    if (driver.needsHandshake && writeChar != null) {
      _writeCharacteristic = writeChar;
    }
  }

  void _onCharacteristicData(
    ScaleDriver driver,
    BluetoothCharacteristic ch,
    List<int> value,
  ) {
    if (value.isEmpty) return;
    final String uuid = ch.characteristicUuid.str128.toLowerCase();

    final ScaleFrame? frame = driver.parse(uuid, value);

    // Si le pilote détecte une trame valide nécessitant un handshake, on le
    // déclenche (ex. première trame AC27 sur Chipsea).
    if (driver.needsHandshake &&
        _writeCharacteristic != null &&
        frame != null) {
      _startHandshake(driver);
    }

    if (frame == null) return;
    _framesCtrl.add(frame);

    if (driver.isResultFrame(value)) {
      unawaited(_acknowledgeResult(driver));
    }
  }

  void _startHandshake(ScaleDriver driver) {
    if (_handshakeStarted || _writeCharacteristic == null || _profile == null) {
      return;
    }
    _handshakeStarted = true;
    _handshakeFuture = _sendHandshake(driver);
  }

  Future<void> _sendHandshake(ScaleDriver driver) async {
    final BluetoothCharacteristic? characteristic = _writeCharacteristic;
    final UserProfile? profile = _profile;
    if (characteristic == null || profile == null) return;

    for (final List<int> frame in driver.buildHandshake(profile)) {
      try {
        await characteristic.write(frame, withoutResponse: false);
      } catch (_) {
        // La balance peut toujours diffuser le poids si elle refuse l'écriture.
        break;
      }
    }
  }

  Future<void> _acknowledgeResult(ScaleDriver driver) async {
    final BluetoothCharacteristic? characteristic = _writeCharacteristic;
    if (characteristic == null) return;
    final List<int>? ack = driver.buildResultAcknowledgement();
    if (ack == null) return;
    try {
      await _handshakeFuture;
      await characteristic.write(ack, withoutResponse: false);
    } catch (_) {
      // Un échec d'accusé ne doit pas interrompre la mesure reçue.
    }
  }

  Future<void> disconnect() async {
    await _connSub?.cancel();
    _connSub = null;
    for (final StreamSubscription<List<int>> s in _notifySubs) {
      await s.cancel();
    }
    _notifySubs.clear();
    _writeCharacteristic = null;
    _profile = null;
    _handshakeFuture = null;
    _handshakeStarted = false;
    _activeDriver?.resetSession();
    _activeDriver = null;
    _ac27Parser.resetSession();
    try {
      await _device?.disconnect();
    } catch (_) {
      // ignore
    }
    _device = null;
    _setStatus(ScaleConnectionStatus.disconnected);
  }

  // ---------------------------------------------------------------------------
  // Mode Simulation (tests sans balance)
  // ---------------------------------------------------------------------------

  /// Génère un cycle de pesée synthétique : montée en poids, stabilisation,
  /// puis émission d'une impédance. Permet de tester l'app et les graphiques.
  void startSimulation({double targetWeightKg = 78.4, int impedance = 512}) {
    stopSimulation();
    _setStatus(ScaleConnectionStatus.connected);

    const int totalTicks = 22;
    int tick = 0;
    _simTimer = Timer.periodic(const Duration(milliseconds: 220), (Timer t) {
      tick++;
      final double progress = (tick / totalTicks).clamp(0, 1);

      if (progress < 1) {
        // Phase de pesée : le poids monte avec une petite oscillation.
        final double base = targetWeightKg * progress;
        final double noise = (tick % 2 == 0 ? 1 : -1) * 0.12;
        final double w = (base + noise).clamp(0, targetWeightKg).toDouble();
        final List<int> raw = <int>[
          0xCF,
          0x00,
          0x00,
          0x00,
          (w * 100).round() >> 8,
          (w * 100).round() & 0xFF,
        ];
        _framesCtrl.add(
          ScaleFrame(
            weightKg: double.parse(w.toStringAsFixed(2)),
            stabilized: false,
            rawHex: toHex(raw),
          ),
        );
      } else {
        // Phase stabilisée + impédance (trame finale).
        final List<int> raw = <int>[
          0xCF,
          0x01,
          0x00,
          0x00,
          (targetWeightKg * 100).round() >> 8,
          (targetWeightKg * 100).round() & 0xFF,
          impedance >> 8,
          impedance & 0xFF,
        ];
        _framesCtrl.add(
          ScaleFrame(
            weightKg: double.parse(targetWeightKg.toStringAsFixed(2)),
            stabilized: true,
            isFinal: true,
            impedanceOhm: impedance,
            rawHex: toHex(raw),
          ),
        );
        stopSimulation();
      }
    });
  }

  void stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
  }

  // ---------------------------------------------------------------------------

  void _setStatus(ScaleConnectionStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<void> dispose() async {
    stopSimulation();
    await _scanSub?.cancel();
    await _connSub?.cancel();
    for (final StreamSubscription<List<int>> s in _notifySubs) {
      await s.cancel();
    }
    _notifySubs.clear();
    await _framesCtrl.close();
    await _statusCtrl.close();
    await _scanCtrl.close();
  }
}
