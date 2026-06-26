import '../l10n/app_localizations.dart';
import '../models/enums.dart';

/// Localized display label for a [MealType] (empty for null), shared by every
/// screen that renders a meal type so the strings stay in one place.
String mealTypeLabel(AppLocalizations l, MealType? type) => switch (type) {
      MealType.breakfast => l.mealBreakfast,
      MealType.lunch => l.mealLunch,
      MealType.dinner => l.mealDinner,
      MealType.snack => l.mealSnack,
      null => '',
    };

/// Same, for a raw DB column value (e.g. history filter chips).
String mealTypeLabelFromDb(AppLocalizations l, String type) => switch (type) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'dinner' => l.mealDinner,
      'snack' => l.mealSnack,
      _ => type,
    };
