import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/enums.dart';

/// Shared meal-type choice chip row used on results, edit, barcode, and log screens.
///
/// [value] may be null (no selection). [onChanged] is called with the tapped type.
/// Set [showLabel] to display a "MEAL TYPE" section header above the chips.
class MealTypeSelector extends StatelessWidget {
  final MealType? value;
  final ValueChanged<MealType> onChanged;
  final bool showLabel;

  const MealTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.showLabel = false,
  });

  static const _labels = {
    MealType.breakfast: 'Breakfast',
    MealType.lunch: 'Lunch',
    MealType.snack: 'Snack',
    MealType.dinner: 'Dinner',
  };

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: 8,
      children: MealType.values
          .map((t) => ChoiceChip(
                label: Text(_labels[t]!),
                selected: value == t,
                onSelected: (_) => onChanged(t),
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
              ))
          .toList(),
    );

    if (!showLabel) return chips;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MEAL TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.subtle,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          chips,
        ],
      ),
    );
  }
}
