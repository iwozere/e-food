import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../models/meal.dart';

typedef MealsFilter = ({String? query, DateTime? day, bool starredOnly, String? mealType});

final historyMealsProvider =
    FutureProvider.autoDispose.family<List<Meal>, MealsFilter>(
  (ref, filter) {
    ref.watch(mealsChangesProvider); // auto-refetch on any write
    final day = filter.day;
    return ref.read(mealsRepositoryProvider).getMeals(
          searchQuery: filter.query,
          from: day != null ? DateTime(day.year, day.month, day.day) : null,
          to: day != null
              ? DateTime(day.year, day.month, day.day, 23, 59, 59)
              : null,
          starredOnly: filter.starredOnly,
          mealType: filter.mealType,
        );
  },
);

final historyDayTotalProvider = FutureProvider.autoDispose<double>((ref) {
  ref.watch(mealsChangesProvider);
  return ref.read(mealsRepositoryProvider).getDayTotalKcal(DateTime.now());
});

final historyWeeklyKcalProvider = FutureProvider.autoDispose<List<double>>((ref) {
  ref.watch(mealsChangesProvider);
  return ref.read(mealsRepositoryProvider).getWeeklyKcal();
});
