import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/analysis_result.dart';
import '../../models/meal_item.dart';

class ResultsState {
  final List<MealItem> items;
  final String? notes;
  final bool utensilDetected;
  final String? scaleConfidence;
  final String photoPath;
  final String utensil;

  const ResultsState({
    required this.items,
    this.notes,
    required this.utensilDetected,
    this.scaleConfidence,
    required this.photoPath,
    required this.utensil,
  });

  double get totalKcal => items.fold(0.0, (sum, i) => sum + i.computedKcal);

  ResultsState copyWith({
    List<MealItem>? items,
    String? notes,
    bool? utensilDetected,
    String? scaleConfidence,
    String? photoPath,
    String? utensil,
  }) {
    return ResultsState(
      items: items ?? this.items,
      notes: notes ?? this.notes,
      utensilDetected: utensilDetected ?? this.utensilDetected,
      scaleConfidence: scaleConfidence ?? this.scaleConfidence,
      photoPath: photoPath ?? this.photoPath,
      utensil: utensil ?? this.utensil,
    );
  }
}

class ResultsNotifier extends StateNotifier<ResultsState> {
  ResultsNotifier(AnalysisResult result)
      : super(ResultsState(
          items: List.of(result.items),
          notes: result.notes,
          utensilDetected: result.utensilDetected,
          scaleConfidence: result.scaleConfidence,
          photoPath: result.photoPath,
          utensil: result.utensil,
        ));

  void updateItem(int index, MealItem updated) {
    final items = List.of(state.items);
    items[index] = updated.copyWith(totalKcal: updated.computedKcal);
    state = state.copyWith(items: items);
  }

  void deleteItem(int index) {
    final items = List.of(state.items)..removeAt(index);
    state = state.copyWith(items: items);
  }

  void addItem() {
    final items = List.of(state.items)
      ..add(MealItem(
        name: 'New item',
        weightG: 100,
        kcalPer100g: 0,
        totalKcal: 0,
        sortOrder: state.items.length,
      ));
    state = state.copyWith(items: items);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }
}

final resultsNotifierProvider =
    StateNotifierProvider.autoDispose<ResultsNotifier, ResultsState>(
  (ref) => throw UnimplementedError('Override with ResultsNotifier(result)'),
);
