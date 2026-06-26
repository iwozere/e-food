/// Pure (Flutter-free) definitions of the Gemini analysis prompt and response
/// schema, shared by the runtime [GeminiService] and the offline accuracy
/// harness in `tool/eval/`. Keep this file dependency-free so `dart run` can
/// import it without a Flutter context.
library;

/// Human-readable utensil name used in the prompt.
String utensilDisplayName(String utensil) => switch (utensil) {
      'fork' => 'dinner fork',
      'knife' => 'dinner knife',
      'spoon' => 'tablespoon / soup spoon',
      _ => utensil,
    };

/// Builds the analysis prompt for a given utensil and its known length (cm).
String buildAnalysisPrompt(String utensil, double utensilLengthCm) {
  final utensilDesc =
      '${utensilDisplayName(utensil)} (${utensilLengthCm.toStringAsFixed(1)} cm)';
  return '''
You are a nutrition analyst. A standard $utensilDesc is visible in the image as a scale reference.

1. Detect the utensil and use its known length to estimate the plate diameter and food portion sizes.
2. Identify every distinct food item on the plate.
3. For each item estimate ALL of: weight in grams, calories per 100 g, total calories, and macronutrients per 100 g — protein, carbohydrates, and fat are mandatory, never omit them. Use standard nutritional knowledge for typical preparation of each food.
4. Return ONLY valid JSON, no prose, no markdown fences:

{
  "utensil_detected": true,
  "scale_confidence": "high|medium|low",
  "items": [
    {
      "name": "string",
      "weight_g": number,
      "kcal_per_100g": number,
      "total_kcal": number,
      "protein_per_100g": number,
      "carbs_per_100g": number,
      "fat_per_100g": number
    }
  ],
  "total_kcal": number,
  "notes": "string or null"
}''';
}

/// OpenAPI-subset schema enforced via `generationConfig.responseSchema` so the
/// model returns structured JSON rather than free-form text.
const geminiResponseSchema = {
  'type': 'OBJECT',
  'properties': {
    'utensil_detected': {'type': 'BOOLEAN'},
    'scale_confidence': {
      'type': 'STRING',
      'enum': ['high', 'medium', 'low'],
      'nullable': true,
    },
    'items': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'name': {'type': 'STRING'},
          'weight_g': {'type': 'NUMBER'},
          'kcal_per_100g': {'type': 'NUMBER'},
          'total_kcal': {'type': 'NUMBER'},
          'protein_per_100g': {'type': 'NUMBER'},
          'carbs_per_100g': {'type': 'NUMBER'},
          'fat_per_100g': {'type': 'NUMBER'},
        },
        'required': [
          'name',
          'weight_g',
          'kcal_per_100g',
          'protein_per_100g',
          'carbs_per_100g',
          'fat_per_100g',
        ],
      },
    },
    'total_kcal': {'type': 'NUMBER'},
    'notes': {'type': 'STRING', 'nullable': true},
  },
  'required': ['utensil_detected', 'items', 'total_kcal'],
};
