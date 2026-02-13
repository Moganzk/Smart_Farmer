import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/section_header.dart';
import '../auth/auth_provider.dart';
import '../auth/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final p = await UserService().getProfile(uid);
      if (mounted)
        setState(() {
          _profile = p;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;

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
                      'PROFILE',
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
              const SizedBox(height: 24),

              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.neonGreen, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonGreen.withValues(alpha: 0.25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.neonGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),

              if (_loading)
                const CircularProgressIndicator(color: AppColors.neonGreen)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SectionHeader(title: 'Account Info'),
                      const SizedBox(height: 14),
                      _InfoRow(label: 'UID', value: user?.uid ?? '—'),
                      _InfoRow(
                        label: 'Email',
                        value: user?.email ?? _profile?.email ?? '—',
                      ),
                      _InfoRow(
                        label: 'Phone',
                        value: user?.phoneNumber ?? _profile?.phone ?? '—',
                      ),
                      _InfoRow(
                        label: 'Role',
                        value: _profile?.role ?? 'farmer',
                      ),
                      const SizedBox(height: 24),
                      GlassContainer(
                        padding: const EdgeInsets.all(14),
                        borderColor: AppColors.cyan.withValues(alpha: 0.2),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: AppColors.cyan,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Edit name — coming soon',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
