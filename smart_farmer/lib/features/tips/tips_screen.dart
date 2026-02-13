import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/section_header.dart';
import '../../core/utils/logger.dart';
import 'tips_repository.dart';
import 'local_tips_cache.dart';
import 'tip_detail_screen.dart';

class TipsScreen extends StatefulWidget {
  /// Optional cache for test injection.
  final LocalTipsCache? cache;

  const TipsScreen({super.key, this.cache});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  TipsRepository? _repo;
  late final LocalTipsCache _cache;

  List<String> _categories = [];
  List<Tip> _tips = [];
  String? _selectedCategory;
  bool _loading = true;
  String? _error;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? LocalTipsCache();
    try {
      _repo = TipsRepository();
    } catch (_) {
      // Firebase not available (e.g. in tests)
    }
    _loadData();
  }

  Future<void> _loadData() async {
    if (_repo == null) {
      // Try offline cache only
      await _loadFromCache();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _isOffline = false;
    });
    try {
      final cats = await _repo!.fetchCategories();
      final tips = await _repo!.fetchTips(category: _selectedCategory);

      // Cache all tips (unfiltered) for offline use
      if (_selectedCategory == null) {
        await _cache.replaceAll(tips);
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _tips = tips;
          _loading = false;
        });
      }
    } catch (e) {
      Log.w('TipsScreen', 'Firestore fetch failed, falling back to cache: $e');
      _error = 'Firestore read failed: $e';
      await _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final cats = await _cache.getCachedCategories();
      final tips = await _cache.getCachedTips(category: _selectedCategory);
      if (mounted) {
        setState(() {
          _categories = cats;
          _tips = tips;
          _loading = false;
          _isOffline = true;
          _error = tips.isEmpty ? 'No cached tips available.' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load tips.';
          _loading = false;
        });
      }
    }
  }

  void _selectCategory(String? cat) {
    setState(() => _selectedCategory = cat);
    _loadData();
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'FARMING TIPS',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: AppColors.neonGreen,
                              letterSpacing: 4,
                            ),
                      ),
                    ),
                    if (_isOffline)
                      Container(
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
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Expert advice for your crops',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Category chips ──
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: _selectedCategory == null,
                      onTap: () => _selectCategory(null),
                    ),
                    ..._categories.map(
                      (c) => _CategoryChip(
                        label: c,
                        selected: _selectedCategory == c,
                        onTap: () => _selectCategory(c),
                      ),
                    ),
                    // Placeholder chips if no categories loaded yet
                    if (_categories.isEmpty && !_loading) ...[
                      for (final c in ['Maize', 'Beans', 'Tomatoes'])
                        _CategoryChip(
                          label: c,
                          selected: false,
                          onTap: () => _selectCategory(c),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SectionHeader(title: 'Tips'),
              ),
              const SizedBox(height: 10),

              // ── Body ──
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonGreen),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error',
        subtitle: _error!,
        iconColor: AppColors.error,
      );
    }
    if (_tips.isEmpty) {
      return const EmptyState(
        icon: Icons.eco_rounded,
        title: 'No tips yet',
        subtitle: 'Farming tips will appear here once added.',
        iconColor: AppColors.neonGreen,
      );
    }
    return RefreshIndicator(
      color: AppColors.neonGreen,
      backgroundColor: AppColors.surface,
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: _tips.length,
        separatorBuilder: (_, _a) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TipCard(
          tip: _tips[i],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TipDetailScreen(tip: _tips[i])),
            );
          },
        ),
      ),
    );
  }
}

// ── Category chip ──

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.neonGreen.withValues(alpha: 0.15)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.neonGreen : AppColors.surfaceLight,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.neonGreen : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tip card ──

class _TipCard extends StatelessWidget {
  final Tip tip;
  final VoidCallback? onTap;
  const _TipCard({required this.tip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tip.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tip.title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tip.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
