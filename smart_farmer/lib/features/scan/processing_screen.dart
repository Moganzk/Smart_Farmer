import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'scan_flow_controller.dart';
import 'results_screen.dart';

/// Futuristic loading screen that runs AI diagnosis.
class ProcessingScreen extends StatefulWidget {
  final File imageFile;
  final ScanFlowController controller;

  const ProcessingScreen({
    super.key,
    required this.imageFile,
    required this.controller,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _spinCtrl;
  bool _navigated = false;

  final _labels = const [
    'INITIALIZING SCANNER...',
    'ANALYZING LEAF PATTERNS...',
    'IDENTIFYING DISEASE MARKERS...',
    'COMPUTING CONFIDENCE...',
    'GENERATING RECOMMENDATIONS...',
  ];

  int _labelIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Cycle labels
    _cycleLabels();

    // Listen for completion
    widget.controller.addListener(_onStatusChanged);

    // Start analysis
    widget.controller.analyzeImage(widget.imageFile);
  }

  void _cycleLabels() async {
    for (var i = 1; i < _labels.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      setState(() => _labelIndex = i);
    }
  }

  void _onStatusChanged() {
    if (!mounted || _navigated) return;
    final ctrl = widget.controller;
    if (ctrl.status == ScanFlowStatus.done && ctrl.lastRecord != null) {
      _navigated = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(record: ctrl.lastRecord!),
        ),
      );
    } else if (ctrl.status == ScanFlowStatus.error ||
        (ctrl.status == ScanFlowStatus.done && ctrl.lastRecord == null)) {
      // Even on AI error the record is saved (unanalyzed)
      if (ctrl.lastRecord != null) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(record: ctrl.lastRecord!),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStatusChanged);
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinning ring
            AnimatedBuilder(
              animation: _spinCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _spinCtrl.value * 2 * pi,
                child: child,
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.neonGreen.withValues(alpha: 0.15),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neonGreen,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonGreen.withValues(alpha: 0.6),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Pulsing text
            FadeTransition(
              opacity: _pulseCtrl,
              child: Text(
                _labels[_labelIndex],
                style: const TextStyle(
                  color: AppColors.neonGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 20),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surfaceLight,
                color: AppColors.neonGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
