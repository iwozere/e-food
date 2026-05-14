import '../../models/meal.dart';
import '../../models/meal_item.dart';
import 'app_database.dart';

class MealsRepository {
  Future<int> insertMeal(Meal meal) async {
    final db = await AppDatabase.mealsDb;
    final mealId = await db.insert('meals', meal.toMap());
    for (var i = 0; i < meal.items.length; i++) {
      final item = meal.items[i].copyWith(mealId: mealId, sortOrder: i);
      await db.insert('meal_items', item.toMap());
    }
    // Update FTS index
    await db.execute(
      "INSERT INTO meals_fts(rowid, name, notes) VALUES (?, ?, ?)",
      [mealId, meal.name, meal.notes],
    );
    return mealId;
  }

  Future<void> updateMeal(Meal meal) async {
    final db = await AppDatabase.mealsDb;
    await db.update('meals', meal.toMap(), where: 'id = ?', whereArgs: [meal.id]);
    await db.delete('meal_items', where: 'meal_id = ?', whereArgs: [meal.id]);
    for (var i = 0; i < meal.items.length; i++) {
      final item = meal.items[i].copyWith(mealId: meal.id, sortOrder: i);
      await db.insert('meal_items', item.toMap());
    }
    await db.execute(
      "INSERT OR REPLACE INTO meals_fts(rowid, name, notes) VALUES (?, ?, ?)",
      [meal.id, meal.name, meal.notes],
    );
  }

  Future<void> deleteMeal(int id) async {
    final db = await AppDatabase.mealsDb;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
    await db.execute("DELETE FROM meals_fts WHERE rowid = ?", [id]);
  }

  Future<Meal?> getMeal(int id) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query('meals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await _getItems(id);
    return Meal.fromMap(rows.first, items: items);
  }

  Future<List<Meal>> getMeals({
    DateTime? from,
    DateTime? to,
    String? searchQuery,
    double? minKcal,
    double? maxKcal,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await AppDatabase.mealsDb;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      return _searchMeals(searchQuery, limit: limit, offset: offset);
    }

    final where = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (minKcal != null) {
      where.add('total_kcal >= ?');
      args.add(minKcal);
    }
    if (maxKcal != null) {
      where.add('total_kcal <= ?');
      args.add(maxKcal);
    }

    final rows = await db.query(
      'meals',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final meals = <Meal>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final items = await _getItems(id);
      meals.add(Meal.fromMap(row, items: items));
    }
    return meals;
  }

  Future<List<Meal>> _searchMeals(String query, {int limit = 50, int offset = 0}) async {
    final db = await AppDatabase.mealsDb;
    final ftsRows = await db.rawQuery(
      "SELECT rowid FROM meals_fts WHERE meals_fts MATCH ? LIMIT ? OFFSET ?",
      [query, limit, offset],
    );
    final ids = ftsRows.map((r) => r['rowid'] as int).toList();
    if (ids.isEmpty) return [];
    final meals = <Meal>[];
    for (final id in ids) {
      final meal = await getMeal(id);
      if (meal != null) meals.add(meal);
    }
    return meals;
  }

  Future<double> getDayTotalKcal(DateTime day) async {
    final db = await AppDatabase.mealsDb;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT SUM(total_kcal) as total FROM meals WHERE created_at BETWEEN ? AND ?',
      [start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<MealItem>> _getItems(int mealId) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query(
      'meal_items',
      where: 'meal_id = ?',
      whereArgs: [mealId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(MealItem.fromMap).toList();
  }
}
