import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/services/gemini_service.dart';

void main() {
  group('GeminiService.parseResponse', () {
    test('parses clean JSON', () {
      const raw = '''
{
  "utensil_detected": true,
  "scale_confidence": "high",
  "items": [
    {"name": "Rice", "weight_g": 150, "kcal_per_100g": 130},
    {"name": "Chicken", "weight_g": 100, "kcal_per_100g": 165}
  ],
  "total_kcal": 360,
  "notes": null
}''';
      final r = GeminiService.parseResponse(raw);
      expect(r.utensilDetected, isTrue);
      expect(r.scaleConfidence, 'high');
      expect(r.items, hasLength(2));
      expect(r.items.first.name, 'Rice');
      expect(r.items.first.weightG, 150);
      expect(r.skippedItems, 0);
    });

    test('strips ```json markdown fences', () {
      const raw = '```json\n'
          '{"utensil_detected": false, "items": [{"name":"Egg","weight_g":50,"kcal_per_100g":155}], "total_kcal": 77}'
          '\n```';
      final r = GeminiService.parseResponse(raw);
      expect(r.items, hasLength(1));
      expect(r.utensilDetected, isFalse);
    });

    test('salvages a truncated-but-recoverable response', () {
      // Cut off mid-way through an incomplete third item.
      const raw =
          '{"utensil_detected": true, "items": [{"name":"A","weight_g":10,"kcal_per_100g":100},'
          '{"name":"B","weight_g":20,"kcal_per_100g":200},{"name":"C","weig';
      final r = GeminiService.parseResponse(raw);
      // The two complete items survive; the partial one is dropped by repair.
      expect(r.items.map((i) => i.name), ['A', 'B']);
    });

    test('throws GeminiParseException when unrecoverable', () {
      expect(
        () => GeminiService.parseResponse('not json at all'),
        throwsA(isA<GeminiParseException>()),
      );
    });

    test('skips a malformed item but keeps the good ones', () {
      const raw = '''
{
  "items": [
    {"name": "Good", "weight_g": 100, "kcal_per_100g": 200},
    {"name": "", "weight_g": 50, "kcal_per_100g": 100},
    {"weight_g": 50, "kcal_per_100g": 100},
    {"name": "NoWeight", "kcal_per_100g": 100},
    {"name": "BadWeight", "weight_g": "abc", "kcal_per_100g": 100}
  ],
  "total_kcal": 200
}''';
      final r = GeminiService.parseResponse(raw);
      expect(r.items.map((i) => i.name), ['Good']);
      expect(r.skippedItems, 4);
    });

    test('coerces numbers encoded as strings', () {
      const raw =
          '{"items":[{"name":"X","weight_g":"120.5","kcal_per_100g":"90"}],"total_kcal":108}';
      final r = GeminiService.parseResponse(raw);
      expect(r.items.single.weightG, 120.5);
      expect(r.items.single.llmKcalPer100g, 90);
    });

    test('empty items list yields no items and no error', () {
      const raw = '{"utensil_detected": true, "items": [], "total_kcal": 0}';
      final r = GeminiService.parseResponse(raw);
      expect(r.items, isEmpty);
      expect(r.skippedItems, 0);
    });

    test('missing items key yields empty list', () {
      const raw = '{"utensil_detected": false, "total_kcal": 0}';
      final r = GeminiService.parseResponse(raw);
      expect(r.items, isEmpty);
    });
  });
}
