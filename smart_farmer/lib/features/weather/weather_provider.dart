import 'weather_models.dart';

/// Abstract interface for weather data providers.
///
/// Implementations fetch current weather + forecast from a specific API.
/// The repository handles caching, location, and provider selection.
abstract class WeatherProvider {
  /// Fetch current weather and forecast for the given coordinates.
  Future<WeatherData> fetchCurrentAndForecast({
    required double lat,
    required double lon,
  });

  /// Clean up resources.
  void dispose() {}
}
