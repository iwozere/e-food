class MealItem {
  final int? id;
  final int? mealId;
  final String name;
  final double weightG;
  final double kcalPer100g;
  final double totalKcal;
  final int sortOrder;
  // Whether kcalPer100g came from USDA (true) or LLM fallback (false)
  final bool usdaMatched;
  // Macronutrients per 100g (nullable — null means "unknown", not zero)
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  const MealItem({
    this.id,
    this.mealId,
    required this.name,
    required this.weightG,
    required this.kcalPer100g,
    required this.totalKcal,
    this.sortOrder = 0,
    this.usdaMatched = false,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  double get computedKcal => weightG / 100.0 * kcalPer100g;

  // Derived per-item macro totals (null when the per-100g value is unknown).
  double? get totalProteinG =>
      proteinPer100g == null ? null : weightG / 100 * proteinPer100g!;
  double? get totalCarbsG =>
      carbsPer100g == null ? null : weightG / 100 * carbsPer100g!;
  double? get totalFatG =>
      fatPer100g == null ? null : weightG / 100 * fatPer100g!;

  // Sentinel used by copyWith to distinguish "pass null to clear" from "omit to keep".
  static const _absent = Object();

  MealItem copyWith({
    Object? id = _absent,
    Object? mealId = _absent,
    String? name,
    double? weightG,
    double? kcalPer100g,
    double? totalKcal,
    int? sortOrder,
    bool? usdaMatched,
    Object? proteinPer100g = _absent,
    Object? carbsPer100g = _absent,
    Object? fatPer100g = _absent,
  }) {
    return MealItem(
      id: id == _absent ? this.id : id as int?,
      mealId: mealId == _absent ? this.mealId : mealId as int?,
      name: name ?? this.name,
      weightG: weightG ?? this.weightG,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      totalKcal: totalKcal ?? this.totalKcal,
      sortOrder: sortOrder ?? this.sortOrder,
      usdaMatched: usdaMatched ?? this.usdaMatched,
      proteinPer100g: proteinPer100g == _absent ? this.proteinPer100g : proteinPer100g as double?,
      carbsPer100g: carbsPer100g == _absent ? this.carbsPer100g : carbsPer100g as double?,
      fatPer100g: fatPer100g == _absent ? this.fatPer100g : fatPer100g as double?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (mealId != null) 'meal_id': mealId,
        'name': name,
        'weight_g': weightG,
        'kcal_per_100g': kcalPer100g,
        'total_kcal': totalKcal,
        'sort_order': sortOrder,
        'usda_matched': usdaMatched ? 1 : 0,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
      };

  factory MealItem.fromMap(Map<String, dynamic> map) => MealItem(
        id: map['id'] as int?,
        mealId: map['meal_id'] as int?,
        name: map['name'] as String,
        weightG: (map['weight_g'] as num).toDouble(),
        kcalPer100g: (map['kcal_per_100g'] as num).toDouble(),
        totalKcal: (map['total_kcal'] as num).toDouble(),
        sortOrder: map['sort_order'] as int? ?? 0,
        usdaMatched: (map['usda_matched'] as int? ?? 0) != 0,
        proteinPer100g: (map['protein_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (map['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (map['fat_per_100g'] as num?)?.toDouble(),
      );
}
