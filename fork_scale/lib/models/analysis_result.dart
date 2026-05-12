import 'meal_item.dart';

class AnalysisResult {
  final bool utensilDetected;
  final String? scaleConfidence; // 'high' | 'medium' | 'low'
  final List<MealItem> items;
  final double totalKcal;
  final String? notes;
  final String photoPath;
  final String utensil; // 'fork' | 'knife'

  const AnalysisResult({
    required this.utensilDetected,
    this.scaleConfidence,
    required this.items,
    required this.totalKcal,
    this.notes,
    required this.photoPath,
    required this.utensil,
  });
}
