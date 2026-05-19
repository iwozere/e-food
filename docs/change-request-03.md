# Change Request 03 — Barcode Scanner · Recipe Builder · Copy Meal

## Context

ForkScale v3 schema (meals + meal_items + starred + meal_type + pending).
All CR-01 and CR-02 items are complete as of 2026-05-14.

This document adds four independent but related features:

- **CR-03-A** — Barcode scanner with Swiss product database lookup (COOP, Migros, ALDI, LIDL, Denner, etc.) · raised 2026-05-16
- **CR-03-B** — Recipe builder: define a dish from raw ingredients, then log any portion of it · raised 2026-05-16
- **CR-03-C** — Copy meal from history: re-log any past meal to today without re-scanning or re-photographing · raised 2026-05-16
- **CR-03-D** — Edit saved meal items from Meal Detail: correct AI-assigned weights and kcal/100g values after saving · raised 2026-05-18

---

## Features

---

### CR-03-A — Barcode scanner + Swiss product database

**Problem:** Packaged products (protein drinks, yoghurt, muesli bars, etc.) have accurate
nutrition data printed on the label and encoded in their EAN barcode. Photographing the
package gives a worse estimate than just reading the label. There is no way in the current
app to look up a product by barcode.

**Solution:**

#### A.1 — Scanner UI

- Add a **"Scan barcode"** `IconButton` to the capture screen's top-right action area
  (alongside the existing gallery-pick button).
- Tapping it replaces the camera preview with a full-screen barcode viewfinder powered
  by the `mobile_scanner` Flutter plugin (uses ML Kit on Android, AVFoundation on iOS —
  no cloud call, instant, works offline once the databases are seeded).
- On successful decode: haptic feedback + brief freeze frame, then navigate to the
  **Barcode Result Screen** (§A.3).
- Back button on the scanner returns to the capture screen without logging anything.

#### A.2 — Database lookup strategy (layered, in order)

**Background:** The former FoodRepo database (EPFL Digital Epidemiology Lab, previously
at foodrepo.org) has been fully migrated into Open Food Facts. The old
`foodrepo.org/api/v3` endpoint is no longer operational. Swiss products from COOP,
Migros, Denner, Spar, Manor, and Volg that were in FoodRepo are now accessible through
the standard Open Food Facts API, typically with `countries_tags` including
`en:switzerland`. There is therefore no longer a separate Swiss-specific endpoint —
**a single OFF lookup covers all Swiss retailers and international brands alike.**

Execute each step only if the previous returned no result:

```
Step 1 — Local SQLite product cache (table: cached_products)
          Key: barcode (EAN-8 / EAN-13 / UPC-A).
          Hit → instant, fully offline.

Step 2 — Open Food Facts API  (single source for all products)
          GET https://world.openfoodfacts.org/api/v2/product/{barcode}
              ?fields=product_name,brands,nutriments,serving_size,
                      product_quantity,image_front_small_url,
                      countries_tags
          Auth: none required.
          User-Agent header: "ForkScale/1.0 (forkscale@example.com)"
          Coverage: COOP, Migros, ALDI, LIDL, Denner, Spar, Volg, Manor,
                    and all international brands — single endpoint, no key needed.
          On success → cache in cached_products (source = 'off'), proceed to §A.3.

Step 3 — Not found screen
          Show scanned barcode + "Product not found" message.
          Offer manual entry form: name, pack size (g/ml), kcal/100g.
          Optional "Contribute to Open Food Facts" button (opens
          https://world.openfoodfacts.org/product/{barcode} in the system
          browser — user's choice, never automatic).
```

**Note on prices:** Open Food Facts does not carry retail prices.
The **Pepesto API** (pepesto.com) covers COOP, Migros, ALDI CH, and Farmy with live
pricing but requires paid credits. Implement price lookup as an **optional enrichment**:
- Add a `pepesto_api_key` field to Settings → Integrations (hidden section, collapsed
  by default).
- If the key is present, fire a Pepesto lookup in parallel with Step 2.
- If absent or if the lookup fails, display "—" in the price field — no error shown.
- Price is informational only; it does not feed into calorie calculations.

**No API key required for OFF:** Open Food Facts is free and keyless for read queries.
No app-level key needs to be registered or embedded. The only requirement is a
descriptive `User-Agent` header so the OFF team can identify the app in their logs.

#### A.3 — Barcode Result Screen

Layout (scrollable):

```
┌─────────────────────────────────────┐
│  [Product photo or generic icon]    │
│  Product name          Brand        │
│  Pack: 500 ml          Price: CHF — │
├─────────────────────────────────────┤
│  Nutrition (per 100 g / 100 ml)     │
│  Energy   kcal_per_100g  kcal       │
│  Protein  xx g                      │
│  Carbs    xx g  (of which sugars)   │
│  Fat      xx g  (of which saturates)│
├─────────────────────────────────────┤
│  How much did you have?             │
│  [  −  ]  [ 330 ml / g ]  [  +  ]  │
│  stepper step: 10 g/ml              │
│  → Total: 142 kcal                  │
├─────────────────────────────────────┤
│  Meal type: [auto-chip row]         │
│  Notes: ___________________         │
├─────────────────────────────────────┤
│  [Log this meal]   [Add to recipe ↗]│
└─────────────────────────────────────┘
```

- **Amount stepper**: default = full pack quantity from DB (e.g. 330 ml). Step = 10.
  Free-text number input also accepted (tap the value to edit directly).
- **Total kcal**: `(amount / 100) × kcal_per_100g`, recalculates live.
- All nutrition fields are editable (tap to edit) so the user can correct wrong DB data.
- **Log this meal**: creates a `meals` row with `source = 'barcode'` and a single
  `meal_items` row. Navigates to History with the new entry highlighted.
- **Add to recipe**: navigates to Recipe Editor (CR-03-B) with this product
  pre-populated as an ingredient at the logged amount.

#### A.4 — New SQLite tables

```sql
-- DB migration v3 → v4

-- Product cache — keyed by barcode
CREATE TABLE cached_products (
  barcode         TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  brand           TEXT,
  pack_size_g     REAL,           -- null if unknown
  kcal_per_100g   REAL NOT NULL,
  protein_g       REAL,
  carbs_g         REAL,
  fat_g           REAL,
  image_url       TEXT,           -- remote URL; app caches image file separately
  source          TEXT NOT NULL,  -- 'off' | 'manual'
  fetched_at      INTEGER NOT NULL -- Unix ms; stale after 30 days → re-fetch
);

-- Add source column to meals to distinguish camera vs barcode vs recipe-portion
ALTER TABLE meals ADD COLUMN source TEXT NOT NULL DEFAULT 'camera';
-- valid values: 'camera' | 'barcode' | 'recipe_portion'

-- Add barcode column to meals (populated for source='barcode')
ALTER TABLE meals ADD COLUMN barcode TEXT REFERENCES cached_products(barcode);

-- Add price_chf column to meals (populated if Pepesto lookup succeeded)
ALTER TABLE meals ADD COLUMN price_chf REAL;
```

#### A.5 — History card for barcode entries

- Thumbnail: cached product image (or a barcode icon placeholder).
- Subtitle: brand + logged amount (e.g. "Sponser · 330 ml").
- Source badge: small "🔖 Barcode" chip (vs "📷 Photo" for camera meals).
- Tapping opens Meal Detail Screen in read-only mode, same as camera meals.

#### A.6 — New dependencies

| Package | Version constraint | Purpose |
|---|---|---|
| `mobile_scanner` | `^6.0.0` | Barcode decoding (ML Kit / AVFoundation) |
| `cached_network_image` | `^3.3.0` | Cache remote product images |

#### A.7 — Permissions

- **Android**: `CAMERA` permission already declared (camera feature). No additional permission needed.
- **iOS**: `NSCameraUsageDescription` already declared. No additional permission needed.
- No `INTERNET` permission change needed (already declared for Gemini).

**Effort:** large (~1.5 days)

---

### CR-03-B — Recipe builder

**Problem:** The user often eats the same home-cooked dish repeatedly (e.g. chicken +
oat + chickpea bowl, omelette). Each time they either re-photograph it or re-enter it
manually. There is no way to define a dish once and log a portion of it indefinitely.

**Solution:**

#### B.1 — Data model

```sql
-- DB migration v3 → v4 (same migration block as CR-03-A)

CREATE TABLE recipes (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,
  yield_g       REAL NOT NULL,     -- total grams produced by the recipe
  kcal_per_100g REAL NOT NULL,     -- derived: sum(items.total_kcal) / yield_g * 100
  photo_path    TEXT,              -- optional, same convention as meals
  notes         TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);

CREATE TABLE recipe_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  recipe_id     INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  weight_g      REAL NOT NULL,
  kcal_per_100g REAL NOT NULL,
  total_kcal    REAL NOT NULL,     -- denormalised: weight_g / 100 * kcal_per_100g
  source        TEXT NOT NULL DEFAULT 'manual',
                                   -- 'manual' | 'foodrepo' | 'off' | 'swiss_fcd'
  barcode       TEXT,              -- if ingredient was added via barcode scan
  sort_order    INTEGER NOT NULL DEFAULT 0
);

-- Link a logged meal back to its source recipe (when source = 'recipe_portion')
ALTER TABLE meals ADD COLUMN recipe_id INTEGER REFERENCES recipes(id) ON DELETE SET NULL;
ALTER TABLE meals ADD COLUMN portion_g REAL;  -- how many grams the user ate
```

`kcal_per_100g` on `recipes` is a **derived column** recomputed on every save:
```
recipe.kcal_per_100g = SUM(recipe_items.total_kcal) / recipe.yield_g * 100
```

#### B.2 — Recipe List Screen

- New **"Recipes"** tab in the bottom navigation bar (between Log and History).
- Card grid (2 columns): recipe photo or food-emoji placeholder, recipe name,
  kcal/100g, yield.
- **"+ New recipe"** FAB.
- Long-press a card → context menu: Edit / Duplicate / Delete.
- Tap a card → Recipe Detail Screen (§B.3).

#### B.3 — Recipe Detail Screen

Read-only summary:

- Photo (or placeholder), name, yield, kcal/100g, notes.
- Ingredient list (read-only cards: name, weight, kcal/100g, total kcal).
- **"Log a portion"** prominent button (§B.4).
- **"Edit recipe"** button → Recipe Editor Screen (§B.5).

#### B.4 — Log Portion Sheet (bottom sheet)

Appears over the Recipe Detail Screen when "Log a portion" is tapped:

```
┌──────────────────────────────────┐
│  Chicken + Oat Bowl              │
│  kcal/100g: 118                  │
│                                  │
│  How much did you eat?           │
│  [  −  ]  [ 350 g ]  [  +  ]    │
│  step: 25 g                      │
│                                  │
│  → 413 kcal                      │
│                                  │
│  Meal type: [auto-chip row]      │
│  Notes: ___________________      │
│                                  │
│  [Log meal]                      │
└──────────────────────────────────┘
```

- Amount stepper: default = yield_g / 2 (half the batch as a sensible starting point).
  Step = 25 g.
- Live kcal: `(portion_g / 100) × recipe.kcal_per_100g`.
- "Log meal" saves a `meals` row with `source = 'recipe_portion'`, `recipe_id`,
  `portion_g`, and `total_kcal`. Ingredients are **not** duplicated into `meal_items`
  at log time — they are read from `recipe_items` when the meal detail is shown.
- After logging: navigate to History, meal highlighted at top.

#### B.5 — Recipe Editor Screen

Used for both create (empty) and edit (pre-populated):

Fields:

- **Recipe name** — text input, required.
- **Yield (g)** — total grams produced (e.g. 1100 for the chicken+oat+chickpea dish).
  Helper text: "Weigh the finished dish if possible."
- **Photo** — optional, camera or gallery.
- **Notes** — optional free text.
- **Ingredient list** — same editable card UI as the analysis Results Screen:
  - Each card: ingredient name, weight\_g, kcal/100g, total\_kcal (auto-calculated).
  - "Edited" badge when user overrides a kcal/100g value (CR-01-B pattern).
  - `source` badge: "FoodRepo" / "OFF" / "Manual" shown in card footer.
- **"+ Add ingredient"** button opens an ingredient picker:
  - **Text search**: fuzzy search against Swiss Food Composition Database (SFCD)
    name list bundled as a small SQLite table (`swiss_fcd_items`) — no network call.
    Tap a result to pre-fill name + kcal/100g.
  - **Scan barcode**: launches scanner (§A.1), adds the scanned product as an
    ingredient card at a default weight of 100 g.
  - **Manual**: blank card, user types everything.
- **Derived summary bar** (sticky at bottom):
  `Total: {sum_kcal} kcal   ·   Per 100 g: {kcal_per_100g} kcal`
  Updates live as weights change.
- **"Save recipe"** button: writes/updates `recipes` + `recipe_items` rows, recomputes
  `kcal_per_100g`, navigates back to Recipe List.

#### B.6 — Swiss Food Composition Database (SFCD) bundle

- Source: Swiss Federal Food Safety and Veterinary Office, naehrwertdaten.ch.
  Data is publicly available (CC-BY, open data).
- At build time: download the published CSV export, extract `name_de`, `name_fr`,
  `name_en`, `energy_kcal_100g` columns, import into a bundled SQLite file
  (`assets/sfcd.db`, read-only, shipped with the app).
- Size estimate: ~3 000 entries → < 500 KB asset.
- Used only for ingredient autocomplete in the Recipe Editor. Never for barcode lookup.
- Refresh: rebuild the asset when a new SFCD export is published (annual cadence).

#### B.7 — History card for recipe-portion entries

- Thumbnail: recipe photo (or food-emoji placeholder).
- Title: recipe name + portion (e.g. "Chicken + Oat Bowl · 350 g").
- Source badge: "🍳 Recipe".
- Meal Detail Screen for recipe-portion meals: shows portion\_g and total\_kcal at top;
  ingredient cards read from `recipe_items` via `recipe_id` (read-only); "Go to recipe"
  link; "Edit recipe" link.

#### B.8 — New dependencies

| Package | Version constraint | Purpose |
|---|---|---|
| *(none new)* | — | Recipe editor reuses existing `sqflite`, Riverpod, UI components |

**Effort:** large (~2 days)

---

### CR-03-C — Copy meal from history

**Problem:** The user ate an omelette with 3 eggs yesterday. Today they want to log
the same thing. Currently they must either re-photograph it (LLM call, imprecise) or
re-enter the items manually. CR-01-H added "Re-log today" via the star/favourite flow,
but it is buried in the meal detail screen and only works for starred meals.

**Solution:**

This CR makes copy-meal a first-class, discoverable action on every meal in history.

#### C.1 — "Copy to today" action on history list tiles

- Each history list tile gains a **long-press context menu** with two options:
  - **"Copy to today"** — immediately creates a copy of the meal logged at `DateTime.now()`,
    with the same `meal_type` auto-detected from the current time, and navigates to
    the new meal's Results/Detail screen for optional editing before saving.
  - **"Delete"** — existing swipe-to-delete behaviour, now also accessible here.
- The copy action is also accessible from the **Meal Detail Screen** as a prominent
  **"Copy to today"** `OutlinedButton` in the action row at the bottom (alongside
  the existing "Re-log today" from CR-01-H — merge these two buttons into one).

#### C.2 — Copy semantics

| Meal source | What is copied |
|---|---|
| `camera` | New `meals` row; same `photo_path` (shared file reference, not duplicated); same `meal_items` rows cloned; `pending = 0`; new `created_at`; new auto-detected `meal_type`; `starred = 0`. |
| `barcode` | New `meals` row; same `barcode`; same single `meal_items` row cloned; same `price_chf` carried over. |
| `recipe_portion` | New `meals` row; same `recipe_id` and `portion_g`; `total_kcal` recomputed from current recipe kcal\_per\_100g (in case the recipe was edited since). |

Photos are **not** duplicated on disk — both the original and the copied meal point to
the same JPEG file path. The file is deleted only when **all** meals referencing it
are deleted. Implement reference-counted deletion:

```sql
-- Before deleting a photo file, check:
SELECT COUNT(*) FROM meals WHERE photo_path = ? AND id != ?;
-- Delete the file only if count = 0.
```

#### C.3 — "Copy from history" quick-pick on the Log tab

A **"Recent meals"** horizontal scroll strip at the bottom of the Log tab (below the
camera FAB and barcode button) shows the last 5 distinct meal names from history as
pill chips with their kcal value. Tapping a chip is equivalent to "Copy to today"
without opening the detail screen first — single tap → meal logged → toast confirmation.

Suppress duplicates: if the same meal name already appears in today's log, show a
"Logged today" badge on the chip instead of making it tappable again.

#### C.4 — No schema changes required

All data needed for copy is already present in v4 schema (after CR-03-A/B migration).
No additional migration block needed for CR-03-C.

**Effort:** medium (~4 h)

---

---

### CR-03-D — Edit saved meal items from Meal Detail

**Problem:** The AI occasionally assigns plausible-looking but wrong kcal/100g values.
For example, an apple may be correctly sized at 180 g but assigned 396 kcal/100g (a
value typical of dried fruit) instead of ~52 kcal/100g. Once a meal is saved the Meal
Detail screen is entirely read-only — there is no way to correct these values.

**Solution:**

#### D.1 — "Edit" entry point in Meal Detail Screen

- Add an **edit `IconButton`** (`Icons.edit_outlined`) to the `AppBar` of `MealDetailScreen`.
- Shown only for `source = 'camera'` meals (barcode meals are corrected via the
  Barcode Result Screen's inline editable fields; recipe-portion meals are corrected
  via the Recipe Editor).
- Also shown for `pending = false` only — pending meals go through the "Analyze now"
  → Results Screen path instead.

#### D.2 — Meal Edit Screen

A new screen (`MealEditScreen`) reachable at `/history/:id/edit`.

Layout — identical to the Analysis Results Screen, but pre-populated from the saved meal:

```
┌─────────────────────────────────────┐
│  ← Edit meal                        │
├─────────────────────────────────────┤
│  [Total kcal banner — live]         │
├─────────────────────────────────────┤
│  [IngredientCard]  name / weight /  │
│                    kcal/100g        │
│  [IngredientCard]  ...              │
│  [+ Add item]                       │
├─────────────────────────────────────┤
│  Meal type: [chip row]              │
│  Notes: ___________________         │
├─────────────────────────────────────┤
│  [Save changes]  ← sticky bottom    │
└─────────────────────────────────────┘
```

Editable fields per ingredient card (same `IngredientCard` widget already used in
Results Screen):

| Field | Editable | Notes |
|---|---|---|
| Name | ✅ | free text |
| Weight (g) | ✅ | numeric |
| kcal/100g | ✅ | numeric — the primary correction point |
| Total kcal | computed | `weight_g / 100 × kcal_per_100g`, shown read-only |

- **"Edited" badge**: shown on a card whenever `kcal/100g` was changed from its
  originally saved value (same visual as the Results Screen).
- **Add / delete items**: same `+` button and delete icon per card as Results Screen.
- **Total kcal banner**: recalculates live as the user edits any value.
- **Meal type** chip row and **Notes** field: both editable, pre-filled from the
  saved meal.

#### D.3 — Save behaviour

On "Save changes":

1. Call `MealsRepository.updateMeal(meal.copyWith(items: editedItems, totalKcal: newTotal, mealType: ..., notes: ...))`.
   `updateMeal` already deletes and re-inserts `meal_items`, so no schema change is needed.
2. `context.pop()` back to Meal Detail.
3. Meal Detail's `_mealProvider` is invalidated (same `await push` + `ref.invalidate`
   pattern established in the pending-meal fix) → screen shows updated values immediately.

#### D.4 — Navigation

```
Meal Detail Screen
  └─ [✏ Edit] (AppBar)  →  /history/:id/edit  (MealEditScreen)
                               → [Save changes] → context.pop()
                               → Meal Detail refreshes via ref.invalidate
```

Route added to `app_router.dart`:
```dart
GoRoute(
  path: '/history/:id/edit',
  builder: (context, state) {
    final id = int.parse(state.pathParameters['id']!);
    return MealEditScreen(mealId: id);
  },
),
```

#### D.5 — Reuse of existing components

| Component | Reused as-is | Notes |
|---|---|---|
| `IngredientCard` | ✅ | no changes needed |
| `MealsRepository.updateMeal` | ✅ | already handles item replacement |
| Total-kcal banner widget | extract from `ResultsScreen._TotalBanner` | minor refactor |
| Meal-type chip row | extract from `ResultsScreen._MealTypeRow` | minor refactor |

No new DB schema or packages required.

#### D.6 — Excluded from scope

- Editing the **photo** of an existing meal — out of scope; the photo is already tied
  to the AI analysis and changing it would require a new analysis pass.
- Editing **barcode meals** — the Barcode Result Screen already provides inline editing
  before saving; post-save correction is a separate, lower-priority item.
- Editing **recipe-portion meals** — weight / kcal corrections belong in the Recipe
  Editor; the meal's `total_kcal` is then recalculated on the next "Log a portion".

**Effort:** small-medium (~3–4 h)

---

## DB migration summary

All three features share a single migration block: **v3 → v4**.

```sql
-- ── Barcode cache ─────────────────────────────────────────────────────────
CREATE TABLE cached_products (
  barcode         TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  brand           TEXT,
  pack_size_g     REAL,
  kcal_per_100g   REAL NOT NULL,
  protein_g       REAL,
  carbs_g         REAL,
  fat_g           REAL,
  image_url       TEXT,
  source          TEXT NOT NULL,   -- 'off' | 'manual'
  fetched_at      INTEGER NOT NULL
);

-- ── Recipe tables ─────────────────────────────────────────────────────────
CREATE TABLE recipes (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,
  yield_g       REAL NOT NULL,
  kcal_per_100g REAL NOT NULL,
  photo_path    TEXT,
  notes         TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);

CREATE TABLE recipe_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  recipe_id     INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  weight_g      REAL NOT NULL,
  kcal_per_100g REAL NOT NULL,
  total_kcal    REAL NOT NULL,
  source        TEXT NOT NULL DEFAULT 'manual',
  barcode       TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0
);

-- ── Meals table additions ─────────────────────────────────────────────────
ALTER TABLE meals ADD COLUMN source     TEXT NOT NULL DEFAULT 'camera';
ALTER TABLE meals ADD COLUMN barcode    TEXT REFERENCES cached_products(barcode);
ALTER TABLE meals ADD COLUMN price_chf  REAL;
ALTER TABLE meals ADD COLUMN recipe_id  INTEGER REFERENCES recipes(id) ON DELETE SET NULL;
ALTER TABLE meals ADD COLUMN portion_g  REAL;

-- ── Indexes ───────────────────────────────────────────────────────────────
CREATE INDEX idx_cached_products_fetched ON cached_products(fetched_at);
CREATE INDEX idx_recipe_items_recipe     ON recipe_items(recipe_id);
CREATE INDEX idx_meals_recipe            ON meals(recipe_id);
CREATE INDEX idx_meals_source            ON meals(source);
```

Existing rows: all new `meals` columns default to `NULL` / `'camera'` — safe for
every previously saved meal.

---

## New / changed dependencies summary

| Package | New? | Purpose |
|---|---|---|
| `mobile_scanner ^6.0.0` | ✅ new | Real-time barcode scanning |
| `cached_network_image ^3.3.0` | ✅ new | Cache remote product images from Open Food Facts |
| `fl_chart` | already added (CR-01-E) | No change |
| `share_plus` | already added (CR-01-F) | No change |

---

## New settings fields

Add a collapsed **"Integrations"** section to the Settings screen:

| Field | Key | Default | Notes |
|---|---|---|---|
| Pepesto API key | `pepesto_api_key` | `""` | Leave blank to disable price lookup |

---

## UX flow additions

```
Log tab (updated)
  ├─ [📷 Camera]  →  Capture Screen  →  LLM analysis  →  Results Screen
  ├─ [🔖 Barcode] →  Scanner viewfinder
  │                    → barcode detected
  │                    → lookup (cache → Open Food Facts)
  │                    → Barcode Result Screen
  │                         → [Log this meal] → History
  │                         → [Add to recipe ↗] → Recipe Editor
  └─ Recent meals strip (last 5 chips)
       → tap chip → meal copied to today → toast

Recipes tab (new)
  ├─ Recipe List Screen
  │    → tap card  → Recipe Detail Screen
  │                     → [Log a portion] → Log Portion Sheet → History
  │                     → [Edit recipe]   → Recipe Editor
  └─ [+ New recipe] FAB → Recipe Editor
                              → ingredient picker: text / scan / manual
                              → [Save recipe] → Recipe List

History Screen (additions)
  ├─ Long-press tile → context menu: Copy to today / Delete
  └─ Meal Detail Screen
       └─ [Copy to today] button (merged with CR-01-H Re-log)
```

---

## Error handling additions

| Scenario | Behaviour |
|---|---|
| OFF returns 404 / product not found | Proceed to Step 3 (not-found screen) |
| OFF timeout (> 5 s) | Show "Barcode not found — enter manually" with pre-filled barcode field |
| OFF returns 429 / 5xx | Retry once after 3 s; if still failing, show "Could not reach product database — enter manually" |
| Barcode decoded but malformed EAN | Show "Could not read barcode — try again" toast; re-open scanner |
| Recipe yield\_g = 0 on save | Validation error: "Yield must be greater than 0" inline below the field |
| Copy meal when source photo deleted | Copy succeeds; detail screen shows placeholder image (existing §7 behaviour) |
| Pepesto API credit exhausted | Silently show "—" in price field; no error banner |

---

## Implementation order (suggested)

1. **DB migration v3 → v4** (schema only, no UI) — unblocks everything.
2. **CR-03-D** meal edit screen — self-contained, no schema change, high user value, quick win.
3. **CR-03-A** barcode scanner + Open Food Facts lookup + Barcode Result Screen.
4. **CR-03-B** recipe data model + Recipe List + Recipe Editor (no SFCD bundle yet).
5. **CR-03-B** SFCD asset bundle + ingredient autocomplete.
6. **CR-03-B** Log Portion Sheet + recipe-portion history card.
7. **CR-03-C** copy-meal context menu + Recent meals strip.

---

## Open questions

1. **OFF Swiss coverage verification**: before shipping, scan ~20 products from COOP,
   Migros, ALDI, LIDL, and Denner and verify hit rate. If coverage for a specific chain
   is consistently poor, consider a targeted crowdsourcing campaign via the OFF mobile
   app to fill gaps.
2. **SFCD data export format**: the naehrwertdaten.ch export format may change between
   now and implementation — verify column names before writing the asset-build script.
3. **Photo reference counting**: confirm that all delete paths (swipe-to-delete,
   "Clear all history", individual meal delete) go through a single
   `MealsRepository.deleteMeal()` method so the reference-count check is never bypassed.
4. **recipe_portion meal detail**: decide whether editing a recipe after meals have
   been logged against it should retroactively change those meal's calorie totals.
   Recommendation: do **not** retroactively update — log-time `total_kcal` is
   immutable; only future portions pick up the new kcal\_per\_100g.

---

## Implementation status

| Item | Status | Notes |
|---|---|---|
| CR-03-A | **complete** | Barcode scanner + Open Food Facts + BarcodeMealBuilderScreen implemented |
| CR-03-B | **complete** | Recipe builder fully implemented as of 2026-05-16 |
| CR-03-C | **complete** | Copy-meal action implemented as of 2026-05-16 |
| CR-03-D | **complete** | MealEditScreen implemented; edit available for camera + barcode meals |
