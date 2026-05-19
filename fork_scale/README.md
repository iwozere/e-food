# ForkScale

**On-device food calorie estimator.** Photograph a plate of food with a fork, knife, or spoon beside it as a physical scale reference — Gemini AI identifies the ingredients, estimates their weights, and logs the calories. Meals can also be logged via barcode scan or by recording a portion of a saved recipe. No account, no cloud sync, all data stays on device.

---

## Features

### Log tab — camera analysis
- Tap the shutter (or pick from gallery) to capture a photo; the utensil in the frame is used as a ruler to estimate portion sizes
- Gemini 2.5 Flash identifies ingredients, estimates weights, and returns kcal/100g values
- Photos can be saved as **pending** (analyzed later) if the API is unavailable — tap "Analyze now" from History any time
- **Barcode scanner** (top-right icon) — scan any EAN-8 to EAN-14 barcode; nutrition data fetched from Open Food Facts (covers Swiss retailers and international products); results cached locally for 30 days
- **Multi-item barcode meals** — tap "Add more items" on any barcode result to open the Meal Builder; scan or enter additional products and log them as a single combined meal entry
- **Recent meals strip** — horizontal scroll of the last 5 distinct meals; tap a chip to re-log it instantly to today; "Logged today" badge appears if already done

### Recipes tab
- Create and manage recipes with ingredients sourced three ways: **search** from the Swiss Food Composition Database (SFCD, ~1190 items, offline), **barcode scan**, or **manual entry**
- Yield weight and kcal/100g are calculated automatically from ingredients; the summary bar updates live
- **Scale chips** (×½, ×1, ×2, ×3, ×4) in the Recipe Editor rescale all ingredient weights and yield proportionally — useful for double batches or halved portions
- Tap a recipe to view the full ingredient list and **log a portion** — weight picker with live kcal preview
- Long-press a recipe card for Edit / **Duplicate** / Delete

### History tab
- **Day summary bar**: today's total kcal vs. daily goal (configurable) with a progress bar
- **Weekly bar chart**: last 7 days; tap a bar to filter the list to that day; goal shown as a dashed line
- **Filter chips**: starred meals; meal type (Breakfast / Lunch / Dinner / Snack); active day; all combinable
- **Full-text search** across meal names and notes (SQLite fts4)
- Tap a meal to view details; long-press for a context menu (Copy to today / Delete)
- **Meal edit** — tap the ✏ icon on any camera or barcode meal to correct weights, kcal/100g, meal type, or notes; History and the day chart refresh on return
- Barcode meals show product image and nutrition info; recipe-portion meals link back to the source recipe with "Go to recipe" / "Edit recipe" shortcuts
- Safe photo deletion: the file is only removed when no other meal references the same path (relevant after "Copy to today")

### Insights tab
- **Streak**: consecutive days with at least one logged meal
- **Average daily intake**: 7-day and 30-day averages side by side
- **This week**: days logged and days over goal (out of 7)
- **Top 5 most-logged meals**: by frequency, with average kcal per log

### Settings tab
- Enter and save your **Gemini API key** (stored in SharedPreferences)
- Configure **daily calorie goal** (default 2000 kcal)
- Set **default utensil** and fine-tune **utensil lengths** (cm) used in the Gemini prompt
- **Export to CSV** — share all meal history as a CSV file via the system share sheet
- **Integrations** section (collapsed): optional Pepesto API key for CHF pricing on Swiss products

---

## Tech stack

| Layer | Library |
|---|---|
| UI | Flutter 3.x (Material 3) |
| State | flutter_riverpod |
| Navigation | go_router (StatefulShellRoute — 5-tab bottom nav) |
| AI vision | Gemini 2.5 Flash API via `http` |
| Local DB | sqflite v4 (`fork_scale.db`) |
| Nutrition reference | USDA FoodData Central SR Legacy (bundled SQLite, ~30 MB) — wired into `GeminiService`; overrides LLM kcal/100g when a match is found |
| Autocomplete | Swiss Food Composition Database v7 (bundled SQLite, ~220 KB, built via `tool/build_sfcd.py`) |
| Barcode | mobile_scanner (ML Kit / AVFoundation) |
| Product lookup | Open Food Facts API (no key required) |
| Secure storage | flutter_secure_storage (API key) |
| Image cache | cached_network_image (barcode product images) |

---

## Navigation routes

```
Shell (bottom nav)
  /              Log tab — camera
  /recipes       Recipes tab
  /history       History tab
  /insights      Insights tab
  /settings      Settings tab

Full-screen (no bottom nav)
  /results              Analysis results
  /scan                 Barcode scanner
  /barcode-result       Barcode product detail / log screen
  /barcode-meal-builder Multi-item barcode meal builder
  /history/:id          Meal detail
  /history/:id/edit     Meal edit screen
  /recipes/new          New recipe editor
  /recipes/:id          Recipe detail
  /recipes/:id/edit     Edit existing recipe
```

---

## Local database schema (v4)

```sql
meals            — id, created_at, photo_path, name, notes, total_kcal,
                   utensil, scale_conf, model_used, meal_type, pending,
                   starred, source, barcode, price_chf, recipe_id, portion_g
meal_items       — id, meal_id, name, weight_g, kcal_per_100g, total_kcal, sort_order
cached_products  — barcode PK, name, brand, pack_size_g, kcal_per_100g,
                   protein_g, carbs_g, fat_g, image_url, source, fetched_at
recipes          — id, name, yield_g, kcal_per_100g, photo_path, notes,
                   created_at, updated_at
recipe_items     — id, recipe_id, name, weight_g, kcal_per_100g, total_kcal,
                   source, barcode, sort_order
```

`meal.source` values: `camera` | `barcode` | `recipe_portion`  
`recipe_item.source` values: `manual` | `off` (Open Food Facts) | `swiss_fcd`

---

## Getting started

### Prerequisites
- Flutter SDK ≥ 3.10.7 / Dart ≥ 3.10.7
- A [Gemini API key](https://aistudio.google.com/app/apikey) (free tier works)
- Python 3.9+ with `openpyxl` (for the SFCD asset build step)

### 1. Clone and install
```powershell
git clone <repo-url>
cd fork_scale
flutter pub get
```

### 2. Build the Swiss Food Composition Database asset
The SFCD SQLite file is not committed to git (built from the official BLV/OSAV export).

```powershell
pip install openpyxl
python tool/build_sfcd.py
```

This downloads the latest XLSX from `naehrwertdaten.ch`, parses ~1190 food items, and writes `assets/db/sfcd.db`. The asset is already declared in `pubspec.yaml`.

> The app runs without this file — ingredient autocomplete in the recipe editor will simply return no results until the asset is present.

### 3. Run
```powershell
flutter run
```

On first launch, open **Settings** and paste your Gemini API key.

---

## Architecture decisions

| ADR | Decision |
|---|---|
| ADR-001 | On-device Moondream model deferred — no stable Flutter binding exists. Gemini-only for now. |
| ADR-002 | USDA FoodData Central SR Legacy bundled as a Flutter asset. `UsdaService` wired into `GeminiService` — USDA kcal/100g overrides LLM value when a match is found; falls back to LLM value silently. |
| ADR-003 | go_router `StatefulShellRoute.indexedStack` with 5 tabs (Log / Recipes / History / Insights / Settings). Full-screen routes use `context.push` (not `go`) so the shell branch stays in the back stack. |
| ADR-004 | Images resized to max 800 px (JPEG 85) before the Gemini API call; 1200 px copy saved to disk in parallel. Both run in a background isolate. |
| ADR-005 | Color palette: primary `#1B4332` (dark green), background `#FFF8F0` (warm cream), accent `#F4A523` (amber), error `#D62828`. |
| ADR-006 | Open Food Facts API is the single barcode lookup endpoint (covers all Swiss retailers + international). Pepesto API for CHF pricing is optional (key in Settings → Integrations). |
| ADR-007 | SFCD bundled as `assets/db/sfcd.db`, built at dev time via `tool/build_sfcd.py`. App returns empty autocomplete results gracefully if asset is missing. |
| ADR-008 | `recipe_portion` meals store only `recipe_id` + `portion_g`; ingredients are read from `recipe_items` at display time, not duplicated. Logged `total_kcal` is immutable — recipe edits do not retroactively change past meal totals. |
| ADR-009 | Reference-counted photo deletion: `deleteMeal()` checks `COUNT(*) FROM meals WHERE photo_path = ?` before removing the file. "Copy to today" shares file paths without duplicating files. |
| ADR-010 | Barcode scanner uses `context.push` (not `pushReplacement`) to the result screen, then forwards the return value with `context.pop(result)`. This keeps the `/scan` future alive so the Recipe Editor's `.then()` callback receives ingredient data. |
| ADR-011 | History search uses SQLite fts4 (not fts5 — not available in default iOS/Android SQLite builds). `meals_fts MATCH ?` is issued via `_searchMeals`; activated automatically when `getMeals(searchQuery:)` is called. |
| ADR-012 | Recipe scaling uses ratio-based in-place mutation (`ratio = target / _multiplier`). Keeping immutable base items was rejected as it requires unscaling user edits on every callback. `_IngredientRow.didUpdateWidget` syncs weight controllers when scaling fires. |
| ADR-013 | Multi-item barcode meal builder uses a dedicated `/barcode-meal-builder` route and `BarcodeMealBuilderScreen`. "Add more items" on `BarcodeResultScreen` passes the current item as `initialItem`; subsequent scans reuse the existing `forRecipe: true` push+pop pattern unchanged. |

---

## Privacy

- No analytics, no telemetry, no cloud sync
- All data (meals, photos, recipes, cached products) is stored locally on the device
- The Gemini API key is stored in the OS secure enclave (Keychain on iOS, EncryptedSharedPreferences on Android)
- Outbound network calls: Gemini API (photo + prompt) and Open Food Facts API (barcode lookups) only
