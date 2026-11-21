import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/navigation/home_shell.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../weighing/application/scale_service.dart';
import '../../weighing/domain/entities/body_composition.dart';
import '../../weighing/domain/entities/weight_measurement.dart';
import '../../weighing/presentation/widgets/ble_scan_sheet.dart';
import 'widgets/activity_preview_card.dart';
import 'widgets/kpi_card.dart';
import 'widgets/weight_gauge.dart';

/// Écran principal : pesée en direct + synthèse de la dernière mesure.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.onOpenActivity});

  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WeighingState weighing = ref.watch(weighingProvider);
    final WeightMeasurement? last = ref.watch(latestMeasurementProvider);
    final BodyComposition? c = last?.composition;

    final double? liveWeight = weighing.liveWeightKg ?? last?.weightKg;
    final bool showLive = weighing.isConnected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, kHomeNavBarClearance),
      children: <Widget>[
        // --- En-tête ---------------------------------------------------------
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pesée en direct',
                    style: AppTheme.numeric(22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    last != null
                        ? 'Dernière pesée : ${_fmtDateTime(last.timestamp)}'
                        : 'Aucune pesée enregistrée',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _StatusChip(
              status: weighing.status,
              simulation: weighing.simulationMode,
            ),
          ],
        ),
        SizedBox(height: 18),

        // --- Jauge -----------------------------------------------------------
        Center(
          child: WeightGauge(
            weightKg: liveWeight,
            maxKg: 200,
            active: weighing.isScanning || (showLive && liveWeight != null),
            stabilized: weighing.stabilized,
            statusLabel: _gaugeLabel(weighing, showLive),
          ),
        ),
        SizedBox(height: 20),

        // --- Actions ---------------------------------------------------------
        _ActionRow(weighing: weighing),
        SizedBox(height: 22),

        // --- KPIs ------------------------------------------------------------
        const SectionHeader(
          title: 'Composition corporelle',
          subtitle: 'Pourcentages convertis en kilogrammes',
          accent: AppColors.emerald,
        ),
        SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: <Widget>[
            KpiCard(
              label: 'Masse grasse',
              icon: Icons.local_fire_department_rounded,
              accent: AppColors.coral,
              primaryValue: c?.fatMassKg,
              secondaryText: c?.fatPercent == null
                  ? null
                  : '${c!.fatPercent!.toStringAsFixed(2)} %',
            ),
            KpiCard(
              label: 'Masse musculaire',
              icon: Icons.fitness_center_rounded,
              accent: AppColors.emerald,
              primaryValue: c?.muscleMassKg,
              secondaryText: c?.musclePercent == null
                  ? null
                  : '${c!.musclePercent!.toStringAsFixed(2)} %',
            ),
            KpiCard(
              label: 'Eau corporelle',
              icon: Icons.water_drop_rounded,
              accent: AppColors.cyan,
              primaryValue: c?.waterMassKg,
              secondaryText: c == null
                  ? null
                  : '${c.waterPercent.toStringAsFixed(2)} %',
            ),
            KpiCard(
              label: 'IMC',
              icon: Icons.straighten_rounded,
              accent: AppColors.amber,
              primaryUnit: '',
              primaryValue: c?.bmi,
              secondaryText: c == null ? null : _bmiLabel(c.bmi),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (c != null)
          GlassCard(
            accent: AppColors.violet,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.battery_charging_full_rounded,
                  color: AppColors.violet,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Métabolisme de base',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${c.bmrKcal.toStringAsFixed(0)} kcal',
                  style: AppTheme.numeric(15, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        SizedBox(height: 22),

        // --- Module V2 -------------------------------------------------------
        SectionHeader(
          title: 'Bientôt disponible',
          subtitle: 'Préparation de la V2',
          accent: AppColors.violet,
        ),
        SizedBox(height: 12),
        ActivityPreviewCard(onTap: onOpenActivity),
        SizedBox(height: 20),

        // --- Diagnostic (trame brute) ----------------------------------------
        if (weighing.lastRawHex != null)
          _RawFrameCard(
            hex: weighing.lastRawHex!,
            impedance: weighing.liveImpedanceOhm,
          ),
      ],
    );
  }

  String _fmtDateTime(DateTime d) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} à ${p(d.hour)}:${p(d.minute)}';
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Insuffisance';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Surpoids';
    return 'Obésité';
  }

  String _gaugeLabel(WeighingState w, bool connected) {
    switch (w.status) {
      case ScaleConnectionStatus.scanning:
        return 'RECHERCHE…';
      case ScaleConnectionStatus.connecting:
        return 'CONNEXION…';
      case ScaleConnectionStatus.error:
        return 'ERREUR BLE';
      case ScaleConnectionStatus.connected:
      case ScaleConnectionStatus.idle:
      case ScaleConnectionStatus.disconnected:
        if (w.simulationMode) {
          return w.stabilized ? 'SIMULATION • STABLE' : 'SIMULATION…';
        }
        if (connected) {
          if (w.stabilized) return 'MESURE STABLE';
          if (w.liveWeightKg != null) return 'PESÉE EN COURS…';
          return 'MONTEZ SUR LA BALANCE';
        }
        return 'NON CONNECTÉ';
    }
  }
}

// -----------------------------------------------------------------------------
// Widgets internes
// -----------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.simulation});

  final ScaleConnectionStatus status;
  final bool simulation;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    if (simulation) {
      color = AppColors.violet;
      label = 'Simulation';
    } else {
      switch (status) {
        case ScaleConnectionStatus.connected:
          color = AppColors.emerald;
          label = 'Connectée';
          break;
        case ScaleConnectionStatus.scanning:
          color = AppColors.cyan;
          label = 'Recherche';
          break;
        case ScaleConnectionStatus.connecting:
          color = AppColors.amber;
          label = 'Connexion';
          break;
        case ScaleConnectionStatus.error:
          color = AppColors.danger;
          label = 'Erreur';
          break;
        case ScaleConnectionStatus.disconnected:
          color = AppColors.textMuted;
          label = 'Déconnectée';
          break;
        case ScaleConnectionStatus.idle:
          color = AppColors.textMuted;
          label = 'Inactive';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.weighing});

  final WeighingState weighing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WeighingNotifier notifier = ref.read(weighingProvider.notifier);

    if (weighing.simulationMode) {
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet.withValues(alpha: 0.18),
                foregroundColor: AppColors.violet,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: notifier.stopSimulation,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Arrêter la simulation'),
            ),
          ),
        ],
      );
    }

    if (weighing.isConnected) {
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.16),
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: notifier.disconnect,
              icon: const Icon(Icons.bluetooth_disabled_rounded),
              label: const Text('Déconnecter'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan.withValues(alpha: 0.16),
              foregroundColor: AppColors.cyan,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => showBleScanSheet(context),
            icon: const Icon(Icons.bluetooth_searching_rounded),
            label: const Text('Connecter la balance'),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Mode Simulation (tester sans balance)',
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.violet,
              side: BorderSide(color: AppColors.violet.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: notifier.startSimulation,
            child: const Icon(Icons.science_rounded),
          ),
        ),
      ],
    );
  }
}

class _RawFrameCard extends StatelessWidget {
  const _RawFrameCard({required this.hex, this.impedance});

  final String hex;
  final int? impedance;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.terminal_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Trame brute (diagnostic / calibration)',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const Spacer(),
              if (impedance != null)
                Text(
                  '$impedance Ω',
                  style: AppTheme.numeric(
                    11.5,
                    weight: FontWeight.w600,
                    color: AppColors.cyan,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            hex,
            style: AppTheme.numeric(
              12,
              weight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
