import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// An empty-state placeholder widget with icon, title, and subtitle.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.iconColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.08),
                border: Border.all(color: iconColor.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: iconColor, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: iconColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
