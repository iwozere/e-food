class RecipeItem {
  final int? id;
  final int? recipeId;
  final String name;
  final double weightG;
  final double kcalPer100g;
  final double totalKcal; // denormalised: weightG / 100 * kcalPer100g
  final String source; // 'manual' | 'off' | 'swiss_fcd'
  final String? barcode;
  final int sortOrder;
  // Macronutrients per 100g (nullable — null means "unknown", not zero)
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  const RecipeItem({
    this.id,
    this.recipeId,
    required this.name,
    required this.weightG,
    required this.kcalPer100g,
    required this.totalKcal,
    this.source = 'manual',
    this.barcode,
    this.sortOrder = 0,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  // Derived per-item macro totals (null when the per-100g value is unknown).
  double? get totalProteinG =>
      proteinPer100g == null ? null : weightG / 100 * proteinPer100g!;
  double? get totalCarbsG =>
      carbsPer100g == null ? null : weightG / 100 * carbsPer100g!;
  double? get totalFatG =>
      fatPer100g == null ? null : weightG / 100 * fatPer100g!;

  static const _absent = Object();

  RecipeItem copyWith({
    Object? id = _absent,
    Object? recipeId = _absent,
    String? name,
    double? weightG,
    double? kcalPer100g,
    double? totalKcal,
    String? source,
    Object? barcode = _absent,
    int? sortOrder,
    Object? proteinPer100g = _absent,
    Object? carbsPer100g = _absent,
    Object? fatPer100g = _absent,
  }) =>
      RecipeItem(
        id: id == _absent ? this.id : id as int?,
        recipeId: recipeId == _absent ? this.recipeId : recipeId as int?,
        name: name ?? this.name,
        weightG: weightG ?? this.weightG,
        kcalPer100g: kcalPer100g ?? this.kcalPer100g,
        totalKcal: totalKcal ?? this.totalKcal,
        source: source ?? this.source,
        barcode: barcode == _absent ? this.barcode : barcode as String?,
        sortOrder: sortOrder ?? this.sortOrder,
        proteinPer100g: proteinPer100g == _absent ? this.proteinPer100g : proteinPer100g as double?,
        carbsPer100g: carbsPer100g == _absent ? this.carbsPer100g : carbsPer100g as double?,
        fatPer100g: fatPer100g == _absent ? this.fatPer100g : fatPer100g as double?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (recipeId != null) 'recipe_id': recipeId,
        'name': name,
        'weight_g': weightG,
        'kcal_per_100g': kcalPer100g,
        'total_kcal': totalKcal,
        'source': source,
        'barcode': barcode,
        'sort_order': sortOrder,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
      };

  factory RecipeItem.fromMap(Map<String, dynamic> map) => RecipeItem(
        id: map['id'] as int?,
        recipeId: map['recipe_id'] as int?,
        name: map['name'] as String,
        weightG: (map['weight_g'] as num).toDouble(),
        kcalPer100g: (map['kcal_per_100g'] as num).toDouble(),
        totalKcal: (map['total_kcal'] as num).toDouble(),
        source: map['source'] as String? ?? 'manual',
        barcode: map['barcode'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        proteinPer100g: (map['protein_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (map['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (map['fat_per_100g'] as num?)?.toDouble(),
      );
}
