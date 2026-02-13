import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/neon_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/debug/firebase_diagnostics.dart';
import '../../core/services/connectivity_service.dart';
import '../auth/auth_provider.dart';
import '../auth/user_service.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/local_notifications_cache.dart';
import '../weather/weather_screen.dart';
import '../scan/local_scan_db.dart';
import '../scan/scan_sync_service.dart';
import '../../core/utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  bool _loadingProfile = true;
  int _unreadCount = 0;
  final LocalNotificationsCache _notifCache = LocalNotificationsCache();
  String? _firestoreError;
  bool _profileSyncPending = false;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadUnreadCount();
    _retryScanSync();
    if (kDebugMode) _runDiagnostics();
    _listenConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _listenConnectivity() {
    try {
      final connectivity = context.read<ConnectivityService>();
      _connectivitySub = connectivity.onConnectivityChanged.listen((online) {
        if (online) {
          Log.i('HomeScreen', 'Connectivity restored — retrying sync');
          _retryScanSync();
          if (_profileSyncPending) _loadProfile();
        }
      });
    } catch (_) {
      // ConnectivityService might not be available in tests
    }
  }

  Future<void> _runDiagnostics() async {
    final result = await runFirebaseDiagnostics();
    if (!result.success && mounted) {
      setState(() {
        _firestoreError =
            'Firestore error [${result.errorCode}]: ${result.errorMessage}';
      });
    }
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      // Retry profile creation in case it failed during registration
      await UserService().createProfileIfAbsent(
        uid: uid,
        email: auth.currentUser?.email,
        phone: auth.currentUser?.phoneNumber,
      );
      final profile = await UserService().getProfile(uid);
      if (mounted)
        setState(() {
          _profile = profile;
          _loadingProfile = false;
          _profileSyncPending = false;
        });
    } catch (e) {
      Log.w('HomeScreen', 'Profile fetch/create failed: $e');
      if (mounted)
        setState(() {
          _loadingProfile = false;
          _profileSyncPending = true;
        });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifCache.unreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _retryScanSync() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    try {
      final db = LocalScanDb();
      final sync = ScanSyncService(db: db);
      await sync.retryFailed(uid);
      Log.i('HomeScreen', 'Background scan sync retry completed');
    } catch (e) {
      Log.w('HomeScreen', 'Background sync retry failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashBackground,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonGreen,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonGreen.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.neonGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loadingProfile
                                ? 'Loading…'
                                : 'Welcome, ${_profile?.role ?? 'Farmer'}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.neonGreen),
                          ),
                          Text(
                            user?.phoneNumber ?? user?.email ?? 'Smart Farmer',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification bell with badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.cyan,
                          ),
                          tooltip: 'Notifications',
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                            // Refresh badge after returning
                            _loadUnreadCount();
                          },
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadCount > 9 ? '9+' : '$_unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Dashboard title ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'DASHBOARD',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppColors.neonGreen,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Your farm at a glance',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Firestore error banner ──
              if (_firestoreError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Firestore disabled or rules blocking.\n'
                            '${kDebugMode ? _firestoreError! : "Check console logs."}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Profile sync pending banner ──
              if (_profileSyncPending)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.sync_problem_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Profile sync pending — will retry automatically.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Quick Actions ──
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(title: 'Quick Actions'),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.15,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _QuickActionCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'START SCAN',
                        subtitle: 'Crop disease\ndetection',
                        color: AppColors.neonGreen,
                        onTap: () => _switchTab(context, 1),
                      ),
                      _QuickActionCard(
                        icon: Icons.history_rounded,
                        label: 'HISTORY',
                        subtitle: 'Past scan\nresults',
                        color: AppColors.cyan,
                        onTap: () => _switchTab(context, 2),
                      ),
                      _QuickActionCard(
                        icon: Icons.eco_rounded,
                        label: 'TIPS',
                        subtitle: 'Farming\nadvice',
                        color: const Color(0xFF76FF03),
                        onTap: () => _switchTab(context, 3),
                      ),
                      _QuickActionCard(
                        icon: Icons.cloud_rounded,
                        label: 'WEATHER',
                        subtitle: 'Local weather\nforecast',
                        color: AppColors.warning,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WeatherScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchTab(BuildContext context, int index) {
    // Communicate to MainShell to switch tabs.
    final cb = MainShellTabSwitcher.of(context);
    if (cb != null) cb(index);
  }
}

// ── Quick action card widget ──

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      glowColor: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── InheritedWidget so HomeScreen can switch MainShell tabs ──

class MainShellTabSwitcher extends InheritedWidget {
  final ValueChanged<int> switchTab;

  const MainShellTabSwitcher({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static ValueChanged<int>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MainShellTabSwitcher>()
        ?.switchTab;
  }

  @override
  bool updateShouldNotify(MainShellTabSwitcher oldWidget) =>
      switchTab != oldWidget.switchTab;
}
