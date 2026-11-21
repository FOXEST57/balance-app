import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/num_fmt.dart';
import '../../../shared/navigation/home_shell.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../weighing/domain/entities/weight_measurement.dart';

/// Écran « Historique » : liste chronologique avec variation par rapport à la
/// pesée précédente et suppression d'une entrée.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WeightMeasurement>> async = ref.watch(
      measurementsProvider,
    );

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace s) => Center(
        child: Text(
          'Erreur : $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (List<WeightMeasurement> items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.history_rounded,
                    size: 46,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Aucune pesée enregistrée.\nConnectez la balance ou utilisez\nle mode Simulation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, kHomeNavBarClearance),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: 10),
          itemBuilder: (BuildContext context, int i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Historique',
                    style: AppTheme.numeric(22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${items.length} pesée${items.length > 1 ? 's' : ''} enregistrée${items.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              );
            }

            final WeightMeasurement m = items[i - 1];
            final WeightMeasurement? previous = i < items.length
                ? items[i]
                : null;
            final double? delta = previous == null
                ? null
                : m.weightKg - previous.weightKg;

            return Dismissible(
              key: ValueKey<int>(m.id ?? m.timestamp.millisecondsSinceEpoch),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 22),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
              ),
              confirmDismiss: (_) => _confirmDelete(context),
              onDismissed: (_) {
                if (m.id != null) {
                  ref.read(measurementsProvider.notifier).remove(m.id!);
                }
              },
              child: _MeasurementTile(measurement: m, delta: delta),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Supprimer cette pesée ?'),
        content: const Text('Cette action est définitive.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({required this.measurement, this.delta});

  final WeightMeasurement measurement;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final bool isDown = (delta ?? 0) <= 0;
    final Color deltaColor = isDown ? AppColors.emerald : AppColors.coral;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      fmtKg(measurement.weightKg),
                      style: AppTheme.numeric(20, weight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    if (delta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: deltaColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          fmtDeltaKg(delta!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: deltaColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${fmtDateTime(measurement.timestamp)}  •  ${measurement.source.label}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: <Widget>[
                    _MiniStat(
                      label: 'Gras',
                      value: fmtKgOpt(measurement.composition.fatMassKg),
                      color: AppColors.coral,
                    ),
                    _MiniStat(
                      label: 'Muscle',
                      value: fmtKgOpt(measurement.composition.muscleMassKg),
                      color: AppColors.emerald,
                    ),
                    _MiniStat(
                      label: 'Eau',
                      value: fmtKg(measurement.composition.waterMassKg),
                      color: AppColors.cyan,
                    ),
                    _MiniStat(
                      label: 'IMC',
                      value: fmtBmi(measurement.composition.bmi),
                      color: AppColors.amber,
                    ),
                    if (measurement.waistCm != null)
                      _MiniStat(
                        label: 'Tour de taille',
                        value: fmtCm(measurement.waistCm!),
                        color: AppColors.violet,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: AppTheme.numeric(
            10.5,
            weight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
