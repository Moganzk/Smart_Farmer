import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single bottom-nav item descriptor.
class NeonNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NeonNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Custom sci-fi bottom navigation bar with neon glow on active item.
class NeonBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NeonNavItem> items;

  const NeonBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: Color(0xFF1F2937), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonGreen.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: _NavItemWidget(item: item, isActive: isActive),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemWidget extends StatelessWidget {
  final NeonNavItem item;
  final bool isActive;

  const _NavItemWidget({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.neonGreen : AppColors.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Active glow dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 3,
          width: isActive ? 20 : 0,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: AppColors.neonGreen,
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.neonGreen.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
        ),
        Icon(isActive ? item.activeIcon : item.icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: isActive ? 0.8 : 0.4,
          ),
        ),
      ],
    );
  }
}
