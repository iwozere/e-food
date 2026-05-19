import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
    final rows = await db.query('meals', columns: ['photo_path'], where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final path = rows.first['photo_path'] as String;
      final refCount = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM meals WHERE photo_path = ? AND id != ?',
        [path, id],
      )).first['c'] as int;
      if (refCount == 0) {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
    }
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
    await db.execute("DELETE FROM meals_fts WHERE rowid = ?", [id]);
  }

  Future<void> starMeal(int id, {required bool starred}) async {
    final db = await AppDatabase.mealsDb;
    await db.update(
      'meals',
      {'starred': starred ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> copyMealToToday(Meal original) async {
    final now = DateTime.now();
    late Meal copy;
    switch (original.source) {
      case 'barcode':
        copy = Meal(
          createdAt: now,
          photoPath: original.photoPath,
          name: original.name,
          notes: original.notes,
          totalKcal: original.totalKcal,
          utensil: original.utensil,
          modelUsed: original.modelUsed,
          mealType: Meal.detectTypeFromTime(now),
          source: 'barcode',
          barcode: original.barcode,
          priceChf: original.priceChf,
          items: original.items.map((i) => i.copyWith(id: null, mealId: null)).toList(),
        );
      case 'recipe_portion':
        // Recompute kcal from current recipe in case it was edited since.
        // If recipe no longer exists, fall back to original totalKcal.
        copy = Meal(
          createdAt: now,
          photoPath: original.photoPath,
          name: original.name,
          totalKcal: original.totalKcal,
          utensil: original.utensil,
          modelUsed: original.modelUsed,
          mealType: Meal.detectTypeFromTime(now),
          source: 'recipe_portion',
          recipeId: original.recipeId,
          portionG: original.portionG,
        );
      default: // 'camera'
        copy = Meal(
          createdAt: now,
          photoPath: original.photoPath,
          name: original.name,
          notes: original.notes,
          totalKcal: original.totalKcal,
          utensil: original.utensil,
          scaleConf: original.scaleConf,
          modelUsed: original.modelUsed,
          mealType: Meal.detectTypeFromTime(now),
          source: 'camera',
          items: original.items.map((i) => i.copyWith(id: null, mealId: null)).toList(),
        );
    }
    return insertMeal(copy);
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
    bool starredOnly = false,
    String? mealType,
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
    if (starredOnly) {
      where.add('starred = 1');
    }
    if (mealType != null) {
      where.add('meal_type = ?');
      args.add(mealType);
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

  /// Returns the last [limit] distinct meal names (non-pending), most recent first.
  Future<List<Meal>> getRecentDistinct({int limit = 5}) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query(
      'meals',
      where: 'name IS NOT NULL AND pending = 0',
      orderBy: 'created_at DESC',
      limit: 50,
    );
    final seen = <String>{};
    final result = <Meal>[];
    for (final row in rows) {
      final name = row['name'] as String? ?? '';
      if (name.isNotEmpty && seen.add(name)) {
        result.add(Meal.fromMap(row));
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  /// Returns the set of distinct meal names logged today.
  Future<Set<String>> getMealNamesToday() async {
    final db = await AppDatabase.mealsDb;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    final rows = await db.query(
      'meals',
      columns: ['name'],
      where: 'created_at BETWEEN ? AND ? AND pending = 0 AND name IS NOT NULL',
      whereArgs: [start, end],
    );
    return rows.map((r) => r['name'] as String).toSet();
  }

  Future<List<Meal>> _searchMeals(String query,
      {int limit = 50, int offset = 0}) async {
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
    final start =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end =
        DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT SUM(total_kcal) as total FROM meals '
      'WHERE created_at BETWEEN ? AND ? AND pending = 0',
      [start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns kcal totals for the last 7 days, index 0 = 6 days ago, index 6 = today.
  Future<List<double>> getWeeklyKcal() async {
    final today = DateTime.now();
    final results = <double>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      results.add(await getDayTotalKcal(day));
    }
    return results;
  }

  /// Exports all analyzed meals to a CSV file in the temp directory.
  /// Returns the file path for sharing.
  Future<String> exportCsv() async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query(
      'meals',
      where: 'pending = 0',
      orderBy: 'created_at ASC',
    );

    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');
    final buf = StringBuffer();
    buf.writeln('Date,Time,Meal Type,Total kcal,Utensil,Starred,Source,Items');

    for (final row in rows) {
      final meal = Meal.fromMap(row);
      final items = await _getItems(meal.id!);
      final itemsStr = items
          .map((i) =>
              '${i.name}: ${i.weightG.round()}g ${i.totalKcal.round()}kcal')
          .join('; ');
      final escapedItems = itemsStr.replaceAll('"', '""');
      buf.writeln(
        '${dateFmt.format(meal.createdAt)},'
        '${timeFmt.format(meal.createdAt)},'
        '${meal.mealType ?? ''},'
        '${meal.totalKcal.round()},'
        '${meal.utensil},'
        '${meal.starred ? '1' : '0'},'
        '${meal.source},'
        '"$escapedItems"',
      );
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/forkscale_$stamp.csv');
    await file.writeAsString(buf.toString());
    return file.path;
  }

  Future<double> getAvgDailyKcal({int days = 30}) async {
    final db = await AppDatabase.mealsDb;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      "SELECT AVG(daily_total) as avg FROM ("
      "  SELECT SUM(total_kcal) as daily_total FROM meals"
      "  WHERE created_at >= ? AND pending = 0"
      "  GROUP BY strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch'))"
      ")",
      [cutoff],
    );
    return (result.first['avg'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<({String name, int count, double avgKcal})>> getTopMeals(
      {int limit = 5}) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.rawQuery(
      "SELECT name, COUNT(*) as cnt, AVG(total_kcal) as avg_kcal "
      "FROM meals "
      "WHERE pending = 0 AND name IS NOT NULL AND name != '' "
      "GROUP BY name ORDER BY cnt DESC LIMIT ?",
      [limit],
    );
    return rows
        .map((r) => (
              name: r['name'] as String,
              count: r['cnt'] as int,
              avgKcal: (r['avg_kcal'] as num).toDouble(),
            ))
        .toList();
  }

  Future<int> getCurrentStreak() async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch')) as day "
      "FROM meals WHERE pending = 0 ORDER BY day DESC LIMIT 365",
    );
    if (rows.isEmpty) return 0;

    final loggedDays = rows.map((r) => r['day'] as String).toSet();
    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    DateTime start = DateTime(today.year, today.month, today.day);
    if (!loggedDays.contains(fmt(start))) {
      start = start.subtract(const Duration(days: 1));
      if (!loggedDays.contains(fmt(start))) return 0;
    }

    int streak = 0;
    DateTime current = start;
    while (streak < 365 && loggedDays.contains(fmt(current))) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<int> getDaysOverGoal({required double goalKcal, int days = 7}) async {
    final db = await AppDatabase.mealsDb;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM ("
      "  SELECT SUM(total_kcal) as daily_total FROM meals"
      "  WHERE created_at >= ? AND pending = 0"
      "  GROUP BY strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch'))"
      "  HAVING daily_total > ?"
      ")",
      [cutoff, goalKcal],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> getDaysWithMeals({int days = 7}) async {
    final db = await AppDatabase.mealsDb;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      "SELECT COUNT(DISTINCT strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch'))) as cnt "
      "FROM meals WHERE created_at >= ? AND pending = 0",
      [cutoff],
    );
    return (result.first['cnt'] as int?) ?? 0;
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
