import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farmer/features/weather/weather_cache.dart';
import 'package:smart_farmer/features/weather/weather_models.dart';
import 'package:smart_farmer/features/weather/weather_controller.dart';
import 'package:smart_farmer/features/weather/weather_repository.dart';

// ── Fake repo that always throws ──
class _FailingRepo implements WeatherRepository {
  @override
  final WeatherCache cache;

  _FailingRepo({required this.cache});

  @override
  Future<WeatherData> getWeather({bool forceRefresh = false}) async {
    throw const WeatherException('Network down');
  }

  @override
  Future<WeatherData> refresh() => getWeather(forceRefresh: true);

  @override
  void dispose() {}
}

final _sampleWeatherData = WeatherData(
  current: CurrentWeather(
    cityName: 'Nairobi',
    temp: 22.0,
    feelsLike: 21.0,
    tempMin: 18.0,
    tempMax: 26.0,
    humidity: 60,
    windSpeed: 2.0,
    description: 'clear',
    icon: '01d',
    conditionCode: 800,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  ),
  forecast: [],
);

void main() {
  group('WeatherController cache fallback', () {
    late WeatherCache cache;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cache = WeatherCache(prefs, ttl: const Duration(minutes: 30));
    });

    test('falls back to cache when network fails', () async {
      // Pre-fill cache
      await cache.save(_sampleWeatherData, -1.286, 36.817);

      final repo = _FailingRepo(cache: cache);
      final ctrl = WeatherController(repo);

      await ctrl.loadWeather();

      expect(ctrl.status, WeatherStatus.loaded);
      expect(ctrl.isOffline, true);
      expect(ctrl.data, isNotNull);
      expect(ctrl.data!.current.cityName, 'Nairobi');
      expect(ctrl.error, 'Network down');
    });

    test('shows error when network fails and no cache', () async {
      final repo = _FailingRepo(cache: cache);
      final ctrl = WeatherController(repo);

      await ctrl.loadWeather();

      expect(ctrl.status, WeatherStatus.error);
      expect(ctrl.data, isNull);
      expect(ctrl.error, 'Network down');
    });

    test('refresh falls back to stale data when network fails', () async {
      await cache.save(_sampleWeatherData, -1.286, 36.817);

      final repo = _FailingRepo(cache: cache);
      final ctrl = WeatherController(repo);

      // First load from cache
      await ctrl.loadWeather();
      expect(ctrl.data, isNotNull);

      // Force refresh — should keep old data
      await ctrl.refresh();
      expect(ctrl.status, WeatherStatus.loaded);
      expect(ctrl.isOffline, true);
      expect(ctrl.data!.current.cityName, 'Nairobi');
    });
  });
}
