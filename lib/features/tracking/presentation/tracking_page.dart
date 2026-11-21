import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/navigation/home_shell.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../weighing/domain/entities/weight_measurement.dart';
import 'widgets/metric_chart.dart';

/// Période d'analyse des graphiques.
enum ChartPeriod {
  d7('7J', 7),
  m1('1M', 30),
  m3('3M', 90),
  y1('1A', 365),
  all('Tout', null);

  const ChartPeriod(this.label, this.days);

  final String label;
  final int? days;
}

/// Métrique affichée sur la courbe.
enum ChartMetric {
  weight('Poids total', 'kg', AppColors.cyan),
  fat('Masse grasse', 'kg', AppColors.coral),
  muscle('Masse musculaire', 'kg', AppColors.emerald);

  const ChartMetric(this.label, this.unit, this.accent);

  final String label;
  final String unit;
  final Color accent;
}

/// Écran « Suivi & Graphiques ».
class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  ChartPeriod _period = ChartPeriod.m1;
  ChartMetric _metric = ChartMetric.weight;

  @override
  Widget build(BuildContext context) {
    final List<WeightMeasurement> all =
        ref.watch(measurementsProvider).value ?? <WeightMeasurement>[];

    // Filtrage par période.
    final DateTime now = DateTime.now();
    final List<WeightMeasurement> filtered = _period.days == null
        ? all.reversed.toList()
        : all
              .where(
                (WeightMeasurement m) =>
                    now.difference(m.timestamp).inDays <= _period.days!,
              )
              .toList()
              .reversed
              .toList();

    final List<ChartPoint> points = <ChartPoint>[];
    for (final WeightMeasurement m in filtered) {
      final double? value = _valueFor(m, _metric);
      if (value != null) {
        points.add(ChartPoint(date: m.timestamp, value: value));
      }
    }

    final double? target = _metric == ChartMetric.weight
        ? ref.watch(activeProfileProvider).targetWeightKg
        : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(18, 8, 18, kHomeNavBarClearance + MediaQuery.of(context).padding.bottom),
      children: <Widget>[
        Text(
          'Suivi & Graphiques',
          style: AppTheme.numeric(22, weight: FontWeight.w700),
        ),
        SizedBox(height: 3),
        const Text(
          'Évolution de votre composition corporelle',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        SizedBox(height: 18),

        // --- Sélecteur de métrique -------------------------------------------
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: ChartMetric.values.map((ChartMetric m) {
              final bool selected = m == _metric;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _metric = m),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? m.accent.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: selected
                            ? m.accent.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? m.accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 14),

        // --- Sélecteur de période --------------------------------------------
        Row(
          children: ChartPeriod.values.map((ChartPeriod p) {
            final bool selected = p == _period;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _period = p),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
                selectedColor: AppColors.cyan,
                backgroundColor: AppColors.glassFill,
                side: BorderSide(
                  color: selected ? AppColors.cyan : AppColors.glassBorder,
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),

        // --- Statistiques -----------------------------------------------------
        _StatsRow(points: points, metric: _metric, target: target),
        SizedBox(height: 16),

        // --- Graphique --------------------------------------------------------
        GlassCard(
          accent: _metric.accent,
          padding: const EdgeInsets.fromLTRB(6, 18, 18, 8),
          child: MetricChart(
            points: points,
            accent: _metric.accent,
            unit: _metric.unit,
            targetValue: target,
          ),
        ),
      ],
    );
  }

  double? _valueFor(WeightMeasurement m, ChartMetric metric) {
    switch (metric) {
      case ChartMetric.weight:
        return m.weightKg;
      case ChartMetric.fat:
        return m.composition.fatMassKg;
      case ChartMetric.muscle:
        return m.composition.muscleMassKg;
    }
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.points, required this.metric, this.target});

  final List<ChartPoint> points;
  final ChartMetric metric;
  final double? target;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final double current = points.last.value;
    final double first = points.first.value;
    final double variation = current - first;
    final double min = points
        .map((ChartPoint p) => p.value)
        .reduce((a, b) => a < b ? a : b);
    final double max = points
        .map((ChartPoint p) => p.value)
        .reduce((a, b) => a > b ? a : b);

    return Row(
      children: <Widget>[
        _StatTile(
          label: 'Actuel',
          value: '${current.toStringAsFixed(2)} ${metric.unit}',
          color: metric.accent,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Variation',
          value:
              '${variation >= 0 ? '+' : ''}${variation.toStringAsFixed(2)} ${metric.unit}',
          color: variation <= 0 ? AppColors.emerald : AppColors.coral,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Min / Max',
          value: '${min.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}',
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.numeric(
                13,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
