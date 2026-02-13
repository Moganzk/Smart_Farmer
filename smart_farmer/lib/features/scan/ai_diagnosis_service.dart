import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';

/// Structured AI diagnosis result.
class DiagnosisResult {
  final String diagnosisName;
  final double confidence;
  final String severity;
  final List<String> recommendations;
  final String? debugReason;

  const DiagnosisResult({
    required this.diagnosisName,
    required this.confidence,
    required this.severity,
    required this.recommendations,
    this.debugReason,
  });

  /// Fallback when AI is unavailable.
  static DiagnosisResult unanalyzed({String? debugReason}) => DiagnosisResult(
    diagnosisName: 'Unanalyzed',
    confidence: 0.0,
    severity: 'medium',
    recommendations: [
      'Connect to internet and re-analyze this scan.',
      'Consult a local agricultural officer.',
    ],
    debugReason: debugReason,
  );
}

/// Abstract interface so AI providers can be swapped.
abstract class AiDiagnosisProvider {
  Future<DiagnosisResult> diagnose(File imageFile);
}

/// Concrete implementation using Google Gemini (gemini-2.0-flash).
class GeminiDiagnosisService implements AiDiagnosisProvider {
  final http.Client _http;

  GeminiDiagnosisService({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const _model = 'gemini-2.0-flash';

  static const _prompt = '''
You are an expert agricultural pathologist. Analyze this crop/plant image and determine if the plant has any disease, pest damage, or nutrient deficiency.

Return your analysis as a valid JSON object with these exact fields:
{
  "diagnosisName": "Name of the disease or condition (e.g. 'Late Blight', 'Healthy', 'Nitrogen Deficiency')",
  "confidence": 0.85,
  "severity": "low",
  "recommendations": [
    "First recommendation",
    "Second recommendation",
    "Third recommendation"
  ]
}

Rules:
- confidence must be a number between 0.0 and 1.0
- severity must be one of: "low", "medium", "high"
- recommendations must be an array of 2-5 short actionable strings
- If the image is not a plant/crop, set diagnosisName to "Not a plant image" with confidence 0.0
- Return ONLY the JSON object, no markdown code fences, no extra text
''';

  @override
  Future<DiagnosisResult> diagnose(File imageFile) async {
    // 1. Check API key
    if (_apiKey.isEmpty) {
      const reason = 'GEMINI_API_KEY is empty or missing from .env';
      if (kDebugMode) Log.e('GeminiAI', reason);
      throw const AiDiagnosisException(reason);
    }
    if (kDebugMode) {
      Log.i(
        'GeminiAI',
        'API key present (${_apiKey.substring(0, 6)}…, len=${_apiKey.length})',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Determine MIME type
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {'mime_type': mime, 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1024},
    });

    final http.Response response;
    try {
      response = await _http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      final reason = 'HTTP request failed: $e';
      if (kDebugMode) Log.e('GeminiAI', reason);
      throw AiDiagnosisException(reason);
    }

    if (kDebugMode) {
      Log.i('GeminiAI', 'HTTP status: ${response.statusCode}');
    }

    if (response.statusCode != 200) {
      final preview = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      final reason = 'Gemini API error (${response.statusCode}): $preview';
      if (kDebugMode) Log.e('GeminiAI', reason);
      throw AiDiagnosisException(reason);
    }

    return _parseResponse(response.body);
  }

  DiagnosisResult _parseResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const AiDiagnosisException('No candidates in Gemini response.');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List;
      final text = parts[0]['text'] as String;

      if (kDebugMode) {
        final preview = text.length > 300 ? text.substring(0, 300) : text;
        Log.i('GeminiAI', 'Raw text response: $preview');
      }

      // Robust extraction: find JSON object in the text
      String cleaned = text.trim();

      // Strip markdown code fences
      cleaned = cleaned.replaceAll(
        RegExp(r'```json\s*', caseSensitive: false),
        '',
      );
      cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
      cleaned = cleaned.trim();

      // Try to extract JSON object between { and }
      final jsonStart = cleaned.indexOf('{');
      final jsonEnd = cleaned.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
        throw AiDiagnosisException(
          'No JSON object found in response: '
          '${cleaned.substring(0, cleaned.length.clamp(0, 150))}',
        );
      }
      cleaned = cleaned.substring(jsonStart, jsonEnd + 1);

      final result = jsonDecode(cleaned) as Map<String, dynamic>;

      final name =
          result['diagnosisName'] as String? ??
          result['diagnosis_name'] as String? ??
          result['name'] as String? ??
          'Unknown';
      final conf = (result['confidence'] as num?)?.toDouble() ?? 0.5;
      final sev = result['severity'] as String? ?? 'medium';
      final recs =
          (result['recommendations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Consult a local agricultural expert.'];

      // Clamp confidence
      final clampedConf = conf.clamp(0.0, 1.0);

      // Validate severity
      final validSev = ['low', 'medium', 'high'].contains(sev) ? sev : 'medium';

      return DiagnosisResult(
        diagnosisName: name,
        confidence: clampedConf,
        severity: validSev,
        recommendations: recs,
      );
    } catch (e) {
      if (e is AiDiagnosisException) rethrow;
      final reason = 'Failed to parse AI response: $e';
      if (kDebugMode) Log.e('GeminiAI', reason);
      throw AiDiagnosisException(reason);
    }
  }

  void dispose() => _http.close();
}

class AiDiagnosisException implements Exception {
  final String message;
  const AiDiagnosisException(this.message);

  @override
  String toString() => message;
}
