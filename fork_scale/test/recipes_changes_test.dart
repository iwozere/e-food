import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fork_scale/core/database/app_database.dart';
import 'package:fork_scale/core/database/recipes_repository.dart';
import 'package:fork_scale/models/recipe.dart';

// Guards T3.3: recipe writes bump RecipesRepository.changes so the recipe
// screens (which watch recipesChangesProvider) refetch by construction instead
// of relying on manual ref.invalidate.

Recipe _recipe({String name = 'Soup'}) => Recipe(
      name: name,
      yieldG: 500,
      kcalPer100g: 80,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.openTestDb();
  });

  tearDown(() async {
    await AppDatabase.closeAll();
  });

  test('insertRecipe bumps the changes stream', () async {
    final repo = RecipesRepository();
    final emitted = expectLater(repo.changes, emits(isA<int>()));
    await repo.insertRecipe(_recipe());
    await emitted;
  });

  test('updateRecipe and deleteRecipe each bump the changes stream', () async {
    final repo = RecipesRepository();
    final id = await repo.insertRecipe(_recipe());

    final twoMore = expectLater(repo.changes, emitsInOrder([isA<int>(), isA<int>()]));
    final saved = await repo.getRecipe(id);
    await repo.updateRecipe(saved!.copyWith(name: 'Stew'));
    await repo.deleteRecipe(id);
    await twoMore;
  });
}
