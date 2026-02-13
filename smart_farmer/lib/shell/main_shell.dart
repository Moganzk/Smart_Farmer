import 'package:flutter/material.dart';
import '../core/widgets/neon_bottom_nav.dart';
import '../features/home/home_screen_new.dart';
import '../features/scan/scan_screen.dart';
import '../features/history/history_screen.dart';
import '../features/tips/tips_screen.dart';
import '../features/more/more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _items = [
    NeonNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    NeonNavItem(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt_rounded,
      label: 'Scan',
    ),
    NeonNavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
    NeonNavItem(
      icon: Icons.eco_outlined,
      activeIcon: Icons.eco_rounded,
      label: 'Tips',
    ),
    NeonNavItem(
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz_rounded,
      label: 'More',
    ),
  ];

  final _screens = const [
    HomeScreen(),
    ScanScreen(),
    HistoryScreen(),
    TipsScreen(),
    MoreScreen(),
  ];

  void _switchTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainShellTabSwitcher(
      switchTab: _switchTab,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: NeonBottomNav(
          currentIndex: _currentIndex,
          onTap: _switchTab,
          items: _items,
        ),
      ),
    );
  }
}
