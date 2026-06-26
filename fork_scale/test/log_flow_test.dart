import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fork_scale/core/database/app_database.dart';
import 'package:fork_scale/core/database/meals_repository.dart';
import 'package:fork_scale/core/services/providers.dart';
import 'package:fork_scale/models/enums.dart';
import 'package:fork_scale/models/meal.dart';

// Guards the log -> History refresh path: a write through MealsRepository must
// bump the `changes` stream so `mealsChangesProvider` emits, which is what
// makes History/day-total providers refetch (the regression in docs/issues.md).
//
// This exercises the data + provider wiring under FFI. A full UI integration
// test that drives the camera/recipe flow lives under integration_test/ and is
// run on a device job, not in this headless suite.

Meal _meal({double kcal = 450}) => Meal(
      createdAt: DateTime.now(),
      photoPath: '',
      totalKcal: kcal,
      utensil: Utensil.fork,
      modelUsed: 'test',
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

  test('insertMeal bumps the changes stream', () async {
    final repo = MealsRepository();
    final emitted = expectLater(repo.changes, emits(isA<int>()));
    await repo.insertMeal(_meal(kcal: 450));
    await emitted;
  });

  test('logging a meal surfaces through mealsChangesProvider and day total',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Keep the StreamProvider alive so it subscribes to repo.changes.
    final sub = container.listen(mealsChangesProvider, (_, _) {});
    addTearDown(sub.close);

    final repo = container.read(mealsRepositoryProvider);
    await repo.insertMeal(_meal(kcal: 600));

    // Let the broadcast event propagate into the StreamProvider.
    await Future<void>.delayed(Duration.zero);

    expect(container.read(mealsChangesProvider).hasValue, isTrue);
    expect(await repo.getDayTotalKcal(DateTime.now()), 600);
  });
}
