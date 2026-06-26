import 'enums.dart';
import 'meal_item.dart';

class Meal {
  final int? id;
  final DateTime createdAt;
  final String photoPath;
  final String? name;
  final String? notes;
  final double totalKcal;
  final Utensil utensil;
  final String? scaleConf; // 'high' | 'medium' | 'low' | null
  final String modelUsed; // 'gemini'
  final MealType? mealType;
  final bool pending;
  final bool starred;
  final MealSource source;
  final String? barcode;
  final int? recipeId;
  final double? portionG;
  // Denormalised per-meal macro totals (grams, nullable). Single source of
  // truth for aggregation; recomputed from items on write when items exist.
  final double? totalProteinG;
  final double? totalCarbsG;
  final double? totalFatG;
  final List<MealItem> items;

  const Meal({
    this.id,
    required this.createdAt,
    required this.photoPath,
    this.name,
    this.notes,
    required this.totalKcal,
    required this.utensil,
    this.scaleConf,
    required this.modelUsed,
    this.mealType,
    this.pending = false,
    this.starred = false,
    this.source = MealSource.camera,
    this.barcode,
    this.recipeId,
    this.portionG,
    this.totalProteinG,
    this.totalCarbsG,
    this.totalFatG,
    this.items = const [],
  });

  /// Sums each item's derived macro total, returning null per-macro when no
  /// item contributes it (so "unknown" stays distinct from a real zero).
  static ({double? protein, double? carbs, double? fat}) sumItemMacros(
      List<MealItem> items) {
    double protein = 0, carbs = 0, fat = 0;
    var hasP = false, hasC = false, hasF = false;
    for (final i in items) {
      final p = i.totalProteinG;
      final c = i.totalCarbsG;
      final f = i.totalFatG;
      if (p != null) { protein += p; hasP = true; }
      if (c != null) { carbs += c; hasC = true; }
      if (f != null) { fat += f; hasF = true; }
    }
    return (
      protein: hasP ? protein : null,
      carbs: hasC ? carbs : null,
      fat: hasF ? fat : null,
    );
  }

  /// Auto-detects meal type from the hour of [at] (defaults to now).
  static MealType detectTypeFromTime([DateTime? at]) {
    final hour = (at ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 10) return MealType.breakfast;
    if (hour >= 10 && hour < 15) return MealType.lunch;
    if (hour >= 15 && hour < 18) return MealType.snack;
    return MealType.dinner;
  }

  // Sentinel used by copyWith to distinguish "pass null to clear" from "omit to keep".
  static const _absent = Object();

  Meal copyWith({
    int? id,
    DateTime? createdAt,
    String? photoPath,
    Object? name = _absent,
    Object? notes = _absent,
    double? totalKcal,
    Utensil? utensil,
    Object? scaleConf = _absent,
    String? modelUsed,
    Object? mealType = _absent,
    bool? pending,
    bool? starred,
    MealSource? source,
    Object? barcode = _absent,
    Object? recipeId = _absent,
    Object? portionG = _absent,
    Object? totalProteinG = _absent,
    Object? totalCarbsG = _absent,
    Object? totalFatG = _absent,
    List<MealItem>? items,
  }) {
    return Meal(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      photoPath: photoPath ?? this.photoPath,
      name: name == _absent ? this.name : name as String?,
      notes: notes == _absent ? this.notes : notes as String?,
      totalKcal: totalKcal ?? this.totalKcal,
      utensil: utensil ?? this.utensil,
      scaleConf: scaleConf == _absent ? this.scaleConf : scaleConf as String?,
      modelUsed: modelUsed ?? this.modelUsed,
      mealType: mealType == _absent ? this.mealType : mealType as MealType?,
      pending: pending ?? this.pending,
      starred: starred ?? this.starred,
      source: source ?? this.source,
      barcode: barcode == _absent ? this.barcode : barcode as String?,
      recipeId: recipeId == _absent ? this.recipeId : recipeId as int?,
      portionG: portionG == _absent ? this.portionG : portionG as double?,
      totalProteinG: totalProteinG == _absent ? this.totalProteinG : totalProteinG as double?,
      totalCarbsG: totalCarbsG == _absent ? this.totalCarbsG : totalCarbsG as double?,
      totalFatG: totalFatG == _absent ? this.totalFatG : totalFatG as double?,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'created_at': createdAt.millisecondsSinceEpoch,
        'photo_path': photoPath,
        'name': name,
        'notes': notes,
        'total_kcal': totalKcal,
        'utensil': utensil.name,
        'scale_conf': scaleConf,
        'model_used': modelUsed,
        'meal_type': mealType?.name,
        'pending': pending ? 1 : 0,
        'starred': starred ? 1 : 0,
        'source': source.dbValue,
        'barcode': barcode,
        'recipe_id': recipeId,
        'portion_g': portionG,
        'total_protein_g': totalProteinG,
        'total_carbs_g': totalCarbsG,
        'total_fat_g': totalFatG,
      };

  factory Meal.fromMap(Map<String, dynamic> map,
          {List<MealItem> items = const []}) =>
      Meal(
        id: map['id'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        photoPath: map['photo_path'] as String,
        name: map['name'] as String?,
        notes: map['notes'] as String?,
        totalKcal: (map['total_kcal'] as num).toDouble(),
        utensil: Utensil.parse(map['utensil'] as String),
        scaleConf: map['scale_conf'] as String?,
        modelUsed: map['model_used'] as String,
        mealType: MealType.tryParse(map['meal_type'] as String?),
        pending: (map['pending'] as int? ?? 0) != 0,
        starred: (map['starred'] as int? ?? 0) != 0,
        source: MealSource.parse(map['source'] as String? ?? 'camera'),
        barcode: map['barcode'] as String?,
        recipeId: map['recipe_id'] as int?,
        portionG: (map['portion_g'] as num?)?.toDouble(),
        totalProteinG: (map['total_protein_g'] as num?)?.toDouble(),
        totalCarbsG: (map['total_carbs_g'] as num?)?.toDouble(),
        totalFatG: (map['total_fat_g'] as num?)?.toDouble(),
        items: items,
      );
}
