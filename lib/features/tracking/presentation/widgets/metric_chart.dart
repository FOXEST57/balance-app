import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/num_fmt.dart';

/// Un point de mesure sur la courbe.
class ChartPoint {
  const ChartPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// Courbe interactive (fl_chart) avec lissage de Bézier et remplissage en
/// dégradé. Affiche un repère horizontal pour l'objectif si [targetValue] est
/// fourni.
class MetricChart extends StatelessWidget {
  const MetricChart({
    super.key,
    required this.points,
    required this.accent,
    required this.unit,
    this.targetValue,
    this.decimals = 2,
  });

  final List<ChartPoint> points;
  final Color accent;
  final String unit;
  final double? targetValue;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: Text(
            'Pas encore de données pour cette période.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];

    final Iterable<double> values = points.map((ChartPoint p) => p.value);
    double minY = values.reduce(math.min);
    double maxY = values.reduce(math.max);

    // Plage serrée autour des données réelles pour que les faibles variations
    // (ex. –1 kg sur 7 jours) restent visibles et motivantes. Le padding est
    // proportionnel à l'étendue des données mais toujours suffisant pour éviter
    // une courbe « plate » écrasée.
    final double dataRange = maxY - minY;
    final double pad = math.max(dataRange * 0.25, 2.0);
    minY = minY - pad;
    maxY = maxY + pad;

    // On n'inclut l'objectif dans la plage visible que s'il est relativement
    // proche des mesures. Sinon, l'écart (ex. 161 kg mesurés vs 120 kg
    // d'objectif) aplatirait la courbe et rendrait la perte invisible.
    if (targetValue != null) {
      final double halfPad = pad * 0.5;
      if (targetValue! > minY - halfPad && targetValue! < maxY + halfPad) {
        minY = math.min(minY, targetValue! - halfPad);
        maxY = math.max(maxY, targetValue! + halfPad);
      }
    }

    final int labelStep = math.max(1, (points.length / 5).ceil());

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(0.01, (maxY - minY) / 4),
            getDrawingHorizontalLine: (double v) => FlLine(
              color: AppColors.glassBorder,
              strokeWidth: 1,
              dashArray: <int>[4, 6],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: math.max(0.01, (maxY - minY) / 4),
                getTitlesWidget: (double value, TitleMeta meta) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toStringAsFixed(decimals == 0 ? 0 : 1),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.round();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  if (i % labelStep != 0 && i != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final DateTime d = points[i].date;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: targetValue == null
              ? const ExtraLinesData()
              : ExtraLinesData(
                  horizontalLines: <HorizontalLine>[
                    HorizontalLine(
                      y: targetValue!,
                      color: AppColors.amber.withValues(alpha: 0.8),
                      strokeWidth: 1.2,
                      dashArray: <int>[6, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                        labelResolver: (HorizontalLine line) =>
                            'Objectif ${targetValue!.toStringAsFixed(2)} $unit',
                      ),
                    ),
                  ],
                ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) => AppColors.surfaceAlt,
              tooltipBorder: BorderSide(color: accent.withValues(alpha: 0.4)),
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((LineBarSpot s) {
                  final ChartPoint p = points[s.x.round()];
                  return LineTooltipItem(
                    '${p.value.toStringAsFixed(decimals)} $unit',
                    TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
                    children: <TextSpan>[
                      TextSpan(
                        text: '\n${fmtDate(p.date)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.32,
              preventCurveOverShooting: true,
              barWidth: 3,
              isStrokeCapRound: true,
              color: accent,
              dotData: FlDotData(
                show: points.length <= 20,
                getDotPainter: (FlSpot spot, double percent, LineChartBarData bar, int index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.background,
                    strokeWidth: 2,
                    strokeColor: accent,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    accent.withValues(alpha: 0.35),
                    accent.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 320),
      ),
    );
  }
}
