import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/utils/logger.dart';
import 'google_weather_provider.dart';
import 'open_meteo_provider.dart';
import 'open_weather_provider.dart';
import 'weather_cache.dart';
import 'weather_models.dart';
import 'weather_provider.dart';

/// Handles location + provider selection + caching for weather data.
///
/// The provider is selected by the `WEATHER_PROVIDER` env variable:
///   - `google`    → Google Weather API  (default, uses GOOGLE_WEATHER_API_KEY)
///   - `openweather` → OpenWeatherMap     (uses WEATHER_API_KEY)
///   - `openmeteo`   → Open-Meteo         (no key required)
class WeatherRepository {
  final WeatherCache cache;
  final WeatherProvider _provider;

  WeatherRepository({required this.cache, WeatherProvider? provider})
    : _provider = provider ?? _createProvider();

  /// Factory that reads .env to pick the right provider.
  static WeatherProvider _createProvider() {
    final providerName = (dotenv.env['WEATHER_PROVIDER'] ?? 'google')
        .toLowerCase()
        .trim();

    if (kDebugMode) {
      Log.i('Weather', 'Provider selection: "$providerName"');
    }

    switch (providerName) {
      case 'openweather':
      case 'owm':
        final key = dotenv.env['WEATHER_API_KEY'] ?? '';
        if (kDebugMode) {
          Log.i('Weather', 'Using OpenWeatherMap (key len=${key.length})');
        }
        return OpenWeatherProvider(apiKey: key);

      case 'openmeteo':
      case 'open-meteo':
        if (kDebugMode) Log.i('Weather', 'Using Open-Meteo (no key)');
        return OpenMeteoProvider();

      case 'google':
      default:
        final key = dotenv.env['GOOGLE_WEATHER_API_KEY'] ?? '';
        if (kDebugMode) {
          Log.i('Weather', 'Using Google Weather API (key len=${key.length})');
        }
        return GoogleWeatherProvider(apiKey: key);
    }
  }

  // ── Public API ──

  /// Fetch weather, using cache when fresh, falling back to network.
  Future<WeatherData> getWeather({bool forceRefresh = false}) async {
    // Try cache first
    if (!forceRefresh && cache.isFresh) {
      final cached = cache.load();
      if (cached != null) {
        if (kDebugMode) Log.i('Weather', 'Serving from cache (fresh)');
        return cached;
      }
    }

    // Get location
    final position = await _determinePosition();

    // If cached is near same spot and still fresh, use it
    if (!forceRefresh &&
        cache.isFresh &&
        cache.isNearby(position.latitude, position.longitude)) {
      final cached = cache.load();
      if (cached != null) {
        if (kDebugMode) Log.i('Weather', 'Serving from cache (nearby)');
        return cached;
      }
    }

    // Network call via provider
    return _fetchAndCache(position.latitude, position.longitude);
  }

  /// Force refresh from network with the last known or current position.
  Future<WeatherData> refresh() => getWeather(forceRefresh: true);

  // ── Private helpers ──

  Future<WeatherData> _fetchAndCache(double lat, double lon) async {
    if (kDebugMode) {
      Log.i('Weather', 'Fetching from provider: lat=$lat, lon=$lon');
    }

    final data = await _provider.fetchCurrentAndForecast(lat: lat, lon: lon);
    await cache.save(data, lat, lon);

    if (kDebugMode) {
      Log.i(
        'Weather',
        'Fetched OK: ${data.current.cityName}, '
            '${data.current.temp.toStringAsFixed(1)}°C, '
            '${data.forecast.length} forecast days',
      );
    }
    return data;
  }

  // ── Location ──

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const WeatherException(
        'Location services are disabled. Please enable them.',
      );
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw const WeatherException('Location permission denied.');
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw const WeatherException(
        'Location permissions are permanently denied. '
        'Please enable them in settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Dispose the provider.
  void dispose() => _provider.dispose();
}

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);

  @override
  String toString() => message;
}
