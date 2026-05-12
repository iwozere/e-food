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

  const MealItem({
    this.id,
    this.mealId,
    required this.name,
    required this.weightG,
    required this.kcalPer100g,
    required this.totalKcal,
    this.sortOrder = 0,
    this.usdaMatched = false,
  });

  double get computedKcal => weightG / 100.0 * kcalPer100g;

  MealItem copyWith({
    int? id,
    int? mealId,
    String? name,
    double? weightG,
    double? kcalPer100g,
    double? totalKcal,
    int? sortOrder,
    bool? usdaMatched,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      name: name ?? this.name,
      weightG: weightG ?? this.weightG,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      totalKcal: totalKcal ?? this.totalKcal,
      sortOrder: sortOrder ?? this.sortOrder,
      usdaMatched: usdaMatched ?? this.usdaMatched,
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
      };

  factory MealItem.fromMap(Map<String, dynamic> map) => MealItem(
        id: map['id'] as int?,
        mealId: map['meal_id'] as int?,
        name: map['name'] as String,
        weightG: (map['weight_g'] as num).toDouble(),
        kcalPer100g: (map['kcal_per_100g'] as num).toDouble(),
        totalKcal: (map['total_kcal'] as num).toDouble(),
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}
