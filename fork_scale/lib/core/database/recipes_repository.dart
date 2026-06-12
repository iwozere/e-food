import '../../models/recipe.dart';
import '../../models/recipe_item.dart';
import 'app_database.dart';

class RecipesRepository {
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await AppDatabase.mealsDb;
    return db.transaction((txn) async {
      final id = await txn.insert('recipes', recipe.toMap());
      if (recipe.items.isNotEmpty) {
        final batch = txn.batch();
        for (var i = 0; i < recipe.items.length; i++) {
          batch.insert('recipe_items', recipe.items[i].copyWith(recipeId: id, sortOrder: i).toMap());
        }
        await batch.commit(noResult: true);
      }
      return id;
    });
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final db = await AppDatabase.mealsDb;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final map = recipe.toMap();
      map['updated_at'] = now;
      await txn.update('recipes', map, where: 'id = ?', whereArgs: [recipe.id]);
      await txn.delete('recipe_items', where: 'recipe_id = ?', whereArgs: [recipe.id]);
      if (recipe.items.isNotEmpty) {
        final batch = txn.batch();
        for (var i = 0; i < recipe.items.length; i++) {
          batch.insert('recipe_items', recipe.items[i].copyWith(recipeId: recipe.id, sortOrder: i).toMap());
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> deleteRecipe(int id) async {
    final db = await AppDatabase.mealsDb;
    // recipe_items cascade via FK; plain delete is sufficient.
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Recipe?> getRecipe(int id) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await _getItems(id);
    return Recipe.fromMap(rows.first, items: items);
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query('recipes', orderBy: 'updated_at DESC');
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await db.rawQuery(
      'SELECT * FROM recipe_items WHERE recipe_id IN ($placeholders) ORDER BY sort_order ASC',
      ids,
    ) as List<Map<String, dynamic>>;

    final itemsByRecipe = <int, List<RecipeItem>>{};
    for (final row in itemRows) {
      final rid = row['recipe_id'] as int;
      (itemsByRecipe[rid] ??= []).add(RecipeItem.fromMap(row));
    }

    return rows.map((row) {
      final id = row['id'] as int;
      return Recipe.fromMap(row, items: itemsByRecipe[id] ?? []);
    }).toList();
  }

  Future<List<RecipeItem>> _getItems(int recipeId) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query(
      'recipe_items',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(RecipeItem.fromMap).toList();
  }
}
