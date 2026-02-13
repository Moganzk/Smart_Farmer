import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'weather_models.dart';

/// Local disk cache for weather data using SharedPreferences.
///
/// Stores serialised [WeatherData] JSON + a timestamp.
/// [ttl] controls how long data is considered fresh (default 30 min).
class WeatherCache {
  static const _keyWeatherData = 'weather_data';
  static const _keyCacheTime = 'weather_cache_time';
  static const _keyLastLat = 'weather_last_lat';
  static const _keyLastLon = 'weather_last_lon';

  final Duration ttl;
  final SharedPreferences _prefs;

  WeatherCache(this._prefs, {this.ttl = const Duration(minutes: 30)});

  // ── Write ──

  Future<void> save(WeatherData data, double lat, double lon) async {
    await _prefs.setString(_keyWeatherData, jsonEncode(data.toJson()));
    await _prefs.setInt(_keyCacheTime, DateTime.now().millisecondsSinceEpoch);
    await _prefs.setDouble(_keyLastLat, lat);
    await _prefs.setDouble(_keyLastLon, lon);
  }

  // ── Read ──

  WeatherData? load() {
    final raw = _prefs.getString(_keyWeatherData);
    if (raw == null) return null;
    try {
      return WeatherData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Freshness ──

  bool get isFresh {
    final ts = _prefs.getInt(_keyCacheTime);
    if (ts == null) return false;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
    return age < ttl;
  }

  DateTime? get cacheTime {
    final ts = _prefs.getInt(_keyCacheTime);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ── Location helpers ──

  double? get lastLat => _prefs.getDouble(_keyLastLat);
  double? get lastLon => _prefs.getDouble(_keyLastLon);

  /// True if cached location is within ~1 km of given coords.
  bool isNearby(double lat, double lon) {
    final cachedLat = lastLat;
    final cachedLon = lastLon;
    if (cachedLat == null || cachedLon == null) return false;

    // Rough check – ±0.01° ≈ 1.1 km
    return (cachedLat - lat).abs() < 0.01 && (cachedLon - lon).abs() < 0.01;
  }

  // ── Clear ──

  Future<void> clear() async {
    await _prefs.remove(_keyWeatherData);
    await _prefs.remove(_keyCacheTime);
    await _prefs.remove(_keyLastLat);
    await _prefs.remove(_keyLastLon);
  }
}
