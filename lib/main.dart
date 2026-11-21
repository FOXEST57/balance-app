import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/theme/app_colors.dart';
import 'features/weighing/application/notification_service.dart';

/// Point d'entrée de l'application.
///
/// Active le mode plein écran immersif (masquage des barres système) comme
/// demandé pour les applications dédiées.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise le service de notifications (canal Android + permissions iOS).
  final NotificationService notificationService = NotificationService();
  await notificationService.initialize();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const BalanceApp(),
    ),
  );
}
