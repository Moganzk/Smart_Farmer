import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppGradients {
  const AppGradients._();

  static const LinearGradient splashBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A0E1A),
      Color(0xFF0D1B2A),
      Color(0xFF1B2838),
      Color(0xFF0A0E1A),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static LinearGradient get neonGlow => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.neonGreen.withValues(alpha: 0.3),
      AppColors.cyan.withValues(alpha: 0.1),
      Colors.transparent,
    ],
  );

  static LinearGradient get cardGlow => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.neonGreen.withValues(alpha: 0.05),
      AppColors.surface,
      AppColors.cyan.withValues(alpha: 0.05),
    ],
  );
}
