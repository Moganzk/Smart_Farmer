import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/logger.dart';
import 'weather_models.dart';
import 'weather_provider.dart';
import 'weather_repository.dart';

/// OpenWeatherMap implementation of [WeatherProvider].
///
/// Requires a valid API key from openweathermap.org.
class OpenWeatherProvider implements WeatherProvider {
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5';

  final String apiKey;
  final http.Client _http;

  OpenWeatherProvider({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  @override
  Future<WeatherData> fetchCurrentAndForecast({
    required double lat,
    required double lon,
  }) async {
    if (apiKey.isEmpty) {
      throw const WeatherException(
        'WEATHER_API_KEY is missing from .env — cannot fetch weather.',
      );
    }

    if (kDebugMode) {
      Log.i(
        'OWM',
        'API key present (${apiKey.substring(0, 4)}…, len=${apiKey.length})',
      );
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

  Future<CurrentWeather> _fetchCurrent(double lat, double lon) async {
    if (kDebugMode) Log.i('OWM', 'Fetching current: lat=$lat, lon=$lon');
    final uri = Uri.parse(
      '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
    );
    final res = await _http.get(uri);
    if (kDebugMode) Log.i('OWM', 'Current HTTP status: ${res.statusCode}');
    if (res.statusCode != 200) {
      throw WeatherException(
        'OpenWeatherMap current weather failed (${res.statusCode})',
      );
    }
    return CurrentWeather.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<ForecastDay>> _fetchForecast(double lat, double lon) async {
    if (kDebugMode) Log.i('OWM', 'Fetching forecast: lat=$lat, lon=$lon');
    final uri = Uri.parse(
      '$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
    );
    final res = await _http.get(uri);
    if (kDebugMode) Log.i('OWM', 'Forecast HTTP status: ${res.statusCode}');
    if (res.statusCode != 200) {
      throw WeatherException(
        'OpenWeatherMap forecast failed (${res.statusCode})',
      );
    }
    return WeatherData.parseForecastResponse(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  void dispose() => _http.close();
}
