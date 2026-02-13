import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glow_button.dart';
import '../auth/auth_provider.dart';
import 'ai_diagnosis_service.dart';
import 'local_scan_db.dart';
import 'processing_screen.dart';
import 'scan_flow_controller.dart';
import 'scan_sync_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _selectedImage;
  final _picker = ImagePicker();
  bool _picking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _startAnalysis() {
    if (_selectedImage == null) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? 'anonymous';

    final db = LocalScanDb();
    final ai = GeminiDiagnosisService();
    ScanSyncService? sync;
    try {
      sync = ScanSyncService(db: db);
    } catch (_) {
      // Firestore not available — skip sync
    }

    final controller = ScanFlowController(db: db, ai: ai, sync: sync, uid: uid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          imageFile: _selectedImage!,
          controller: controller,
        ),
      ),
    ).then((_) {
      // Reset selection after returning
      if (mounted) setState(() => _selectedImage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashBackground,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Title
                Text(
                  'CROP SCANNER',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppColors.neonGreen,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI-powered disease detection',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),

                const Spacer(),

                // Image preview area
                _selectedImage != null ? _imagePreview() : _placeholderArea(),

                const SizedBox(height: 24),

                // Pick buttons
                Row(
                  children: [
                    Expanded(
                      child: GlowButton(
                        label: 'GALLERY',
                        icon: Icons.photo_library_rounded,
                        glowColor: AppColors.cyan,
                        isOutlined: true,
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlowButton(
                        label: 'CAMERA',
                        icon: Icons.camera_alt_rounded,
                        glowColor: AppColors.cyan,
                        isOutlined: true,
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Analyze CTA
                SizedBox(
                  width: double.infinity,
                  child: GlowButton(
                    label: 'ANALYZE',
                    icon: Icons.auto_fix_high_rounded,
                    onPressed: _selectedImage != null ? _startAnalysis : () {},
                    glowColor: _selectedImage != null
                        ? AppColors.neonGreen
                        : AppColors.textSecondary,
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderArea() {
    return GlassContainer(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neonGreen.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.add_photo_alternate_rounded,
              color: AppColors.neonGreen.withValues(alpha: 0.6),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select a crop image to analyze',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedImage!,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() => _selectedImage = null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: AppColors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
