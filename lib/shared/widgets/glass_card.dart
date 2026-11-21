import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Carte « Glassmorphism » : fond translucide, bordure fine 1px blanche 10 %
/// et léger flou d'arrière-plan.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.accent,
    this.onTap,
    this.blur = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Couleur d'accent optionnelle (teinte la bordure et ajoute un halo).
  final Color? accent;
  final VoidCallback? onTap;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final Color border = accent?.withValues(alpha: 0.35) ?? AppColors.glassBorder;

    final Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.glassHighlight,
                AppColors.glassFill,
                AppColors.glassFill,
              ],
            ),
            boxShadow: accent == null
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: accent!.withValues(alpha: 0.10),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      splashColor: (accent ?? AppColors.cyan).withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
      child: content,
    );
  }
}
