# ForkScale — Architecture Decisions

Decisions made during planning and implementation that diverge from or extend the project specification. ADR-001–005 were agreed before initial implementation (2026-05-11); ADR-006–009 were agreed before CR-03 implementation (2026-05-16); ADR-010 added post-CR-03 (2026-05-18); ADR-011–012 added post-CR-03 refinements (2026-05-19).

---

## ADR-001: Defer on-device Moondream model (M3)

**Decision:** Ship with Gemini API as the sole analysis backend. M3 (Moondream 2 + llama.cpp binding) is deferred indefinitely.

**Rationale:** No well-maintained `flutter_llama_cpp` binding exists on pub.dev. The on-device model can be revisited once the Flutter/llama.cpp ecosystem matures or a stable binding is published.

**Impact:**
- `model_used` column in `meals` is always `'gemini'` for camera-analyzed meals
- No model download flow or storage-size concerns for the model
- Settings screen has no AI model selector

---

## ADR-002: USDA FoodData Central bundled for nutrition reference

**Decision:** Bundle a curated SQLite snapshot of USDA FoodData Central SR Legacy as a read-only Flutter asset. `UsdaService` provides a fuzzy-match lookup by food name returning `kcal_per_100g`.

**Rationale:** LLMs hallucinate nutrition numbers. USDA data is authoritative, auditable, and requires no network access.

**Current status:** Fully implemented and active. `GeminiService` calls `UsdaService.lookup(name)` for each item returned by the LLM. If a match is found, the USDA `kcal_per_100g` replaces the LLM value; the LLM weight estimate is kept. The `usdaMatched` flag on `MealItem` is `true` when USDA overrode the LLM value, which the UI renders as an "Edited" badge. Falls back to the LLM value silently if no USDA match is found.

**Implementation notes:**
- Source: USDA FoodData Central "SR Legacy" dataset (public domain)
- Pre-processed into `usda_nutrition.db` (`foods` table with `description`, `kcal_per_100g`)
- Lookup: exact match → all-words LIKE match → null (fallback to LLM value)
- Shipped as a Flutter asset; copied to app documents on first launch

---

## ADR-003: go_router with StatefulShellRoute

**Decision:** Use `go_router` (Flutter team's official declarative routing package) with `StatefulShellRoute.indexedStack` for the 4-tab bottom navigation.

**Rationale:** Cleaner deep-link support, type-safe routes, independent navigation stacks per tab, easy control over back-stack for complex flows (Capture → Results → History, barcode scan chain, recipe editor chain).

**Route map (current):**

```
Shell (bottom nav — 5 branches)
  /              → CaptureScreen        (Log tab)
  /recipes       → RecipesScreen        (Recipes tab)
  /history       → HistoryScreen        (History tab)
  /insights      → InsightsScreen       (Insights tab)
  /settings      → SettingsScreen       (Settings tab)

Full-screen routes (no bottom nav)
  /results              → ResultsScreen      (extra: AnalysisResult)
  /scan                 → BarcodeScannerScreen (extra: {forRecipe: bool})
  /barcode-result       → BarcodeResultScreen  (extra: {barcode, forRecipe})
  /history/:id          → MealDetailScreen
  /history/:id/edit     → MealEditScreen (via _MealEditLoader)
  /recipes/new          → RecipeEditorScreen (extra: prefill map or null)
  /recipes/:id          → RecipeDetailScreen
  /recipes/:id/edit     → RecipeEditorScreen (via _RecipeEditorLoader)
```

**Navigation invariants:**
- `context.push` (not `go`) is used for all detail/edit routes so the shell branch stays in the back stack
- After editing (recipe, meal), the caller `await`s the push and calls `ref.invalidate(provider)` on return — no stale provider data on back navigation
- Barcode scanner uses `context.push` (not `pushReplacement`) to `/barcode-result` so the result can be forwarded back via `context.pop(result)` to the recipe editor's `.then()` callback

---

## ADR-004: Image resize before Gemini API call

**Decision:** Resize the captured image to a maximum of 800 px on the longest side (JPEG quality 85) before sending to the Gemini API. A separate 1200 px copy is saved to disk for history.

**Rationale:** Reduces API latency, lowers free-tier quota consumption (Gemini charges per image token), and keeps round-trip time closer to the target. The fork/knife scale reference remains visible at 800 px.

**Implementation:** Both resize operations run concurrently in `Future.wait` using the `image` Dart package inside a background `Isolate`. The API bytes are used only for the network call and not stored.

---

## ADR-005: Color palette and design language

**Decision:** Dark green primary, warm cream background, amber accent.

| Token | Hex | Usage |
|---|---|---|
| `colorPrimary` | `#1B4332` | App bar, filled buttons, active states, banners |
| `colorBackground` | `#FFF8F0` | Screen backgrounds |
| `colorSurface` | `#FFFFFF` | Cards |
| `colorAccent` | `#F4A523` | Calorie totals, highlights, CTAs, chart bars |
| `colorError` | `#D62828` | Error states, delete actions |
| `colorSubtle` | `#78909C` | Secondary text, badges, empty states |

**Rationale:** Conveys freshness and food context without the sterile look of generic health apps. High contrast between primary and background meets WCAG AA.

---

## ADR-006: Open Food Facts as the single barcode product endpoint

**Decision:** Open Food Facts API (`world.openfoodfacts.org/api/v2/product/{barcode}`) is the sole product lookup endpoint. The former FoodRepo endpoint (EPFL, `foodrepo.org/api/v3`) is not used — it has been fully migrated into Open Food Facts and its endpoint is no longer operational.

**Rationale:** OFF covers Swiss retailers (COOP, Migros, ALDI CH, LIDL, Denner, Spar, Manor, Volg) through `countries_tags: en:switzerland` and all international brands. No API key required. Single endpoint simplifies maintenance.

**Cache:** Results are stored in `cached_products` with a `fetched_at` timestamp. A cached entry is considered fresh for 30 days before the app re-fetches from OFF.

**Optional enrichment:** Pepesto API (pepesto.com) can provide CHF retail prices for Swiss products. Requires a paid API key stored in Settings → Integrations. If the key is absent or the lookup fails, price is displayed as "—" with no error shown.

---

## ADR-007: Swiss Food Composition Database (SFCD) bundled as an asset

**Decision:** Bundle the SFCD as `assets/db/sfcd.db`, built at dev time via `tool/build_sfcd.py`. The file is not committed to git.

**Rationale:** The SFCD (~1190 food items, German-language) gives the recipe editor an offline ingredient autocomplete. Network access for ingredient search would hurt UX when creating recipes offline.

**Build process:** `tool/build_sfcd.py` downloads the BLV/OSAV XLSX export from `naehrwertdaten.ch`, extracts `name_de`, `energy_kcal_100g`, and writes `assets/db/sfcd.db`. Asset declared in `pubspec.yaml`.

**Graceful degradation:** If the asset is absent at runtime, `SfcdService.search()` returns an empty list — no crash, autocomplete simply shows no results. The rest of the app is unaffected.

---

## ADR-008: Recipe-portion meals do not duplicate ingredient data

**Decision:** When a user logs a portion of a recipe, the resulting `meals` row stores only `recipe_id`, `portion_g`, and the computed `total_kcal`. Ingredient data is **not** copied into `meal_items`.

**Rationale:** Avoids data duplication and keeps the history record lightweight. The Meal Detail screen reads ingredients from `recipe_items` via `recipe_id` at display time.

**Immutability:** The logged `total_kcal` is immutable — editing a recipe after a meal is logged does **not** retroactively change that meal's calorie total. Only future portions of the recipe pick up the updated `kcal_per_100g`.

---

## ADR-009: Reference-counted photo deletion

**Decision:** `MealsRepository.deleteMeal()` checks `COUNT(*) FROM meals WHERE photo_path = ?` before deleting the JPEG file on disk. The file is only deleted when no other meal references the same path.

**Rationale:** "Copy to today" creates a new `meals` row that shares the original meal's `photo_path` (no file duplication). If the original is deleted first, the copy must still be able to display the photo.

**Scope:** All delete paths (swipe-to-delete, long-press context menu, Meal Detail edit flow) go through a single `MealsRepository.deleteMeal()` so the reference-count check is never bypassed.

---

## ADR-010: Barcode scanner uses push+forward pattern, not pushReplacement

**Decision:** `BarcodeScannerScreen._onDetect` calls `context.push('/barcode-result', ...)` (not `pushReplacement`) and then forwards the return value with `context.pop(result)` in a chained async method.

**Rationale:** When the scanner is opened from the Recipe Editor via `context.push<Map?>('/scan').then(result)`, the editor's `.then()` callback only fires when `/scan` itself is popped. `pushReplacement` pops `/scan` immediately (completing the future with `null`) and the ingredient data from the result screen is never delivered. Using `push` keeps `/scan` alive; the scanner receives the result from the result screen and relays it up the stack.

**Pattern:**

```dart
Future<void> _navigateToResult(String barcode) async {
  final result = await context.push<Map<String, dynamic>?>(
    '/barcode-result',
    extra: {'barcode': barcode, 'forRecipe': widget.forRecipe},
  );
  if (mounted) context.pop(result);
}
```

---

## ADR-011: SQLite fts4 (not fts5) for full-text meal search

**Decision:** History search uses a `meals_fts` virtual table created with `fts4`, not `fts5`.

**Rationale:** SQLite's fts5 extension is not compiled into the default iOS/Android SQLite builds shipped with `sqflite`. fts4 has the same `MATCH` query API for our use case (prefix search on name and notes) and is universally available. The search path in `getMeals` delegates to `_searchMeals` when `searchQuery` is non-null; `_searchMeals` issues `SELECT rowid FROM meals_fts WHERE meals_fts MATCH ?`.

**Limitation:** fts4 content tables require manual sync triggers (not added); instead, the `meals_fts` table is populated at insert/update time directly alongside the `meals` row. Deletes are handled implicitly because `meals_fts` uses a content= table pattern with DELETE triggers at schema creation.

---

## ADR-013: Multi-item barcode meal builder

**Decision:** "Add more items" on `BarcodeResultScreen` pushes to a new `/barcode-meal-builder` route (no `forRecipe` modification) that hosts `BarcodeMealBuilderScreen`. The screen reuses the existing `forRecipe: true` push+pop pattern (ADR-010) to acquire additional scanned items.

**Rationale:** Introducing a dedicated builder screen avoids complicating `BarcodeResultScreen` with multi-item state. The builder is a peer route rather than a nested stack, so the first item is passed as `initialItem` via route extra and subsequent scans follow the identical pattern already used by the Recipe Editor. No changes to `BarcodeScannerScreen` were required.

**Route flow:**

```
/barcode-result (first item scanned)
  → "Add more items" → push /barcode-meal-builder (initialItem = first item)
       → "Scan barcode" → push /scan (forRecipe: true)
            → push /barcode-result (forRecipe: true)
            ← context.pop(result)   ← BarcodeResultScreen
       ← context.pop(result)        ← BarcodeScannerScreen (ADR-010)
       // result added to _items list
  → "Log meal" → inserts Meal(source:'barcode') → /history
```

---

## ADR-012: Recipe scaling uses ratio-based in-place mutation

**Decision:** The Recipe Editor maintains a `_multiplier` double (default 1.0). Tapping a scale chip (×½, ×1, ×2, ×3, ×4) computes `ratio = target / _multiplier`, multiplies every ingredient's `weightG` and `totalKcal` by `ratio`, scales the yield, and sets `_multiplier = target`.

**Rationale:** An alternative approach — keeping immutable `_baseItems` and applying the multiplier as a live transform — was rejected because it requires unscaling user edits back to base units on every `onChanged` callback, adding complexity with no user-visible benefit. The ratio approach is transparent: the editor always shows the actual weights that will be saved, and ×1 correctly halves items that were previously doubled.

**Controller sync:** `_IngredientRow` is a `StatefulWidget` with its own `TextEditingController` for the weight field. `didUpdateWidget` is implemented to sync `_weightCtrl.text` when `widget.item.weightG` changes, which fires automatically when scaling mutates the parent's `_items` list and Flutter reconciles widget positions.
