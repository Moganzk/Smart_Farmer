import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A sci-fi styled card with neon border glow.
class NeonCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const NeonCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.neonGreen,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: glowColor.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          splashColor: glowColor.withValues(alpha: 0.1),
          highlightColor: glowColor.withValues(alpha: 0.05),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
