# Known Issues & Fixes

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

## 2026-05-18 — Black screen after deleting a recipe

**Description:**
Long-pressing a recipe card, selecting "Delete", and confirming caused the Recipes screen to go completely black and become unresponsive.

**Root cause:**
`showDialog` uses `useRootNavigator: true` by default, so the confirmation dialog is pushed onto the **root** navigator. The Delete and Cancel button callbacks called `Navigator.pop(context, value)` using the outer `context` from `_RecipeCard`, which belongs to the shell's **branch** navigator (not the root). Flutter resolved `Navigator.of(context)` to the branch navigator and popped the only route on it (`/recipes`), leaving the branch navigator empty — resulting in a black screen.

**Solution:**
In `recipes_screen.dart`, changed the `showDialog` builder parameter from `_` to `dialogContext` and replaced `Navigator.pop(context, ...)` with `Navigator.pop(dialogContext, ...)` inside the dialog actions. This ensures the pop targets the root navigator that actually owns the dialog.
