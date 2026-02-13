import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_container.dart';
import 'weather_cache.dart';
import 'weather_controller.dart';
import 'weather_models.dart';
import 'weather_repository.dart';

/// Full-screen weather dashboard — sci-fi themed.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherController? _controller;
  bool _initError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = WeatherCache(prefs);
      final repo = WeatherRepository(cache: cache);
      _controller = WeatherController(repo);
      _controller!.addListener(_onChanged);
      await _controller!.loadWeather();
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('WEATHER'),
        actions: [
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.cyan),
              onPressed: () => _controller!.refresh(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initError) return _errorView('Failed to initialise weather service.');

    final ctrl = _controller;
    if (ctrl == null ||
        ctrl.status == WeatherStatus.loading && ctrl.data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonGreen),
      );
    }

    if (ctrl.status == WeatherStatus.error) {
      return _errorView(ctrl.error ?? 'Unknown error');
    }

    final data = ctrl.data;
    if (data == null) return _errorView('No weather data available.');

    return RefreshIndicator(
      color: AppColors.neonGreen,
      backgroundColor: AppColors.surface,
      onRefresh: () => ctrl.refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ctrl.isOffline) _offlineBanner(),
          _heroCard(data.current),
          const SizedBox(height: 20),
          _detailsRow(data.current),
          const SizedBox(height: 24),
          _forecastSection(data.forecast),
          const SizedBox(height: 16),
          _cacheInfo(),
        ],
      ),
    );
  }

  // ── Hero card ──

  Widget _heroCard(CurrentWeather w) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      borderColor: AppColors.neonGreen.withValues(alpha: 0.3),
      child: Column(
        children: [
          // City
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: AppColors.cyan, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  w.cityName.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 14,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big temperature
          Text(
            '${w.temp.round()}°',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: AppColors.neonGreen,
              height: 1,
              shadows: [
                Shadow(color: AppColors.neonGreen, blurRadius: 30),
                Shadow(color: AppColors.neonGreen, blurRadius: 60),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            w.description.toUpperCase(),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Feels like + Hi/Lo
          Text(
            'FEELS LIKE ${w.feelsLike.round()}°  ·  '
            'H: ${w.tempMax.round()}°  L: ${w.tempMin.round()}°',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail chips ──

  Widget _detailsRow(CurrentWeather w) {
    return Row(
      children: [
        Expanded(
          child: _detailChip(Icons.water_drop, '${w.humidity}%', 'Humidity'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _detailChip(
            Icons.air,
            '${w.windSpeed.toStringAsFixed(1)} m/s',
            'Wind',
          ),
        ),
      ],
    );
  }

  Widget _detailChip(IconData icon, String value, String label) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      borderColor: AppColors.cyan.withValues(alpha: 0.2),
      child: Column(
        children: [
          Icon(icon, color: AppColors.cyan, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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

  // ── 5-day forecast ──

  Widget _forecastSection(List<ForecastDay> days) {
    if (days.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.neonGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'FORECAST',
              style: TextStyle(
                color: AppColors.neonGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...days.map(_forecastTile),
      ],
    );
  }

  Widget _forecastTile(ForecastDay day) {
    final dayName = DateFormat('EEE').format(day.date).toUpperCase();
    final dateFmt = DateFormat('d MMM').format(day.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: AppColors.surfaceLight.withValues(alpha: 0.5),
        child: Row(
          children: [
            // Day name
            SizedBox(
              width: 48,
              child: Text(
                dayName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            // Date
            SizedBox(
              width: 60,
              child: Text(
                dateFmt,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            // Icon
            _weatherIcon(day.conditionCode, day.icon, size: 22),
            const SizedBox(width: 8),
            // Desc
            Expanded(
              child: Text(
                day.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Temps
            Text(
              '${day.tempMax.round()}°',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${day.tempMin.round()}°',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _weatherIcon(int code, String iconStr, {double size = 28}) {
    IconData icon;
    Color color;
    if (code >= 200 && code < 300) {
      icon = Icons.flash_on;
      color = AppColors.warning;
    } else if (code >= 300 && code < 600) {
      icon = Icons.water_drop;
      color = AppColors.cyan;
    } else if (code >= 600 && code < 700) {
      icon = Icons.ac_unit;
      color = Colors.white;
    } else if (code >= 700 && code < 800) {
      icon = Icons.cloud;
      color = AppColors.textSecondary;
    } else if (code == 800) {
      icon = iconStr.contains('n') ? Icons.nightlight_round : Icons.wb_sunny;
      color = iconStr.contains('n') ? AppColors.cyan : AppColors.warning;
    } else {
      icon = Icons.cloud_queue;
      color = AppColors.textSecondary;
    }
    return Icon(icon, size: size, color: color);
  }

  Widget _offlineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: AppColors.warning, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached data — no internet',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cacheInfo() {
    final ctrl = _controller;
    if (ctrl == null) return const SizedBox.shrink();
    final cache = ctrl.data != null ? _controller!.data : null;
    if (cache == null) return const SizedBox.shrink();

    // Try to get cache time from the repo
    final ts = cache.current.timestamp;
    final formatted = DateFormat('d MMM, HH:mm').format(ts);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Updated: $formatted',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _controller?.loadWeather(),
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neonGreen,
                side: const BorderSide(color: AppColors.neonGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
