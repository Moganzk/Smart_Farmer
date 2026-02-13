import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/neon_card.dart';
import '../../core/utils/logger.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../scan/local_scan_db.dart';
import '../scan/scan_sync_service.dart';
import 'profile_screen.dart';
import 'about_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _offlineMode = false;
  bool _syncing = false;
  bool _exporting = false;
  int _pendingScans = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadPendingCount();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _offlineMode = prefs.getBool('offline_mode') ?? false;
      });
    }
  }

  Future<void> _toggleOfflineMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode', value);
    if (mounted) setState(() => _offlineMode = value);
  }

  Future<void> _loadPendingCount() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    try {
      final db = LocalScanDb();
      final pending = await db.getPendingScans(uid);
      if (mounted) setState(() => _pendingScans = pending.length);
    } catch (_) {}
  }

  Future<void> _retryScanSync() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    setState(() => _syncing = true);
    try {
      final db = LocalScanDb();
      final sync = ScanSyncService(db: db);
      await sync.retryFailed(uid);
      Log.i('MoreScreen', 'Manual sync retry completed');
      await _loadPendingCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync retry completed'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      Log.e('MoreScreen', 'Sync retry failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _exportHistory() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    setState(() => _exporting = true);
    try {
      final db = LocalScanDb();
      final scans = await db.getScans(uid);
      final jsonList = scans.map((s) => s.toMap()).toList();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonList);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/smart_farmer_export.json');
      await file.writeAsString(jsonStr);

      Log.i('MoreScreen', 'Exported ${scans.length} scans to ${file.path}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${scans.length} scans to ${file.path}'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      Log.e('MoreScreen', 'Export failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'SETTINGS',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppColors.neonGreen,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Account & configuration',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Account ──
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  subtitle: 'View and edit your account',
                  color: AppColors.cyan,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Offline mode toggle ──
                NeonCard(
                  glowColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Mode',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Use cached data only',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _offlineMode,
                        onChanged: _toggleOfflineMode,
                        activeColor: AppColors.warning,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Retry sync ──
                _MenuItem(
                  icon: Icons.sync_rounded,
                  label: _syncing ? 'Syncing…' : 'Retry Sync',
                  subtitle: _pendingScans > 0
                      ? '$_pendingScans scan(s) pending'
                      : 'All scans synced',
                  color: AppColors.cyan,
                  onTap: _syncing ? () {} : _retryScanSync,
                ),
                const SizedBox(height: 12),

                // ── Export ──
                _MenuItem(
                  icon: Icons.file_download_outlined,
                  label: _exporting ? 'Exporting…' : 'Export History',
                  subtitle: 'Save scan history as JSON',
                  color: AppColors.neonGreen,
                  onTap: _exporting ? () {} : _exportHistory,
                ),
                const SizedBox(height: 12),

                // ── About ──
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  subtitle: 'App version & credits',
                  color: AppColors.neonGreen,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Seed data (debug only) ──
                if (kDebugMode) ...[
                  _MenuItem(
                    icon: Icons.dataset_rounded,
                    label: 'Seed Data',
                    subtitle: 'Write sample tips + notifications',
                    color: AppColors.warning,
                    onTap: _seedFirestoreData,
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Logout ──
                _MenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  subtitle: 'Sign out of your account',
                  color: AppColors.error,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _seedFirestoreData() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    try {
      final db = FirebaseFirestore.instanceFor(
        app: FirebaseFirestore.instance.app,
        databaseId: 'smart-farmer-kenya',
      );

      // Seed 3 tips
      final tipsColl = db.collection('tips');
      final sampleTips = [
        {
          'title': 'Water Early Morning',
          'body':
              'Watering crops early in the morning reduces evaporation and helps plants absorb moisture before the heat of the day.',
          'category': 'General',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Rotate Maize with Legumes',
          'body':
              'Alternating maize with beans or cowpeas restores nitrogen to the soil and breaks pest cycles.',
          'category': 'Maize',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Tomato Blight Prevention',
          'body':
              'Stake tomato plants and space them 60 cm apart to improve air flow and reduce fungal infections.',
          'category': 'Tomatoes',
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];
      for (final tip in sampleTips) {
        await tipsColl.add(tip);
      }

      // Seed 3 notifications
      final notifColl = db
          .collection('notifications')
          .doc(uid)
          .collection('items');
      final sampleNotifs = [
        {
          'title': 'Welcome to Smart Farmer',
          'body': 'Start scanning your crops to detect diseases early.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Weather Alert',
          'body': 'Heavy rain expected this week — protect your seedlings.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'New Tip Available',
          'body': 'Check the Tips tab for advice on tomato blight prevention.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];
      for (final notif in sampleNotifs) {
        await notifColl.add(notif);
      }

      Log.i('MoreScreen', 'Seed data written successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('3 tips + 3 notifications seeded'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      Log.e('MoreScreen', 'Seed data failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seed failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'LOGOUT',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: color.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
