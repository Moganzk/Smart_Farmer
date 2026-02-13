import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Quick test script to validate all API keys in .env
/// Run with: dart test_api_keys.dart

void main() async {
  print('🔑 Testing API Keys from .env\n');
  print('=' * 60);

  // Read .env file
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ .env file not found');
    exit(1);
  }

  final envContent = await envFile.readAsString();
  final geminiKey = _extractKey(envContent, 'GEMINI_API_KEY');
  final groqKey = _extractKey(envContent, 'GROQ_API_KEY');
  final weatherKey = _extractKey(envContent, 'WEATHER_API_KEY');

  // Test Gemini API
  await _testGemini(geminiKey);
  print('');

  // Test Groq API
  await _testGroq(groqKey);
  print('');

  // Test Weather API
  await _testWeather(weatherKey);
  print('');

  print('=' * 60);
  print('✅ API key validation complete');
}

String _extractKey(String content, String keyName) {
  final regex = RegExp('^$keyName=(.+)', multiLine: true);
  final match = regex.firstMatch(content);
  return match?.group(1)?.trim() ?? '';
}

Future<void> _testGemini(String apiKey) async {
  print('\n📡 Testing GEMINI_API_KEY');
  print('   Key: ${apiKey.substring(0, 8)}...');

  if (apiKey.isEmpty) {
    print('   ❌ EMPTY KEY');
    return;
  }

  try {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': 'Hello'},
                ],
              },
            ],
          }),
        )
        .timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final hasContent = data['candidates'] != null;
      print(
        '   ✅ VALID — Status: ${response.statusCode}, Response: ${hasContent ? "OK" : "Unexpected format"}',
      );
    } else if (response.statusCode == 400) {
      print(
        '   ⚠️  Status 400 — Check if key is valid or model name is correct',
      );
      print('   Response: ${response.body.substring(0, 100)}...');
    } else if (response.statusCode == 403) {
      print('   ❌ FORBIDDEN (403) — Key may be invalid or quota exceeded');
    } else if (response.statusCode == 429) {
      print('   ⚠️  RATE LIMITED (429) — Key is valid but quota exceeded');
    } else {
      print('   ❌ FAILED — Status: ${response.statusCode}');
      print('   Response: ${response.body.substring(0, 100)}...');
    }
  } catch (e) {
    print('   ❌ ERROR: $e');
  }
}

Future<void> _testGroq(String apiKey) async {
  print('\n📡 Testing GROQ_API_KEY');
  print('   Key: ${apiKey.substring(0, 8)}...');

  if (apiKey.isEmpty) {
    print('   ❌ EMPTY KEY');
    return;
  }

  try {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'llama-3.3-70b-versatile',
            'messages': [
              {'role': 'user', 'content': 'Hello'},
            ],
            'max_tokens': 10,
          }),
        )
        .timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final hasChoices = data['choices'] != null;
      print(
        '   ✅ VALID — Status: ${response.statusCode}, Response: ${hasChoices ? "OK" : "Unexpected format"}',
      );
    } else if (response.statusCode == 401) {
      print('   ❌ UNAUTHORIZED (401) — Invalid API key');
    } else if (response.statusCode == 429) {
      print('   ⚠️  RATE LIMITED (429) — Key is valid but quota exceeded');
    } else {
      print('   ❌ FAILED — Status: ${response.statusCode}');
      print('   Response: ${response.body.substring(0, 100)}...');
    }
  } catch (e) {
    print('   ❌ ERROR: $e');
  }
}

Future<void> _testWeather(String apiKey) async {
  print('\n📡 Testing WEATHER_API_KEY');
  print('   Key: ${apiKey.substring(0, 8)}...');

  if (apiKey.isEmpty) {
    print('   ❌ EMPTY KEY');
    return;
  }

  // Check if it's a Google API key (starts with AIzaSy)
  if (apiKey.startsWith('AIzaSy')) {
    print('   ℹ️  Detected Google API key format');
    await _testGoogleGeocoding(apiKey);
  } else {
    // OpenWeatherMap key format
    print('   ℹ️  Detected OpenWeatherMap key format');
    await _testOpenWeatherMap(apiKey);
  }
}

Future<void> _testGoogleGeocoding(String apiKey) async {
  try {
    // Test with Google Geocoding API (Nairobi)
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=-1.286,36.817&key=$apiKey',
    );

    final response = await http.get(url).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = data['status'];

      if (status == 'OK') {
        final address = data['results']?[0]?['formatted_address'] ?? 'Unknown';
        print('   ✅ VALID Google API Key');
        print('   Geocoding test: $address');
        print('   ⚠️  NOTE: Google does not provide weather data directly.');
        print(
          '   ⚠️  For weather, use OpenWeatherMap, WeatherAPI.com, or similar.',
        );
      } else if (status == 'REQUEST_DENIED') {
        print(
          '   ❌ REQUEST DENIED — API key valid but Geocoding API not enabled',
        );
        print('   Enable "Geocoding API" in Google Cloud Console');
      } else if (status == 'OVER_QUERY_LIMIT') {
        print('   ⚠️  RATE LIMITED — Key is valid but quota exceeded');
      } else {
        print('   ⚠️  Status: $status');
        print('   Error: ${data['error_message'] ?? 'Unknown'}');
      }
    } else if (response.statusCode == 403) {
      print('   ❌ FORBIDDEN (403) — Invalid API key or API not enabled');
    } else {
      print('   ❌ FAILED — Status: ${response.statusCode}');
      print('   Response: ${response.body.substring(0, 150)}...');
    }
  } catch (e) {
    print('   ❌ ERROR: $e');
  }
}

Future<void> _testOpenWeatherMap(String apiKey) async {
  try {
    // Test with Nairobi coordinates
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=-1.286&lon=36.817&appid=$apiKey&units=metric',
    );

    final response = await http.get(url).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final city = data['name'] ?? 'Unknown';
      final temp = data['main']?['temp'] ?? 'N/A';
      print('   ✅ VALID — Status: ${response.statusCode}');
      print('   Location: $city, Temp: ${temp}°C');
    } else if (response.statusCode == 401) {
      print('   ❌ UNAUTHORIZED (401) — Invalid API key');
    } else if (response.statusCode == 429) {
      print('   ⚠️  RATE LIMITED (429) — Key is valid but quota exceeded');
    } else {
      print('   ❌ FAILED — Status: ${response.statusCode}');
      print('   Response: ${response.body.substring(0, 100)}...');
    }
  } catch (e) {
    print('   ❌ ERROR: $e');
  }
}
