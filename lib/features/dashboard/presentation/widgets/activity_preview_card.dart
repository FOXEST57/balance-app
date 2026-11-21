import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../activity/presentation/activity_provider.dart';

/// Carte d'aperçu de l'activité du jour (pas + calories), cliquable pour
/// ouvrir le module Activité.
class ActivityPreviewCard extends ConsumerWidget {
  const ActivityPreviewCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ActivityState> state = ref.watch(activityProvider);
    final int steps = state.value?.todayStepsLive ?? 0;
    final double kcal = state.value?.today.kcal ?? 0;

    return GlassCard(
      accent: AppColors.violet,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.violet.withValues(alpha: 0.4), width: 1),
            ),
            child: const Icon(Icons.directions_run_rounded,
                color: AppColors.violet, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Activité du jour',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '$steps pas · ${kcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
