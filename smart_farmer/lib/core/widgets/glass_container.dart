import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A glassmorphism container with frosted-glass effect.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;
  final double blur;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.borderColor = const Color(0x33FFFFFF),
    this.blur = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}
