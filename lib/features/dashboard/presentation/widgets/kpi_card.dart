import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';

/// Carte KPI compacte affichant une valeur principale (en kg) et une valeur
/// secondaire libre (pourcentage, IMC, kcal…).
///
/// Exemple : « Masse grasse  •  13.87 kg  •  18.50 % »
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.primaryValue,
    required this.secondaryText,
    this.primaryUnit = 'kg',
  });

  final String label;
  final IconData icon;
  final Color accent;
  final double? primaryValue;
  final String? secondaryText;
  final String primaryUnit;

  @override
  Widget build(BuildContext context) {
    final bool hasData = primaryValue != null;
    return GlassCard(
      accent: accent,
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasData
                ? '${primaryValue!.toStringAsFixed(2)} $primaryUnit'
                : '--.-- $primaryUnit',
            style: AppTheme.numeric(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            secondaryText ?? '—',
            style: AppTheme.numeric(11.5, weight: FontWeight.w500, color: accent),
          ),
        ],
      ),
    );
  }
}
