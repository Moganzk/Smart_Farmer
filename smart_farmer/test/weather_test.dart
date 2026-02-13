import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farmer/features/weather/weather_cache.dart';
import 'package:smart_farmer/features/weather/weather_controller.dart';
import 'package:smart_farmer/features/weather/weather_models.dart';

// ── Sample API payloads ──

final _currentJson = {
  'name': 'Nairobi',
  'main': {
    'temp': 22.5,
    'feels_like': 21.0,
    'temp_min': 18.0,
    'temp_max': 26.0,
    'humidity': 65,
  },
  'wind': {'speed': 3.2},
  'weather': [
    {'description': 'scattered clouds', 'icon': '03d', 'id': 802},
  ],
  'dt': 1700000000,
};

final _forecastJson = {
  'dt': 1700100000,
  'temp_min': 17.0,
  'temp_max': 28.0,
  'description': 'light rain',
  'icon': '10d',
  'id': 500,
};

// ── Tests ──

void main() {
  group('CurrentWeather', () {
    test('parses from JSON correctly', () {
      final w = CurrentWeather.fromJson(_currentJson);

      expect(w.cityName, 'Nairobi');
      expect(w.temp, 22.5);
      expect(w.feelsLike, 21.0);
      expect(w.tempMin, 18.0);
      expect(w.tempMax, 26.0);
      expect(w.humidity, 65);
      expect(w.windSpeed, 3.2);
      expect(w.description, 'scattered clouds');
      expect(w.icon, '03d');
      expect(w.conditionCode, 802);
    });

    test('round-trips through JSON', () {
      final w = CurrentWeather.fromJson(_currentJson);
      final w2 = CurrentWeather.fromJson(w.toJson());

      expect(w2.cityName, w.cityName);
      expect(w2.temp, w.temp);
      expect(w2.humidity, w.humidity);
      expect(w2.conditionCode, w.conditionCode);
    });

    test('weatherIcon maps codes correctly', () {
      expect(
        CurrentWeather.fromJson({
          ..._currentJson,
          'weather': [
            {'id': 200, 'icon': '11d', 'description': ''},
          ],
        }).weatherIcon,
        IconAlias.thunderstorm,
      );
      expect(
        CurrentWeather.fromJson({
          ..._currentJson,
          'weather': [
            {'id': 500, 'icon': '10d', 'description': ''},
          ],
        }).weatherIcon,
        IconAlias.rain,
      );
      expect(
        CurrentWeather.fromJson({
          ..._currentJson,
          'weather': [
            {'id': 800, 'icon': '01d', 'description': ''},
          ],
        }).weatherIcon,
        IconAlias.clearDay,
      );
      expect(
        CurrentWeather.fromJson({
          ..._currentJson,
          'weather': [
            {'id': 800, 'icon': '01n', 'description': ''},
          ],
        }).weatherIcon,
        IconAlias.clearNight,
      );
    });
  });

  group('ForecastDay', () {
    test('parses from JSON correctly', () {
      final f = ForecastDay.fromJson(_forecastJson);

      expect(f.tempMin, 17.0);
      expect(f.tempMax, 28.0);
      expect(f.description, 'light rain');
      expect(f.conditionCode, 500);
    });

    test('round-trips through JSON', () {
      final f = ForecastDay.fromJson(_forecastJson);
      final f2 = ForecastDay.fromJson(f.toJson());

      expect(f2.tempMin, f.tempMin);
      expect(f2.tempMax, f.tempMax);
      expect(f2.description, f.description);
    });
  });

  group('WeatherData', () {
    late WeatherData data;

    setUp(() {
      data = WeatherData(
        current: CurrentWeather.fromJson(_currentJson),
        forecast: [ForecastDay.fromJson(_forecastJson)],
      );
    });

    test('round-trips through JSON', () {
      final d2 = WeatherData.fromJson(data.toJson());

      expect(d2.current.cityName, 'Nairobi');
      expect(d2.forecast.length, 1);
      expect(d2.forecast.first.description, 'light rain');
    });

    test('parseForecastResponse groups by day', () {
      // Build a mock 5-day/3-hour response with entries across 2 days
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final dayAfter = now.add(const Duration(days: 2));

      List<Map<String, dynamic>> makeEntries(DateTime day, int count) {
        return List.generate(count, (i) {
          final dt = DateTime(day.year, day.month, day.day, 6 + i * 3);
          return {
            'dt': dt.millisecondsSinceEpoch ~/ 1000,
            'main': {'temp': 20.0 + i, 'humidity': 50},
            'weather': [
              {'description': 'clouds', 'icon': '04d', 'id': 804},
            ],
          };
        });
      }

      final response = {
        'list': [
          ...makeEntries(now, 3), // today → should be skipped
          ...makeEntries(tomorrow, 4),
          ...makeEntries(dayAfter, 4),
        ],
      };

      final days = WeatherData.parseForecastResponse(response);

      expect(days.length, 2);
      expect(days[0].description, 'clouds');
    });
  });

  group('WeatherCache', () {
    late WeatherCache cache;
    late WeatherData sampleData;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cache = WeatherCache(prefs, ttl: const Duration(minutes: 30));

      sampleData = WeatherData(
        current: CurrentWeather.fromJson(_currentJson),
        forecast: [ForecastDay.fromJson(_forecastJson)],
      );
    });

    test('save + load round-trips', () async {
      await cache.save(sampleData, -1.286, 36.817);

      final loaded = cache.load();
      expect(loaded, isNotNull);
      expect(loaded!.current.cityName, 'Nairobi');
      expect(loaded.forecast.length, 1);
    });

    test('isFresh returns true when freshly cached', () async {
      await cache.save(sampleData, -1.286, 36.817);

      expect(cache.isFresh, isTrue);
    });

    test('isFresh returns false when no cache', () {
      expect(cache.isFresh, isFalse);
    });

    test('isNearby detects nearby coordinates', () async {
      await cache.save(sampleData, -1.286, 36.817);

      expect(cache.isNearby(-1.286, 36.817), isTrue);
      expect(cache.isNearby(-1.287, 36.818), isTrue); // within 0.01°
      expect(cache.isNearby(-1.30, 36.83), isFalse); // too far
    });

    test('clear removes cached data', () async {
      await cache.save(sampleData, -1.286, 36.817);
      await cache.clear();

      expect(cache.load(), isNull);
      expect(cache.isFresh, isFalse);
    });

    test('stores lat/lon', () async {
      await cache.save(sampleData, -1.286, 36.817);

      expect(cache.lastLat, -1.286);
      expect(cache.lastLon, 36.817);
    });

    test('cacheTime is set after save', () async {
      await cache.save(sampleData, -1.286, 36.817);

      expect(cache.cacheTime, isNotNull);
      expect(
        cache.cacheTime!.difference(DateTime.now()).inSeconds.abs(),
        lessThan(2),
      );
    });
  });

  group('WeatherController', () {
    test('initial status is idle', () {
      // Can't construct a real controller without a repo/cache,
      // but model-level status enum is testable.
      expect(WeatherStatus.idle.name, 'idle');
      expect(WeatherStatus.values.length, 4);
    });
  });
}
