import 'package:flutter_test/flutter_test.dart';

import 'package:fork_scale/models/enums.dart';
import 'package:fork_scale/models/meal.dart';

void main() {
  group('Meal.detectTypeFromTime', () {
    DateTime at(int hour) => DateTime(2024, 1, 15, hour, 0);

    test('4:59 → dinner (late night belongs to previous day)', () {
      expect(Meal.detectTypeFromTime(at(4)), MealType.dinner);
    });

    test('5:00 → breakfast boundary', () {
      expect(Meal.detectTypeFromTime(at(5)), MealType.breakfast);
    });

    test('9:59 → breakfast (last minute)', () {
      expect(Meal.detectTypeFromTime(at(9)), MealType.breakfast);
    });

    test('10:00 → lunch boundary', () {
      expect(Meal.detectTypeFromTime(at(10)), MealType.lunch);
    });

    test('14:59 → lunch (last minute)', () {
      expect(Meal.detectTypeFromTime(at(14)), MealType.lunch);
    });

    test('15:00 → snack boundary', () {
      expect(Meal.detectTypeFromTime(at(15)), MealType.snack);
    });

    test('17:59 → snack (last minute)', () {
      expect(Meal.detectTypeFromTime(at(17)), MealType.snack);
    });

    test('18:00 → dinner boundary', () {
      expect(Meal.detectTypeFromTime(at(18)), MealType.dinner);
    });

    test('23:00 → dinner', () {
      expect(Meal.detectTypeFromTime(at(23)), MealType.dinner);
    });
  });
}
