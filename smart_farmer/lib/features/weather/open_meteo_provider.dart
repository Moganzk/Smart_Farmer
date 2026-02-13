import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/logger.dart';
import 'weather_models.dart';
import 'weather_provider.dart';
import 'weather_repository.dart';

/// Open-Meteo implementation of [WeatherProvider].
///
/// **No API key required.** Free, open-source weather API.
/// https://open-meteo.com/
class OpenMeteoProvider implements WeatherProvider {
  static const _baseUrl = 'https://api.open-meteo.com/v1';

  final http.Client _http;

  OpenMeteoProvider({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  @override
  Future<WeatherData> fetchCurrentAndForecast({
    required double lat,
    required double lon,
  }) async {
    if (kDebugMode) Log.i('OpenMeteo', 'Fetching lat=$lat, lon=$lon');

    final uri = Uri.parse(
      '$_baseUrl/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature'
      ',wind_speed_10m,weather_code'
      '&daily=temperature_2m_max,temperature_2m_min,weather_code'
      '&timezone=auto'
      '&forecast_days=6',
    );

    final res = await _http.get(uri);
    if (kDebugMode) Log.i('OpenMeteo', 'HTTP status: ${res.statusCode}');

    if (res.statusCode != 200) {
      throw WeatherException('Open-Meteo request failed (${res.statusCode})');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (kDebugMode) Log.i('OpenMeteo', 'Response keys: ${json.keys}');

    return _parseResponse(json, lat, lon);
  }

  WeatherData _parseResponse(
    Map<String, dynamic> json,
    double lat,
    double lon,
  ) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final wmoCode = (current['weather_code'] as num?)?.toInt() ?? 0;

    final currentWeather = CurrentWeather(
      cityName: _cityNameFromCoords(lat, lon),
      temp: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
      tempMin: _safeDailyDouble(daily, 'temperature_2m_min', 0),
      tempMax: _safeDailyDouble(daily, 'temperature_2m_max', 0),
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      description: _wmoDescription(wmoCode),
      icon: _wmoToIcon(wmoCode),
      conditionCode: _wmoToOwmCode(wmoCode),
      timestamp: DateTime.now(),
    );

    // Parse daily forecast (skip today = index 0)
    final dates = (daily['time'] as List?)?.cast<String>() ?? [];
    final maxTemps = (daily['temperature_2m_max'] as List?)?.cast<num>() ?? [];
    final minTemps = (daily['temperature_2m_min'] as List?)?.cast<num>() ?? [];
    final codes = (daily['weather_code'] as List?)?.cast<num>() ?? [];

    final forecast = <ForecastDay>[];
    for (var i = 1; i < dates.length && forecast.length < 5; i++) {
      final code = (i < codes.length) ? codes[i].toInt() : 0;
      forecast.add(
        ForecastDay(
          date: DateTime.parse(dates[i]),
          tempMin: (i < minTemps.length) ? minTemps[i].toDouble() : 0.0,
          tempMax: (i < maxTemps.length) ? maxTemps[i].toDouble() : 0.0,
          description: _wmoDescription(code),
          icon: _wmoToIcon(code),
          conditionCode: _wmoToOwmCode(code),
        ),
      );
    }

    return WeatherData(current: currentWeather, forecast: forecast);
  }

  double _safeDailyDouble(Map<String, dynamic> daily, String key, int index) {
    final list = daily[key] as List?;
    if (list == null || list.isEmpty) return 0.0;
    final idx = index < list.length ? index : 0;
    return (list[idx] as num).toDouble();
  }

  /// Approximate city name from coordinates (offline fallback).
  /// In production the UI can geocode, but for now we use lat/lon.
  String _cityNameFromCoords(double lat, double lon) {
    // Kenya-specific heuristics for common locations
    if ((lat - (-1.286)).abs() < 0.2 && (lon - 36.817).abs() < 0.2) {
      return 'Nairobi';
    }
    if ((lat - (-4.043)).abs() < 0.2 && (lon - 39.668).abs() < 0.2) {
      return 'Mombasa';
    }
    if ((lat - 0.514).abs() < 0.2 && (lon - 35.270).abs() < 0.2) {
      return 'Eldoret';
    }
    if ((lat - (-0.091)).abs() < 0.2 && (lon - 34.768).abs() < 0.2) {
      return 'Kisumu';
    }
    if ((lat - (-0.423)).abs() < 0.2 && (lon - 36.951).abs() < 0.2) {
      return 'Thika';
    }
    if ((lat - (-1.516)).abs() < 0.2 && (lon - 37.264).abs() < 0.2) {
      return 'Machakos';
    }
    return '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
  }

  /// Convert WMO weather code to human-readable description.
  static String _wmoDescription(int code) {
    switch (code) {
      case 0:
        return 'clear sky';
      case 1:
        return 'mainly clear';
      case 2:
        return 'partly cloudy';
      case 3:
        return 'overcast';
      case 45:
      case 48:
        return 'fog';
      case 51:
      case 53:
      case 55:
        return 'drizzle';
      case 56:
      case 57:
        return 'freezing drizzle';
      case 61:
        return 'light rain';
      case 63:
        return 'moderate rain';
      case 65:
        return 'heavy rain';
      case 66:
      case 67:
        return 'freezing rain';
      case 71:
      case 73:
      case 75:
        return 'snowfall';
      case 77:
        return 'snow grains';
      case 80:
      case 81:
      case 82:
        return 'rain showers';
      case 85:
      case 86:
        return 'snow showers';
      case 95:
        return 'thunderstorm';
      case 96:
      case 99:
        return 'thunderstorm with hail';
      default:
        return 'unknown';
    }
  }

  /// Map WMO code to an OWM-style icon string for the UI.
  static String _wmoToIcon(int code) {
    if (code <= 1) return '01d';
    if (code == 2) return '02d';
    if (code == 3) return '04d';
    if (code == 45 || code == 48) return '50d';
    if (code >= 51 && code <= 57) return '09d';
    if (code >= 61 && code <= 67) return '10d';
    if (code >= 71 && code <= 77) return '13d';
    if (code >= 80 && code <= 82) return '09d';
    if (code >= 85 && code <= 86) return '13d';
    if (code >= 95) return '11d';
    return '01d';
  }

  /// Map WMO code to an OWM-compatible condition code for icon rendering.
  static int _wmoToOwmCode(int code) {
    if (code == 0 || code == 1) return 800;
    if (code == 2) return 802;
    if (code == 3) return 804;
    if (code == 45 || code == 48) return 741;
    if (code >= 51 && code <= 57) return 301;
    if (code >= 61 && code <= 65) return 500;
    if (code >= 66 && code <= 67) return 511;
    if (code >= 71 && code <= 77) return 601;
    if (code >= 80 && code <= 82) return 521;
    if (code >= 85 && code <= 86) return 601;
    if (code >= 95) return 211;
    return 800;
  }

  @override
  void dispose() => _http.close();
}
