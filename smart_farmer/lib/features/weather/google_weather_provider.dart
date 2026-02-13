import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/logger.dart';
import 'weather_models.dart';
import 'weather_provider.dart';
import 'weather_repository.dart';

/// Google Weather API implementation of [WeatherProvider].
///
/// Uses the Google Maps Platform Weather API:
///   - Current conditions: `currentConditions:lookup`
///   - Daily forecast:     `forecast/days:lookup`
///
/// Requires a valid `GOOGLE_WEATHER_API_KEY` with the Weather API enabled
/// in Google Cloud Console.
class GoogleWeatherProvider implements WeatherProvider {
  static const _baseUrl = 'https://weather.googleapis.com/v1';

  final String apiKey;
  final http.Client _http;

  GoogleWeatherProvider({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  @override
  Future<WeatherData> fetchCurrentAndForecast({
    required double lat,
    required double lon,
  }) async {
    if (apiKey.isEmpty) {
      throw const WeatherException(
        'GOOGLE_WEATHER_API_KEY is missing — cannot fetch weather.',
      );
    }

    if (kDebugMode) {
      Log.i(
        'GoogleWeather',
        'API key present (${apiKey.substring(0, apiKey.length.clamp(0, 6))}…, len=${apiKey.length})',
      );
      Log.i('GoogleWeather', 'Fetching lat=$lat, lon=$lon');
    }

    final results = await Future.wait([
      _fetchCurrent(lat, lon),
      _fetchForecast(lat, lon),
    ]);

    return WeatherData(
      current: results[0] as CurrentWeather,
      forecast: results[1] as List<ForecastDay>,
    );
  }

  // ── Current conditions ──

  Future<CurrentWeather> _fetchCurrent(double lat, double lon) async {
    final uri = Uri.parse(
      '$_baseUrl/currentConditions:lookup'
      '?key=$apiKey'
      '&location.latitude=$lat'
      '&location.longitude=$lon',
    );

    final res = await _http.get(uri);
    if (kDebugMode) {
      Log.i('GoogleWeather', 'Current HTTP ${res.statusCode}');
    }
    if (res.statusCode != 200) {
      throw WeatherException(
        'Google Weather current conditions failed (${res.statusCode}): '
        '${_errorMessage(res.body)}',
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return _parseCurrent(json, lat, lon);
  }

  CurrentWeather _parseCurrent(
    Map<String, dynamic> json,
    double lat,
    double lon,
  ) {
    // weatherCondition
    final wc = json['weatherCondition'] as Map<String, dynamic>? ?? {};
    final condType = wc['type'] as String? ?? 'CLEAR';
    final desc =
        (wc['description'] as Map<String, dynamic>?)?['text'] as String? ??
        condType.replaceAll('_', ' ').toLowerCase();

    // temperature
    final temp =
        (json['temperature'] as Map<String, dynamic>?)?['degrees'] as num? ?? 0;
    final feelsLike =
        (json['feelsLikeTemperature'] as Map<String, dynamic>?)?['degrees']
            as num? ??
        temp;

    // humidity
    final humidity = (json['relativeHumidity'] as num?)?.toInt() ?? 0;

    // wind
    final wind = json['wind'] as Map<String, dynamic>? ?? {};
    final windSpeed =
        ((wind['speed'] as Map<String, dynamic>?)?['value'] as num?)
            ?.toDouble() ??
        0.0;

    // Map Google condition type to OWM-compatible code + icon
    final code = conditionTypeToOwmCode(condType);
    final icon = conditionTypeToIcon(condType);

    return CurrentWeather(
      cityName: _cityNameFromCoords(lat, lon),
      temp: temp.toDouble(),
      feelsLike: feelsLike.toDouble(),
      tempMin: temp.toDouble(), // will be overridden from forecast if available
      tempMax: temp.toDouble(),
      humidity: humidity,
      windSpeed: windSpeed / 3.6, // convert km/h → m/s for UI consistency
      description: desc,
      icon: icon,
      conditionCode: code,
      timestamp: DateTime.now(),
    );
  }

  // ── Daily forecast ──

  Future<List<ForecastDay>> _fetchForecast(double lat, double lon) async {
    final uri = Uri.parse(
      '$_baseUrl/forecast/days:lookup'
      '?key=$apiKey'
      '&location.latitude=$lat'
      '&location.longitude=$lon'
      '&days=6',
    );

    final res = await _http.get(uri);
    if (kDebugMode) {
      Log.i('GoogleWeather', 'Forecast HTTP ${res.statusCode}');
    }
    if (res.statusCode != 200) {
      throw WeatherException(
        'Google Weather forecast failed (${res.statusCode}): '
        '${_errorMessage(res.body)}',
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return _parseForecast(json);
  }

  List<ForecastDay> _parseForecast(Map<String, dynamic> json) {
    final daysJson = json['forecastDays'] as List? ?? [];
    final forecast = <ForecastDay>[];

    for (var i = 0; i < daysJson.length && forecast.length < 5; i++) {
      final day = daysJson[i] as Map<String, dynamic>;
      final displayDate = day['displayDate'] as Map<String, dynamic>? ?? {};

      final date = DateTime(
        (displayDate['year'] as num?)?.toInt() ?? DateTime.now().year,
        (displayDate['month'] as num?)?.toInt() ?? 1,
        (displayDate['day'] as num?)?.toInt() ?? 1,
      );

      // Skip today
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        continue;
      }

      final maxTemp =
          (day['maxTemperature'] as Map<String, dynamic>?)?['degrees']
              as num? ??
          0;
      final minTemp =
          (day['minTemperature'] as Map<String, dynamic>?)?['degrees']
              as num? ??
          0;

      // Use daytime forecast for description
      final daytime = day['daytimeForecast'] as Map<String, dynamic>? ?? {};
      final wc = daytime['weatherCondition'] as Map<String, dynamic>? ?? {};
      final condType = wc['type'] as String? ?? 'CLEAR';
      final desc =
          (wc['description'] as Map<String, dynamic>?)?['text'] as String? ??
          condType.replaceAll('_', ' ').toLowerCase();

      forecast.add(
        ForecastDay(
          date: date,
          tempMin: minTemp.toDouble(),
          tempMax: maxTemp.toDouble(),
          description: desc,
          icon: conditionTypeToIcon(condType),
          conditionCode: conditionTypeToOwmCode(condType),
        ),
      );
    }

    return forecast;
  }

  // ── Helpers ──

  /// Extract error message from Google API error response.
  String _errorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      return error?['message'] as String? ?? 'Unknown error';
    } catch (_) {
      return body.length > 200 ? body.substring(0, 200) : body;
    }
  }

  /// Approximate city name from coordinates (Kenya-specific heuristics).
  String _cityNameFromCoords(double lat, double lon) {
    const cities = <(double, double, String)>[
      (-1.286, 36.817, 'Nairobi'),
      (-4.043, 39.668, 'Mombasa'),
      (0.514, 35.270, 'Eldoret'),
      (-0.091, 34.768, 'Kisumu'),
      (-0.423, 36.951, 'Thika'),
      (-1.516, 37.264, 'Machakos'),
      (0.052, 37.650, 'Meru'),
      (-0.717, 36.430, 'Nakuru'),
      (-1.100, 37.010, 'Juja'),
    ];
    for (final (cLat, cLon, name) in cities) {
      if ((lat - cLat).abs() < 0.2 && (lon - cLon).abs() < 0.2) return name;
    }
    return '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
  }

  /// Map Google Weather condition type strings to OWM-compatible codes.
  static int conditionTypeToOwmCode(String type) {
    switch (type) {
      case 'CLEAR':
        return 800;
      case 'MOSTLY_CLEAR':
        return 801;
      case 'PARTLY_CLOUDY':
        return 802;
      case 'MOSTLY_CLOUDY':
        return 803;
      case 'CLOUDY':
      case 'OVERCAST':
        return 804;
      case 'FOG':
      case 'LIGHT_FOG':
        return 741;
      case 'DRIZZLE':
      case 'LIGHT_RAIN':
        return 300;
      case 'RAIN':
      case 'MODERATE_RAIN':
        return 500;
      case 'HEAVY_RAIN':
        return 502;
      case 'RAIN_SHOWERS':
      case 'SCATTERED_SHOWERS':
        return 521;
      case 'SNOW':
      case 'LIGHT_SNOW':
      case 'MODERATE_SNOW':
      case 'HEAVY_SNOW':
        return 601;
      case 'SNOW_SHOWERS':
      case 'FLURRIES':
        return 621;
      case 'RAIN_AND_SNOW':
      case 'SLEET':
      case 'FREEZING_RAIN':
      case 'FREEZING_DRIZZLE':
      case 'ICE_PELLETS':
        return 611;
      case 'THUNDERSTORM':
      case 'THUNDERSTORMS':
      case 'ISOLATED_THUNDERSTORMS':
      case 'SCATTERED_THUNDERSTORMS':
        return 200;
      case 'HAZE':
      case 'DUST':
      case 'SMOKE':
        return 721;
      case 'TORNADO':
        return 781;
      case 'WINDY':
      case 'BREEZY':
        return 800; // no OWM wind-only code; use clear
      default:
        return 800;
    }
  }

  /// Map Google Weather condition type to an OWM icon string.
  static String conditionTypeToIcon(String type) {
    switch (type) {
      case 'CLEAR':
      case 'MOSTLY_CLEAR':
        return '01d';
      case 'PARTLY_CLOUDY':
        return '02d';
      case 'MOSTLY_CLOUDY':
        return '03d';
      case 'CLOUDY':
      case 'OVERCAST':
        return '04d';
      case 'FOG':
      case 'LIGHT_FOG':
      case 'HAZE':
        return '50d';
      case 'DRIZZLE':
      case 'LIGHT_RAIN':
        return '09d';
      case 'RAIN':
      case 'MODERATE_RAIN':
      case 'HEAVY_RAIN':
      case 'RAIN_SHOWERS':
      case 'SCATTERED_SHOWERS':
        return '10d';
      case 'SNOW':
      case 'LIGHT_SNOW':
      case 'MODERATE_SNOW':
      case 'HEAVY_SNOW':
      case 'SNOW_SHOWERS':
      case 'FLURRIES':
        return '13d';
      case 'RAIN_AND_SNOW':
      case 'SLEET':
      case 'FREEZING_RAIN':
      case 'FREEZING_DRIZZLE':
      case 'ICE_PELLETS':
        return '13d';
      case 'THUNDERSTORM':
      case 'THUNDERSTORMS':
      case 'ISOLATED_THUNDERSTORMS':
      case 'SCATTERED_THUNDERSTORMS':
        return '11d';
      default:
        return '01d';
    }
  }

  @override
  void dispose() => _http.close();
}
