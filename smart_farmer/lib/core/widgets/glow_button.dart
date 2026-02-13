import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color glowColor;
  final bool isOutlined;

  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.glowColor = AppColors.neonGreen,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon != null ? Icon(icon, size: 20) : const SizedBox(),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: glowColor,
                side: BorderSide(color: glowColor, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon != null ? Icon(icon, size: 20) : const SizedBox(),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: glowColor,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
}
