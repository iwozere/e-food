# Known Issues & Fixes

---

## 2026-05-18 — History list and daily chart not updated after editing a meal

**Description:**
After tapping a meal in History, opening the edit screen, changing weight or calories, and saving, the Meal Detail screen correctly reflected the new values. However, the History list tile still showed the old calorie count, and the day summary bar and weekly bar chart were also unchanged.

**Root cause:**
`_MealTile.onTap` called `context.push('/history/${meal.id}')` without `await`, so control never returned to `HistoryScreen` in a way that triggered any refresh. The three providers that drive the History screen — `_mealsProvider` (the list), `_dayTotalProvider` (the day banner), and `_weeklyKcalProvider` (the chart) — were never invalidated after returning from the detail/edit flow. The `onRefresh` callback passed to `_MealList` also only invalidated `_mealsProvider`, leaving the other two stale regardless.

**Solution:**
- In `_MealTile.build`, changed `onTap` from `() => context.push(...)` to an async lambda that `await`s the push and then calls `onRefresh()` when the screen returns.
- In `HistoryScreen`, expanded the `onRefresh` callback passed to `_MealList` to invalidate all three providers: `_mealsProvider`, `_dayTotalProvider`, and `_weeklyKcalProvider`.

---

---

## 2026-05-18 — Recipe detail: no visible way to edit ingredients; edits appear lost on return

**Description:**
Opening a recipe from the Recipes tab showed the ingredients as completely read-only list items with no affordance to add, delete, or change any values (name, weight, kcal/100g). The only edit entry point was a small pencil icon in the AppBar, which was easy to miss. Additionally, even when the user did find the AppBar icon and made changes in the Recipe Editor, returning to the detail screen showed the old recipe — making edits appear to have had no effect.

**Root cause:**
Two independent issues:

1. **Stale data on return**: `context.push('/recipes/$recipeId/edit')` in the AppBar action was not awaited and never called `ref.invalidate(_recipeProvider(recipeId))`. Because `_recipeProvider` is `FutureProvider.autoDispose.family` and the detail screen stayed alive during the edit, it retained its cached pre-edit value and never re-fetched.

2. **Discoverability**: `_RecipeDetail` rendered ingredients as plain read-only `ListTile`s. The only edit entry point was a small icon in the AppBar with no corresponding affordance in the scrollable body.

**Solution:**
- In `RecipeDetailScreen`, changed the AppBar edit button `onPressed` to `await context.push(...)` followed by `ref.invalidate(_recipeProvider(recipeId))`, so the provider re-fetches fresh data when the editor is dismissed.
- Added `onEdit` callback to `_RecipeDetail` and placed a prominent **"Edit recipe"** `OutlinedButton` alongside the existing "Log a portion" button at the bottom of the detail body — same callback, so both the AppBar icon and the body button invalidate the provider on return.

---

## 2026-05-18 — "Contribute to Open Food Facts" does nothing; "Enter manually" crashes

**Description:**
When scanning a barcode that doesn't exist in the database, the "Product not found" screen appeared. Two actions on that screen were broken:
1. **"Contribute to Open Food Facts"** — tapping it showed a plain snackbar with a URL string instead of opening the browser.
2. **"Enter manually"** — tapping it caused the error *"Page not found: GoException: no routes for location /barcode-result-manual"* because that route was never defined or implemented.

**Solution:**

Bug 1 — Added `import 'package:url_launcher/url_launcher.dart'` (package already in `pubspec.yaml`) and replaced the snackbar with `launchUrl(uri, mode: LaunchMode.externalApplication)` pointing to `https://world.openfoodfacts.org/product/{barcode}`.

Bug 2 — Rather than adding a new route (and screen file) for `/barcode-result-manual`, converted `_NotFoundScreen` from a `StatelessWidget` to a `ConsumerStatefulWidget` that manages a `_showForm` boolean. "Enter manually" now toggles inline to a manual-entry form (product name, kcal/100g, amount stepper, meal-type chips, "Log this meal" button) within the same screen — no router change required. Saving calls `MealsRepository.insertMeal` and navigates to history.

---

## 2026-05-18 — Pending meal shows stale data (still pending, no items) after "Analyze now" → Save

**Description:**
After tapping "Analyze now" on a pending meal, completing analysis, and saving on the Results screen, the Meal Detail screen showed "Pending Meal" with no items — as if the save had no effect.

**Root cause:**
Two compounding issues:

1. `_mealProvider` is `FutureProvider.autoDispose.family`. The "Analyze now" flow pushed `/results` on top of the existing `MealDetailScreen`. After saving, the code navigated with `context.go('/history')` + `context.push('/history/$pendingId')`, which destroyed the old `MealDetailScreen` and created a new one. However, because go_router defers widget disposal to the next frame, the old `MealDetailScreen` was still alive when the new one started watching `_mealProvider(pendingId)`. Riverpod's `autoDispose` therefore kept the provider alive with its **stale cached value** (`pending=true`, no items), which the new screen consumed.

2. Creating an entirely new `MealDetailScreen` for the same meal ID is the wrong navigation pattern — the original screen is still on the stack and should simply be refreshed.

**Solution:**
- In `meal_detail_screen.dart`: changed `context.push('/results', ...)` to `await context.push(...)` so control returns to the **existing** `MealDetailScreen` when the results screen is dismissed. Added `ref.invalidate(_mealProvider(widget.mealId))` in the `finally` block so the provider re-fetches fresh data from the DB on return (covering both the "saved" and "back without saving" paths).
- In `results_screen.dart`: for the pending-meal save path, replaced `context.go('/history'); context.push('/history/$pendingId')` with a simple `context.pop()`. This returns to the already-existing `MealDetailScreen`, which then picks up the invalidation and re-fetches the now-analyzed meal.

---

## 2026-05-18 — Back button broken on Meal Detail after saving a meal

**Description:**
After taking a photo (without a utensil), analyzing it, and tapping "Save meal" on the Results screen, the app navigated to the Meal Detail screen. The back arrow in the top-left did nothing — the user was stuck with no way to leave the screen. The same issue occurred after "Copy to today" in Meal Detail.

**Root cause:**
`_saveMeal` in `results_screen.dart` and `_copyToToday` in `meal_detail_screen.dart` used `context.go('/history/$id')` to navigate after saving. In go_router, `context.go` replaces the entire navigation stack. Because `/history/:id` is declared as a top-level route outside the `StatefulShellRoute`, the resulting stack contained only the Meal Detail screen with nothing underneath it. `context.pop()` in the back button had nowhere to navigate to.

**Solution:**
Replaced `context.go('/history/$id')` with a two-step navigation in both locations:
```dart
context.go('/history');       // activate the History shell branch
context.push('/history/$id'); // push the detail on top
```
This leaves the History tab as the back destination, so the back button correctly returns the user to the meal history list.

---

## 2026-05-18 — New recipe not saved (list not refreshed)

**Description:**
Creating a new recipe via "New recipe" → filling in photo, title, yield → tapping Save appeared to do nothing. The recipe was actually written to the database correctly, but the Recipes list screen showed stale data because `_recipesProvider` (a `FutureProvider.autoDispose`) retained its cached value while the editor screen was on top. On returning, no re-fetch was triggered.

**Solution:**
In `recipes_screen.dart`, changed all `context.push('/recipes/new')` and `context.push('/recipes/:id/edit')` call sites to `await` the navigation and then call `ref.invalidate(_recipesProvider)` on return. Also passed a `onNewRecipe` callback down to `_EmptyState` so the same invalidation fires from the empty-state button. The edit action in `_RecipeCard._showContextMenu` was updated similarly (was missing `onRefresh()` entirely).

---

## 2026-05-18 — Barcode scan from recipe editor: scanned ingredient never added (result lost)

**Description:**
Opening a new or existing recipe, tapping "Add item" → "Scan barcode", scanning a product, adjusting the amount, and tapping "Add to recipe" had no effect — the ingredient did not appear in the recipe editor.

**Root cause:**
`RecipeEditorScreen` calls `context.push<Map?>('/scan', extra: {'forRecipe': true}).then((result) { _addIngredient(...) })`. It correctly waits for the `/scan` push to complete with ingredient data. However, `BarcodeScannerScreen._onDetect` forwarded to the result screen via `context.pushReplacement('/barcode-result', ...)`. `pushReplacement` removes `/scan` from the navigation stack immediately, which causes go_router to complete the `push('/scan')` Future with `null` right away. The `.then(result)` callback ran with `result == null`, so `_addIngredient` was never called. Later, when `BarcodeResultScreen` called `context.pop(data)`, there was no pending `push` listener to receive that data.

**Solution:**
Replaced the `context.pushReplacement` call in `BarcodeScannerScreen._onDetect` with a new async method `_navigateToResult` that uses `context.push('/barcode-result', ...)` and then calls `context.pop(result)` to forward the return value back to the original `/scan` push. This keeps `/scan` alive in the stack while the result screen is shown, so when the result screen pops with ingredient data, the scanner receives it and propagates it back to `RecipeEditorScreen`.

---

## 2026-05-18 — Barcode scan from recipe editor adds ingredient to new recipe instead of the one being edited

**Description:**
When editing an existing recipe, tapping "Add item" → "Scan barcode", scanning a product, adjusting the amount, and tapping "Add to recipe" did not add the ingredient to the open recipe. Instead, it opened a brand-new recipe editor pre-filled with the scanned product — discarding all context of the recipe being edited.

**Root cause:**
Three independent gaps in the navigation chain:

1. `RecipeEditorScreen._showAddIngredientSheet` called `context.push('/scan')` without passing any context and ignored the return value (`.then((_) { })` was a no-op). There was no way for the scan flow to communicate back to the editor.

2. `BarcodeScannerScreen` always called `context.pushReplacement('/barcode-result', extra: raw)` with a plain String, with no flag to indicate the caller's intent.

3. `BarcodeResultScreen`'s "Add to recipe" button always navigated to `/recipes/new`, regardless of how the screen was reached.

**Solution:**
Threaded a `forRecipe` boolean through the entire navigation chain:

- `RecipeEditorScreen.onScanBarcode`: changed from a no-op `.then()` to `context.push<Map<String,dynamic>?>('/scan', extra: {'forRecipe': true}).then((result) { _addIngredient(...) })`. Also extended `_addIngredient` to accept an optional `weightG` parameter so the scanned amount is preserved.
- `BarcodeScannerScreen`: added `final bool forRecipe` parameter; forwards it in `pushReplacement('/barcode-result', extra: {'barcode': raw, 'forRecipe': forRecipe})`.
- `BarcodeResultScreen`: added `final bool forRecipe` parameter; "Add to recipe" now calls `context.pop({'name', 'kcalPer100g', 'weightG', 'barcode'})` when `forRecipe` is true, otherwise navigates to `/recipes/new` as before.
- `_NotFoundScreen`: same `forRecipe` flag; the manual-entry form shows "Add to recipe" (pops with ingredient data) instead of "Log this meal" when `forRecipe` is true.
- `app_router.dart`: updated `/scan` and `/barcode-result` builders to parse `extra` as `Map<String, dynamic>` and pass `forRecipe` to the respective widgets.

---

## 2026-05-18 — Black screen after deleting a recipe

**Description:**
Long-pressing a recipe card, selecting "Delete", and confirming caused the Recipes screen to go completely black and become unresponsive.

**Root cause:**
`showDialog` uses `useRootNavigator: true` by default, so the confirmation dialog is pushed onto the **root** navigator. The Delete and Cancel button callbacks called `Navigator.pop(context, value)` using the outer `context` from `_RecipeCard`, which belongs to the shell's **branch** navigator (not the root). Flutter resolved `Navigator.of(context)` to the branch navigator and popped the only route on it (`/recipes`), leaving the branch navigator empty — resulting in a black screen.

**Solution:**
In `recipes_screen.dart`, changed the `showDialog` builder parameter from `_` to `dialogContext` and replaced `Navigator.pop(context, ...)` with `Navigator.pop(dialogContext, ...)` inside the dialog actions. This ensures the pop targets the root navigator that actually owns the dialog.
