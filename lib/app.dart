import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'shared/navigation/home_shell.dart';

/// Racine de l'application.
class BalanceApp extends StatelessWidget {
  const BalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardio Balance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}
