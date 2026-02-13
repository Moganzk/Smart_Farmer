import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/neon_card.dart';
import '../../core/widgets/section_header.dart';
import '../auth/auth_provider.dart';
import '../scan/local_scan_db.dart';
import '../scan/results_screen.dart';
import '../scan/scan_record.dart';
import 'history_notifier.dart';

class HistoryScreen extends StatefulWidget {
  /// Allow injecting a DB for testing.
  final LocalScanDb? db;

  const HistoryScreen({super.key, this.db});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryNotifier _notifier;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? 'anonymous';
    _notifier = HistoryNotifier(db: widget.db ?? LocalScanDb(), uid: uid);
    _notifier.addListener(_onData);
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifier.removeListener(_onData);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashBackground,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'SCAN HISTORY',
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
                  'Your past diagnoses',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(title: 'Recent Scans'),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_notifier.initialLoading) {
      return _shimmerList();
    }

    if (_notifier.records.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No scans yet',
        subtitle: 'Your crop scan results will appear here.',
        iconColor: AppColors.cyan,
      );
    }

    return RefreshIndicator(
      color: AppColors.neonGreen,
      backgroundColor: AppColors.surface,
      onRefresh: _notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _notifier.records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ScanRecordTile(
          record: _notifier.records[i],
          onTap: () => _openDetail(_notifier.records[i]),
        ),
      ),
    );
  }

  Widget _shimmerList() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _openDetail(ScanRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(record: record, fromHistory: true),
      ),
    );
  }
}

// ── List tile ──

class _ScanRecordTile extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onTap;

  const _ScanRecordTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sevColor = Color(record.severityColorHex);

    return NeonCard(
      glowColor: sevColor,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          // Thumbnail
          _thumbnail(),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.diagnosisName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.cropType}  •  ${(record.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: sevColor, fontSize: 12),
                ),
              ],
            ),
          ),

          // Date + sync badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMM').format(record.createdAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              _syncDot(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbnail() {
    final file = File(record.imagePath);
    final exists = file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child: exists
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: AppColors.surfaceLight,
                child: const Icon(Icons.eco, color: AppColors.cyan, size: 22),
              ),
      ),
    );
  }

  Widget _syncDot() {
    Color c;
    String tip;
    switch (record.syncStatus) {
      case 'synced':
        c = AppColors.neonGreen;
        tip = 'Synced';
        break;
      case 'pending':
        c = AppColors.cyan;
        tip = 'Pending sync';
        break;
      case 'failed':
        c = AppColors.error;
        tip = 'Sync failed';
        break;
      default:
        c = AppColors.textSecondary;
        tip = 'Local only';
    }

    return Tooltip(
      message: tip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
