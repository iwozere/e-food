import 'meal_item.dart';

class AnalysisResult {
  final bool utensilDetected;
  final String? scaleConfidence; // 'high' | 'medium' | 'low'
  final List<MealItem> items;
  final double totalKcal;
  final String? notes;
  final String photoPath;
  final String utensil; // 'fork' | 'knife' | 'spoon'
  /// Set when re-analyzing a saved pending meal; results screen will update
  /// this row instead of inserting a new one.
  final int? pendingMealId;
  /// Original capture time for a pending meal; used to auto-detect meal type.
  final DateTime? capturedAt;

  const AnalysisResult({
    required this.utensilDetected,
    this.scaleConfidence,
    required this.items,
    required this.totalKcal,
    this.notes,
    required this.photoPath,
    required this.utensil,
    this.pendingMealId,
    this.capturedAt,
  });
}
