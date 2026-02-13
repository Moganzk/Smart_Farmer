/// Weather data models parsed from OpenWeatherMap API responses.

class CurrentWeather {
  final String cityName;
  final double temp;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;
  final int conditionCode;
  final DateTime timestamp;

  const CurrentWeather({
    required this.cityName,
    required this.temp,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
    required this.conditionCode,
    required this.timestamp,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;

    return CurrentWeather(
      cityName: json['name'] as String? ?? '',
      temp: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      tempMin: (main['temp_min'] as num).toDouble(),
      tempMax: (main['temp_max'] as num).toDouble(),
      humidity: (main['humidity'] as num).toInt(),
      windSpeed: (wind['speed'] as num).toDouble(),
      description: weather['description'] as String? ?? '',
      icon: weather['icon'] as String? ?? '01d',
      conditionCode: (weather['id'] as num?)?.toInt() ?? 800,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] as num).toInt() * 1000,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': cityName,
    'main': {
      'temp': temp,
      'feels_like': feelsLike,
      'temp_min': tempMin,
      'temp_max': tempMax,
      'humidity': humidity,
    },
    'wind': {'speed': windSpeed},
    'weather': [
      {'description': description, 'icon': icon, 'id': conditionCode},
    ],
    'dt': timestamp.millisecondsSinceEpoch ~/ 1000,
  };

  /// Map weather condition code to a Material icon.
  IconAlias get weatherIcon {
    if (conditionCode >= 200 && conditionCode < 300) {
      return IconAlias.thunderstorm;
    } else if (conditionCode >= 300 && conditionCode < 600) {
      return IconAlias.rain;
    } else if (conditionCode >= 600 && conditionCode < 700) {
      return IconAlias.snow;
    } else if (conditionCode >= 700 && conditionCode < 800) {
      return IconAlias.fog;
    } else if (conditionCode == 800) {
      return icon.contains('n') ? IconAlias.clearNight : IconAlias.clearDay;
    } else {
      return IconAlias.clouds;
    }
  }
}

/// Avoid importing flutter/material in model layer.
enum IconAlias { thunderstorm, rain, snow, fog, clearDay, clearNight, clouds }

// ── 5-day forecast ──

class ForecastDay {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final String description;
  final String icon;
  final int conditionCode;

  const ForecastDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.description,
    required this.icon,
    required this.conditionCode,
  });

  Map<String, dynamic> toJson() => {
    'dt': date.millisecondsSinceEpoch ~/ 1000,
    'temp_min': tempMin,
    'temp_max': tempMax,
    'description': description,
    'icon': icon,
    'id': conditionCode,
  };

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] as num).toInt() * 1000,
      ),
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '01d',
      conditionCode: (json['id'] as num?)?.toInt() ?? 800,
    );
  }
}

/// Full weather payload (current + forecast).
class WeatherData {
  final CurrentWeather current;
  final List<ForecastDay> forecast;

  const WeatherData({required this.current, required this.forecast});

  Map<String, dynamic> toJson() => {
    'current': current.toJson(),
    'forecast': forecast.map((f) => f.toJson()).toList(),
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      current: CurrentWeather.fromJson(json['current'] as Map<String, dynamic>),
      forecast: (json['forecast'] as List)
          .map((f) => ForecastDay.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Parse the OpenWeatherMap 5-day/3-hour forecast response
  /// into daily min/max summaries.
  static List<ForecastDay> parseForecastResponse(Map<String, dynamic> json) {
    final list = json['list'] as List;

    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (map['dt'] as num).toInt() * 1000,
      );
      final key = '${dt.year}-${dt.month}-${dt.day}';

      // Skip today
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        continue;
      }

      grouped.putIfAbsent(key, () => []).add(map);
    }

    // Build daily summaries (max 5 days)
    final days = <ForecastDay>[];
    for (final entry in grouped.entries) {
      if (days.length >= 5) break;

      double min = double.infinity;
      double max = double.negativeInfinity;
      String desc = '';
      String icon = '01d';
      int code = 800;

      for (final item in entry.value) {
        final main = item['main'] as Map<String, dynamic>;
        final t = (main['temp'] as num).toDouble();
        if (t < min) min = t;
        if (t > max) max = t;
      }

      // Use the midday entry for description
      final midday = entry.value.length > 2
          ? entry.value[entry.value.length ~/ 2]
          : entry.value.first;
      final w = (midday['weather'] as List).first as Map<String, dynamic>;
      desc = w['description'] as String? ?? '';
      icon = w['icon'] as String? ?? '01d';
      code = (w['id'] as num?)?.toInt() ?? 800;

      days.add(
        ForecastDay(
          date: DateTime.fromMillisecondsSinceEpoch(
            (entry.value.first['dt'] as num).toInt() * 1000,
          ),
          tempMin: min,
          tempMax: max,
          description: desc,
          icon: icon,
          conditionCode: code,
        ),
      );
    }

    return days;
  }
}
