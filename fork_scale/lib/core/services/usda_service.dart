import '../database/app_database.dart';

class UsdaService {
  // Returns kcal per 100g for the best-matching food name, or null if no match.
  Future<({double kcalPer100g, String matchedName})?> lookup(String foodName) async {
    final db = await AppDatabase.usdaDb;
    // Try exact then LIKE on description column
    final lower = foodName.toLowerCase().trim();
    var rows = await db.rawQuery(
      'SELECT description, kcal_per_100g FROM foods WHERE LOWER(description) = ? LIMIT 1',
      [lower],
    );
    if (rows.isNotEmpty) {
      return (
        kcalPer100g: (rows.first['kcal_per_100g'] as num).toDouble(),
        matchedName: rows.first['description'] as String,
      );
    }
    // Partial match — find description containing all words
    final words = lower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isEmpty) return null;
    final likeClause = words.map((_) => "LOWER(description) LIKE ?").join(' AND ');
    final likeArgs = words.map((w) => '%$w%').toList();
    rows = await db.rawQuery(
      'SELECT description, kcal_per_100g FROM foods WHERE $likeClause LIMIT 5',
      likeArgs,
    );
    if (rows.isNotEmpty) {
      // sqflite returns an unmodifiable list — copy before sorting
      final sorted = rows.toList()
        ..sort((a, b) => (a['description'] as String)
            .length
            .compareTo((b['description'] as String).length));
      return (
        kcalPer100g: (sorted.first['kcal_per_100g'] as num).toDouble(),
        matchedName: sorted.first['description'] as String,
      );
    }
    return null;
  }
}
