import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/meal_item.dart';
import 'gemini_prompt.dart';
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
    final prompt = buildAnalysisPrompt(utensil, utensilLengthCm);

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
        // Force the model to emit JSON matching our item shape. The prompt's
        // JSON instructions and _repairTruncated remain as belt-and-braces.
        'responseMimeType': 'application/json',
        'responseSchema': geminiResponseSchema,
      },
    });

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: body,
    ).timeout(const Duration(seconds: 90));

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

  Future<GeminiAnalysisResult> _parseAndEnrich(String rawText) async {
    final parsed = parseResponse(rawText);

    final items = <MealItem>[];
    for (var i = 0; i < parsed.items.length; i++) {
      final item = parsed.items[i];
      final usdaMatch = await _usda.lookup(item.name);
      final kcalPer100g = usdaMatch?.kcalPer100g ?? item.llmKcalPer100g;
      final totalKcal = item.weightG / 100.0 * kcalPer100g;

      // Prefer USDA macros when matched, falling back per-macro to the LLM
      // estimate where USDA lacks that nutrient — mirroring how kcal is chosen.
      items.add(MealItem(
        name: item.name,
        weightG: item.weightG,
        kcalPer100g: kcalPer100g,
        totalKcal: totalKcal,
        sortOrder: i,
        usdaMatched: usdaMatch != null,
        proteinPer100g: usdaMatch?.proteinPer100g ?? item.proteinPer100g,
        carbsPer100g: usdaMatch?.carbsPer100g ?? item.carbsPer100g,
        fatPer100g: usdaMatch?.fatPer100g ?? item.fatPer100g,
      ));
    }

    final totalKcal = items.fold(0.0, (sum, item) => sum + item.totalKcal);

    // Don't silently drop unreadable items — tell the user one was skipped.
    var notes = parsed.notes;
    if (parsed.skippedItems > 0) {
      final warning = parsed.skippedItems == 1
          ? '1 item could not be read and was skipped.'
          : '${parsed.skippedItems} items could not be read and were skipped.';
      notes = (notes == null || notes.isEmpty) ? warning : '$notes\n$warning';
    }

    return GeminiAnalysisResult(
      utensilDetected: parsed.utensilDetected,
      scaleConfidence: parsed.scaleConfidence,
      items: items,
      totalKcal: totalKcal,
      notes: notes,
    );
  }

  /// Parses Gemini's raw text into structured items **without** any DB/USDA
  /// enrichment, so it is pure and unit-testable. Strips markdown fences,
  /// salvages truncated JSON, and defensively skips malformed items (recording
  /// the count in [GeminiParse.skippedItems]) rather than throwing away the
  /// whole meal. Throws [GeminiParseException] only when the envelope itself is
  /// unrecoverable.
  @visibleForTesting
  static GeminiParse parseResponse(String rawText) {
    final cleaned = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    late Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      final repaired = _repairTruncated(cleaned);
      if (repaired != null) {
        json = repaired;
      } else {
        throw GeminiParseException(rawText, truncated: !cleaned.endsWith('}'));
      }
    }

    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    final items = <ParsedItem>[];
    var skipped = 0;
    for (final entry in rawItems) {
      final item = _tryParseItem(entry);
      if (item == null) {
        skipped++;
      } else {
        items.add(item);
      }
    }

    return GeminiParse(
      utensilDetected: json['utensil_detected'] as bool? ?? false,
      scaleConfidence: json['scale_confidence'] as String?,
      items: items,
      notes: json['notes'] as String?,
      skippedItems: skipped,
    );
  }

  /// Returns a [ParsedItem] for a well-formed entry, or null if [entry] is not
  /// a map or lacks a usable name / positive weight / non-negative kcal.
  static ParsedItem? _tryParseItem(dynamic entry) {
    if (entry is! Map<String, dynamic>) return null;
    final name = entry['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final weightG = _asDouble(entry['weight_g']);
    final kcal = _asDouble(entry['kcal_per_100g']);
    if (weightG == null || weightG <= 0 || kcal == null || kcal < 0) {
      return null;
    }
    return ParsedItem(
      name: name.trim(),
      weightG: weightG,
      llmKcalPer100g: kcal,
      proteinPer100g: _asDouble(entry['protein_per_100g']),
      carbsPer100g: _asDouble(entry['carbs_per_100g']),
      fatPer100g: _asDouble(entry['fat_per_100g']),
    );
  }

  /// Coerces a JSON value to a double, tolerating numbers encoded as strings.
  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  /// Attempts to close a truncated JSON response at the last complete item object.
  /// Returns the decoded map on success, null if the fragment is unrecoverable.
  static Map<String, dynamic>? _repairTruncated(String s) {
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
}

/// One food item parsed from the model response, prior to USDA enrichment.
@visibleForTesting
class ParsedItem {
  final String name;
  final double weightG;
  final double llmKcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  const ParsedItem({
    required this.name,
    required this.weightG,
    required this.llmKcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });
}

/// Result of [GeminiService.parseResponse] — the structured envelope plus the
/// count of items that were dropped because they were malformed.
@visibleForTesting
class GeminiParse {
  final bool utensilDetected;
  final String? scaleConfidence;
  final List<ParsedItem> items;
  final String? notes;
  final int skippedItems;

  const GeminiParse({
    required this.utensilDetected,
    required this.scaleConfidence,
    required this.items,
    required this.notes,
    required this.skippedItems,
  });
}

enum KeyValidationResult { valid, invalid, networkError }

/// Lightweight auth check — calls the models list endpoint (no generation, no quota used).
Future<KeyValidationResult> validateGeminiKey(String apiKey) async {
  try {
    final response = await http.get(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=1'),
      headers: {'x-goog-api-key': apiKey},
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
