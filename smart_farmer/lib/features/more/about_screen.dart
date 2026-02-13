import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back + title
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.neonGreen,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'ABOUT',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            color: AppColors.neonGreen,
                            letterSpacing: 4,
                            fontSize: 20,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonGreen.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.neonGreen.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonGreen.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.neonGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppConstants.appName.toUpperCase(),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.neonGreen,
                  letterSpacing: 3,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Version 1.0.0',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Smart Farmer uses AI-powered image recognition to '
                    'help farmers diagnose crop diseases in real time. '
                    'Take a photo, get an instant diagnosis, and receive '
                    'expert treatment recommendations — all from your phone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  '© 2026 Smart Farmer',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
