import 'meal_item.dart';

class Meal {
  final int? id;
  final DateTime createdAt;
  final String photoPath;
  final String? name;
  final String? notes;
  final double totalKcal;
  final String utensil; // 'fork' | 'knife' | 'spoon'
  final String? scaleConf; // 'high' | 'medium' | 'low' | null
  final String modelUsed; // 'gemini'
  final String? mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final bool pending;
  final bool starred;
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
    this.items = const [],
  });

  /// Auto-detects meal type from the hour of [at] (defaults to now).
  static String detectTypeFromTime([DateTime? at]) {
    final hour = (at ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 18) return 'snack';
    return 'dinner';
  }

  Meal copyWith({
    int? id,
    DateTime? createdAt,
    String? photoPath,
    String? name,
    String? notes,
    double? totalKcal,
    String? utensil,
    String? scaleConf,
    String? modelUsed,
    String? mealType,
    bool? pending,
    bool? starred,
    List<MealItem>? items,
  }) {
    return Meal(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      photoPath: photoPath ?? this.photoPath,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      totalKcal: totalKcal ?? this.totalKcal,
      utensil: utensil ?? this.utensil,
      scaleConf: scaleConf ?? this.scaleConf,
      modelUsed: modelUsed ?? this.modelUsed,
      mealType: mealType ?? this.mealType,
      pending: pending ?? this.pending,
      starred: starred ?? this.starred,
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
        'utensil': utensil,
        'scale_conf': scaleConf,
        'model_used': modelUsed,
        'meal_type': mealType,
        'pending': pending ? 1 : 0,
        'starred': starred ? 1 : 0,
      };

  factory Meal.fromMap(Map<String, dynamic> map, {List<MealItem> items = const []}) => Meal(
        id: map['id'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        photoPath: map['photo_path'] as String,
        name: map['name'] as String?,
        notes: map['notes'] as String?,
        totalKcal: (map['total_kcal'] as num).toDouble(),
        utensil: map['utensil'] as String,
        scaleConf: map['scale_conf'] as String?,
        modelUsed: map['model_used'] as String,
        mealType: map['meal_type'] as String?,
        pending: (map['pending'] as int? ?? 0) != 0,
        starred: (map['starred'] as int? ?? 0) != 0,
        items: items,
      );
}
