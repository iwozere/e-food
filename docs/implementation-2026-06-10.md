# ForkScale — Implementation Plan

**Date:** 2026-06-10  
**Input:** `docs/review-2026-06-10.md`  
**Author role:** Senior developer  

This plan sequences the 17 findings from the review into five deliverable phases. Each phase is independently shippable. Items within a phase may be done in parallel by a single developer; dependencies across phases are called out explicitly.

---

## How to read this document

- **Files** are repo-relative from `fork_scale/lib/` unless noted.
- **Effort** re-uses the review legend: XS < 1 h · S = a few hours · M = 1–3 days.
- `→ §X.Y` cross-references the review section.
- "Done when" criteria are observable facts, not intentions.

---

## Phase 1 — Critical fixes (ship before any wider distribution)

These are zero-API-break, low-risk patches. Do them in a single PR.

---

### 1.1 Zip-slip: sanitize restore entry paths

**File:** `core/services/backup_service.dart`  
**Effort:** XS → §3.1

**Current code (lines 58-64):**
```dart
for (final file in archive.files) {
  if (!file.isFile) continue;
  final outFile = File(p.join(docs.path, file.name));
  await outFile.create(recursive: true);
  await outFile.writeAsBytes(file.content as List<int>);
}
```

**Replace with:**
```dart
for (final file in archive.files) {
  if (!file.isFile) continue;
  final outPath = p.normalize(p.join(docs.path, file.name));
  if (!p.isWithin(docs.path, outPath)) continue; // silently skip traversal attempts
  final outFile = File(outPath);
  await outFile.create(recursive: true);
  await outFile.writeAsBytes(file.content as List<int>);
}
```

**Done when:** a zip with an entry named `../../shared_prefs/x.xml` silently skips and restore completes without writing outside `docs.path`.

---

### 1.2 Enable foreign-key enforcement + orphan cleanup migration

**File:** `core/database/app_database.dart`  
**Effort:** S → §4.1

**Step A — enable FK enforcement at DB open.**  
Add an `onConfigure` callback to the `openDatabase` call in `_openMealsDb` (or however the meals DB is opened):

```dart
onConfigure: (db) async {
  await db.execute('PRAGMA foreign_keys = ON');
},
```

**Step B — schema version bump to 7 + orphan cleanup migration.**  
Increment `_dbVersion` from 6 to 7. Add a `case 6:` block in the `onUpgrade` switch:

```dart
case 6:
  // Remove orphaned meal_items whose meal no longer exists (FK was off before v7).
  await db.execute(
    'DELETE FROM meal_items WHERE meal_id NOT IN (SELECT id FROM meals)',
  );
  // Remove orphaned recipe_items.
  await db.execute(
    'DELETE FROM recipe_items WHERE recipe_id NOT IN (SELECT id FROM recipes)',
  );
  // Clear dangling recipe references on meals.
  await db.execute(
    'UPDATE meals SET recipe_id = NULL '
    'WHERE recipe_id IS NOT NULL '
    'AND recipe_id NOT IN (SELECT id FROM recipes)',
  );
```

**Step C — verify cascade is declared.**  
Grep `CREATE TABLE meal_items` and `recipe_items` — confirm `REFERENCES meals(id) ON DELETE CASCADE` is present. If any `ON DELETE` clause is missing, add it in the v7 migration with `DROP TABLE` + re-create (or accept that FK is now enforced going forward and the constraint is logical only).

**Done when:** calling `deleteMeal` on a record that has 3 `meal_items` leaves zero rows in `meal_items` for that `meal_id`.

---

### 1.3 Wrap compound writes in transactions + use Batch for item loops

**Files:** `core/database/meals_repository.dart`, `core/database/recipes_repository.dart`  
**Effort:** S → §4.2, §6.5

**Pattern for each compound write — example `insertMeal`:**

```dart
Future<int> insertMeal(Meal meal) async {
  final db = await AppDatabase.instance.mealsDb;
  return db.transaction((txn) async {
    final id = await txn.insert('meals', meal.toMap()..remove('id'));
    final batch = txn.batch();
    for (final item in meal.items) {
      batch.insert('meal_items', item.copyWith(mealId: id).toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
    await txn.insert('meals_fts', {'rowid': id, 'name': meal.name, 'notes': meal.notes ?? ''});
    return id;
  });
}
```

Apply the same pattern to:
- `updateMeal` (update + delete items + re-insert + FTS update)
- `deleteMeal` (if FK is now ON, items cascade; only FTS cleanup needs explicit delete)
- `insertRecipe` / `updateRecipe` / `deleteRecipe`

**Done when:** killing the process in the middle of an `insertMeal` (debug breakpoint mid-loop) leaves either the complete meal or nothing — no partial rows.

---

### 1.4 Disable Android auto-backup for SharedPreferences

**File:** `android/app/src/main/AndroidManifest.xml`  
**Effort:** XS → §3.2

Add to the `<application>` element:

```xml
android:allowBackup="false"
android:dataExtractionRules="@xml/data_extraction_rules"
android:fullBackupContent="@xml/backup_rules"
```

Create `android/app/src/main/res/xml/data_extraction_rules.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="sharedpref" path="."/>
  </cloud-backup>
  <device-transfer>
    <exclude domain="sharedpref" path="."/>
  </device-transfer>
</data-extraction-rules>
```

Create `android/app/src/main/res/xml/backup_rules.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
  <exclude domain="sharedpref" path="."/>
</full-backup-content>
```

**Optional upgrade (same session):** Return the Gemini key to `flutter_secure_storage` — the package is already in `pubspec.yaml`. In `settings_screen.dart`, replace the `SharedPreferences.setString('geminiApiKey', ...)` path with `FlutterSecureStorage().write(key: 'geminiApiKey', value: ...)`. In `providers.dart`, update `geminiApiKeyProvider` to read from secure storage. The migration-away code in `settings_screen.dart` (lines 62-77) can then be deleted.

**Done when:** `adb backup` of the app produces an archive that does not contain the SharedPreferences XML.

---

## Phase 2 — High-severity correctness bugs

These are functional correctness fixes. One PR per sub-item is reasonable; they have no interdependencies.

---

### 2.1 Local-time day bucketing in all aggregate queries

**File:** `core/database/meals_repository.dart`  
**Effort:** S → §4.3

Every `strftime` that currently groups meals by day uses UTC because `datetime(col/1000, 'unixepoch')` defaults to UTC. Append `'localtime'` as a third argument to all such calls.

**Affected query methods and their current pattern → fixed pattern:**

| Method | Line (approx.) | Current | Fix |
|--------|----------------|---------|-----|
| `getAvgDailyKcal` | ~340 | `datetime(created_at/1000, 'unixepoch')` | `datetime(created_at/1000, 'unixepoch', 'localtime')` |
| `getAvgDailyMacros` | ~358 | same | same |
| `getDaysOverGoal` | ~392 | same | same |
| `getDaysWithMeals` | ~425 | same | same |
| `getCurrentStreak` | ~438 | same | same |

Also fix the off-by-one in day range queries (§4.9): replace `BETWEEN :start AND :end` where `end = '23:59:59'` with `created_at >= :start AND created_at < :nextDayStart`, where `nextDayStart` is the start of the following day in milliseconds.

**Done when:** a meal logged at 23:30 Swiss time (22:30 UTC) is counted on the correct local calendar day in every aggregate (streak, daily average, "days over goal").

---

### 2.2 Fix add-ingredient sheet: own state + debounce

**File:** `features/recipes/recipe_editor_screen.dart`  
**Effort:** S → §5.1, §6.6

The root cause: `_showAddIngredientSheet` passes mutable state from the parent screen into a stateless widget; the parent's `setState` never re-runs the sheet's builder.

**Fix:** Extract `_AddIngredientSheet` into a `ConsumerStatefulWidget` that owns its own search state.

```dart
class _AddIngredientSheet extends ConsumerStatefulWidget {
  final void Function(SfcdFood food) onAdd;
  const _AddIngredientSheet({required this.onAdd});
  @override
  ConsumerState<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<_AddIngredientSheet> {
  final _queryCtrl = TextEditingController();
  List<SfcdFood> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _queryCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final results = await ref.read(sfcdServiceProvider).search(q.trim());
      if (mounted) setState(() { _results = results; _searching = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... move the existing sheet UI here, reading _results / _searching from own state
  }
}
```

Also fix the missing SFCD connection cache (§6.6) while in this area — see §3.5 of this plan.

**Done when:** typing "zucchini" in the add-ingredient sheet shows SFCD search results within ~400 ms.

---

### 2.3 Stable keys + `didUpdateWidget` in `IngredientCard`

**File:** `features/results/ingredient_card.dart`, `features/results/results_screen.dart`, `features/history/meal_detail_screen.dart`  
**Effort:** S → §5.2

**Step A — stable keys.**  
In every place `IngredientCard` is rendered in a list, key by the item's stable identity, not position:

```dart
// Before
ValueKey('item_$i')
// After
ValueKey(item.id ?? item.hashCode)  // id is non-null after DB round-trip; hashCode covers new items
```

Apply same fix to `meal_detail_screen.dart` and `meal_edit_screen.dart` if they key by index.

**Step B — `didUpdateWidget` to resync controllers.**  
In `_IngredientCardState`, add:

```dart
@override
void didUpdateWidget(IngredientCard old) {
  super.didUpdateWidget(old);
  if (widget.item.name != old.item.name) _nameCtrl.text = widget.item.name;
  if (widget.item.weightG != old.item.weightG) {
    _weightCtrl.text = widget.item.weightG.toStringAsFixed(0);
  }
  if (widget.item.kcalPer100g != old.item.kcalPer100g) {
    _kcalCtrl.text = widget.item.kcalPer100g.toStringAsFixed(0);
  }
  if (widget.item.proteinPer100g != old.item.proteinPer100g) {
    _proteinCtrl.text = _fmt(widget.item.proteinPer100g);
  }
  if (widget.item.carbsPer100g != old.item.carbsPer100g) {
    _carbsCtrl.text = _fmt(widget.item.carbsPer100g);
  }
  if (widget.item.fatPer100g != old.item.fatPer100g) {
    _fatCtrl.text = _fmt(widget.item.fatPer100g);
  }
}
```

**Done when:** deleting item 0 of [A, B, C] shows [B, C] with correct text field values in both the results screen and the edit screen.

---

### 2.4 WAL checkpoint before backup; clean sidecars on restore; fix `clearHistory`

**Files:** `core/services/backup_service.dart`, `features/settings/settings_screen.dart`  
**Effort:** S → §4.4, §4.5

**`createBackup`:** Before zipping the DB file, issue a WAL checkpoint so the `.db` file is self-contained:

```dart
Future<void> createBackup(String destPath) async {
  final db = await AppDatabase.instance.mealsDb;
  await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  // now zip fork_scale.db — WAL is empty, backup is complete
  ...
}
```

**`restoreBackup`:** After closing connections and before opening the new DB, delete stale WAL sidecars:

```dart
await AppDatabase.closeAll();
// delete old WAL/SHM so SQLite doesn't replay them against the restored file
for (final ext in ['-wal', '-shm']) {
  final f = File('${dbPath}$ext');
  if (await f.exists()) await f.delete();
}
// now overwrite dbPath with restored file, then re-open
```

**`clearHistory` in `settings_screen.dart`:** Replace the current delete-and-snackbar with a proper teardown:

```dart
Future<void> _clearHistory() async {
  await AppDatabase.closeAll();
  final dbFile = File(dbPath);
  if (await dbFile.exists()) await dbFile.delete();
  for (final ext in ['-wal', '-shm']) {
    final f = File('$dbPath$ext');
    if (await f.exists()) await f.delete();
  }
  // Invalidate all providers that hold meal data so screens reload from the new empty DB.
  ref.invalidate(historyMealsProvider);
  ref.invalidate(historyDayTotalProvider);
  ref.invalidate(historyWeeklyKcalProvider);
  ref.invalidate(mealsRepositoryProvider); // forces DB re-open
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('History cleared.')),
  );
}
```

Remove the "Restart the app" snackbar text. → §8.1

**Done when:** "Clear history" immediately shows an empty History tab without a restart; backup of a WAL-heavy DB restores without missing recent entries.

---

### 2.5 Move API key to HTTP header

**File:** `core/services/gemini_service.dart`  
**Effort:** XS → §3.3

Locate the two URL constructions that append `?key=$apiKey`:

```dart
// Before
Uri.parse('${_baseUrl}/models/$model:generateContent?key=$apiKey')

// After — use header instead
Uri.parse('${_baseUrl}/models/$model:generateContent')
// and in the request headers map:
headers: {
  'Content-Type': 'application/json',
  'x-goog-api-key': apiKey,
},
```

**Done when:** network traffic capture shows no `key=` parameter in the URL.

---

## Phase 3 — Architecture & performance

These deliver measurable runtime improvements and reduce future bug surface. Recommended order: 3.1 → 3.2 → 3.3 → 3.4 (each is independent after 3.1 lays the notification foundation).

---

### 3.1 Repository change-notification — eliminate manual invalidation web

**Files:** `core/database/meals_repository.dart`, `core/services/providers.dart`, all feature files that call `ref.invalidate(...)`  
**Effort:** M → §7.1, §5.5

**Goal:** any write to `MealsRepository` automatically makes all read providers refetch — no call site needs to remember which providers to invalidate.

**Step A — add a revision counter to `MealsRepository`.**

```dart
// In MealsRepository
int _revision = 0;
int get revision => _revision;
void _bump() => _revision++;
```

Call `_bump()` at the end of every write method (`insertMeal`, `updateMeal`, `deleteMeal`, `insertRecipe`, `updateRecipe`, `deleteRecipe`).

**Step B — expose the revision as a provider.**

```dart
// providers.dart
final mealsRevisionProvider = StateProvider<int>((ref) => 0);
```

In `MealsRepository`, after bumping, fire through a provided callback. The cleanest approach without restructuring the repository is to make the repository an observable: replace the `StateProvider` with a `StreamProvider` backed by a `StreamController` in `MealsRepository`, or simply wire the bump to invalidate via a `ProviderContainer` reference injected at construction.

**Simplest viable approach (no DI restructuring):** after each write, broadcast on a `StreamController.broadcast()` stored on the repository:

```dart
// MealsRepository
final _changeStream = StreamController<void>.broadcast();
Stream<void> get changes => _changeStream.stream;
void _bump() => _changeStream.add(null);
```

```dart
// providers.dart — replaces the three history providers' invalidation pattern
final _mealsChangeProvider = StreamProvider<void>((ref) {
  return ref.read(mealsRepositoryProvider).changes;
});

final historyMealsProvider = FutureProvider.autoDispose.family<...>((ref, args) async {
  ref.watch(_mealsChangeProvider); // re-runs on any write
  return ref.read(mealsRepositoryProvider).getMeals(...);
});
```

**Step C — remove all manual `ref.invalidate(historyMealsProvider)` etc. calls** from: `log_portion_sheet.dart`, `results_screen.dart`, `barcode_result_screen.dart`, `barcode_meal_builder_screen.dart`, `meal_detail_screen.dart`, `capture_screen.dart`. Replace with nothing — the stream handles it.

**Done when:** logging a meal from the Capture tab causes the History tab's meal list to show the new entry on next tab-switch, with no `ref.invalidate` call anywhere in the logging path.

---

### 3.2 Eliminate N+1 queries

**Files:** `core/database/meals_repository.dart`, `core/database/recipes_repository.dart`  
**Effort:** S → §6.1, §6.2

**`getMeals` fix:**

```dart
Future<List<Meal>> getMeals({...}) async {
  final db = await AppDatabase.instance.mealsDb;
  final mealRows = await db.query('meals', ...);
  if (mealRows.isEmpty) return [];

  final ids = mealRows.map((r) => r['id'] as int).toList();
  final placeholders = List.filled(ids.length, '?').join(',');
  final itemRows = await db.rawQuery(
    'SELECT * FROM meal_items WHERE meal_id IN ($placeholders) ORDER BY sort_order',
    ids,
  );

  final itemsByMeal = <int, List<MealItem>>{};
  for (final row in itemRows) {
    final mid = row['meal_id'] as int;
    itemsByMeal.putIfAbsent(mid, () => []).add(MealItem.fromMap(row));
  }

  return mealRows.map((row) {
    final id = row['id'] as int;
    return Meal.fromMap(row, items: itemsByMeal[id] ?? []);
  }).toList();
}
```

Apply the same `IN (?)` pattern to:
- `_searchMeals`: fetch all hit IDs from FTS, then one `IN` query for items.
- `getAllRecipes` in `recipes_repository.dart`.
- `exportCsv` (join meals + items in SQL rather than N+1 Dart loops).

**`getWeeklyKcal` fix (§6.2):**

```dart
Future<List<double>> getWeeklyKcal() async {
  final db = await AppDatabase.instance.mealsDb;
  // Build 7-day window
  final now = DateTime.now();
  final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));
  final startMs = days.first.millisecondsSinceEpoch;
  final endMs = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;

  final rows = await db.rawQuery('''
    SELECT strftime('%Y-%m-%d', datetime(created_at/1000, 'unixepoch', 'localtime')) AS day,
           SUM(total_kcal) AS kcal
    FROM meals
    WHERE created_at >= ? AND created_at < ?
    GROUP BY day
  ''', [startMs, endMs]);

  final totals = {for (final r in rows) r['day'] as String: (r['kcal'] as num).toDouble()};
  return days.map((d) {
    final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    return totals[key] ?? 0.0;
  }).toList();
}
```

**Done when:** a `flutter test` integration test (ffi sqlite) loading 50 meals shows `getMeals` issuing exactly 2 DB queries (meals + items); `getWeeklyKcal` issues 1.

---

### 3.3 Image pipeline: single decode per capture + thumbnail cache hints

**Files:** `features/capture/capture_screen.dart`, `features/history/history_screen.dart`  
**Effort:** S → §6.3, §6.4

**Single decode per capture:**

Currently `resizeForApi` and `saveForHistory` each call `img.decodeImage(bytes)` on the same source JPEG. Refactor `ImageService` to expose a method that accepts an already-decoded `img.Image` and does only the encode step, or introduce a small pipeline:

```dart
// In ImageService
Future<({Uint8List apiBytes, String historyPath})> processCapture(
  Uint8List sourceJpeg,
  String savePath,
) async {
  final decoded = await compute(_decodeImage, sourceJpeg); // decode once in isolate
  final apiBytes = await compute(_encodeForApi, decoded);  // resize to 1536
  await compute(_encodeForHistory, _EncodeParams(decoded, savePath)); // resize to 1200
  return (apiBytes: apiBytes, historyPath: savePath);
}
```

**Thumbnail cache hints in history list:**

```dart
// Before
Image.file(file, width: 56, height: 56)

// After
Image.file(
  file,
  width: 56,
  height: 56,
  cacheWidth: 112,   // 2× for typical DPR; Flutter scales down in the image cache
  cacheHeight: 112,
  fit: BoxFit.cover,
)
```

Apply the same `cacheWidth`/`cacheHeight` to recipe card thumbnails and any other place a large file is rendered at a small display size.

**Done when:** scrolling the history list does not trigger decoder jank; the Dart DevTools memory timeline shows image cache size stabilized rather than growing with list length.

---

### 3.4 Cache SFCD database connection; debounce search in editor

**Files:** `core/database/app_database.dart`, `features/recipes/recipe_editor_screen.dart`  
**Effort:** S → §6.6

**Cache the SFCD connection** (same pattern as `usdaDb`):

```dart
// app_database.dart
Database? _sfcdDb;

Future<Database> get sfcdDb async {
  if (_sfcdDb != null) return _sfcdDb!;
  // ... existing copy-from-assets logic ...
  _sfcdDb = await openDatabase(sfcdPath, readOnly: true);
  return _sfcdDb!;
}

// Add to closeAll():
await _sfcdDb?.close();
_sfcdDb = null;
```

**Debounce** is handled in §2.2 (the `_AddIngredientSheet` rewrite). If search is also called elsewhere, add the same 300 ms `Timer`-based debounce pattern.

**Done when:** typing a 7-character query in the ingredient sheet opens the SFCD database exactly once (checked by adding a temporary `print` in `openSfcdDb`); the debounce means at most 1 active query per 300 ms of typing.

---

## Phase 4 — Design debt reduction

These are higher-effort refactors that pay down the duplication and modeling debt. Do them in separate PRs; they have no interdependencies.

---

### 4.1 Fix `copyWith` null-trap — adopt explicit nullable sentinel

**Files:** `models/meal.dart`, `models/meal_item.dart`, `models/recipe.dart`, `models/recipe_item.dart`  
**Effort:** M → §4.6

**Option A (recommended — no new dependency):** Replace `field: x ?? this.field` with an `Optional<T>` / absent-sentinel pattern:

```dart
// Define once in lib/core/utils/optional.dart
class Absent<T> {
  const Absent();
}
const _absent = Absent();

// In Meal.copyWith:
Meal copyWith({
  Object? notes = _absent,
  ...
}) {
  return Meal(
    notes: notes == _absent ? this.notes : notes as String?,
    ...
  );
}
```

**Option B:** Adopt `freezed`. Given `riverpod_generator` is already an unused dependency, this may be the right time to either commit to codegen or remove it (§5.1 of this plan removes the unused dep). `freezed` requires `build_runner` which is already listed.

Whichever option is chosen, apply it to all four model classes and delete `_emitMacros` workarounds in `IngredientCard` and `_IngredientRow` once `copyWith(fieldX: null)` works correctly.

**Done when:** `meal.copyWith(notes: null)` returns a meal with `notes == null`; the "clear notes" path in `MealEditScreen` persists a null notes column.

---

### 4.2 Extract shared widgets

**New file:** `widgets/meal_type_selector.dart`, `widgets/amount_stepper.dart`, `widgets/ingredient_editor.dart`  
**Effort:** M → §7.3

**`MealTypeSelector`** — replaces the 5 inline `_MealTypeRow` / meal-type chip `Wrap` copies in:
- `results_screen.dart`
- `meal_edit_screen.dart`
- `barcode_result_screen.dart`
- `barcode_meal_builder_screen.dart`
- `log_portion_sheet.dart`

```dart
class MealTypeSelector extends StatelessWidget {
  final String? current;
  final ValueChanged<String> onChanged;
  const MealTypeSelector({super.key, required this.current, required this.onChanged});
  // single canonical implementation
}
```

**`AmountStepper`** — replaces the 4 diverging ± button + text field combos.

**`IngredientEditor`** — the big one. `_IngredientRow` (recipe editor) and `IngredientCard` (results) are the same component over different model types. Define a thin `IngredientData` interface (or use `({String name, double weightG, double kcalPer100g, ...})`) and implement one stateful widget. This also centralizes the `didUpdateWidget` fix from §2.3 and the `_emitMacros` fix from §4.1.

Deduplicate `_mealTypeLabel`, `_PhotoHeader`, `_autoName` helpers the same way.

**Done when:** `grep -r "_MealTypeRow\|MealTypeChips"` returns only the definition; all five call sites use `MealTypeSelector`.

---

### 4.3 Replace stringly-typed domain values with enums

**Files:** `models/meal.dart`, `models/meal_item.dart`, `core/services/gemini_service.dart`, `core/router/app_router.dart`, all switch-on-string sites  
**Effort:** S → §7.4

Define enums:

```dart
enum MealType { breakfast, lunch, snack, dinner }
enum Utensil { fork, knife, spoon }
enum MealSource { camera, barcode, recipePortion, manual }
enum FoodSource { usda, swissFcd, openFoodFacts, ai, manual }
```

Use `enumValue.name` for DB serialization and `MealType.values.byName(str)` for deserialization with a safe fallback. Search for every `switch`/`if` on the raw string and replace. The DB stores strings, so this is backward-compatible without a migration.

**Done when:** `grep "'breakfast'\|'barcode'\|'recipe_portion'\|'fork'"` returns zero hits in `lib/` (excluding test fixtures and DB column values that come from `enum.name`).

---

### 4.4 Persist `usdaMatched` flag

**Files:** `models/meal_item.dart`, `core/database/app_database.dart`  
**Effort:** S → §4.7

Add a DB migration (v8 if following the sequence above):

```sql
ALTER TABLE meal_items ADD COLUMN usda_matched INTEGER NOT NULL DEFAULT 0;
```

Add `'usda_matched': usdaMatched ? 1 : 0` to `MealItem.toMap()` and parse `(row['usda_matched'] as int? ?? 0) == 1` in `MealItem.fromMap`.

**Done when:** an item matched by `GeminiService._parseAndEnrich` shows the USDA-verified state (no flask icon) after the app is killed and reopened.

---

## Phase 5 — Quality, safety nets, and polish

These are lower-urgency but compound over time. Tackle after Phase 3 is merged.

---

### 5.1 Remove dead code and unused dependencies

**Files:** `pubspec.yaml`, `features/settings/settings_screen.dart`, `features/results/results_screen.dart`, `core/services/providers.dart`  
**Effort:** XS → §5.4, §5.8, §7.5

- Remove `riverpod_annotation`, `riverpod_generator`, `build_runner` from `pubspec.yaml` if the decision is to not use codegen (they add 30+ MB to build tools and hide intent). If codegen is desired, migrate at least one provider to demonstrate the pattern.
- Remove the dead Pepesto settings section from `settings_screen.dart`: the API key field, `pepestoApiKeyProvider`, and the `price_chf` write path. (Either ship the feature or remove it cleanly.)
- Remove the dead `ProviderScope` override in `results_screen.dart` and the throw-stub `resultsNotifierProvider` fallback.
- Delete the placeholder comment in `capture_controller.dart` or move the orchestration logic there.

---

### 5.2 Fix orphaned photos on analysis failure

**File:** `features/capture/capture_screen.dart`  
**Effort:** XS → §5.6

In the error branches of `_analyse` where no meal is saved, delete the already-written history photo:

```dart
// In the catch / non-retryable failure blocks:
if (_pendingSavedPath != null) {
  await ImageService().deletePhoto(_pendingSavedPath!);
  _pendingSavedPath = null;
}
```

**Done when:** 10 consecutive "Cancel" / forced-error runs accumulate zero extra files in the `meal_photos` directory.

---

### 5.3 Fix settings screen controller and storage scan

**File:** `features/settings/settings_screen.dart`  
**Effort:** XS → §5.7

- Move the daily-goal `TextEditingController` to `initState` (and dispose in `dispose`) as a `late final`.
- Wrap `_storageSummary()` in a `FutureProvider` or compute it once in `initState`, storing the result in state — not inline in `build`.

---

### 5.4 Fix CSV export

**File:** `core/database/meals_repository.dart`  
**Effort:** S → §3.5, §8.5

Add missing columns (name, notes, macros) to the CSV output. Sanitize formula injection:

```dart
String _escapeCsv(String? v) {
  if (v == null) return '';
  final s = v.replaceAll('"', '""');
  // Excel formula injection guard
  if (s.isNotEmpty && '=+-@'.contains(s[0])) return '"\'$s"';
  return s.contains(',') || s.contains('"') || s.contains('\n') ? '"$s"' : s;
}
```

---

### 5.5 FTS query safety

**File:** `core/database/meals_repository.dart`  
**Effort:** XS → §3.6

Wrap user input before interpolating into the FTS MATCH query:

```dart
String _ftsEscape(String q) {
  // Remove FTS4 operator characters; wrap in double-quotes for phrase search
  final cleaned = q.replaceAll(RegExp(r'["\(\)\*:^]'), '');
  return '"$cleaned"';
}
// Usage:
'MATCH ?', [_ftsEscape(query)]
```

---

### 5.6 Add repository + parsing unit tests

**Files:** `test/`  
**Effort:** M → §9

Use `sqflite_common_ffi` for in-memory integration tests. Priority test targets:

1. **`MealsRepository` day boundaries and streak logic** — seed meals at UTC+1 boundary times, assert streak counts and day totals are correct.
2. **`MealsRepository` FK cascade** — after Phase 1.2, assert `deleteMeal` leaves zero orphan items.
3. **`GeminiService._repairTruncated`** — test known truncation patterns (unclosed array, unclosed string, unclosed object).
4. **`ResultsNotifier.deleteItem`** — assert `editedIndices` remaps correctly after deletion at positions 0, middle, last.
5. **`Meal.detectTypeFromTime`** — boundary hours (05:59 → null?, 06:00 → breakfast, etc.).

```dart
// Example test setup
setUpAll(() { sqfliteTestInit(); });

test('deleteMeal removes meal_items via cascade', () async {
  final db = await AppDatabase.instance.mealsDb; // uses in-memory ffi DB
  final repo = MealsRepository();
  final id = await repo.insertMeal(Meal(..., items: [MealItem(...), MealItem(...)]));
  await repo.deleteMeal(id);
  final orphans = await db.query('meal_items', where: 'meal_id = ?', whereArgs: [id]);
  expect(orphans, isEmpty);
});
```

---

### 5.7 Accessibility minimum pass

**Files:** `features/results/ingredient_card.dart`, `features/history/history_screen.dart`, `features/capture/capture_screen.dart`  
**Effort:** M → §8.2

Minimum viable:
- Replace bare `GestureDetector` on `_StepButton` with `IconButton` (inherits 48dp minimum touch target and `Semantics`).
- Add `Semantics(label: ...)` wrappers around emoji-only interactive widgets (meal-type chip emojis, streak display).
- Add `semanticLabel` to `Icon` and `IconButton` calls that currently omit it.

---

## Dependency map

```
Phase 1 (all items independent)
  ↓
Phase 2.1 (UTC fix) — independent
Phase 2.2 (sheet state) — independent; feeds Phase 3.4 (debounce is done here)
Phase 2.3 (stable keys) — independent; feeds Phase 4.2 (IngredientEditor rewrite)
Phase 2.4 (WAL/clearHistory) — independent
Phase 2.5 (header key) — independent
  ↓
Phase 3.1 (change-notification) — do first; 3.2-3.4 are independent of it
Phase 3.2 (N+1) — independent
Phase 3.3 (image pipeline) — independent
Phase 3.4 (SFCD cache) — after 2.2 (debounce is already there)
  ↓
Phase 4.1 (copyWith) — prerequisite for removing _emitMacros in Phase 4.2
Phase 4.2 (shared widgets) — after 2.3, after 4.1
Phase 4.3 (enums) — independent
Phase 4.4 (persist usdaMatched) — independent
  ↓
Phase 5 (all independent of each other; 5.6 tests benefit from Phases 1-4 being done)
```

---

## Risk register

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| FK migration + orphan cleanup corrupts data for users with existing installs | Low | Run cleanup in a transaction; test on a copy of a real DB before rolling out. |
| `wal_checkpoint(TRUNCATE)` blocks briefly under write load | Very low (single-user app) | Checkpoint is on user-initiated backup, not background. |
| `copyWith` sentinel pattern breaks existing call sites | Medium | After change, run `flutter analyze` + full app smoke-test; failing call sites are compile errors. |
| Stream-based invalidation over-fires, causing visible flicker | Low | Providers already show `valueOrNull` fallback while loading; brief flicker on write is acceptable. |
| Removing Pepesto UI loses work-in-progress code | Low | Code stays in git history; grep for `pepesto` before deleting to confirm nothing is live. |

---

## Definition of done (per phase)

- `flutter analyze` reports zero issues.
- The specific "Done when" criteria in each item are met.
- No regression in any feature exercised by a manual smoke-test of: capture → results → save → history → detail → edit → re-save → delete.
- Phase 1: additionally verified by the backup/restore round-trip test described in §1.2 and §2.4.
- Phase 5.6: all added tests pass with `flutter test`.
