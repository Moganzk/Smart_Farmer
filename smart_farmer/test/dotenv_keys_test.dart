import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Tests that verify dotenv key-loading logic works correctly.
/// We mock the env map directly rather than loading a file.
void main() {
  group('Dotenv key presence handling', () {
    test('GEMINI_API_KEY is accessible when set', () {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_key_123\n');
      expect(dotenv.env['GEMINI_API_KEY'], 'test_key_123');
      expect(dotenv.env['GEMINI_API_KEY']!.isNotEmpty, true);
    });

    test('GEMINI_API_KEY defaults to empty string when missing', () {
      dotenv.testLoad(fileInput: 'OTHER_KEY=value\n');
      expect(dotenv.env['GEMINI_API_KEY'] ?? '', '');
    });

    test('WEATHER_API_KEY is accessible when set', () {
      dotenv.testLoad(fileInput: 'WEATHER_API_KEY=weather_abc\n');
      expect(dotenv.env['WEATHER_API_KEY'], 'weather_abc');
    });

    test('WEATHER_API_KEY defaults to empty string when missing', () {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=x\n');
      expect(dotenv.env['WEATHER_API_KEY'] ?? '', '');
    });

    test('multiple keys can be loaded simultaneously', () {
      dotenv.testLoad(
        fileInput:
            'GEMINI_API_KEY=gem123\nWEATHER_API_KEY=wea456\nGROQ_API_KEY=groq789\n',
      );
      expect(dotenv.env['GEMINI_API_KEY'], 'gem123');
      expect(dotenv.env['WEATHER_API_KEY'], 'wea456');
      expect(dotenv.env['GROQ_API_KEY'], 'groq789');
    });

    test('key with special characters loads correctly', () {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=AIzaSy-Test_1234+ABC\n');
      expect(dotenv.env['GEMINI_API_KEY'], 'AIzaSy-Test_1234+ABC');
    });

    test('empty value yields empty string', () {
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=\n');
      expect(dotenv.env['GEMINI_API_KEY'], '');
    });
  });
}
