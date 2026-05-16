import 'recipe_item.dart';

class Recipe {
  final int? id;
  final String name;
  final double yieldG;
  final double kcalPer100g; // derived: SUM(items.totalKcal) / yieldG * 100
  final String? photoPath;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeItem> items;

  const Recipe({
    this.id,
    required this.name,
    required this.yieldG,
    required this.kcalPer100g,
    this.photoPath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  double get totalKcal => items.fold(0.0, (s, i) => s + i.totalKcal);

  static double computeKcalPer100g(List<RecipeItem> items, double yieldG) {
    if (yieldG <= 0) return 0;
    final total = items.fold(0.0, (s, i) => s + i.totalKcal);
    return total / yieldG * 100;
  }

  Recipe copyWith({
    int? id,
    String? name,
    double? yieldG,
    double? kcalPer100g,
    String? photoPath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RecipeItem>? items,
  }) =>
      Recipe(
        id: id ?? this.id,
        name: name ?? this.name,
        yieldG: yieldG ?? this.yieldG,
        kcalPer100g: kcalPer100g ?? this.kcalPer100g,
        photoPath: photoPath ?? this.photoPath,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        items: items ?? this.items,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'yield_g': yieldG,
        'kcal_per_100g': kcalPer100g,
        'photo_path': photoPath,
        'notes': notes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Recipe.fromMap(Map<String, dynamic> map,
          {List<RecipeItem> items = const []}) =>
      Recipe(
        id: map['id'] as int?,
        name: map['name'] as String,
        yieldG: (map['yield_g'] as num).toDouble(),
        kcalPer100g: (map['kcal_per_100g'] as num).toDouble(),
        photoPath: map['photo_path'] as String?,
        notes: map['notes'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        items: items,
      );
}
