import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/enums.dart';
import 'meal_type_label.dart';

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chips = Wrap(
      spacing: 8,
      children: MealType.values
          .map((t) => ChoiceChip(
                label: Text(mealTypeLabel(l, t)),
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
          Text(
            l.mealTypeHeader,
            style: const TextStyle(
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
