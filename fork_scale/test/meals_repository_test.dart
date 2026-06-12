import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fork_scale/core/database/app_database.dart';
import 'package:fork_scale/core/database/meals_repository.dart';
import 'package:fork_scale/models/enums.dart';
import 'package:fork_scale/models/meal.dart';
import 'package:fork_scale/models/meal_item.dart';

Meal _meal({
  DateTime? at,
  double kcal = 500,
  MealType? mealType,
  List<MealItem> items = const [],
}) =>
    Meal(
      createdAt: at ?? DateTime.now(),
      photoPath: '',
      totalKcal: kcal,
      utensil: Utensil.fork,
      modelUsed: 'test',
      mealType: mealType,
      items: items,
    );

MealItem _mealItem({double kcal = 500}) => MealItem(
      name: 'item',
      weightG: 100,
      kcalPer100g: kcal,
      totalKcal: kcal,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Each test gets its own fresh in-memory database.
    await AppDatabase.openTestDb();
  });

  tearDown(() async {
    await AppDatabase.closeAll();
  });

  group('FK cascade — deleteMeal removes meal_items', () {
    test('deleting a meal removes all its items', () async {
      final repo = MealsRepository();
      final items = [_mealItem(), _mealItem(kcal: 300)];
      final id = await repo.insertMeal(_meal(items: items));

      final db = await AppDatabase.mealsDb;
      final before =
          await db.query('meal_items', where: 'meal_id = ?', whereArgs: [id]);
      expect(before.length, 2);

      await repo.deleteMeal(id);

      final after =
          await db.query('meal_items', where: 'meal_id = ?', whereArgs: [id]);
      expect(after, isEmpty);
    });

    test('deleting a meal does not affect items from other meals', () async {
      final repo = MealsRepository();
      final id1 = await repo.insertMeal(_meal(items: [_mealItem()]));
      final id2 = await repo.insertMeal(_meal(items: [_mealItem()]));

      await repo.deleteMeal(id1);

      final db = await AppDatabase.mealsDb;
      final remaining =
          await db.query('meal_items', where: 'meal_id = ?', whereArgs: [id2]);
      expect(remaining.length, 1);
    });
  });

  group('getCurrentStreak', () {
    test('no meals → streak is 0', () async {
      final repo = MealsRepository();
      expect(await repo.getCurrentStreak(), 0);
    });

    test('single meal today → streak is 1', () async {
      final repo = MealsRepository();
      await repo.insertMeal(_meal(at: DateTime.now()));
      expect(await repo.getCurrentStreak(), 1);
    });

    test('consecutive days → streak counts correctly', () async {
      final repo = MealsRepository();
      final now = DateTime.now();
      // Insert meals for today, yesterday, and two days ago.
      await repo.insertMeal(_meal(at: now));
      await repo.insertMeal(_meal(at: now.subtract(const Duration(days: 1))));
      await repo.insertMeal(_meal(at: now.subtract(const Duration(days: 2))));
      expect(await repo.getCurrentStreak(), 3);
    });

    test('gap in days breaks the streak', () async {
      final repo = MealsRepository();
      final now = DateTime.now();
      await repo.insertMeal(_meal(at: now));
      // Skip yesterday, insert two days ago.
      await repo.insertMeal(_meal(at: now.subtract(const Duration(days: 2))));
      // Streak is 1 (only today counts, yesterday is missing).
      expect(await repo.getCurrentStreak(), 1);
    });
  });

  group('getDayTotalKcal', () {
    test('sums only meals on the given day', () async {
      final repo = MealsRepository();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      await repo.insertMeal(_meal(at: today, kcal: 400));
      await repo.insertMeal(_meal(at: today, kcal: 600));
      await repo.insertMeal(_meal(at: yesterday, kcal: 9999));

      final total = await repo.getDayTotalKcal(today);
      expect(total, 1000.0);
    });
  });
}
