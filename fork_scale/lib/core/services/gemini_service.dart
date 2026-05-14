import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../models/meal_item.dart';
import 'usda_service.dart';

const _model = 'gemini-2.5-flash';
const _baseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

class GeminiAnalysisResult {
  final bool utensilDetected;
  final String? scaleConfidence;
  final List<MealItem> items;
  final double totalKcal;
  final String? notes;

  const GeminiAnalysisResult({
    required this.utensilDetected,
    this.scaleConfidence,
    required this.items,
    required this.totalKcal,
    this.notes,
  });
}

class GeminiService {
  final String apiKey;
  final UsdaService _usda;

  GeminiService({required this.apiKey, UsdaService? usdaService})
      : _usda = usdaService ?? UsdaService();

  Future<GeminiAnalysisResult> analyzeImage({
    required Uint8List imageBytes,
    required String utensil, // 'fork' | 'knife' | 'spoon'
    required double utensilLengthCm,
  }) async {
    final utensilName = switch (utensil) {
      'fork' => 'dinner fork',
      'knife' => 'dinner knife',
      'spoon' => 'tablespoon / soup spoon',
      _ => utensil,
    };
    final utensilDesc = '$utensilName (${utensilLengthCm.toStringAsFixed(1)} cm)';

    final prompt = '''
You are a nutrition analyst. A standard $utensilDesc is visible in the image as a scale reference.

1. Detect the utensil and use its known length to estimate the plate diameter and food portion sizes.
2. Identify every distinct food item on the plate.
3. For each item estimate: weight in grams, calories per 100 g, total calories.
4. Return ONLY valid JSON, no prose, no markdown fences:

{
  "utensil_detected": true,
  "scale_confidence": "high|medium|low",
  "items": [
    {
      "name": "string",
      "weight_g": number,
      "kcal_per_100g": number,
      "total_kcal": number
    }
  ],
  "total_kcal": number,
  "notes": "string or null"
}''';

    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 8192,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 429) {
      throw const GeminiRateLimitException();
    }
    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = decoded['candidates'][0]['content']['parts'][0]['text'] as String;

    return _parseAndEnrich(text);
  }

  /// Attempts to close a truncated JSON response at the last complete item object.
  /// Returns the decoded map on success, null if the fragment is unrecoverable.
  Map<String, dynamic>? _repairTruncated(String s) {
    // Find the last closing brace of a complete item (i.e. "}" followed only by
    // whitespace, commas, or the start of an incomplete next item before EOF).
    final lastBrace = s.lastIndexOf('}');
    if (lastBrace < 0) return null;
    // Close: end the items array and the root object.
    final candidate = '${s.substring(0, lastBrace + 1)}]}';
    try {
      return jsonDecode(candidate) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<GeminiAnalysisResult> _parseAndEnrich(String rawText) async {
    late Map<String, dynamic> json;
    final cleaned = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      // Try to salvage truncated JSON by closing at the last complete item.
      final repaired = _repairTruncated(cleaned);
      if (repaired != null) {
        json = repaired;
      } else {
        throw GeminiParseException(rawText, truncated: !cleaned.endsWith('}'));
      }
    }

    final rawItems = (json['items'] as List<dynamic>?) ?? [];
    final items = <MealItem>[];

    for (var i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i] as Map<String, dynamic>;
      final name = raw['name'] as String;
      final weightG = (raw['weight_g'] as num).toDouble();
      final llmKcal = (raw['kcal_per_100g'] as num).toDouble();

      final usdaMatch = await _usda.lookup(name);
      final kcalPer100g = usdaMatch?.kcalPer100g ?? llmKcal;
      final totalKcal = weightG / 100.0 * kcalPer100g;

      items.add(MealItem(
        name: name,
        weightG: weightG,
        kcalPer100g: kcalPer100g,
        totalKcal: totalKcal,
        sortOrder: i,
        usdaMatched: usdaMatch != null,
      ));
    }

    final totalKcal = items.fold(0.0, (sum, item) => sum + item.totalKcal);

    return GeminiAnalysisResult(
      utensilDetected: json['utensil_detected'] as bool? ?? false,
      scaleConfidence: json['scale_confidence'] as String?,
      items: items,
      totalKcal: totalKcal,
      notes: json['notes'] as String?,
    );
  }
}

enum KeyValidationResult { valid, invalid, networkError }

/// Lightweight auth check — calls the models list endpoint (no generation, no quota used).
Future<KeyValidationResult> validateGeminiKey(String apiKey) async {
  try {
    final response = await http.get(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey&pageSize=1'),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) { return KeyValidationResult.valid; }
    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) { return KeyValidationResult.invalid; }
    return KeyValidationResult.networkError;
  } catch (_) {
    return KeyValidationResult.networkError;
  }
}

class GeminiRateLimitException implements Exception {
  const GeminiRateLimitException();
}

class GeminiApiException implements Exception {
  final int statusCode;
  final String body;
  const GeminiApiException(this.statusCode, this.body);
}

class GeminiParseException implements Exception {
  final String rawText;
  final bool truncated;
  const GeminiParseException(this.rawText, {this.truncated = false});
}
