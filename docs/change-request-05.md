# Change Request 05 — Macros Everywhere: SFCD Search + Logged-Meal Macro Tracking

## Context

ForkScale v5 schema (CR-04 added `protein_per_100g` / `carbs_per_100g` /
`fat_per_100g` to `recipe_items`). CR-04 captures macros on **recipe ingredients**
only — they are entered/auto-filled in the Recipe Editor and shown on Recipe Detail,
but they stop there: SFCD-searched ingredients have no macros, and nothing carries
macros into **logged meals**, History, or Insights.

This CR closes the two open questions left by CR-04:

- **CR-05-A** — SFCD ingredient search returns macros (the bundled `sfcd.db` already
  has the columns; only the query + model drop them) · raised 2026-06-03
- **CR-05-B** — Macros on logged meals: capture on every meal source, denormalise
  per-meal totals, persist · raised 2026-06-03
- **CR-05-C** — Surface macros in Meal Detail, the Meal Editor, and Insights
  (daily macro averages) · raised 2026-06-03

All macro fields stay **nullable** ("unknown" ≠ "zero"); meals/items without macro
data behave exactly as today.

---

### CR-05-A — Macros from SFCD search

**Problem:** `tool/build_sfcd.py` already parses and stores `fat_g`, `carbs_g`,
`protein_g` into `swiss_fcd_items`, but `SfcdService.search` only `SELECT`s
`energy_kcal_100g`, and `SfcdItem` only carries `kcalPer100g`. Ingredients added via
the Recipe Editor's text search therefore always have null macros.

**Solution:**

#### A.1 — `SfcdService` / `SfcdItem`

- `SfcdItem` gains `proteinPer100g`, `carbsPer100g`, `fatPer100g` (all `double?`).
- `search()` adds `protein_g, carbs_g, fat_g` to the `SELECT`.
- **Resilience:** if the `SELECT` throws (an older shipped `sfcd.db` predating the
  macro columns), fall back to the kcal-only query so search keeps working with null
  macros — never breaks. (Implementation: wrap the macro query in its own try; on
  failure run the original column list.)

#### A.2 — Recipe Editor wiring

- `_SfcdResult` gains the three macro fields.
- `_searchSfcd` maps them from `SfcdItem`.
- `onSelectSfcd` carries them into `_addIngredient(... proteinPer100g: …)`, with
  `source: 'swiss_fcd'`.

No asset rebuild is *required*; if the user re-runs `tool/build_sfcd.py` the values are
already there. No schema change.

**Effort:** small (~1 h)

---

### CR-05-B — Macros on logged meals (model + persistence + capture)

**Problem:** `MealItem` has no macro fields, and `meals` stores only `total_kcal`.
Recipe-portion meals carry **no `meal_items` at all** (they read ingredients from
`recipe_items` at display time), so per-meal macro totals cannot be derived from items
alone for aggregation.

**Solution:** add per-100g macros to `meal_items` **and** denormalised per-meal macro
totals to `meals` (mirroring the existing `total_kcal` denormalisation). The meal-level
totals are the single source of truth for Insights aggregation across all sources.

#### B.1 — Schema change (DB migration v5 → v6)

```sql
-- per-ingredient macros (per 100 g, nullable)
ALTER TABLE meal_items ADD COLUMN protein_per_100g REAL;
ALTER TABLE meal_items ADD COLUMN carbs_per_100g   REAL;
ALTER TABLE meal_items ADD COLUMN fat_per_100g     REAL;

-- denormalised per-meal macro totals (grams, nullable)
ALTER TABLE meals ADD COLUMN total_protein_g REAL;
ALTER TABLE meals ADD COLUMN total_carbs_g   REAL;
ALTER TABLE meals ADD COLUMN total_fat_g     REAL;
```

Bump `AppDatabase` version 5 → 6; add an `if (oldVersion < 6)` block; add the same
columns to the `meal_items` and `meals` blocks of `_createMealsSchema`. Existing rows
get `NULL` everywhere.

#### B.2 — `MealItem` model

Add `proteinPer100g` / `carbsPer100g` / `fatPer100g` (`double?`) threaded through
`copyWith` / `toMap` / `fromMap`, plus derived totals
`totalProteinG` / `totalCarbsG` / `totalFatG` (null when the per-100g value is null).

#### B.3 — `Meal` model

Add `totalProteinG` / `totalCarbsG` / `totalFatG` (`double?`) fields (persisted to the
new `meals` columns) threaded through the constructor / `copyWith` / `toMap` /
`fromMap`. Add a static helper:

```dart
static ({double? protein, double? carbs, double? fat}) sumItemMacros(
    List<MealItem> items);
```

summing each item's derived total, returning `null` per-macro when no item contributes
it.

#### B.4 — `MealsRepository` — recompute on write

In `insertMeal` and `updateMeal`, when `meal.items` is non-empty, overwrite the three
`total_*_g` map values with `Meal.sumItemMacros(items)` before persisting. This means
**item-based callers don't each have to compute totals** — they just set item macros.
For recipe-portion meals (no items) the totals set on the `Meal` are persisted as-is.

`copyMealToToday` carries `totalProteinG`/`totalCarbsG`/`totalFatG` from the original in
all three branches (item-based branches will be recomputed identically; the
recipe-portion branch relies on the carried values).

#### B.5 — Capture sites

| Source | Where | Macro source |
|---|---|---|
| Barcode (single) | `barcode_result_screen._logMeal` | `MealItem(proteinPer100g: p.proteinG, …)` from the resolved `CachedProduct` |
| Barcode (multi) | `barcode_meal_builder_screen` | `_Item` gains macro fields; scan fills them from the result map (already provided by CR-04-B); manual sheet leaves null |
| Recipe portion | `log_portion_sheet._log` | Compute meal totals from the recipe scaled by portion: `mealMacro = portionG × recipe.total<Macro>G / yieldG`; set on the `Meal` (no items) |
| Camera | `results_*` | Gemini does not return macros → items keep null macros → totals null (unchanged). Manual entry possible via the Meal Editor (§C.2) |
| Manual barcode (not-found) | `_NotFoundScreen` | null (no macro inputs there — out of scope) |

**Effort:** medium (~4–5 h)

---

### CR-05-C — Surface macros: Meal Detail, Meal Editor, Insights

#### C.1 — Meal Detail (`meal_detail_screen.dart`)

- **Meal-level chips:** add P/C/F `_InfoChip`s next to the `kcal` chip in both
  `_MealDetail` and `_RecipePortionDetail`, driven by `meal.totalProteinG` etc. (shown
  only when non-null).
- **Per-ingredient macro line:** for item-based meals, append a compact
  `P 18 g · C 90 g · F 12 g` line to each ingredient `ListTile` subtitle (item totals,
  only when present). The recipe-portion ingredient list reads `recipe.items`, which
  already carry macros from CR-04 — reuse the same line there.

#### C.2 — Meal Editor (`ingredient_card.dart`, shared with Results)

Add an optional, collapsible **"Macros (per 100 g)"** section to `IngredientCard`
(Protein / Carbs / Fat fields), mirroring the CR-04 Recipe Editor card:

- Auto-expanded when any macro is already non-null.
- Cleared field ⇒ `null` (rebuild the `MealItem` explicitly rather than via `copyWith`,
  whose `?? this.x` pattern can't clear to null).
- Because `IngredientCard` is also used by the **camera Results screen**, this
  incidentally lets users hand-enter macros for camera meals — acceptable and useful;
  no behavioural regression (fields start empty/collapsed).

On save, `MealsRepository.updateMeal` recomputes meal totals from the edited items
(B.4), so meal-level chips and Insights update automatically.

#### C.3 — Insights (`insights_screen.dart`)

Add an **"AVERAGE DAILY MACROS"** card (last 7 / 30 days) below the existing kcal
averages. Backed by a new repository method:

```dart
Future<({double? protein, double? carbs, double? fat})> getAvgDailyMacros({int days});
```

— same daily-grouping pattern as `getAvgDailyKcal`, but `SUM`ming the `total_*_g`
columns per day then averaging. `NULL` totals are ignored by `SUM`; a macro with no
data anywhere shows "—". New `FutureProvider`s mirror `_avgKcal7Provider` /
`_avgKcal30Provider`.

#### C.4 — Out of scope

- **History list cards**: no macro line added to the compact history tiles (kcal
  stays the headline metric). Meal Detail covers the per-meal macro view.
- **Daily macro goals / targets** (analogous to the kcal goal): not in this CR —
  Insights shows descriptive averages only. Could be a follow-up.
- **Gemini macro estimation** for camera meals: out of scope; camera items stay
  macro-less unless hand-entered in the Meal Editor.

**Effort:** medium (~4 h)

---

## DB migration summary

Single block: **v5 → v6**.

```sql
ALTER TABLE meal_items ADD COLUMN protein_per_100g REAL;
ALTER TABLE meal_items ADD COLUMN carbs_per_100g   REAL;
ALTER TABLE meal_items ADD COLUMN fat_per_100g     REAL;
ALTER TABLE meals      ADD COLUMN total_protein_g  REAL;
ALTER TABLE meals      ADD COLUMN total_carbs_g    REAL;
ALTER TABLE meals      ADD COLUMN total_fat_g      REAL;
```

`_createMealsSchema` gets the same columns inline. No backfill; existing rows `NULL`.

---

## Files touched

| File | Change |
|---|---|
| `lib/core/services/sfcd_service.dart` | `SfcdItem` macros; `SELECT` macro cols + resilient fallback |
| `lib/features/recipes/recipe_editor_screen.dart` | `_SfcdResult` macros; `onSelectSfcd`/`_searchSfcd` wiring |
| `lib/core/database/app_database.dart` | Version 5→6; v6 upgrade block; create-schema cols |
| `lib/models/meal_item.dart` | Macro fields + total getters; map/copyWith |
| `lib/models/meal.dart` | Macro-total fields; `sumItemMacros`; map/copyWith |
| `lib/core/database/meals_repository.dart` | Recompute totals on write; `copyMealToToday`; `getAvgDailyMacros` |
| `lib/features/barcode/barcode_result_screen.dart` | Fill `MealItem` macros from `CachedProduct` |
| `lib/features/barcode/barcode_meal_builder_screen.dart` | `_Item` macros; thread scan→item |
| `lib/features/recipes/log_portion_sheet.dart` | Compute & set recipe-portion meal macro totals |
| `lib/features/results/ingredient_card.dart` | Collapsible macro inputs (shared editor card) |
| `lib/features/history/meal_detail_screen.dart` | Meal-level macro chips + per-ingredient macro lines |
| `lib/features/insights/insights_screen.dart` | Average daily macros card + providers |

## Dependencies

None.

---

## Error handling / edge cases

| Scenario | Behaviour |
|---|---|
| Older `sfcd.db` without macro columns | `SfcdService` falls back to kcal-only query; null macros |
| OFF product missing a macro | That field stays `null`; chip/line hidden |
| Recipe with `yieldG > 0` but no macro data | `recipe.total*G` null ⇒ portion meal macro totals null |
| Camera meal (no macros) | No macro chips/lines; Insights skips nulls |
| Pre-v6 meals after migration | All macro columns `NULL`; everything still renders |
| Editing a meal item's macros | `updateMeal` recomputes meal totals; detail + Insights refresh |

---

## Implementation order (suggested)

1. **CR-05-A** SFCD search macros — self-contained, immediately enriches recipes.
2. **Migration v5 → v6** + `MealItem` / `Meal` model fields (B.1–B.3).
3. **B.4** repository recompute + `copyMealToToday`.
4. **B.5** capture sites (barcode single, barcode multi, recipe portion).
5. **C.1 / C.2** Meal Detail display + Meal Editor macro inputs.
6. **C.3** Insights average-daily-macros card.

---

## Implementation status

| Item | Status | Notes |
|---|---|---|
| CR-05-A | **complete** | `SfcdService`/`SfcdItem` carry macros (resilient fallback for old assets); Recipe Editor wired (implemented 2026-06-03) |
| CR-05-B | **complete** | Schema v6 (`meal_items` + `meals` macro cols); `MealItem`/`Meal` models; repository recompute + `copyMealToToday`; barcode single/multi + recipe-portion capture |
| CR-05-C | **complete** | Meal Detail chips + per-item lines; collapsible macro inputs in shared `IngredientCard` (Results + Meal Editor); Insights avg-daily-macros card |

> **Note:** the committed `assets/db/sfcd.db` only yields macros if it was built with
> the current `tool/build_sfcd.py` (which already extracts protein/fat/carbs). If the
> shipped asset predates those columns, search still works (kcal-only) via the resilient
> fallback — re-run `python tool/build_sfcd.py` to populate SFCD macros.
