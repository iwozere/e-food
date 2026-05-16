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
  });

  RecipeItem copyWith({
    int? id,
    int? recipeId,
    String? name,
    double? weightG,
    double? kcalPer100g,
    double? totalKcal,
    String? source,
    String? barcode,
    int? sortOrder,
  }) =>
      RecipeItem(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        name: name ?? this.name,
        weightG: weightG ?? this.weightG,
        kcalPer100g: kcalPer100g ?? this.kcalPer100g,
        totalKcal: totalKcal ?? this.totalKcal,
        source: source ?? this.source,
        barcode: barcode ?? this.barcode,
        sortOrder: sortOrder ?? this.sortOrder,
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
      );
}
