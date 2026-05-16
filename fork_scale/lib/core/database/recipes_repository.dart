import '../../models/recipe.dart';
import '../../models/recipe_item.dart';
import 'app_database.dart';

class RecipesRepository {
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await AppDatabase.mealsDb;
    final id = await db.insert('recipes', recipe.toMap());
    for (var i = 0; i < recipe.items.length; i++) {
      await db.insert(
          'recipe_items', recipe.items[i].copyWith(recipeId: id, sortOrder: i).toMap());
    }
    return id;
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final db = await AppDatabase.mealsDb;
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = recipe.toMap();
    map['updated_at'] = now;
    await db.update('recipes', map, where: 'id = ?', whereArgs: [recipe.id]);
    await db.delete('recipe_items', where: 'recipe_id = ?', whereArgs: [recipe.id]);
    for (var i = 0; i < recipe.items.length; i++) {
      await db.insert(
          'recipe_items', recipe.items[i].copyWith(recipeId: recipe.id, sortOrder: i).toMap());
    }
  }

  Future<void> deleteRecipe(int id) async {
    final db = await AppDatabase.mealsDb;
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
    final recipes = <Recipe>[];
    for (final row in rows) {
      final items = await _getItems(row['id'] as int);
      recipes.add(Recipe.fromMap(row, items: items));
    }
    return recipes;
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
