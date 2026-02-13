import 'package:flutter/foundation.dart';

import '../../core/utils/logger.dart';
import '../notifications/notifications_service.dart';
import 'weather_models.dart';
import 'weather_repository.dart';

enum WeatherStatus { idle, loading, loaded, error }

/// ChangeNotifier that drives the Weather UI.
class WeatherController extends ChangeNotifier {
  final WeatherRepository _repo;
  final NotificationsService? _notifications;

  WeatherController(this._repo, {NotificationsService? notifications})
    : _notifications = notifications;

  WeatherStatus _status = WeatherStatus.idle;
  WeatherData? _data;
  String? _error;
  bool _isOffline = false;

  // ── Getters ──

  WeatherStatus get status => _status;
  WeatherData? get data => _data;
  CurrentWeather? get current => _data?.current;
  List<ForecastDay> get forecast => _data?.forecast ?? [];
  String? get error => _error;
  bool get isOffline => _isOffline;

  // ── Actions ──

  /// Load weather (cache-first).
  Future<void> loadWeather() async {
    _status = WeatherStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _data = await _repo.getWeather();
      _isOffline = false;
      _status = WeatherStatus.loaded;
      _checkWeatherAlerts();
    } on WeatherException catch (e) {
      _error = e.message;
      if (kDebugMode) Log.w('WeatherCtrl', 'WeatherException: ${e.message}');
      // Check if we have stale cache to show
      final cached = _repo.cache.load();
      if (cached != null) {
        _data = cached;
        _isOffline = true;
        _status = WeatherStatus.loaded;
      } else {
        _status = WeatherStatus.error;
      }
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      if (kDebugMode) Log.e('WeatherCtrl', 'Unexpected error', e);
      final cached = _repo.cache.load();
      if (cached != null) {
        _data = cached;
        _isOffline = true;
        _status = WeatherStatus.loaded;
      } else {
        _status = WeatherStatus.error;
      }
    }

    notifyListeners();
  }

  /// Force refresh from network.
  Future<void> refresh() async {
    _status = WeatherStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _data = await _repo.refresh();
      _isOffline = false;
      _status = WeatherStatus.loaded;
    } on WeatherException catch (e) {
      _error = e.message;
      if (_data != null) {
        _isOffline = true;
        _status = WeatherStatus.loaded;
      } else {
        _status = WeatherStatus.error;
      }
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      if (_data != null) {
        _isOffline = true;
        _status = WeatherStatus.loaded;
      } else {
        _status = WeatherStatus.error;
      }
    }

    notifyListeners();
  }

  /// Check for severe weather conditions and create alerts.
  void _checkWeatherAlerts() {
    final current = _data?.current;
    if (current == null || _notifications == null) return;

    // Alert for storm / heavy rain / extreme conditions
    final code = current.conditionCode;
    final isAlertWorthy =
        code >= 200 && code < 300 || // thunderstorm
        code == 502 ||
        code == 503 ||
        code == 504 || // heavy rain
        code >= 600 && code < 700 || // snow
        code >= 700 && code < 800; // fog/haze

    if (isAlertWorthy) {
      _notifications.onWeatherAlert(
        condition: current.description.isNotEmpty
            ? current.description[0].toUpperCase() +
                  current.description.substring(1)
            : 'Severe weather',
        location: current.cityName,
      );
    }
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }
}
