# Change Request 04 — Macronutrients on Recipe Ingredients

## Context

ForkScale v4 schema (meals + meal_items + cached_products + recipes + recipe_items).
All CR-03 items (A–D) are complete as of 2026-05-16/18.

This document adds a single, cohesive feature, broken into three implementation
sub-parts:

- **CR-04-A** — Store and manually edit macronutrients (protein, fat, carbohydrates) on recipe ingredients · raised 2026-06-03
- **CR-04-B** — Auto-populate macros from the product database when an ingredient is added by barcode scan · raised 2026-06-03
- **CR-04-C** — Surface the derived macro breakdown on the Recipe Detail screen · raised 2026-06-03

---

## Problem

When a recipe is created, ingredients can be added three ways (Recipe Editor →
"+ Add"):

1. **Search** the Swiss Food Composition Database (SFCD).
2. **Scan a barcode** → looks the product up via the local cache → Open Food Facts.
3. **Enter manually.**

For each ingredient the app stores only **name**, **weight (g)**, and **kcal/100g**
(`recipe_items` table → `RecipeItem` model). The **macronutrient content — protein,
fat, carbohydrates — is never captured**, even though:

- The user often knows these values (they are printed on every package label), and
- For barcode-scanned items the values are **already fetched and cached**:
  `CachedProduct.proteinG` / `.carbsG` / `.fatG` are populated by
  `OpenFoodFactsService` from the OFF `proteins_100g` / `carbohydrates_100g` /
  `fat_100g` nutriments, displayed on the Barcode Result Screen, then **silently
  discarded** when the item is handed back to the Recipe Editor (only
  `name`, `kcalPer100g`, `weightG`, `barcode` are passed in the `context.pop` map).

So the data exists but is thrown away, and there is no way to type it in by hand.

## Solution

Add nullable per-100g macro fields to recipe ingredients, expose editable inputs for
them in the Recipe Editor, auto-fill them from the product database on barcode scan,
and show the rolled-up totals on the Recipe Detail screen.

All macro fields are **optional** (nullable) throughout — an ingredient with no macro
data behaves exactly as today, and existing recipes are unaffected.

---

### CR-04-A — Macros on recipe ingredients (data model + manual entry)

#### A.1 — Unit convention

Macros are stored **per 100 g**, mirroring the existing `kcal_per_100g` convention
(and matching what Open Food Facts and the Barcode Result Screen already use — the
nutrition card is explicitly labelled "Nutrition per 100 g / 100 ml"). The per-item
total for any macro is derived the same way kcal totals are:

```
item.total_<macro> = weight_g / 100 × <macro>_per_100g
```

Storing per-100g (rather than absolute grams) means the values stay correct when the
user changes an ingredient's weight or applies the recipe scale multiplier
(`×½ … ×4`), with no extra bookkeeping.

#### A.2 — Schema change (DB migration v4 → v5)

```sql
ALTER TABLE recipe_items ADD COLUMN protein_per_100g REAL;  -- nullable
ALTER TABLE recipe_items ADD COLUMN carbs_per_100g   REAL;  -- nullable
ALTER TABLE recipe_items ADD COLUMN fat_per_100g     REAL;  -- nullable
```

Bump `AppDatabase` schema `version` from `4` to `5` and add an `if (oldVersion < 5)`
block in `_upgradeMealsSchema` with the three `ALTER TABLE` statements above. Add the
same three columns to the `recipe_items` block of `_createMealsSchema` so fresh
installs match.

Existing `recipe_items` rows get `NULL` for all three columns — safe and treated as
"unknown" everywhere.

#### A.3 — Model change (`RecipeItem`)

Add three nullable fields and thread them through `copyWith`, `toMap`, and
`fromMap`:

```dart
final double? proteinPer100g;
final double? carbsPer100g;
final double? fatPer100g;
```

- `toMap`: write `'protein_per_100g': proteinPer100g` etc. (null-safe — keep the keys
  so updates can clear a value).
- `fromMap`: `(map['protein_per_100g'] as num?)?.toDouble()` etc.

Add convenience getters for the derived totals (used by CR-04-C and the editor):

```dart
double? get totalProteinG =>
    proteinPer100g == null ? null : weightG / 100 * proteinPer100g!;
// …same for carbs, fat
```

#### A.4 — Recipe Editor — manual entry / edit (`_IngredientRow`)

The `_IngredientRow` card today shows two numeric fields (Weight, kcal/100g) and a
total-kcal line. Extend it with an **optional, collapsible "Macros (per 100 g)"
section**:

```
┌─ Ingredient card ─────────────────────────────┐
│  [Ingredient name]                  [OFF] [🗑] │
│  ──────────────────────────────────────────── │
│  Weight (g)  [ 150 ]     kcal/100g  [ 380 ]    │
│                                                │
│  ▸ Macros (per 100 g)            (tap to open) │   ← collapsed by default
│  ┌────────────────────────────────────────┐   │
│  │ Protein [ 12 ]  Carbs [ 60 ]  Fat [ 8 ] │   │   ← shown when expanded
│  └────────────────────────────────────────┘   │
│                                    380 kcal    │
└────────────────────────────────────────────────┘
```

- A single expandable row (`ExpansionTile`-style header, or an inline "+ Add macros" /
  chevron toggle) keeps the card compact for users who don't care about macros.
- **Auto-expand** the section when any of the three values is already non-null (e.g.
  after a barcode scan, CR-04-B) so the populated data is visible without a tap.
- Three numeric fields: **Protein**, **Carbs**, **Fat**, each per 100 g, suffix `g`,
  same `_Field` widget / `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))` as the
  existing weight & kcal fields. Empty field ⇒ `null` (not `0`), so "unknown" stays
  distinct from "zero".
- Editing a value calls `widget.onChanged(_cur.copyWith(proteinPer100g: …))`. No total
  recompute is needed on save — totals are derived on read.
- This same card is used for both **adding** (a freshly added blank/manual item) and
  **editing** (an existing item loaded from a saved recipe), so both flows in the
  user's request are covered by one change.

`_addIngredient(...)` and the barcode/manual/SFCD entry points gain optional
`proteinPer100g` / `carbsPer100g` / `fatPer100g` parameters so callers can seed them.

**Note — SFCD search:** the bundled Swiss Food Composition DB currently exposes only
name + kcal/100g through `SfcdService` (`_SfcdResult` has `name`, `kcalPer100g`). Macro
columns for SFCD are **out of scope** for this CR (the asset would need rebuilding via
`tool/build_sfcd.py` to include protein/fat/carb columns). SFCD-sourced ingredients
start with null macros that the user may fill in manually. This is called out in
§Open questions.

**Effort:** small-medium (~3–4 h)

---

### CR-04-B — Auto-populate macros from the product database (barcode)

**Problem:** `CachedProduct` already holds `proteinG`, `carbsG`, `fatG` (per 100 g,
nullable) for every scanned product, but they never reach the recipe ingredient.

**Solution:** carry the three values through the barcode → recipe handoff.

#### B.1 — Barcode Result Screen (`barcode_result_screen.dart`)

The "Add to recipe" action returns a map via `context.pop`. Today:

```dart
context.pop(<String, dynamic>{
  'name': _nameCtrl.text.trim(),
  'kcalPer100g': kcalPer100,
  'weightG': _amount,
  'barcode': widget.barcode,
  'imageUrl': p.imageUrl,
});
```

Add the macro values (read straight off the resolved `CachedProduct`, which is already
in scope as `p` / `_product`):

```dart
  'proteinPer100g': p.proteinG,
  'carbsPer100g':   p.carbsG,
  'fatPer100g':     p.fatG,
```

Apply the same addition to the **"Add to recipe"** path of the `_NotFoundScreen`
manual-entry form (`_addToRecipe`). There the macros come from the manual fields if we
choose to add them; at minimum pass through whatever is captured (initially `null`,
since the not-found form has no macro inputs — acceptable, out of scope to add them
there).

#### B.2 — Recipe Editor — consume the macros

In `_showAddIngredientSheet`'s `onScanBarcode` callback, the result map is unpacked
into `_addIngredient(...)`. Extend it to read the new keys:

```dart
_addIngredient(
  name: result['name'] as String?,
  kcalPer100g: result['kcalPer100g'] as double?,
  weightG: result['weightG'] as double?,
  proteinPer100g: result['proteinPer100g'] as double?,
  carbsPer100g:   result['carbsPer100g'] as double?,
  fatPer100g:     result['fatPer100g'] as double?,
  source: 'off',
  barcode: result['barcode'] as String?,
);
```

#### B.3 — Prefill path (`/recipes/new` from Barcode Result "Add to recipe")

The other barcode→recipe entry point passes a `prefill` map into
`RecipeEditorScreen(prefill: …)`, consumed in `initState`. Extend both the producer
(`barcode_result_screen.dart`, the `context.push('/recipes/new', extra: {...})` branch)
and the consumer (`RecipeEditorScreen.initState`) with `prefillProtein` /
`prefillCarbs` / `prefillFat`, populating the seeded `RecipeItem`.

#### B.4 — Behaviour when data is missing

If a product has no macro data in OFF, the corresponding `CachedProduct` field is
`null`; it passes through as `null` and the ingredient simply has no macros (section
stays collapsed/empty, user can fill manually). No error, no zero-filling.

**Effort:** small (~1–2 h)

---

### CR-04-C — Show macro breakdown on Recipe Detail

**Problem:** Once macros are stored there is no read-only place to see them.

**Solution:** extend the Recipe Detail screen (`recipe_detail_screen.dart`).

#### C.1 — Per-ingredient subtitle

The ingredient `ListTile` subtitle currently reads
`"{weight} g · {kcal/100g} kcal/100g"`. When macro data is present, append a compact
macro line, e.g.:

```
150 g · 380 kcal/100g
P 18 g · C 90 g · F 12 g          ← only shown if any macro is non-null
```

(values are the derived **totals** for that ingredient via the `RecipeItem.total*G`
getters, rounded).

#### C.2 — Recipe-level macro summary chips

Next to the existing `{kcal/100g}` and `Yield` chips, add up to three derived chips
showing the recipe's **total** protein / carbs / fat (sum of per-ingredient totals).
Only render a chip if at least one ingredient contributes that macro. Example:

```
[ 118 kcal/100g ]  [ Yield: 1100 g ]
[ P 92 g ]  [ C 210 g ]  [ F 34 g ]
```

A `Recipe.totalProteinG` / `.totalCarbsG` / `.totalFatG` helper (sum over items,
skipping nulls) on the `Recipe` model keeps the screen logic simple. Optionally also
expose `*Per100g` derived getters (sum / yield × 100) for symmetry with `kcalPer100g`
— include only if cheap; not required for this CR.

**Excluded from scope:** the **Log Portion Sheet** and logged-meal macro tracking.
This CR stops at the recipe definition. Carrying macros into `meal_items` /
History / Insights (so a logged portion contributes to a daily protein target, etc.)
is a natural follow-up but is intentionally **not** part of CR-04 — see §Open questions.

**Effort:** small (~2 h)

---

## DB migration summary

Single migration block: **v4 → v5**.

```sql
-- ── recipe_items macro columns ─────────────────────────────────────────────
ALTER TABLE recipe_items ADD COLUMN protein_per_100g REAL;  -- nullable, per 100 g
ALTER TABLE recipe_items ADD COLUMN carbs_per_100g   REAL;  -- nullable, per 100 g
ALTER TABLE recipe_items ADD COLUMN fat_per_100g     REAL;  -- nullable, per 100 g
```

`_createMealsSchema` (fresh installs) gets the same three columns inside the
`recipe_items` `CREATE TABLE`. No data backfill — existing rows are `NULL`.

---

## Files touched

| File | Change |
|---|---|
| `lib/core/database/app_database.dart` | Bump version 4→5; add v5 upgrade block; add columns to create schema |
| `lib/models/recipe_item.dart` | Add 3 nullable fields + getters; update `copyWith`/`toMap`/`fromMap` |
| `lib/models/recipe.dart` | Add `totalProteinG`/`totalCarbsG`/`totalFatG` derived getters (CR-04-C) |
| `lib/features/recipes/recipe_editor_screen.dart` | Collapsible macro inputs in `_IngredientRow`; extend `_addIngredient` + barcode/prefill plumbing |
| `lib/features/barcode/barcode_result_screen.dart` | Pass `proteinPer100g`/`carbsPer100g`/`fatPer100g` in both "Add to recipe" handoffs (pop + push prefill) |
| `lib/features/recipes/recipe_detail_screen.dart` | Per-ingredient macro subtitle + recipe-level macro chips |

`RecipesRepository` needs **no change** — it persists whatever `RecipeItem.toMap`
emits, so the new columns flow through `insertRecipe` / `updateRecipe` automatically.

## Dependencies

None. No new packages.

---

## Error handling / edge cases

| Scenario | Behaviour |
|---|---|
| Product has no macro data in OFF | Fields stay `null`; macro section empty/collapsed; no error |
| User clears a macro field | Stored as `null` (unknown), not `0` |
| User enters non-numeric / partial text | Existing `[\d.]` input formatter rejects it; unparseable ⇒ keep previous value |
| Scale multiplier (×½…×4) applied | Per-100g macros unchanged (correct); totals re-derive from new weight |
| Existing pre-v5 recipe opened/edited | All macros `null`; editing & saving works; user may fill them in |
| SFCD-searched ingredient | Macros `null` (SFCD asset has no macro columns yet); user can add manually |

---

## Implementation order (suggested)

1. **DB migration v4 → v5** + `RecipeItem` model fields (CR-04-A.2, A.3) — unblocks the rest.
2. **CR-04-B** barcode plumbing — small, high value, makes scanned items rich immediately.
3. **CR-04-A.4** Recipe Editor macro inputs (manual entry + edit).
4. **CR-04-C** Recipe Detail display.

---

## Open questions

1. **SFCD macros:** should `tool/build_sfcd.py` and `assets/db/sfcd.db` be rebuilt to
   include protein/fat/carb columns so search-added ingredients are also pre-filled?
   Deferred — separate asset-pipeline task. Recommendation: do it in a later CR once
   the export columns are confirmed.
2. **Macros into logged meals:** should logged portions (`meal_items`) and the History
   / Insights screens carry macros too, enabling daily protein/fat/carb totals and
   targets? This is the obvious next step but is deliberately out of CR-04 scope to
   keep the change small. Recommendation: scope as CR-05 if daily macro tracking is
   desired.
3. **"of which sugars / saturates":** OFF also exposes `sugars_100g` and
   `saturated-fat_100g`. Out of scope — only the three top-level macros are captured.
   Revisit if detailed breakdowns are wanted.

---

## Implementation status

| Item | Status | Notes |
|---|---|---|
| CR-04-A | **complete** | Schema v5 migration + `RecipeItem` macro fields + collapsible macro inputs in Recipe Editor (implemented 2026-06-03) |
| CR-04-B | **complete** | Barcode → recipe macro passthrough (both pop + `/recipes/new` prefill paths) |
| CR-04-C | **complete** | Recipe Detail per-ingredient macro line + recipe-level P/C/F chips |
