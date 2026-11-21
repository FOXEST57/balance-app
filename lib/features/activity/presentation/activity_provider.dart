import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../weighing/domain/entities/weight_measurement.dart';
import '../../weighing/domain/repositories/i_settings_repository.dart';
import '../application/step_counter_service.dart';
import '../data/activity_repository.dart';
import '../domain/entities/activity_daily_summary.dart';
import '../domain/entities/activity_entry.dart';
import '../domain/entities/activity_goals.dart';
import '../domain/entities/activity_type.dart';
import '../domain/repositories/i_activity_repository.dart';
import '../domain/services/calorie_calculator.dart';

/// État complet du module Activité.
class ActivityState {
  const ActivityState({
    required this.today,
    required this.week,
    required this.month,
    required this.goals,
    this.todayStepsLive = 0,
  });

  final ActivityDailySummary today;
  final List<ActivityDailySummary> week;
  final List<ActivityDailySummary> month;
  final ActivityGoals goals;

  /// Pas du jour en direct (mis à jour par le flux du capteur).
  final int todayStepsLive;

  /// Pourcentage d'atteinte de l'objectif de pas.
  double get stepsProgress =>
      goals.steps > 0 ? (todayStepsLive / goals.steps).clamp(0.0, 1.0) : 0.0;

  double get kcalProgress =>
      goals.kcal > 0 ? (today.kcal / goals.kcal).clamp(0.0, 1.0) : 0.0;

  double get minutesProgress =>
      goals.minutes > 0
          ? (today.minutes / goals.minutes).clamp(0.0, 1.0)
          : 0.0;

  ActivityState copyWith({
    ActivityDailySummary? today,
    List<ActivityDailySummary>? week,
    List<ActivityDailySummary>? month,
    ActivityGoals? goals,
    int? todayStepsLive,
  }) {
    return ActivityState(
      today: today ?? this.today,
      week: week ?? this.week,
      month: month ?? this.month,
      goals: goals ?? this.goals,
      todayStepsLive: todayStepsLive ?? this.todayStepsLive,
    );
  }
}

class ActivityNotifier extends AsyncNotifier<ActivityState> {
  StepCounterService? _stepService;
  StreamSubscription<int>? _stepsSub;

  @override
  Future<ActivityState> build() async {
    final IActivityRepository repo = ref.watch(activityRepositoryProvider);
    final ISettingsRepository settings = ref.watch(settingsRepositoryProvider);
    final WeightMeasurement? latest = ref.watch(latestMeasurementProvider);
    final double weightKg = latest?.composition.weightKg ?? 80.0;

    // Démarre le service de comptage de pas.
    _stepService = StepCounterService(repo, settings);
    _stepService!.updateWeight(weightKg);
    unawaited(_stepService!.start());

    _stepsSub = _stepService!.stepsStream.listen((int steps) {
      final ActivityState? current = state.value;
      if (current == null) return;
      state = AsyncValue<ActivityState>.data(
        current.copyWith(todayStepsLive: steps),
      );
    });

    ref.onDispose(() {
      unawaited(_stepsSub?.cancel());
      unawaited(_stepService?.dispose());
    });

    // Le build surveille déjà activeProfileProvider et latestMeasurementProvider
    // : le notifier se reconstruit automatiquement quand le poids change.

    return _load(repo, settings);
  }

  Future<ActivityState> _load(
    IActivityRepository repo,
    ISettingsRepository settings,
  ) async {
    final DateTime now = DateTime.now();

    // Objectifs.
    final String? goalsRaw = await settings.read(kActivityGoalsKey);
    final ActivityGoals goals = ActivityGoals.deserialize(goalsRaw);

    // Aujourd'hui.
    final List<ActivityEntry> todayEntries = await repo.forDay(now);
    final ActivityDailySummary today =
        ActivityDailySummary.fromEntries(now, todayEntries);

    // Semaine (7 derniers jours).
    final List<ActivityDailySummary> week = await _loadRange(
      repo,
      now.subtract(const Duration(days: 6)),
      7,
    );

    // Mois (30 derniers jours).
    final List<ActivityDailySummary> month = await _loadRange(
      repo,
      now.subtract(const Duration(days: 29)),
      30,
    );

    return ActivityState(
      today: today,
      week: week,
      month: month,
      goals: goals,
      todayStepsLive: _stepService?.todaySteps ?? today.steps,
    );
  }

  Future<List<ActivityDailySummary>> _loadRange(
    IActivityRepository repo,
    DateTime start,
    int days,
  ) async {
    final List<ActivityDailySummary> result = <ActivityDailySummary>[];
    for (int i = 0; i < days; i++) {
      final DateTime day = start.add(Duration(days: i));
      final List<ActivityEntry> entries = await repo.forDay(day);
      result.add(ActivityDailySummary.fromEntries(day, entries));
    }
    return result;
  }

  Future<void> reload() async {
    final IActivityRepository repo = ref.read(activityRepositoryProvider);
    final ISettingsRepository settings = ref.read(settingsRepositoryProvider);
    state = const AsyncValue<ActivityState>.loading();
    state = AsyncValue<ActivityState>.data(await _load(repo, settings));
  }

  /// Ajoute une séance d'activité manuelle.
  Future<void> addSession({
    required ActivityType type,
    required int minutes,
    String? note,
  }) async {
    final WeightMeasurement? latest = ref.read(latestMeasurementProvider);
    final double weightKg = latest?.composition.weightKg ?? 80.0;
    final double kcal = CalorieCalculator.fromDuration(
      type: type,
      weightKg: weightKg,
      minutes: minutes,
    );
    final ActivityEntry entry = ActivityEntry(
      day: ActivityEntry.dayStartOf(DateTime.now()),
      activeKcal: kcal,
      sessionMinutes: minutes,
      activityType: type,
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(activityRepositoryProvider).insert(entry);
    await reload();
  }

  /// Supprime une séance.
  Future<void> removeSession(int id) async {
    await ref.read(activityRepositoryProvider).delete(id);
    await reload();
  }

  /// Met à jour les objectifs quotidiens.
  Future<void> updateGoals(ActivityGoals goals) async {
    await ref
        .read(settingsRepositoryProvider)
        .write(kActivityGoalsKey, goals.serialize());
    final ActivityState? current = state.value;
    if (current != null) {
      state = AsyncValue<ActivityState>.data(
        current.copyWith(goals: goals),
      );
    }
  }
}

final AsyncNotifierProvider<ActivityNotifier, ActivityState> activityProvider =
    AsyncNotifierProvider<ActivityNotifier, ActivityState>(
      ActivityNotifier.new,
    );

final Provider<IActivityRepository> activityRepositoryProvider =
    Provider<IActivityRepository>((Ref ref) {
      return ActivityRepository(ref.watch(appDatabaseProvider));
    });
