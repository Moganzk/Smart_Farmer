import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:smart_farmer/features/weather/google_weather_provider.dart';
import 'package:smart_farmer/features/weather/weather_models.dart';
import 'package:smart_farmer/features/weather/weather_repository.dart';

// ── Sample Google Weather API responses ──

final _currentConditionsJson = {
  'weatherCondition': {
    'iconBaseUri': 'https://maps.gstatic.com/weather/v1/partly_cloudy',
    'description': {'text': 'Partly cloudy', 'languageCode': 'en'},
    'type': 'PARTLY_CLOUDY',
  },
  'temperature': {'degrees': 24.5, 'unit': 'CELSIUS'},
  'feelsLikeTemperature': {'degrees': 23.0, 'unit': 'CELSIUS'},
  'relativeHumidity': 68,
  'wind': {
    'direction': {'degrees': 180, 'cardinal': 'SOUTH'},
    'speed': {'value': 12, 'unit': 'KILOMETERS_PER_HOUR'},
    'gust': {'value': 20, 'unit': 'KILOMETERS_PER_HOUR'},
  },
  'cloudCover': 45,
  'precipitation': {
    'probability': {'percent': 10, 'type': 'RAIN'},
    'qpf': {'quantity': 0, 'unit': 'MILLIMETERS'},
  },
};

Map<String, dynamic> _forecastDayJson({
  required int year,
  required int month,
  required int day,
  String condType = 'CLEAR',
  String descText = 'Sunny',
  double maxTemp = 28.0,
  double minTemp = 18.0,
}) => {
  'interval': {
    'startTime':
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T00:00:00Z',
    'endTime':
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T23:59:59Z',
  },
  'displayDate': {'year': year, 'month': month, 'day': day},
  'daytimeForecast': {
    'weatherCondition': {
      'iconBaseUri': 'https://maps.gstatic.com/weather/v1/sunny',
      'description': {'text': descText, 'languageCode': 'en'},
      'type': condType,
    },
    'relativeHumidity': 55,
    'wind': {
      'direction': {'degrees': 270, 'cardinal': 'WEST'},
      'speed': {'value': 8, 'unit': 'KILOMETERS_PER_HOUR'},
    },
  },
  'nighttimeForecast': {
    'weatherCondition': {
      'type': 'PARTLY_CLOUDY',
      'description': {'text': 'Partly cloudy', 'languageCode': 'en'},
    },
  },
  'maxTemperature': {'degrees': maxTemp, 'unit': 'CELSIUS'},
  'minTemperature': {'degrees': minTemp, 'unit': 'CELSIUS'},
  'feelsLikeMaxTemperature': {'degrees': maxTemp, 'unit': 'CELSIUS'},
  'feelsLikeMinTemperature': {'degrees': minTemp, 'unit': 'CELSIUS'},
};

void main() {
  group('GoogleWeatherProvider', () {
    test('parses current conditions correctly', () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final dayAfter = now.add(const Duration(days: 2));

      final mockClient = http_testing.MockClient((req) async {
        if (req.url.path.contains('currentConditions')) {
          return http.Response(jsonEncode(_currentConditionsJson), 200);
        }
        if (req.url.path.contains('forecast/days')) {
          return http.Response(
            jsonEncode({
              'forecastDays': [
                _forecastDayJson(
                  year: now.year,
                  month: now.month,
                  day: now.day,
                ),
                _forecastDayJson(
                  year: tomorrow.year,
                  month: tomorrow.month,
                  day: tomorrow.day,
                  condType: 'RAIN',
                  descText: 'Rain',
                  maxTemp: 22.0,
                  minTemp: 16.0,
                ),
                _forecastDayJson(
                  year: dayAfter.year,
                  month: dayAfter.month,
                  day: dayAfter.day,
                  condType: 'THUNDERSTORM',
                  descText: 'Thunderstorms',
                  maxTemp: 20.0,
                  minTemp: 15.0,
                ),
              ],
              'timeZone': {'id': 'Africa/Nairobi'},
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final provider = GoogleWeatherProvider(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final data = await provider.fetchCurrentAndForecast(
        lat: -1.286,
        lon: 36.817,
      );

      // Current conditions
      expect(data.current.temp, 24.5);
      expect(data.current.feelsLike, 23.0);
      expect(data.current.humidity, 68);
      expect(data.current.description, 'Partly cloudy');
      expect(data.current.conditionCode, 802); // PARTLY_CLOUDY
      expect(data.current.icon, '02d');
      expect(data.current.cityName, 'Nairobi'); // heuristic match

      // Wind: 12 km/h → m/s
      expect(data.current.windSpeed, closeTo(3.33, 0.01));

      // Forecast (today skipped)
      expect(data.forecast.length, 2);
      expect(data.forecast[0].description, 'Rain');
      expect(data.forecast[0].tempMax, 22.0);
      expect(data.forecast[0].tempMin, 16.0);
      expect(data.forecast[0].conditionCode, 500); // RAIN
      expect(data.forecast[1].description, 'Thunderstorms');
      expect(data.forecast[1].conditionCode, 200); // THUNDERSTORM

      provider.dispose();
    });

    test('throws WeatherException on API error', () async {
      final mockClient = http_testing.MockClient((req) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'API not enabled', 'code': 403},
          }),
          403,
        );
      });

      final provider = GoogleWeatherProvider(
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      expect(
        () => provider.fetchCurrentAndForecast(lat: 0, lon: 0),
        throwsA(isA<WeatherException>()),
      );

      provider.dispose();
    });

    test('throws on empty API key', () async {
      final provider = GoogleWeatherProvider(apiKey: '');

      expect(
        () => provider.fetchCurrentAndForecast(lat: 0, lon: 0),
        throwsA(isA<WeatherException>()),
      );
    });

    test('condition type mapping covers all major types', () {
      // Verify key mappings via the static method
      expect(GoogleWeatherProvider.conditionTypeToOwmCode('CLEAR'), 800);
      expect(GoogleWeatherProvider.conditionTypeToOwmCode('THUNDERSTORM'), 200);
      expect(GoogleWeatherProvider.conditionTypeToOwmCode('HEAVY_RAIN'), 502);
      expect(GoogleWeatherProvider.conditionTypeToOwmCode('SNOW'), 601);
      expect(GoogleWeatherProvider.conditionTypeToOwmCode('FOG'), 741);
    });

    test('icon mapping returns valid OWM icons', () {
      expect(GoogleWeatherProvider.conditionTypeToIcon('CLEAR'), '01d');
      expect(GoogleWeatherProvider.conditionTypeToIcon('PARTLY_CLOUDY'), '02d');
      expect(GoogleWeatherProvider.conditionTypeToIcon('RAIN'), '10d');
      expect(GoogleWeatherProvider.conditionTypeToIcon('THUNDERSTORM'), '11d');
      expect(GoogleWeatherProvider.conditionTypeToIcon('SNOW'), '13d');
    });

    test('city name heuristics for Kenya', () async {
      // Test via a full fetch to exercise _cityNameFromCoords
      final mockClient = http_testing.MockClient((req) async {
        if (req.url.path.contains('currentConditions')) {
          return http.Response(jsonEncode(_currentConditionsJson), 200);
        }
        return http.Response(
          jsonEncode({
            'forecastDays': [],
            'timeZone': {'id': 'Africa/Nairobi'},
          }),
          200,
        );
      });

      final provider = GoogleWeatherProvider(
        apiKey: 'test',
        httpClient: mockClient,
      );

      // Mombasa coordinates
      final data = await provider.fetchCurrentAndForecast(
        lat: -4.043,
        lon: 39.668,
      );
      expect(data.current.cityName, 'Mombasa');

      // Unknown coordinates
      final data2 = await provider.fetchCurrentAndForecast(
        lat: 10.0,
        lon: 20.0,
      );
      expect(data2.current.cityName, contains('°'));

      provider.dispose();
    });

    test(
      'forecast parses WeatherData that round-trips through cache JSON',
      () async {
        final now = DateTime.now();
        final tomorrow = now.add(const Duration(days: 1));

        final mockClient = http_testing.MockClient((req) async {
          if (req.url.path.contains('currentConditions')) {
            return http.Response(jsonEncode(_currentConditionsJson), 200);
          }
          return http.Response(
            jsonEncode({
              'forecastDays': [
                _forecastDayJson(
                  year: tomorrow.year,
                  month: tomorrow.month,
                  day: tomorrow.day,
                ),
              ],
              'timeZone': {'id': 'Africa/Nairobi'},
            }),
            200,
          );
        });

        final provider = GoogleWeatherProvider(
          apiKey: 'test',
          httpClient: mockClient,
        );

        final data = await provider.fetchCurrentAndForecast(
          lat: -1.286,
          lon: 36.817,
        );

        // Round-trip through JSON (same as cache format)
        final json = data.toJson();
        final restored = WeatherData.fromJson(json);

        expect(restored.current.temp, data.current.temp);
        expect(restored.current.humidity, data.current.humidity);
        expect(restored.forecast.length, data.forecast.length);

        provider.dispose();
      },
    );
  });
}
