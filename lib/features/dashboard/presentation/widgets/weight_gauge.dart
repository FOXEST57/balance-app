import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Jauge circulaire futuriste affichant le poids en temps réel.
///
/// - Un halo pulsant est dessiné lorsque la balance est en recherche ou en
///   cours de mesure ([active] = true).
/// - La valeur centrale utilise des chiffres tabulaires pour ne pas « sauter »
///   pendant la pesée.
class WeightGauge extends StatefulWidget {
  const WeightGauge({
    super.key,
    required this.weightKg,
    required this.statusLabel,
    this.maxKg = 200,
    this.active = false,
    this.stabilized = false,
    this.accent = AppColors.cyan,
    this.size = 260,
  });

  final double? weightKg;
  final String statusLabel;
  final double maxKg;
  final bool active;
  final bool stabilized;
  final Color accent;
  final double size;

  @override
  State<WeightGauge> createState() => _WeightGaugeState();
}

class _WeightGaugeState extends State<WeightGauge>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _smooth;
  double _displayed = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.weightKg ?? 0;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _smooth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didUpdateWidget(covariant WeightGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weightKg != null && widget.weightKg != oldWidget.weightKg) {
      _animateTo(widget.weightKg!);
    }
  }

  void _animateTo(double target) {
    final double begin = _displayed;
    _smooth.reset();
    final Animation<double> tween = Tween<double>(
      begin: begin,
      end: target,
    ).animate(CurvedAnimation(parent: _smooth, curve: Curves.easeOutCubic));
    void listener() => setState(() => _displayed = tween.value);
    tween.addListener(listener);
    _smooth.forward().whenComplete(() => tween.removeListener(listener));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _smooth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValue = widget.weightKg != null && widget.weightKg! > 0;
    final Color accent = widget.stabilized ? AppColors.emerald : widget.accent;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _GaugePainter(
              progress: hasValue ? (_displayed / widget.maxKg).clamp(0, 1) : 0,
              accent: accent,
              pulse: widget.active && !widget.stabilized ? _pulse.value : 0,
              stabilized: widget.stabilized,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    hasValue ? _displayed.toStringAsFixed(2) : '--.--',
                    style: AppTheme.numeric(
                      46,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'KG',
                    style: AppTheme.numeric(
                      13,
                      weight: FontWeight.w500,
                      color: AppColors.textMuted,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.accent,
    required this.pulse,
    required this.stabilized,
  });

  final double progress;
  final Color accent;
  final double pulse;
  final bool stabilized;

  static const double _startAngle = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 18;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // --- Halo pulsant (recherche / mesure en cours) -------------------------
    if (pulse > 0) {
      final double haloRadius = radius + 10 + pulse * 18;
      final Paint halo = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.28 * (1 - pulse)),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
      canvas.drawCircle(center, haloRadius, halo);
    }

    // --- Piste de fond ------------------------------------------------------
    final Paint track = Paint()
      ..color = AppColors.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweep, false, track);

    // --- Graduations --------------------------------------------------------
    final Paint tick = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i <= 10; i++) {
      final double a = _startAngle + (_sweep * i / 10);
      final Offset p1 =
          center + Offset(math.cos(a), math.sin(a)) * (radius - 10);
      final Offset p2 =
          center + Offset(math.cos(a), math.sin(a)) * (radius - 18);
      canvas.drawLine(p1, p2, tick);
    }

    // --- Arc de progression -------------------------------------------------
    if (progress > 0) {
      // Lueur externe
      final Paint glow = Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(rect, _startAngle, _sweep * progress, false, glow);

      // Arc principal en dégradé
      final Paint arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _startAngle,
          endAngle: _startAngle + _sweep,
          colors: <Color>[
            accent.withValues(alpha: 0.5),
            accent,
            stabilized ? AppColors.emerald : accent,
          ],
        ).createShader(rect);
      canvas.drawArc(rect, _startAngle, _sweep * progress, false, arc);

      // Point lumineux en bout d'arc
      final double endAngle = _startAngle + _sweep * progress;
      final Offset tip =
          center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;
      canvas.drawCircle(tip, 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        tip,
        12,
        Paint()
          ..color = accent.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.accent != accent ||
      old.stabilized != stabilized;
}
