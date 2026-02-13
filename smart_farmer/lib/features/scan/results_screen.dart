import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import 'scan_record.dart';

/// Displays diagnosis results for a [ScanRecord].
/// Reused as both the post-scan result view and the detail view from history.
class ResultsScreen extends StatelessWidget {
  final ScanRecord record;
  final bool fromHistory;

  const ResultsScreen({
    super.key,
    required this.record,
    this.fromHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final sevColor = Color(record.severityColorHex);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(fromHistory ? 'SCAN DETAIL' : 'RESULTS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image preview
          if (record.imagePath.isNotEmpty) _imageCard(),

          const SizedBox(height: 16),

          // Diagnosis hero
          GlassContainer(
            borderColor: sevColor.withValues(alpha: 0.4),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sevColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    record.severity.toUpperCase(),
                    style: TextStyle(
                      color: sevColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Disease name
                Text(
                  record.diagnosisName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Confidence
                _confidenceBar(record.confidence, sevColor),
                const SizedBox(height: 6),
                Text(
                  'Confidence: ${(record.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Details row
          Row(
            children: [
              Expanded(child: _detailChip(Icons.eco, record.cropType, 'Crop')),
              const SizedBox(width: 12),
              Expanded(
                child: _detailChip(
                  Icons.access_time,
                  DateFormat('d MMM yyyy').format(record.createdAt),
                  'Date',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Sync status
          _syncBadge(),

          const SizedBox(height: 20),

          // Recommendations
          _sectionTitle('RECOMMENDATIONS'),
          const SizedBox(height: 10),
          ...record.recommendations.asMap().entries.map(
            (e) => _recommendationTile(e.key + 1, e.value, sevColor),
          ),

          const SizedBox(height: 24),

          // Action buttons
          if (!fromHistory) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Pop back to the scan tab
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('DONE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageCard() {
    final file = File(record.imagePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: file.existsSync()
          ? Image.file(
              file,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          : Container(
              height: 200,
              color: AppColors.surfaceLight,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: AppColors.textSecondary,
                  size: 48,
                ),
              ),
            ),
    );
  }

  Widget _confidenceBar(double confidence, Color color) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: confidence.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String value, String label) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      borderColor: AppColors.cyan.withValues(alpha: 0.2),
      child: Column(
        children: [
          Icon(icon, color: AppColors.cyan, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncBadge() {
    Color badge;
    String label;
    IconData icon;

    switch (record.syncStatus) {
      case 'synced':
        badge = AppColors.neonGreen;
        label = 'SYNCED';
        icon = Icons.cloud_done;
        break;
      case 'pending':
        badge = AppColors.cyan;
        label = 'SYNC PENDING';
        icon = Icons.cloud_upload;
        break;
      case 'failed':
        badge = AppColors.error;
        label = 'SYNC FAILED';
        icon = Icons.cloud_off;
        break;
      default:
        badge = AppColors.textSecondary;
        label = 'LOCAL ONLY';
        icon = Icons.phone_android;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badge.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badge.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: badge),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: badge,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.neonGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.neonGreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _recommendationTile(int index, String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        borderColor: accent.withValues(alpha: 0.15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
