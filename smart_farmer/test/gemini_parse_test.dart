import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_farmer/features/scan/ai_diagnosis_service.dart';

/// Best-effort cleanup — Windows may hold file locks during tests.
void _tryDelete(Directory dir) {
  try {
    dir.deleteSync(recursive: true);
  } catch (_) {
    // Ignore file-lock errors on Windows
  }
}

/// Helpers to build a fake Gemini response body.
String _geminiResponse(String textContent) {
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': textContent},
          ],
        },
      },
    ],
  });
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_fake_key_123\n');
  });

  group('GeminiDiagnosisService parse', () {
    test('parses clean JSON response', () async {
      final cleanJson = jsonEncode({
        'diagnosisName': 'Late Blight',
        'confidence': 0.92,
        'severity': 'high',
        'recommendations': ['Remove infected leaves', 'Apply fungicide'],
      });

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(cleanJson), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.diagnosisName, 'Late Blight');
      expect(result.confidence, 0.92);
      expect(result.severity, 'high');
      expect(result.recommendations.length, 2);

      _tryDelete(tmpDir);
    });

    test('parses markdown-fenced JSON', () async {
      final fenced =
          '```json\n'
          '{"diagnosisName":"Healthy","confidence":0.95,"severity":"low",'
          '"recommendations":["Continue current care"]}\n'
          '```';

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(fenced), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test2_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.diagnosisName, 'Healthy');
      expect(result.confidence, 0.95);

      _tryDelete(tmpDir);
    });

    test('parses JSON with extra text before and after', () async {
      final messy =
          'Here is my analysis:\n\n'
          '{"diagnosisName":"Nitrogen Deficiency","confidence":0.78,'
          '"severity":"medium",'
          '"recommendations":["Apply nitrogen fertilizer","Test soil pH"]}\n\n'
          'I hope this helps!';

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(messy), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test3_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.diagnosisName, 'Nitrogen Deficiency');
      expect(result.confidence, closeTo(0.78, 0.01));

      _tryDelete(tmpDir);
    });

    test('handles missing fields with defaults', () async {
      // Only diagnosisName present
      final partial = '{"diagnosisName":"Unknown Condition"}';

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(partial), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test4_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.diagnosisName, 'Unknown Condition');
      expect(result.confidence, 0.5); // default
      expect(result.severity, 'medium'); // default
      expect(result.recommendations, isNotEmpty);

      _tryDelete(tmpDir);
    });

    test('clamps confidence to 0-1 range', () async {
      final badConf =
          '{"diagnosisName":"Over","confidence":1.5,"severity":"low",'
          '"recommendations":["test"]}';

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(badConf), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test5_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.confidence, 1.0);

      _tryDelete(tmpDir);
    });

    test('throws on HTTP 500', () async {
      final client = MockClient((req) async {
        return http.Response('Internal Server Error', 500);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test6_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      expect(() => svc.diagnose(img), throwsA(isA<AiDiagnosisException>()));

      _tryDelete(tmpDir);
    });

    test('throws when API key is empty', () async {
      dotenv.testLoad(fileInput: 'OTHER=value\n');

      final client = MockClient((req) async {
        return http.Response('', 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test7_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      expect(() => svc.diagnose(img), throwsA(isA<AiDiagnosisException>()));

      _tryDelete(tmpDir);

      // Restore key for other tests
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=test_fake_key_123\n');
    });

    test('handles alternate key name diagnosis_name', () async {
      final altKey =
          '{"diagnosis_name":"Rust","confidence":0.8,"severity":"high",'
          '"recommendations":["Spray"]}';

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(altKey), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test8_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.diagnosisName, 'Rust');

      _tryDelete(tmpDir);
    });

    test('invalid severity defaults to medium', () async {
      final badSev =
          '{"diagnosisName":"X","confidence":0.5,"severity":"critical",'
          '"recommendations":["test"]}';

      final client = MockClient((req) async {
        return http.Response(_geminiResponse(badSev), 200);
      });

      final svc = GeminiDiagnosisService(httpClient: client);
      final tmpDir = Directory.systemTemp.createTempSync('gemini_test9_');
      final img = File('${tmpDir.path}/test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      final result = await svc.diagnose(img);
      expect(result.severity, 'medium');

      _tryDelete(tmpDir);
    });
  });

  group('DiagnosisResult.unanalyzed', () {
    test('has zero confidence and Unanalyzed name', () {
      final r = DiagnosisResult.unanalyzed();
      expect(r.diagnosisName, 'Unanalyzed');
      expect(r.confidence, 0.0);
    });

    test('stores debugReason when provided', () {
      final r = DiagnosisResult.unanalyzed(debugReason: 'Network error');
      expect(r.debugReason, 'Network error');
    });
  });
}
