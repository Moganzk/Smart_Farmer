import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/section_header.dart';
import '../auth/auth_provider.dart';
import 'notifications_repository.dart';
import 'notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  /// Optional service for test injection.
  final NotificationsService? service;

  const NotificationsScreen({super.key, this.service});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsService _service;
  bool _externalService = false;

  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _service = widget.service!;
      _externalService = true;
    } else {
      _service = context.read<NotificationsService>();
      _externalService = true; // owned by provider tree
    }
    _initService();
  }

  Future<void> _initService() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    // Set uid and attach repository if not already done
    if (!_externalService || _service.uid == null) {
      NotificationsRepository? repo;
      try {
        repo = NotificationsRepository();
      } catch (_) {}

      // Re-create with uid if needed
      _service = NotificationsService(
        cache: _service.cacheForReinit,
        remote: repo,
        uid: uid,
      );
    }

    _service.addListener(_onChanged);
    await _service.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    if (!_externalService) _service.dispose();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'CLEAR ALL',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'Delete all notifications?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.clearAll();
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
              // Back + title + clear button
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
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
                    Expanded(
                      child: Text(
                        'NOTIFICATIONS',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: AppColors.neonGreen,
                              letterSpacing: 4,
                              fontSize: 20,
                            ),
                      ),
                    ),
                    if (_service.isOffline)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OFFLINE',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (_service.items.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          color: AppColors.error,
                          size: 22,
                        ),
                        tooltip: 'Clear all',
                        onPressed: _clearAll,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(title: 'Recent'),
              ),
              const SizedBox(height: 12),

              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_service.loading) {
      return _shimmerList();
    }
    if (_service.error != null && _service.items.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error',
        subtitle: _service.error!,
        iconColor: AppColors.error,
      );
    }
    if (_service.items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications',
        subtitle: 'You\'re all caught up!',
        iconColor: AppColors.cyan,
      );
    }
    return RefreshIndicator(
      color: AppColors.neonGreen,
      backgroundColor: AppColors.surface,
      onRefresh: () => _service.load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _service.items.length,
        separatorBuilder: (_, _a) => const SizedBox(height: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _service.markAsRead(i),
          child: _NotificationTile(notification: _service.items[i]),
        ),
      ),
    );
  }

  /// Shimmer loading placeholder.
  Widget _shimmerList() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderColor: notification.read
          ? const Color(0x22FFFFFF)
          : AppColors.cyan.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              notification.read
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              color: AppColors.cyan,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: notification.read
                        ? AppColors.textSecondary
                        : AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.read)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.cyan,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
