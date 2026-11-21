import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';

import '../../weighing/domain/repositories/i_settings_repository.dart';
import '../domain/entities/activity_entry.dart';
import '../domain/repositories/i_activity_repository.dart';
import '../domain/services/calorie_calculator.dart';

/// Service de comptage de pas via le capteur pédomètre du téléphone.
///
/// Écoute le flux de pas cumulés depuis le dernier redémarrage, calcule les
/// pas de la journée (en soustrayant la référence de minuit) et persiste
/// le résultat dans la table `activity_entries`.
///
/// Expose un [Stream] du nombre de pas du jour pour que l'UI se mette à
/// jour en temps réel.
class StepCounterService {
  StepCounterService(this._repo, this._settings);

  final IActivityRepository _repo;
  final ISettingsRepository _settings;

  final StreamController<int> _stepsCtrl = StreamController<int>.broadcast();
  StreamSubscription<StepCount>? _sub;

  int? _baselineSteps;
  int? _baselineDay;
  int _todaySteps = 0;
  double _weightKg = 80.0;

  /// Nombre de pas de la journée en cours.
  int get todaySteps => _todaySteps;

  /// Flux du nombre de pas de la journée (mis à jour en temps réel).
  Stream<int> get stepsStream => _stepsCtrl.stream;

  /// Met à jour le poids utilisé pour l'estimation des calories.
  void updateWeight(double weightKg) {
    _weightKg = weightKg > 0 ? weightKg : 80.0;
  }

  /// Démarre l'écoute du pédomètre.
  Future<void> start() async {
    if (_sub != null) return;

    // Demande la permission de reconnaissance d'activité (Android 10+).
    try {
      await Permission.activityRecognition.request();
    } catch (_) {
      // Permission refusée ou indisponible : on continue sans comptage auto.
    }

    // Charge la référence de minuit si elle existe.
    final String? baselineDayRaw =
        await _settings.read(kActivityBaselineDayKey);
    final String? baselineStepsRaw =
        await _settings.read(kActivityBaselineStepsKey);

    final int today = ActivityEntry.dayStartOf(DateTime.now());
    _baselineDay = int.tryParse(baselineDayRaw ?? '');
    _baselineSteps = int.tryParse(baselineStepsRaw ?? '');

    // Si la référence est périmée (autre jour), on la réinitialisera dès la
    // première mesure reçue.
    if (_baselineDay != today) {
      _baselineSteps = null;
      _baselineDay = null;
    }

    _sub = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onError,
    );
  }

  Future<void> _onStepCount(StepCount event) async {
    final int today = ActivityEntry.dayStartOf(DateTime.now());
    final int cumulative = event.steps;

    // Changement de jour : nouvelle référence.
    if (_baselineDay != today || _baselineSteps == null) {
      _baselineDay = today;
      _baselineSteps = cumulative;
      await _settings.write(kActivityBaselineDayKey, today.toString());
      await _settings.write(
        kActivityBaselineStepsKey,
        cumulative.toString(),
      );
    }

    final int steps = (cumulative - (_baselineSteps ?? cumulative))
        .clamp(0, 1 << 31);
    _todaySteps = steps;
    _stepsCtrl.add(steps);

    // Persiste l'agrégat de la journée (pas + calories + minutes estimées).
    final double kcal = CalorieCalculator.fromSteps(
      steps: steps,
      weightKg: _weightKg,
    );
    final int minutes = CalorieCalculator.minutesFromSteps(steps);
    try {
      await _repo.upsertStepsForDay(
        day: DateTime.now(),
        steps: steps,
        kcal: kcal,
        minutes: minutes,
      );
    } catch (_) {
      // La persistance est non bloquante : on continue d'écouter.
    }
  }

  void _onError(Object error) {
    // Capteur indisponible ou permission refusée : le service reste inactif
    // mais l'application continue de fonctionner (saisie manuelle possible).
  }

  /// Arrête l'écoute du pédomètre.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _stepsCtrl.close();
  }
}

/// Clé settings : jour de la référence de pas (minuit en millis).
const String kActivityBaselineDayKey = 'activity_baseline_day';

/// Clé settings : nombre de pas cumulés au moment de la référence.
const String kActivityBaselineStepsKey = 'activity_baseline_steps';

/// Clé settings : objectifs d'activité quotidiens (sérialisés).
const String kActivityGoalsKey = 'activity_goals';
