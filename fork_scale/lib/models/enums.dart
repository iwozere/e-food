// Domain enums for stringly-typed fields stored as their `.name` in SQLite
// (or a custom `dbValue` where the name diverges, e.g. `recipePortion` ↔
// `'recipe_portion'`).

enum MealType {
  breakfast,
  lunch,
  snack,
  dinner;

  static MealType? tryParse(String? s) {
    if (s == null) return null;
    return MealType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MealType.dinner,
    );
  }
}

enum Utensil {
  fork,
  knife,
  spoon;

  static Utensil parse(String s) => Utensil.values.firstWhere(
        (e) => e.name == s,
        orElse: () => Utensil.fork,
      );
}

enum MealSource {
  camera,
  barcode,
  recipePortion;

  /// The value written to / read from the `source` column.
  String get dbValue => switch (this) {
        MealSource.recipePortion => 'recipe_portion',
        _ => name,
      };

  static MealSource parse(String s) => switch (s) {
        'recipe_portion' => MealSource.recipePortion,
        'barcode' => MealSource.barcode,
        _ => MealSource.camera,
      };
}

enum FoodSource {
  manual,
  openFoodFacts,
  swissFcd;

  String get dbValue => switch (this) {
        FoodSource.openFoodFacts => 'off',
        FoodSource.swissFcd => 'swiss_fcd',
        _ => name,
      };

  static FoodSource parse(String s) => switch (s) {
        'off' => FoodSource.openFoodFacts,
        'swiss_fcd' => FoodSource.swissFcd,
        _ => FoodSource.manual,
      };
}
