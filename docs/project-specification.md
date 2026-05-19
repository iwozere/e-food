# ForkScale — On-Device Food Calorie Estimator
## Project Specification — current state as of 2026-05-19

---

## 1. Overview

A mobile application (iOS + Android via Flutter) that lets users photograph a plate of food — with a standard fork, knife, or spoon placed beside it as a physical scale reference — and receive an AI-generated calorie and ingredient breakdown. Meals can also be logged via barcode scan or by recording a portion of a saved recipe. All data is stored locally on-device. No backend, no account, no cloud sync; the only outbound network calls are to the Gemini API (photo analysis) and Open Food Facts (barcode lookups).

---

## 2. Goals

- Estimate calories from a photo in under 5–10 seconds (API round-trip included)
- Use fork/knife/spoon as a physical ruler to improve portion estimation accuracy
- Present results as editable ingredient cards so users can correct the AI
- Support barcode scanning for packaged products (no AI call required)
- Support recipe definitions that can be re-logged by portion indefinitely
- Store full meal history locally (photo + ingredients + totals)
- Work offline for history and recipe browsing; only analysis and barcode lookup require network

---

## 3. Platform & Stack

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Flutter 3.x | Single codebase for iOS + Android |
| Language | Dart | Flutter native |
| Vision LLM | Gemini 2.5 Flash API | Higher accuracy; free tier sufficient for personal use |
| Local storage | SQLite via `sqflite` | Structured queries for history/search |
| Image storage | App's local file system (`path_provider`) | Photos stored as JPEG next to DB records |
| State management | Riverpod | Testable, no boilerplate |
| Navigation | go_router | Declarative, deep-link ready, StatefulShellRoute 5-tab bottom nav |
| Barcode | mobile_scanner | ML Kit on Android, AVFoundation on iOS — offline, instant |
| Product lookup | Open Food Facts API | Covers Swiss retailers + international brands; no key required |
| Autocomplete | Swiss Food Composition Database (SFCD) | Bundled SQLite ~220 KB; used in recipe ingredient search |
| Nutrition reference | USDA FoodData Central SR Legacy | Bundled SQLite ~30 MB; `UsdaService` wired into `GeminiService` — USDA `kcal_per_100g` overrides LLM value when a match is found; `usdaMatched` flag shown as "Edited" badge |

> **On-device model (M3) status:** The original specification called for Moondream 2 as the primary on-device model with Gemini as a fallback. This milestone is deferred — no stable Flutter/llama.cpp binding exists. Gemini is currently the sole analysis backend. See ADR-001.

---

## 4. Core Features

### 4.1 Log Tab — Camera Capture

- Full-screen camera viewfinder (`camera` plugin)
- Overlay UI:
  - Framing guide: plate circle + utensil silhouette
  - Instruction banner: "Place utensil beside the plate as scale"
  - Utensil toggle: 🍴 fork / 🔪 knife / 🥄 spoon — shows configured length (cm) on each button
  - Shutter button, gallery-pick button
  - Barcode scanner icon (top-right) — opens full barcode flow
- **Recent meals strip**: horizontal scroll of the last 5 distinct meals below the shutter; tap to re-log instantly; "Logged today" badge when already logged today
- After capture:
  - If Gemini API key is present: "Analysing…" overlay → Results Screen
  - If key missing: snackbar → Settings
  - If rate-limited or network error: snackbar with "Save for later" action → saves as pending meal

### 4.2 Analysis — Gemini Prompt

Image is resized to max 800 px on the longest side (JPEG 85) before the API call. Full-size copy (max 1200 px) is saved to disk in parallel. Both happen in a background isolate.

System prompt (abbreviated):

```
You are a nutrition analyst. A standard dinner [utensil (X cm)] is visible as a scale reference.
1. Detect the utensil and estimate food portion sizes.
2. Identify every distinct food item.
3. Return ONLY valid JSON:
{
  "utensil_detected": bool,
  "scale_confidence": "high|medium|low",
  "items": [{"name","weight_g","kcal_per_100g","total_kcal"}],
  "total_kcal": number,
  "notes": string|null
}
```

### 4.3 Results Screen

- **Total calories banner** — large, live-updating
- **Ingredient cards** — editable per-item: name, weight (g), kcal/100g, total kcal (computed); "Edited" badge when kcal/100g is manually changed; delete button
- **"+ Add item"** button
- **Scale confidence badge** — High / Medium / Low (color-coded)
- **Utensil-not-detected warning** if `utensil_detected` is false
- **Meal type chips** — auto-detected from time; user-adjustable (Breakfast / Lunch / Snack / Dinner)
- **Notes field**
- **"Save meal"** — persists to DB, navigates to History

### 4.4 Barcode Scanner Flow

Entry points: barcode icon on Capture screen; "Add ingredient → Scan barcode" in Recipe Editor.

1. Full-screen scanner viewfinder — haptic feedback on decode; validates EAN-8 to EAN-14 format
2. Lookup chain:
   - **Step 1** — local `cached_products` table (instant, offline)
   - **Step 2** — Open Food Facts API; result cached for 30 days
   - **Step 3** — "Product not found" screen: inline manual-entry form (name, kcal/100g, amount); "Contribute to Open Food Facts" browser link
3. **Barcode Result Screen**: product image (cached_network_image), name (editable), brand, nutrition per 100g (editable), amount stepper (±10 g/ml, default = pack size), live total kcal, meal type chips
   - **"Log this meal"** → saves with `source = 'barcode'`; navigates to History
   - **"Add to recipe"** → when opened from Recipe Editor, pops back with ingredient data instead of navigating
   - **"Add more items"** (only when `forRecipe = false`) → pushes `/barcode-meal-builder` with the current item as `initialItem`; the Meal Builder allows scanning or manually entering further products before logging the combined meal

4. **Barcode Meal Builder** (`/barcode-meal-builder`): multi-item meal assembly screen
   - Item list with per-item weight stepper (±10 g), editable amount field, live kcal, delete button
   - "Scan barcode" button — pushes `/scan` using the existing `forRecipe: true` push+pop pattern; scanned product appended to item list
   - "Add manually" button — bottom sheet with product name, kcal/100g, and amount fields
   - Meal type chips and optional notes field
   - Sticky bottom bar showing item count, total kcal, and "Log meal" button
   - Saved as a single `Meal(source:'barcode', modelUsed:'barcode')` with all `MealItem` rows

### 4.5 Recipes Tab

- **Recipe list**: card grid — recipe photo or food-emoji placeholder, name, kcal/100g, yield
- Long-press a card → context menu: Edit / **Duplicate** / Delete (with confirmation)
  - Duplicate creates a copy with "(copy)" suffix and refreshes the list immediately
- Tap a card → **Recipe Detail Screen**:
  - Photo, name, yield, kcal/100g, notes
  - Read-only ingredient list (name, weight, kcal/100g, total kcal)
  - **"Log a portion"** button → Log Portion Sheet
  - **"Edit recipe"** button (AppBar icon + body button) → Recipe Editor
- **Log Portion Sheet** (modal bottom sheet):
  - Weight picker (step 25 g, default = yield/2), live kcal preview
  - Meal type chips, notes
  - "Log meal" → saves with `source = 'recipe_portion'`, `recipe_id`, `portion_g`; navigates to History
- **Recipe Editor** (new + edit):
  - Fields: name, yield (g), photo (optional), notes
  - **Scale chips** (×½, ×1, ×2, ×3, ×4) above the ingredient list — tapping a preset rescales all ingredient weights and yield proportionally; currently active scale is highlighted
  - Ingredient list with per-card editing (name, weight, kcal/100g, total kcal computed)
  - "Add ingredient" → bottom sheet with three paths:
    - **Search**: SFCD autocomplete (offline, ~1190 items in German)
    - **Scan barcode**: full barcode flow; returns ingredient data on "Add to recipe"
    - **Manual**: blank card
  - Sticky summary bar: total kcal + kcal/100g, live

### 4.6 History Tab

- **Day summary bar** (top): today's date, total kcal vs. daily goal, linear progress bar
- **Weekly bar chart**: last 7 days; tappable bars filter the list to that day; goal shown as dashed horizontal line
- **Filter chips** (horizontal scrollable row): "Starred" (shows only starred meals); meal type chips (Breakfast / Lunch / Dinner / Snack — single-select, clears on re-tap); active day chip (with ×)
- **Search field**: full-text search via SQLite fts4 virtual table (`meals_fts MATCH ?`); falls back to returning all meals when query is cleared
- **Meal list**: thumbnail, name, kcal, meal type + time, star icon, source badge (🔖 Barcode / 🍳 Recipe)
- Swipe left to delete (with confirmation dialog)
- Long-press → context menu: Copy to today / Delete
- Tap → **Meal Detail Screen**:
  - **Camera meals**: photo header, ingredient list (read-only), chips, notes; edit icon in AppBar → Meal Edit Screen; "Copy to today" button
  - **Barcode meals**: product image, nutrition summary; edit icon in AppBar → Meal Edit Screen (same as camera meals); "Copy to today" button
  - **Recipe-portion meals**: portion size, linked recipe; "Go to recipe" / "Edit recipe" shortcuts; "Copy to today" button
- **Meal Edit Screen** (`/history/:id/edit`) — camera and barcode meals (hidden for `recipe_portion`):
  - Same layout as Results Screen: total kcal banner, editable ingredient cards, meal type, notes
  - "Save changes" → pops back to Meal Detail (refreshed); History also refreshes on return

### 4.7 Settings Tab

- **Gemini API key** — enter / update (stored in SharedPreferences; one-time migration from FlutterSecureStorage)
- **Daily calorie goal** — number input (default 2000 kcal)
- **Default utensil** — fork / knife / spoon
- **Utensil lengths** — configurable per utensil in cm (used in Gemini prompt)
- **Storage section**: disk usage summary (DB + photos); **"Export to CSV"** button — serialises all analysed meals with item details; shared via `share_plus`; **"Clear all history"** (with confirmation)
- **Integrations** (collapsed): Pepesto API key for CHF price enrichment on barcode results (optional; no effect if blank)

### 4.8 Insights Tab

Fifth tab (bar chart icon), positioned between History and Settings.

- **Streak card**: consecutive days ending today (or yesterday if today has no meals yet) with at least one logged meal
- **Average daily intake**: 7-day avg kcal and 30-day avg kcal side by side (computed over logged days only, not calendar days)
- **This week**: days logged (of 7) and days over daily goal (of 7)
- **Most logged meals**: top 5 by log frequency — name, count, average kcal per log

All values come from aggregate SQLite queries in `MealsRepository` (`getAvgDailyKcal`, `getCurrentStreak`, `getDaysOverGoal`, `getDaysWithMeals`, `getTopMeals`).

---

## 5. Local Data Model

### 5.1 SQLite Schema (v4)

```sql
CREATE TABLE meals (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at    INTEGER NOT NULL,           -- Unix timestamp ms
  photo_path    TEXT NOT NULL,              -- absolute path; may be '' for barcode/recipe meals
  name          TEXT,
  notes         TEXT,
  total_kcal    REAL NOT NULL,
  utensil       TEXT NOT NULL DEFAULT 'fork',
  scale_conf    TEXT,                       -- 'high' | 'medium' | 'low' | null
  model_used    TEXT NOT NULL,              -- 'gemini' | 'barcode' | 'recipe'
  meal_type     TEXT,                       -- 'breakfast' | 'lunch' | 'snack' | 'dinner'
  pending       INTEGER NOT NULL DEFAULT 0,
  starred       INTEGER NOT NULL DEFAULT 0,
  source        TEXT NOT NULL DEFAULT 'camera',  -- 'camera' | 'barcode' | 'recipe_portion'
  barcode       TEXT REFERENCES cached_products(barcode),
  price_chf     REAL,
  recipe_id     INTEGER REFERENCES recipes(id) ON DELETE SET NULL,
  portion_g     REAL
);

CREATE TABLE meal_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  meal_id       INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  weight_g      REAL NOT NULL,
  kcal_per_100g REAL NOT NULL,
  total_kcal    REAL NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE cached_products (
  barcode       TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  brand         TEXT,
  pack_size_g   REAL,
  kcal_per_100g REAL NOT NULL,
  protein_g     REAL,
  carbs_g       REAL,
  fat_g         REAL,
  image_url     TEXT,
  source        TEXT NOT NULL,              -- 'off' | 'manual'
  fetched_at    INTEGER NOT NULL            -- Unix ms; stale after 30 days
);

CREATE TABLE recipes (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,
  yield_g       REAL NOT NULL,
  kcal_per_100g REAL NOT NULL,             -- derived: SUM(items.total_kcal) / yield_g * 100
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
  source        TEXT NOT NULL DEFAULT 'manual',  -- 'manual' | 'off' | 'swiss_fcd'
  barcode       TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_meals_created          ON meals(created_at DESC);
CREATE INDEX idx_meals_source           ON meals(source);
CREATE INDEX idx_meals_recipe           ON meals(recipe_id);
CREATE INDEX idx_recipe_items_recipe    ON recipe_items(recipe_id);
CREATE INDEX idx_cached_products_fetched ON cached_products(fetched_at);
```

`recipe_portion` meal detail reads ingredients from `recipe_items` via `recipe_id` at display time — they are not duplicated into `meal_items`. The logged `total_kcal` is immutable; editing a recipe does not retroactively change past meal totals.

### 5.2 Photo Storage

- Directory: `{app_documents}/meal_photos/`
- Filename: `{uuid4}.jpg`
- API copy: max 800 px longest side, JPEG 85 (temp, not stored)
- History copy: max 1200 px longest side, JPEG 85 (stored permanently)
- Reference-counted deletion: a file is deleted only when no other meal row references the same `photo_path` (relevant for "Copy to today" which shares the file path)
- Barcode and recipe-portion meals may have an empty `photo_path` — detail screens show a placeholder

---

## 6. UX Flow (Happy Path)

```
App launch → Capture Screen (Log tab)

─── Camera flow ─────────────────────────────────────────────────────────
Capture → shutter → "Analysing…" → Results → "Save meal" → History

─── Pending meal flow ───────────────────────────────────────────────────
Capture (error) → "Save for later" → History → tap pending
  → "Analyze now" → Results → "Save meal" → back to Meal Detail

─── Barcode flow ────────────────────────────────────────────────────────
Capture → [🔖] → Scanner → barcode detected
  → Barcode Result → "Log this meal" → History

─── Recipe flow ─────────────────────────────────────────────────────────
Recipes → [+ New recipe] → Recipe Editor → save → Recipes list
Recipes → tap card → Recipe Detail → "Log a portion"
  → Portion Sheet → "Log meal" → History

─── Copy meal ───────────────────────────────────────────────────────────
History → long-press tile → "Copy to today"   OR
History → tap tile → Meal Detail → "Copy to today"
  → new meal at today's time → History

─── Meal edit ───────────────────────────────────────────────────────────
History → tap tile → Meal Detail → [✏] edit icon
  → Meal Edit Screen → "Save changes" → Meal Detail (refreshed)
  → back → History (refreshed)
```

---

## 7. Error Handling

| Scenario | Behaviour |
|---|---|
| Gemini API key missing | Snackbar with "Settings" action |
| Gemini rate limit (429) | Snackbar with "Save for later" → pending meal |
| Gemini overloaded (503) | Same as rate limit |
| Gemini key invalid (401/403) | Snackbar: "API key invalid — check Settings" |
| JSON parse failure | Snackbar: "Could not read results — please retake photo" |
| Barcode not in Open Food Facts | Inline "Product not found" screen with manual-entry form |
| OFF timeout / 5xx | Same as not found, worded as connectivity error |
| Photo file missing on Detail | Placeholder image; ingredient data intact |
| Recipe yield = 0 on save | Inline validation error below yield field |
| Barcode format invalid | Snackbar: "Could not read barcode — try again" |
| Analysis from Meal Detail, API key missing | Snackbar with "Settings" action |

---

## 8. Privacy & Security

- No analytics, no crash reporters, no telemetry, no third-party SDKs beyond those listed
- Gemini API key stored in OS secure enclave (Keychain on iOS, EncryptedSharedPreferences on Android)
- All data (meals, photos, recipes, cached products) stored locally on-device
- Outbound calls: Gemini API (image + prompt) and Open Food Facts API (barcode lookup) only
- Images sent to Google when using Gemini — disclosed in Settings UI

---

## 9. Milestones — Completion Status

### M1 — Core analysis loop ✅ Complete
- Camera capture with utensil toggle (fork / knife / spoon)
- Gemini Flash API integration + JSON parsing + error handling
- Results screen with editable ingredient cards, live kcal, scale confidence badge
- "Utensil not detected" soft warning

### M2 — Local persistence ✅ Complete
- SQLite schema + sqflite integration (v4)
- Photo pipeline (API resize + history copy, background isolate)
- History screen (list, day summary bar, weekly bar chart)
- Meal detail screen (camera / barcode / recipe-portion variants)
- Pending meal flow (save for later + analyze now)
- Starred meals + swipe-to-delete

### CR-01 — Polish ✅ Complete
- Meal type auto-detection + chip UI
- "Edited" badge on modified ingredient cards
- Settings screen (goal, API key, utensil lengths)

### CR-02 — Refinements ✅ Complete
- Pending meal capture flow
- Analyze now from Meal Detail
- Navigation stack correctness (stale providers, back button, pushReplacement chains)

### CR-03 — Barcode, Recipes, Copy ✅ Complete
- Barcode scanner + Open Food Facts lookup + product cache
- Recipe builder (list, detail, editor, log-portion sheet, SFCD autocomplete)
- Copy meal (context menu, Meal Detail button, recent meals strip)
- Meal edit screen (camera meals)

### Post-CR-03 refinements ✅ Complete
- Edit barcode meals (edit icon now shown for `source != 'recipe_portion'`)
- Recipe duplication (long-press → Duplicate in recipe grid)
- Meal type filter chips in History (Breakfast / Lunch / Dinner / Snack)
- SQLite fts4 full-text search for meal history
- Data export to CSV via `share_plus`
- USDA `kcal_per_100g` lookup wired into `GeminiService` post-analysis
- Recipe scaling (×½–×4 chips in Recipe Editor)
- Insights tab (streak, averages, weekly stats, top meals)
- Multi-item barcode meal builder (`/barcode-meal-builder`, "Add more items" entry point)

### M3 — On-device model ⏸ Deferred
Moondream 2 + llama.cpp binding deferred indefinitely. See ADR-001.

---

## 10. Known Gaps

| Gap | Notes |
|---|---|
| Starred sort | Starred is a filter, not a sort-to-top; "bubble up" not yet implemented |
| Macro tracking | `cached_products` has macros for barcode meals; `meal_items` does not; no macro display anywhere |

See `docs/roadmap.md` for planned improvements.
