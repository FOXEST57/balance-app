import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Fréquence de répétition du rappel de pesée.
enum ReminderRepeat {
  /// Chaque semaine le même jour.
  weekly,

  /// Tous les 15 jours.
  biweekly,

  /// Tous les mois le même jour.
  monthly,
}

extension ReminderRepeatLabel on ReminderRepeat {
  String get label {
    switch (this) {
      case ReminderRepeat.weekly:
        return 'Chaque semaine';
      case ReminderRepeat.biweekly:
        return 'Tous les 15 jours';
      case ReminderRepeat.monthly:
        return 'Tous les mois';
    }
  }
}

/// Service de notifications pour planifier des rappels de pesée.
class NotificationService {
  NotificationService() {
    tz.initializeTimeZones();
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'weighing_reminders';
  static const String _channelName = 'Rappels de pesée';
  static const String _channelDesc =
      'Rappels pour ne pas oublier de monter sur la balance.';
  static const int _notificationId = 1001;

  bool _initialized = false;

  /// Initialise le plugin de notifications (doit être appelé au démarrage).
  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.defaultImportance,
          ),
        );

    _initialized = true;
  }

  /// Demande la permission d'afficher des notifications (Android 13+).
  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final bool? granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Planifie un rappel de pesée.
  ///
  /// - [hour]/[minute] : heure du rappel
  /// - [dayOfWeek] : jour de la semaine (1=lundi … 7=dimanche), utilisé pour
  ///   la répétition hebdomadaire.
  /// - [repeat] : fréquence de répétition.
  Future<void> scheduleReminder({
    required int hour,
    required int minute,
    required int dayOfWeek,
    required ReminderRepeat repeat,
  }) async {
    await _cancelAll();

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    switch (repeat) {
      case ReminderRepeat.weekly:
        // Répétition automatique chaque semaine le même jour.
        await _plugin.zonedSchedule(
          _notificationId,
          'Il est l\'heure de vous peser ⚖️',
          'Pensez à monter sur votre balance pour suivre votre évolution.',
          _nextWeekly(now, dayOfWeek, hour, minute),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        break;

      case ReminderRepeat.monthly:
        // Répétition automatique chaque mois le même jour du mois.
        await _plugin.zonedSchedule(
          _notificationId,
          'Il est l\'heure de vous peser ⚖️',
          'Pensez à monter sur votre balance pour suivre votre évolution.',
          _nextMonthly(now, dayOfWeek, hour, minute),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
        break;

      case ReminderRepeat.biweekly:
        // Pas de répétition native : on planifie la prochaine occurrence
        // (15 jours après le dernier jour programmé). La reprogrammation
        // est assurée par [ensureNextReminder] au démarrage de l'app.
        await _plugin.zonedSchedule(
          _notificationId,
          'Il est l\'heure de vous peser ⚖️',
          'Pensez à monter sur votre balance pour suivre votre évolution.',
          _nextBiweekly(now, dayOfWeek, hour, minute),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        break;
    }
  }

  /// Vérifie si le rappel bi-mensuel doit être reprogrammé et le fait si
  /// nécessaire. À appeler au démarrage de l'application.
  Future<void> ensureNextReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required int dayOfWeek,
    required ReminderRepeat repeat,
  }) async {
    if (!enabled) return;
    if (repeat != ReminderRepeat.biweekly) return;

    final List<PendingNotificationRequest> pending =
        await _plugin.pendingNotificationRequests();
    if (pending.any((PendingNotificationRequest p) => p.id == _notificationId)) {
      return; // déjà programmé
    }

    await scheduleReminder(
      hour: hour,
      minute: minute,
      dayOfWeek: dayOfWeek,
      repeat: repeat,
    );
  }

  /// Annule le rappel de pesée.
  Future<void> cancelReminder() async {
    await _cancelAll();
  }

  Future<void> _cancelAll() async {
    await _plugin.cancel(_notificationId);
  }

  // --- Calcul des prochaines occurrences -------------------------------------

  /// Prochain jour [dayOfWeek] (1=lundi) à [hour]:[minute].
  tz.TZDateTime _nextWeekly(
    tz.TZDateTime now,
    int dayOfWeek,
    int hour,
    int minute,
  ) {
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // Décale au prochain jour de la semaine correspondant.
    while (candidate.weekday != dayOfWeek || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Prochain [dayOfWeek] du mois à [hour]:[minute] (si dépassé, mois suivant).
  tz.TZDateTime _nextMonthly(
    tz.TZDateTime now,
    int dayOfMonth,
    int hour,
    int minute,
  ) {
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      dayOfMonth,
      hour,
      minute,
    );
    if (candidate.isBefore(now)) {
      candidate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        dayOfMonth,
        hour,
        minute,
      );
    }
    return candidate;
  }

  /// Prochaine occurrence bi-mensuelle : on prend le prochain [dayOfWeek] puis
  /// on ajoute 15 jours si une période de 15 jours vient de s'écouler.
  ///
  /// Pour simplifier, on programme toujours 15 jours à compter du prochain
  /// jour de semaine cible (cela garantit une occurrence toutes les 2 semaines
  /// environ).
  tz.TZDateTime _nextBiweekly(
    tz.TZDateTime now,
    int dayOfWeek,
    int hour,
    int minute,
  ) {
    final tz.TZDateTime nextWeekly = _nextWeekly(now, dayOfWeek, hour, minute);
    // 15 jours après le prochain jour cible = occurrence dans ~2 semaines.
    return nextWeekly.add(const Duration(days: 14));
  }
}
