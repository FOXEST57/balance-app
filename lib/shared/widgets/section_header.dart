import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Titre de section avec trait néon optionnel.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = AppColors.cyan,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTheme.numeric(16, weight: FontWeight.w600),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
