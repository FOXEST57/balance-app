import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balance/features/weighing/application/notification_service.dart';
import 'package:balance/features/weighing/application/scale_service.dart';
import 'package:balance/features/weighing/data/app_database.dart';
import 'package:balance/features/weighing/data/measurement_repository.dart';
import 'package:balance/features/weighing/data/profile_repository.dart';
import 'package:balance/features/weighing/data/settings_repository.dart';
import 'package:balance/features/weighing/domain/entities/scale_frame.dart';
import 'package:balance/features/weighing/domain/entities/user_profile.dart';
import 'package:balance/features/weighing/domain/entities/weight_measurement.dart';
import 'package:balance/features/weighing/domain/repositories/i_measurement_repository.dart';
import 'package:balance/features/weighing/domain/repositories/i_profile_repository.dart';
import 'package:balance/features/weighing/domain/repositories/i_settings_repository.dart';
import 'package:balance/features/weighing/domain/services/bia_calculator.dart';

// -----------------------------------------------------------------------------
// Infrastructure
//
// Les providers exposent des **interfaces** (`I*Repository`) et non les
// implémentations concrètes (SQLite). Cela permet de remplacer la source de
// données (ex. API distante du projet global) en modifiant uniquement la
// factory ci-dessous, sans toucher aux consumers.
// -----------------------------------------------------------------------------

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) => AppDatabase.instance,
);

/// Implémentation SQLite injectée partout où une interface de repository est
/// demandée. Pour brancher une source distante, remplacer ces factories.
final Provider<IProfileRepository> profileRepositoryProvider =
    Provider<IProfileRepository>(
      (Ref ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<IMeasurementRepository> measurementRepositoryProvider =
    Provider<IMeasurementRepository>(
      (Ref ref) => MeasurementRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ISettingsRepository> settingsRepositoryProvider =
    Provider<ISettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
    );

/// Service BLE unique pour toute l'application (libéré automatiquement).
final Provider<ScaleService> scaleServiceProvider = Provider<ScaleService>((
  Ref ref,
) {
  final ScaleService service = ScaleService();
  ref.onDispose(service.dispose);
  return service;
});

/// Service de notifications (rappels de pesée).
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService());

/// Option de scan : afficher tous les périphériques (sélection manuelle).
final StateProvider<bool> showAllDevicesProvider = StateProvider<bool>(
  (Ref ref) => false,
);

// -----------------------------------------------------------------------------
// Profils utilisateur (multi-profils)
// -----------------------------------------------------------------------------

class ProfilesNotifier extends AsyncNotifier<List<UserProfile>> {
  @override
  Future<List<UserProfile>> build() async {
    final IProfileRepository repo = ref.watch(profileRepositoryProvider);
    List<UserProfile> list = await repo.all();
    if (list.isEmpty) {
      // Premier lancement : on persiste le profil par défaut.
      await repo.save(UserProfile.defaults.copyWith(isActive: true));
      list = await repo.all();
    }
    return list;
  }

  Future<void> reload() async {
    state = AsyncValue<List<UserProfile>>.data(
      await ref.read(profileRepositoryProvider).all(),
    );
  }

  /// Crée ou met à jour un profil et rafraîchit la liste.
  Future<UserProfile> save(UserProfile profile) async {
    final UserProfile saved = await ref
        .read(profileRepositoryProvider)
        .save(profile);
    await reload();
    return saved;
  }

  Future<void> setActive(int id) async {
    await ref.read(profileRepositoryProvider).setActive(id);
    await reload();
  }

  Future<void> remove(int id) async {
    await ref.read(profileRepositoryProvider).delete(id);
    await reload();
  }
}

final AsyncNotifierProvider<ProfilesNotifier, List<UserProfile>>
profilesProvider = AsyncNotifierProvider<ProfilesNotifier, List<UserProfile>>(
  ProfilesNotifier.new,
);

/// Profil actuellement sélectionné (premier profil si aucun n'est marqué actif).
final Provider<UserProfile> activeProfileProvider = Provider<UserProfile>((
  Ref ref,
) {
  final List<UserProfile>? list = ref.watch(profilesProvider).value;
  if (list == null || list.isEmpty) return UserProfile.defaults;
  return list.firstWhere(
    (UserProfile p) => p.isActive,
    orElse: () => list.first,
  );
});

// -----------------------------------------------------------------------------
// Historique des mesures (du profil actif)
// -----------------------------------------------------------------------------

class MeasurementsNotifier extends AsyncNotifier<List<WeightMeasurement>> {
  @override
  Future<List<WeightMeasurement>> build() async {
    final int? profileId = ref.watch(activeProfileProvider).id;
    if (profileId == null) return const <WeightMeasurement>[];
    return ref.watch(measurementRepositoryProvider).all(profileId: profileId);
  }

  Future<void> reload() async {
    final int? profileId = ref.read(activeProfileProvider).id;
    if (profileId == null) {
      state = const AsyncValue<List<WeightMeasurement>>.data(
        <WeightMeasurement>[],
      );
      return;
    }
    state = const AsyncValue<List<WeightMeasurement>>.loading();
    state = AsyncValue<List<WeightMeasurement>>.data(
      await ref
          .read(measurementRepositoryProvider)
          .all(profileId: profileId),
    );
  }

  Future<WeightMeasurement> add(WeightMeasurement measurement) async {
    final WeightMeasurement inserted = await ref
        .read(measurementRepositoryProvider)
        .insert(measurement);
    await reload();
    return inserted;
  }

  Future<void> updateMeasurement(WeightMeasurement measurement) async {
    await ref.read(measurementRepositoryProvider).update(measurement);
    await reload();
  }

  Future<void> remove(int id) async {
    await ref.read(measurementRepositoryProvider).delete(id);
    await reload();
  }

  Future<void> clearAll() async {
    final int? profileId = ref.read(activeProfileProvider).id;
    await ref.read(measurementRepositoryProvider).deleteAll(profileId: profileId);
    await reload();
  }
}

final AsyncNotifierProvider<MeasurementsNotifier, List<WeightMeasurement>>
measurementsProvider =
    AsyncNotifierProvider<MeasurementsNotifier, List<WeightMeasurement>>(
      MeasurementsNotifier.new,
    );

/// Dernière mesure connue (KPI du Dashboard).
final Provider<WeightMeasurement?> latestMeasurementProvider =
    Provider<WeightMeasurement?>((Ref ref) {
      final List<WeightMeasurement>? list = ref
          .watch(measurementsProvider)
          .value;
      return (list == null || list.isEmpty) ? null : list.first;
    });

// -----------------------------------------------------------------------------
// Pesée en direct / connexion
// -----------------------------------------------------------------------------

class WeighingState {
  const WeighingState({
    this.status = ScaleConnectionStatus.idle,
    this.discovered = const <String, DiscoveredScale>{},
    this.connected,
    this.liveWeightKg,
    this.liveImpedanceOhm,
    this.stabilized = false,
    this.lastRawHex,
    this.simulationMode = false,
    this.error,
    this.lastSaved,
    this.autoConnect = true,
    this.savedScaleName,
    this.reminderEnabled = false,
    this.reminderHour = 8,
    this.reminderMinute = 0,
    this.reminderDayOfWeek = 1,
    this.reminderRepeat = ReminderRepeat.weekly,
  });

  final ScaleConnectionStatus status;
  final Map<String, DiscoveredScale> discovered;
  final DiscoveredScale? connected;
  final double? liveWeightKg;
  final int? liveImpedanceOhm;
  final bool stabilized;
  final String? lastRawHex;
  final bool simulationMode;
  final String? error;
  final WeightMeasurement? lastSaved;

  /// Reconnexion automatique à la balance mémorisée.
  final bool autoConnect;

  /// Nom de la balance mémorisée (null tant qu'aucune n'a été appairée).
  final String? savedScaleName;

  /// Rappel de pesée quotidien activé ?
  final bool reminderEnabled;

  /// Heure du rappel de pesée (0-23).
  final int reminderHour;

  /// Minute du rappel de pesée (0-59).
  final int reminderMinute;

  /// Jour de la semaine du rappel (1=lundi … 7=dimanche).
  final int reminderDayOfWeek;

  /// Fréquence de répétition du rappel.
  final ReminderRepeat reminderRepeat;

  bool get isScanning => status == ScaleConnectionStatus.scanning;
  bool get isConnected =>
      status == ScaleConnectionStatus.connected || simulationMode;

  WeighingState copyWith({
    ScaleConnectionStatus? status,
    Map<String, DiscoveredScale>? discovered,
    DiscoveredScale? connected,
    bool clearConnected = false,
    double? liveWeightKg,
    int? liveImpedanceOhm,
    bool clearLiveImpedance = false,
    bool? stabilized,
    String? lastRawHex,
    bool? simulationMode,
    String? error,
    bool clearError = false,
    WeightMeasurement? lastSaved,
    bool? autoConnect,
    String? savedScaleName,
    bool clearSavedScaleName = false,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? reminderDayOfWeek,
    ReminderRepeat? reminderRepeat,
  }) {
    return WeighingState(
      status: status ?? this.status,
      discovered: discovered ?? this.discovered,
      connected: clearConnected ? null : (connected ?? this.connected),
      liveWeightKg: liveWeightKg ?? this.liveWeightKg,
      liveImpedanceOhm: clearLiveImpedance
          ? null
          : (liveImpedanceOhm ?? this.liveImpedanceOhm),
      stabilized: stabilized ?? this.stabilized,
      lastRawHex: lastRawHex ?? this.lastRawHex,
      simulationMode: simulationMode ?? this.simulationMode,
      error: clearError ? null : (error ?? this.error),
      lastSaved: lastSaved ?? this.lastSaved,
      autoConnect: autoConnect ?? this.autoConnect,
      savedScaleName: clearSavedScaleName
          ? null
          : (savedScaleName ?? this.savedScaleName),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderDayOfWeek: reminderDayOfWeek ?? this.reminderDayOfWeek,
      reminderRepeat: reminderRepeat ?? this.reminderRepeat,
    );
  }
}

class WeighingNotifier extends Notifier<WeighingState> {
  StreamSubscription<ScaleFrame>? _frameSub;
  StreamSubscription<ScaleConnectionStatus>? _statusSub;
  StreamSubscription<Map<String, DiscoveredScale>>? _scanSub;

  bool _savedThisCycle = false;
  WeightMeasurement? _savedCycleMeasurement;
  ScaleFrame? _pendingFinalFrame;
  bool _disposed = false;

  @override
  WeighingState build() {
    _disposed = false;
    final ScaleService service = ref.watch(scaleServiceProvider);

    _statusSub = service.status.listen((ScaleConnectionStatus s) {
      if (_disposed) return;
      state = state.copyWith(status: s);
    });
    _scanSub = service.scanResults.listen((Map<String, DiscoveredScale> m) {
      if (_disposed) return;
      state = state.copyWith(discovered: m);
    });
    _frameSub = service.frames.listen((ScaleFrame frame) {
      if (_disposed) return;
      _onFrame(frame);
    });

    ref.onDispose(() {
      _disposed = true;
      unawaited(_frameSub?.cancel());
      unawaited(_statusSub?.cancel());
      unawaited(_scanSub?.cancel());
    });

    // Charge la balance mémorisée et tente une reconnexion automatique.
    unawaited(_loadPreferences());

    return const WeighingState();
  }

  // --- Reconnexion automatique ----------------------------------------------

  /// Lit les préférences persistées puis, si la reconnexion est active et
  /// qu'une balance a été appairée auparavant, tente de s'y reconnecter.
  Future<void> _loadPreferences() async {
    String? id;
    String? name;
    String? enabled;
    String? reminderEnabled;
    String? reminderTime;
    String? reminderDayOfWeek;
    String? reminderRepeat;
    try {
      final ISettingsRepository settings = ref.read(settingsRepositoryProvider);
      id = await settings.read(kLastScaleIdKey);
      name = await settings.read(kLastScaleNameKey);
      enabled = await settings.read(kAutoConnectEnabledKey);
      reminderEnabled = await settings.read(kReminderEnabledKey);
      reminderTime = await settings.read(kReminderTimeKey);
      reminderDayOfWeek = await settings.read(kReminderDayOfWeekKey);
      reminderRepeat = await settings.read(kReminderRepeatKey);
    } catch (_) {
      // Préférences indisponibles : on continue sans reconnexion automatique.
      return;
    }
    if (_disposed) return;

    final bool auto = enabled != 'false';
    final bool reminderOn = reminderEnabled == 'true';
    int hour = 8;
    int minute = 0;
    if (reminderTime != null && reminderTime.contains(':')) {
      final List<String> parts = reminderTime.split(':');
      hour = int.tryParse(parts[0]) ?? 8;
      minute = int.tryParse(parts[1]) ?? 0;
    }
    final int dayOfWeek = int.tryParse(reminderDayOfWeek ?? '1') ?? 1;
    final ReminderRepeat repeat = switch (reminderRepeat) {
      'biweekly' => ReminderRepeat.biweekly,
      'monthly' => ReminderRepeat.monthly,
      _ => ReminderRepeat.weekly,
    };

    state = state.copyWith(
      autoConnect: auto,
      savedScaleName: (name != null && name.isNotEmpty) ? name : null,
      reminderEnabled: reminderOn,
      reminderHour: hour,
      reminderMinute: minute,
      reminderDayOfWeek: dayOfWeek,
      reminderRepeat: repeat,
    );

    if (auto && id != null && id.isNotEmpty) {
      unawaited(_tryAutoConnect(id));
    }

    // Reprogramme le rappel bi-mensuel si nécessaire (pas de répétition native).
    if (reminderOn) {
      unawaited(
        ref.read(notificationServiceProvider).ensureNextReminder(
          enabled: true,
          hour: hour,
          minute: minute,
          dayOfWeek: dayOfWeek,
          repeat: repeat,
        ),
      );
    }
  }

  /// Active/désactive la reconnexion automatique (persistée).
  Future<void> setAutoConnect(bool enabled) async {
    await ref
        .read(settingsRepositoryProvider)
        .write(kAutoConnectEnabledKey, enabled ? 'true' : 'false');
    if (_disposed) return;
    state = state.copyWith(autoConnect: enabled);
  }

  /// Active/désactive le rappel de pesée et planifie la prochaine occurrence.
  Future<void> setReminder({
    required bool enabled,
    int? hour,
    int? minute,
    int? dayOfWeek,
    ReminderRepeat? repeat,
  }) async {
    final ISettingsRepository settings = ref.read(settingsRepositoryProvider);
    await settings.write(kReminderEnabledKey, enabled ? 'true' : 'false');
    final int h = hour ?? state.reminderHour;
    final int m = minute ?? state.reminderMinute;
    final int dow = dayOfWeek ?? state.reminderDayOfWeek;
    final ReminderRepeat rep = repeat ?? state.reminderRepeat;
    await settings.write(
      kReminderTimeKey,
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
    );
    await settings.write(kReminderDayOfWeekKey, dow.toString());
    await settings.write(kReminderRepeatKey, rep.name);

    if (_disposed) return;
    state = state.copyWith(
      reminderEnabled: enabled,
      reminderHour: h,
      reminderMinute: m,
      reminderDayOfWeek: dow,
      reminderRepeat: rep,
    );

    final NotificationService notif = ref.read(notificationServiceProvider);
    if (enabled) {
      final bool granted = await notif.requestPermission();
      if (!granted) {
        state = state.copyWith(reminderEnabled: false);
        await settings.write(kReminderEnabledKey, 'false');
        return;
      }
      await notif.scheduleReminder(
        hour: h,
        minute: m,
        dayOfWeek: dow,
        repeat: rep,
      );
    } else {
      await notif.cancelReminder();
    }
  }

  Future<void> _tryAutoConnect(String remoteId) async {
    if (_disposed) return;
    final ScaleService service = ref.read(scaleServiceProvider);
    if (service.currentStatus == ScaleConnectionStatus.connected) return;

    try {
      if (!await service.isAdapterOn()) return;
    } catch (_) {
      return;
    }
    if (_disposed) return;

    // Scan court : la balance est reconnue dès qu'elle s'allume et diffuse.
    unawaited(_scanAndConnect(remoteId));
  }

  /// Scan court : se connecte dès que la balance mémorisée est détectée.
  Future<void> _scanAndConnect(String remoteId) async {
    if (_disposed) return;
    final ScaleService service = ref.read(scaleServiceProvider);

    final Completer<void> done = Completer<void>();
    StreamSubscription<Map<String, DiscoveredScale>>? sub;
    sub = service.scanResults.listen((Map<String, DiscoveredScale> m) {
      final DiscoveredScale? found = m[remoteId];
      if (found == null || _disposed) return;
      unawaited(sub?.cancel());
      if (!done.isCompleted) done.complete();
      unawaited(_connectTo(found).catchError((Object _) {}));
    });

    try {
      await service.startScan(
        showAllDevices: true,
        timeout: const Duration(seconds: 20),
      );
    } catch (_) {
      // Scan impossible (permissions/Bluetooth) : on abandonne silencieusement.
    }
    await sub.cancel();
    if (!done.isCompleted) done.complete();
  }

  /// Connexion effective puis mémorisation de la balance appairée.
  Future<void> _connectTo(DiscoveredScale scale) async {
    await ref
        .read(scaleServiceProvider)
        .connect(scale, profile: ref.read(activeProfileProvider));
    if (_disposed) return;
    state = state.copyWith(connected: scale, simulationMode: false);

    try {
      final ISettingsRepository settings = ref.read(settingsRepositoryProvider);
      await settings.write(kLastScaleIdKey, scale.remoteId);
      await settings.write(kLastScaleNameKey, scale.name);
    } catch (_) {
      // La mémorisation est un confort : une erreur ne doit pas casser la
      // connexion en cours.
      return;
    }
    if (_disposed) return;
    state = state.copyWith(savedScaleName: scale.name);
  }

  // --- Actions ---------------------------------------------------------------

  Future<void> startScan({bool showAll = false}) async {
    state = state.copyWith(clearError: true);
    try {
      await ref.read(scaleServiceProvider).startScan(showAllDevices: showAll);
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        status: ScaleConnectionStatus.error,
        error: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> stopScan() async {
    await ref.read(scaleServiceProvider).stopScan();
  }

  Future<void> connect(DiscoveredScale scale) async {
    try {
      await _connectTo(scale);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        error: 'Connexion impossible : ${e.toString()}',
        status: ScaleConnectionStatus.error,
      );
    }
  }

  Future<void> disconnect() async {
    await ref.read(scaleServiceProvider).disconnect();
    if (_disposed) return;
    state = WeighingState(
      discovered: state.discovered,
      lastSaved: state.lastSaved,
      autoConnect: state.autoConnect,
      savedScaleName: state.savedScaleName,
    );
  }

  /// Démarre le mode Simulation (aucun matériel requis).
  void startSimulation({double targetWeightKg = 78.4, int impedance = 512}) {
    state = state.copyWith(
      simulationMode: true,
      clearError: true,
      status: ScaleConnectionStatus.connected,
    );
    ref
        .read(scaleServiceProvider)
        .startSimulation(targetWeightKg: targetWeightKg, impedance: impedance);
  }

  void stopSimulation() {
    ref.read(scaleServiceProvider).stopSimulation();
    state = WeighingState(
      discovered: state.discovered,
      lastSaved: state.lastSaved,
      autoConnect: state.autoConnect,
      savedScaleName: state.savedScaleName,
    );
  }

  /// Enregistre manuellement un poids (sans balance).
  Future<void> saveManualWeight(double weightKg) async {
    final UserProfile profile =
        ref.read(activeProfileProvider);
    final WeightMeasurement m = _buildMeasurement(
      weightKg: weightKg,
      impedance: null,
      source: MeasurementSource.manual,
      profile: profile,
    );
    await ref.read(measurementsProvider.notifier).add(m);
    if (_disposed) return;
    state = state.copyWith(lastSaved: m);
  }

  // --- Réception des trames --------------------------------------------------

  void _onFrame(ScaleFrame frame) {
    if (_disposed) return;
    // Nouvelle pesée en cours (poids non stabilisé) => on réautorise la sauvegarde.
    if (!frame.stabilized) {
      _savedThisCycle = false;
      _savedCycleMeasurement = null;
      _pendingFinalFrame = null;
    }

    state = state.copyWith(
      liveWeightKg: frame.isUnloaded
          ? 0
          : (frame.weightKg > 0 ? frame.weightKg : state.liveWeightKg),
      clearLiveImpedance: frame.isUnloaded,
      liveImpedanceOhm: frame.impedanceOhm ?? state.liveImpedanceOhm,
      stabilized: frame.stabilized,
      lastRawHex: frame.rawHex,
    );

    if (frame.isFinal && frame.impedanceOhm != null) {
      final WeightMeasurement? saved = _savedCycleMeasurement;
      if (saved == null) {
        _pendingFinalFrame = frame;
      } else {
        unawaited(_applyFinalFrame(saved, frame));
      }
    }

    if (frame.stabilized && frame.weightKg > 0 && !_savedThisCycle) {
      _savedThisCycle = true;
      unawaited(_autoSave(_pendingFinalFrame ?? frame));
      _pendingFinalFrame = null;
    }
  }

  Future<void> _autoSave(ScaleFrame frame) async {
    if (_disposed) return;
    final UserProfile profile =
        ref.read(activeProfileProvider);
    final WeightMeasurement m = _buildMeasurement(
      weightKg: frame.weightKg,
      impedance: frame.impedanceOhm,
      source: state.simulationMode
          ? MeasurementSource.simulation
          : MeasurementSource.ble,
      profile: profile,
    );
    final WeightMeasurement saved = await ref
        .read(measurementsProvider.notifier)
        .add(m);
    if (_disposed) return;
    _savedCycleMeasurement = saved;
    state = state.copyWith(lastSaved: saved);

    final ScaleFrame? pending = _pendingFinalFrame;
    if (pending != null && pending.weightKg == saved.weightKg) {
      _pendingFinalFrame = null;
      await _applyFinalFrame(saved, pending);
    }
  }

  Future<void> _applyFinalFrame(
    WeightMeasurement saved,
    ScaleFrame frame,
  ) async {
    if (_disposed) return;
    final UserProfile profile =
        ref.read(activeProfileProvider);
    final WeightMeasurement updated = saved.copyWith(
      composition: BiaCalculator.compute(
        weightKg: frame.weightKg,
        profile: profile,
        impedanceOhm: frame.impedanceOhm,
      ),
    );
    await ref.read(measurementsProvider.notifier).updateMeasurement(updated);
    if (_disposed) return;
    _savedCycleMeasurement = updated;
    state = state.copyWith(lastSaved: updated);
  }

  WeightMeasurement _buildMeasurement({
    required double weightKg,
    required int? impedance,
    required MeasurementSource source,
    required UserProfile profile,
  }) {
    final composition = BiaCalculator.compute(
      weightKg: weightKg,
      profile: profile,
      impedanceOhm: impedance,
    );
    return WeightMeasurement(
      profileId: profile.id,
      timestamp: DateTime.now(),
      composition: composition,
      source: source,
    );
  }
}

final NotifierProvider<WeighingNotifier, WeighingState> weighingProvider =
    NotifierProvider<WeighingNotifier, WeighingState>(WeighingNotifier.new);
