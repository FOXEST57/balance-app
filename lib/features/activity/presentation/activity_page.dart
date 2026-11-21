import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/navigation/home_shell.dart';
import '../../../shared/widgets/glass_card.dart';
import '../domain/entities/activity_daily_summary.dart';
import '../domain/entities/activity_goals.dart';
import '../domain/entities/activity_type.dart';
import 'activity_provider.dart';

/// Écran « Activité Physique » : dashboard du jour, graphiques semaine/mois,
/// saisie manuelle de séances et configuration des objectifs.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ActivityState> state = ref.watch(activityProvider);

    return state.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.violet),
      ),
      error: (Object e, _) => Center(
        child: Text('Erreur : $e',
            style: const TextStyle(color: AppColors.danger)),
      ),
      data: (ActivityState data) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, kHomeNavBarClearance),
        children: <Widget>[
          Text('Activité Physique',
              style: AppTheme.numeric(22, weight: FontWeight.w700)),
          const SizedBox(height: 3),
          const Text(
            'Suivez votre effort quotidien et hebdomadaire',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),

          // --- Dashboard du jour -------------------------------------------
          _TodayDashboard(data: data),
          const SizedBox(height: 16),

          // --- Graphique semaine -------------------------------------------
          GlassCard(
            accent: AppColors.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Cette semaine',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${_weekTotalSteps(data.week)} pas au total',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 180,
                  child: _WeeklyBarChart(summaries: data.week),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Mois ---------------------------------------------------------
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Ces 30 derniers jours',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _MonthStats(summaries: data.month),
                const SizedBox(height: 14),
                SizedBox(
                  height: 120,
                  child: _MonthMiniChart(summaries: data.month),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Séances du jour ---------------------------------------------
          if (data.today.entries.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'Séances du jour'),
            const SizedBox(height: 10),
            ...data.today.entries.map((e) => _SessionTile(entry: e)),
          ],

          const SizedBox(height: 16),

          // --- Actions ------------------------------------------------------
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_rounded,
                  label: 'Ajouter une séance',
                  onTap: () => _showAddSessionSheet(context, ref),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.flag_rounded,
                  label: 'Objectifs',
                  onTap: () => _showGoalsSheet(context, ref, data.goals),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _weekTotalSteps(List<ActivityDailySummary> week) =>
      week.fold(0, (int acc, s) => acc + s.steps);

  // --- Bottom sheet : ajouter une séance -----------------------------------

  void _showAddSessionSheet(BuildContext context, WidgetRef ref) {
    ActivityType selectedType = ActivityType.walking;
    final TextEditingController minutesCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Ajouter une séance',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  const Text('Type d\'activité',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ActivityType.values
                        .where((t) => t != ActivityType.steps)
                        .map((ActivityType t) => ChoiceChip(
                              label: Text(t.label),
                              selected: selectedType == t,
                              onSelected: (bool sel) {
                                if (sel) {
                                  setSheetState(() => selectedType = t);
                                }
                              },
                              selectedColor: AppColors.violet.withValues(alpha: 0.25),
                              backgroundColor: AppColors.surfaceAlt,
                              labelStyle: TextStyle(
                                color: selectedType == t
                                    ? AppColors.violet
                                    : AppColors.textSecondary,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Durée (minutes)',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '30',
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final int minutes =
                            int.tryParse(minutesCtrl.text) ?? 0;
                        if (minutes <= 0) return;
                        await ref
                            .read(activityProvider.notifier)
                            .addSession(
                              type: selectedType,
                              minutes: minutes,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Enregistrer',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Bottom sheet : objectifs --------------------------------------------

  void _showGoalsSheet(
    BuildContext context,
    WidgetRef ref,
    ActivityGoals goals,
  ) {
    final TextEditingController stepsCtrl =
        TextEditingController(text: goals.steps.toString());
    final TextEditingController kcalCtrl =
        TextEditingController(text: goals.kcal.toString());
    final TextEditingController minCtrl =
        TextEditingController(text: goals.minutes.toString());

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Objectifs quotidiens',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _GoalField(label: 'Pas par jour', controller: stepsCtrl, suffix: 'pas'),
              const SizedBox(height: 12),
              _GoalField(label: 'Calories actives', controller: kcalCtrl, suffix: 'kcal'),
              const SizedBox(height: 12),
              _GoalField(label: 'Minutes d\'activité', controller: minCtrl, suffix: 'min'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final ActivityGoals updated = ActivityGoals(
                      steps: int.tryParse(stepsCtrl.text) ?? 10000,
                      kcal: int.tryParse(kcalCtrl.text) ?? 300,
                      minutes: int.tryParse(minCtrl.text) ?? 30,
                    );
                    await ref
                        .read(activityProvider.notifier)
                        .updateGoals(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Enregistrer',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Widgets internes
// ===========================================================================

class _TodayDashboard extends StatelessWidget {
  const _TodayDashboard({required this.data});

  final ActivityState data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.violet,
      child: Row(
        children: <Widget>[
          // Anneau de progression des pas.
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: data.stepsProgress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.violet),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${data.todayStepsLive}',
                      style: AppTheme.numeric(22, weight: FontWeight.w700),
                    ),
                    const Text('pas',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MiniStat(
                  label: 'Calories',
                  value: '${data.today.kcal.toStringAsFixed(0)} kcal',
                  progress: data.kcalProgress,
                  color: AppColors.coral,
                ),
                const SizedBox(height: 12),
                _MiniStat(
                  label: 'Minutes',
                  value: '${data.today.minutes} min',
                  progress: data.minutesProgress,
                  color: AppColors.emerald,
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
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.summaries});

  final List<ActivityDailySummary> summaries;

  @override
  Widget build(BuildContext context) {
    final int maxSteps = summaries.fold(
      0,
      (int m, ActivityDailySummary s) => s.steps > m ? s.steps : m,
    );
    final double maxY = (maxSteps > 0 ? maxSteps : 1).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY * 1.1,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= summaries.length) {
                  return const SizedBox.shrink();
                }
                final DateTime day = summaries[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${day.day}/${day.month}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: summaries
            .asMap()
            .entries
            .map((MapEntry<int, ActivityDailySummary> e) {
          return BarChartGroupData(
            x: e.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: e.value.steps.toDouble(),
                color: AppColors.violet.withValues(alpha: 0.8),
                width: 18,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MonthStats extends StatelessWidget {
  const _MonthStats({required this.summaries});

  final List<ActivityDailySummary> summaries;

  @override
  Widget build(BuildContext context) {
    final int totalSteps =
        summaries.fold(0, (int a, s) => a + s.steps);
    final double totalKcal =
        summaries.fold(0.0, (double a, s) => a + s.kcal);
    final int totalMin =
        summaries.fold(0, (int a, s) => a + s.minutes);
    final int activeDays =
        summaries.where((s) => s.steps > 0 || s.kcal > 0).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        _MonthStat(value: '$totalSteps', label: 'pas'),
        _MonthStat(
            value: totalKcal.toStringAsFixed(0), label: 'kcal'),
        _MonthStat(value: '$totalMin', label: 'min'),
        _MonthStat(value: '$activeDays', label: 'jours act.'),
      ],
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(value,
            style: AppTheme.numeric(16, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

class _MonthMiniChart extends StatelessWidget {
  const _MonthMiniChart({required this.summaries});

  final List<ActivityDailySummary> summaries;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = summaries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.steps.toDouble()))
        .toList();
    final double maxY = (summaries.fold(
              0,
              (int m, s) => s.steps > m ? s.steps : m,
            ) *
            1.1).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY > 0 ? maxY : 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.violet,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.violet.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.entry});

  final dynamic entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(
              (entry.activityType as ActivityType?)?.icon ??
                  Icons.fitness_center_rounded,
              color: AppColors.violet,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    (entry.activityType as ActivityType?)?.label ?? 'Activité',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${entry.sessionMinutes ?? 0} min · ${(entry.activeKcal ?? 0).toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.violet, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.label,
    required this.controller,
    required this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
  }
}
