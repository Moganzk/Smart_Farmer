import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/glow_button.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
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
                            'Welcome, Farmer',
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
                    IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                      ),
                      onPressed: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'DASHBOARD',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.neonGreen,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your farm at a glance',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Feature cards
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildFeatureCard(
                        context,
                        icon: Icons.camera_alt_rounded,
                        label: 'SCAN',
                        subtitle: 'Crop disease\ndetection',
                        color: AppColors.neonGreen,
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.history_rounded,
                        label: 'HISTORY',
                        subtitle: 'Past scan\nresults',
                        color: AppColors.cyan,
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.cloud_rounded,
                        label: 'WEATHER',
                        subtitle: 'Local weather\nforecast',
                        color: const Color(0xFFFFD600),
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.settings_rounded,
                        label: 'SETTINGS',
                        subtitle: 'App\nconfiguration',
                        color: AppColors.textSecondary,
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

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
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
          ),
        ),
      ),
    );
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          GlowButton(
            label: 'LOGOUT',
            icon: Icons.logout_rounded,
            glowColor: AppColors.error,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
