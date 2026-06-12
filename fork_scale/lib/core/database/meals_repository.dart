import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/enums.dart';
import '../../models/meal.dart';
import '../../models/meal_item.dart';
import 'app_database.dart';

class MealsRepository {
  // Emits an incrementing revision number after every write so that all
  // read providers (history, insights) can react without manual invalidation.
  int _revision = 0;
  final _changesController = StreamController<int>.broadcast();
  Stream<int> get changes => _changesController.stream;
  void _bump() => _changesController.add(++_revision);

  /// Builds the meal row map, recomputing denormalised macro totals from the
  /// items when items are present. Meals without items (e.g. recipe portions)
  /// keep whatever totals the caller set on the [Meal].
  Map<String, dynamic> _mealMap(Meal meal) {
    final map = meal.toMap();
    if (meal.items.isNotEmpty) {
      final macros = Meal.sumItemMacros(meal.items);
      map['total_protein_g'] = macros.protein;
      map['total_carbs_g'] = macros.carbs;
      map['total_fat_g'] = macros.fat;
    }
    return map;
  }

  Future<int> insertMeal(Meal meal) async {
    final db = await AppDatabase.mealsDb;
    final id = await db.transaction((txn) async {
      final mealId = await txn.insert('meals', _mealMap(meal));
      if (meal.items.isNotEmpty) {
        final batch = txn.batch();
        for (var i = 0; i < meal.items.length; i++) {
          batch.insert('meal_items', meal.items[i].copyWith(mealId: mealId, sortOrder: i).toMap());
        }
        await batch.commit(noResult: true);
      }
      if (AppDatabase.hasFts) {
        await txn.execute(
          "INSERT INTO meals_fts(rowid, name, notes) VALUES (?, ?, ?)",
          [mealId, meal.name, meal.notes],
        );
      }
      return mealId;
    });
    _bump();
    return id;
  }

  Future<void> updateMeal(Meal meal) async {
    final db = await AppDatabase.mealsDb;
    await db.transaction((txn) async {
      await txn.update('meals', _mealMap(meal), where: 'id = ?', whereArgs: [meal.id]);
      await txn.delete('meal_items', where: 'meal_id = ?', whereArgs: [meal.id]);
      if (meal.items.isNotEmpty) {
        final batch = txn.batch();
        for (var i = 0; i < meal.items.length; i++) {
          batch.insert('meal_items', meal.items[i].copyWith(mealId: meal.id, sortOrder: i).toMap());
        }
        await batch.commit(noResult: true);
      }
      if (AppDatabase.hasFts) {
        await txn.execute(
          "INSERT OR REPLACE INTO meals_fts(rowid, name, notes) VALUES (?, ?, ?)",
          [meal.id, meal.name, meal.notes],
        );
      }
    });
    _bump();
  }

  Future<void> deleteMeal(int id) async {
    final db = await AppDatabase.mealsDb;
    // Resolve photo ref-count outside the transaction (read-only, avoids nesting).
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
    await db.transaction((txn) async {
      await txn.delete('meals', where: 'id = ?', whereArgs: [id]);
      // meal_items cascade via FK; FTS has no FK so needs explicit removal.
      if (AppDatabase.hasFts) {
        await txn.execute("DELETE FROM meals_fts WHERE rowid = ?", [id]);
      }
    });
    _bump();
  }

  Future<void> starMeal(int id, {required bool starred}) async {
    final db = await AppDatabase.mealsDb;
    await db.update(
      'meals',
      {'starred': starred ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _bump();
  }

  Future<int> copyMealToToday(Meal original) async {
    final now = DateTime.now();
    late Meal copy;
    switch (original.source) {
      case MealSource.barcode:
        copy = Meal(
          createdAt: now,
          photoPath: original.photoPath,
          name: original.name,
          notes: original.notes,
          totalKcal: original.totalKcal,
          utensil: original.utensil,
          modelUsed: original.modelUsed,
          mealType: Meal.detectTypeFromTime(now),
          source: MealSource.barcode,
          barcode: original.barcode,
          priceChf: original.priceChf,
          totalProteinG: original.totalProteinG,
          totalCarbsG: original.totalCarbsG,
          totalFatG: original.totalFatG,
          items: original.items.map((i) => i.copyWith(id: null, mealId: null)).toList(),
        );
      case MealSource.recipePortion:
        copy = Meal(
          createdAt: now,
          photoPath: original.photoPath,
          name: original.name,
          totalKcal: original.totalKcal,
          utensil: original.utensil,
          modelUsed: original.modelUsed,
          mealType: Meal.detectTypeFromTime(now),
          source: MealSource.recipePortion,
          recipeId: original.recipeId,
          portionG: original.portionG,
          totalProteinG: original.totalProteinG,
          totalCarbsG: original.totalCarbsG,
          totalFatG: original.totalFatG,
        );
      case MealSource.camera:
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
          source: MealSource.camera,
          totalProteinG: original.totalProteinG,
          totalCarbsG: original.totalCarbsG,
          totalFatG: original.totalFatG,
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

    return _hydrateMeals(db, rows);
  }

  // Fetches items for a list of meal rows in a single IN query, then zips them.
  Future<List<Meal>> _hydrateMeals(dynamic db, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await db.rawQuery(
      'SELECT * FROM meal_items WHERE meal_id IN ($placeholders) ORDER BY sort_order ASC',
      ids,
    ) as List<Map<String, dynamic>>;

    final itemsByMeal = <int, List<MealItem>>{};
    for (final row in itemRows) {
      final mid = row['meal_id'] as int;
      (itemsByMeal[mid] ??= []).add(MealItem.fromMap(row));
    }

    return rows.map((row) {
      final id = row['id'] as int;
      return Meal.fromMap(row, items: itemsByMeal[id] ?? []);
    }).toList();
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
    final end = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'meals',
      columns: ['name'],
      where: 'created_at >= ? AND created_at < ? AND pending = 0 AND name IS NOT NULL',
      whereArgs: [start, end],
    );
    return rows.map((r) => r['name'] as String).toSet();
  }

  // Wraps each whitespace-separated token in double-quotes for FTS4 MATCH.
  // Prevents SqliteException on inputs with unbalanced quotes or operators.
  String _sanitizeFtsQuery(String q) {
    return q
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"')
        .join(' ');
  }

  Future<List<Meal>> _searchMeals(String query,
      {int limit = 50, int offset = 0}) async {
    final db = await AppDatabase.mealsDb;
    final ftsRows = await db.rawQuery(
      "SELECT rowid FROM meals_fts WHERE meals_fts MATCH ? LIMIT ? OFFSET ?",
      [_sanitizeFtsQuery(query), limit, offset],
    );
    final ids = ftsRows.map((r) => r['rowid'] as int).toList();
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final mealRows = await db.rawQuery(
      'SELECT * FROM meals WHERE id IN ($placeholders)',
      ids,
    ) as List<Map<String, dynamic>>;
    return _hydrateMeals(db, mealRows);
  }

  Future<double> getDayTotalKcal(DateTime day) async {
    final db = await AppDatabase.mealsDb;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT SUM(total_kcal) as total FROM meals '
      'WHERE created_at >= ? AND created_at < ? AND pending = 0',
      [start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns kcal totals for the last 7 days, index 0 = 6 days ago, index 6 = today.
  Future<List<double>> getWeeklyKcal() async {
    final db = await AppDatabase.mealsDb;
    final today = DateTime.now();
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final cutoff = weekStart.millisecondsSinceEpoch;
    final end = DateTime(today.year, today.month, today.day + 1).millisecondsSinceEpoch;

    final rows = await db.rawQuery(
      "SELECT strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch', 'localtime')) as day, "
      "SUM(total_kcal) as total FROM meals "
      "WHERE created_at >= ? AND created_at < ? AND pending = 0 "
      "GROUP BY day",
      [cutoff, end],
    );

    final byDay = <String, double>{
      for (final r in rows)
        r['day'] as String: (r['total'] as num).toDouble(),
    };

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return byDay[fmt(day)] ?? 0.0;
    });
  }

  /// Exports all analyzed meals to a CSV file in the temp directory.
  /// Returns the file path for sharing.
  Future<String> exportCsv() async {
    final db = await AppDatabase.mealsDb;

    // Single JOIN — avoids N+1 item queries.
    final rows = await db.rawQuery(
      'SELECT m.id, m.created_at, m.meal_type, m.total_kcal, m.utensil, '
      'm.starred, m.source, '
      'i.name as item_name, i.weight_g, i.total_kcal as item_kcal '
      'FROM meals m '
      'LEFT JOIN meal_items i ON i.meal_id = m.id '
      'WHERE m.pending = 0 '
      'ORDER BY m.created_at ASC, i.sort_order ASC',
    );

    // Group items by meal id.
    final mealOrder = <int>[];
    final mealRows = <int, Map<String, dynamic>>{};
    final mealItems = <int, List<String>>{};

    for (final row in rows) {
      final id = row['id'] as int;
      if (!mealRows.containsKey(id)) {
        mealOrder.add(id);
        mealRows[id] = row;
        mealItems[id] = [];
      }
      if (row['item_name'] != null) {
        final name = csvSafe(row['item_name'] as String);
        final g = (row['weight_g'] as num).round();
        final kcal = (row['item_kcal'] as num).round();
        mealItems[id]!.add('$name: ${g}g ${kcal}kcal');
      }
    }

    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');
    final buf = StringBuffer();
    buf.writeln('Date,Time,Meal Type,Total kcal,Utensil,Starred,Source,Items');

    for (final id in mealOrder) {
      final row = mealRows[id]!;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);
      final itemsStr = mealItems[id]!.join('; ').replaceAll('"', '""');
      buf.writeln(
        '${dateFmt.format(createdAt)},'
        '${timeFmt.format(createdAt)},'
        '${csvSafe(row['meal_type'] as String? ?? '')},'
        '${(row['total_kcal'] as num).round()},'
        '${csvSafe(row['utensil'] as String)},'
        '${(row['starred'] as int? ?? 0) == 1 ? '1' : '0'},'
        '${csvSafe(row['source'] as String)},'
        '"$itemsStr"',
      );
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/forkscale_$stamp.csv');
    await file.writeAsString(buf.toString());
    return file.path;
  }

  // Prefixes cell values starting with formula chars to prevent spreadsheet injection.
  static String csvSafe(String s) =>
      (s.isNotEmpty &&
          (s.startsWith('=') || s.startsWith('+') || s.startsWith('-') || s.startsWith('@')))
          ? "'$s"
          : s;

  Future<double> getAvgDailyKcal({int days = 30}) async {
    final db = await AppDatabase.mealsDb;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      "SELECT AVG(daily_total) as avg FROM ("
      "  SELECT SUM(total_kcal) as daily_total FROM meals"
      "  WHERE created_at >= ? AND pending = 0"
      "  GROUP BY strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch', 'localtime'))"
      ")",
      [cutoff],
    );
    return (result.first['avg'] as num?)?.toDouble() ?? 0.0;
  }

  /// Average daily macro totals (grams) over the last [days]. Each macro is
  /// the mean of per-day sums; null when no meal in the window carries it.
  Future<({double? protein, double? carbs, double? fat})> getAvgDailyMacros(
      {int days = 7}) async {
    final db = await AppDatabase.mealsDb;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      "SELECT AVG(p) as avg_p, AVG(c) as avg_c, AVG(f) as avg_f FROM ("
      "  SELECT SUM(total_protein_g) as p, SUM(total_carbs_g) as c, SUM(total_fat_g) as f"
      "  FROM meals WHERE created_at >= ? AND pending = 0"
      "  GROUP BY strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch', 'localtime'))"
      ")",
      [cutoff],
    );
    final row = result.first;
    return (
      protein: (row['avg_p'] as num?)?.toDouble(),
      carbs: (row['avg_c'] as num?)?.toDouble(),
      fat: (row['avg_f'] as num?)?.toDouble(),
    );
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
      "SELECT DISTINCT strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch', 'localtime')) as day "
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
      "  GROUP BY strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch', 'localtime'))"
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
      "SELECT COUNT(DISTINCT strftime('%Y-%m-%d', datetime(created_at / 1000, 'unixepoch', 'localtime'))) as cnt "
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
