# ForkScale

**On-device food calorie estimator.** Photograph a plate of food with a fork, knife, or spoon beside it as a physical scale reference — Gemini AI identifies the ingredients, estimates their weights, and logs the calories. No account, no cloud sync, all data stays on device.

---

## Features

### Log tab — camera analysis
- Tap the shutter to capture a photo; the utensil in the frame is used as a ruler to estimate portion sizes
- Gemini 2.5 Flash (vision) identifies ingredients, estimates weights, and returns kcal/100g values cross-referenced against the bundled USDA FoodData Central SR Legacy database
- Photos can be saved as **pending** (analyzed later) or immediately sent to Gemini
- **Barcode scanner** (top-right icon) — scan any EAN-8/13 or QR barcode; nutrition data fetched from Open Food Facts (covers Swiss retailers and international products); results cached locally for 30 days
- **Recent meals strip** — horizontal scroll of the last 5 distinct meals; tap a chip to re-log it instantly to today

### Recipes tab
- Create and manage recipes with ingredients sourced three ways: manual entry, barcode scan, or autocomplete from the Swiss Food Composition Database (SFCD, German-language, ~1 190 items)
- Yield weight and kcal/100g are calculated automatically from ingredients
- Long-press a recipe card for Edit / Duplicate / Delete
- Tap a recipe to view the full ingredient list and log a portion (weight picker with live kcal preview)

### History tab
- Full log of all meals sorted by date; starred meals bubble up
- Filter by meal type (Breakfast / Lunch / Dinner / Snack)
- Tap a meal to view details; long-press for a context menu (Copy to today / Delete)
- Barcode meals show product image and pack-size info; recipe-portion meals link back to the source recipe with "Go to recipe" / "Edit recipe" shortcuts
- Safe photo deletion: the file is only removed when no other meal references the same path

### Settings tab
- Enter and save your **Gemini API key** (stored in Flutter Secure Storage, never leaves the device)
- Configure utensil lengths (fork / knife / spoon) for more accurate scale estimation
- **Integrations** section (collapsed): optional Pepesto API key for CHF pricing on Swiss products

---

## Tech stack

| Layer | Library |
|---|---|
| UI | Flutter 3.x (Material 3) |
| State | flutter_riverpod + riverpod_generator |
| Navigation | go_router (StatefulShellRoute — 4-tab bottom nav) |
| AI vision | Gemini 2.5 Flash API (`google/generative-ai`) via `http` |
| Local DB | sqflite v4 (`fork_scale.db`) |
| Nutrition reference | USDA FoodData Central SR Legacy (bundled SQLite, ~30 MB) |
| Autocomplete | Swiss Food Composition Database v7 (bundled SQLite, ~220 KB, built via `tool/build_sfcd.py`) |
| Barcode | mobile_scanner (ML Kit / AVFoundation) |
| Product lookup | Open Food Facts API (no key required) |
| Secure storage | flutter_secure_storage (API key) |
| Image cache | cached_network_image (barcode product images) |

---

## Navigation routes

```
/ (Log tab — camera)
/recipes (Recipes tab)
/history (History tab)
/settings (Settings tab)

/results              — Analysis results (full-screen, no nav bar)
/scan                 — Barcode scanner (full-screen)
/barcode-result       — Barcode product detail / log screen
/history/:id          — Meal detail
/recipes/new          — New recipe editor
/recipes/:id          — Recipe detail
/recipes/:id/edit     — Edit existing recipe
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
- Python 3.9+ with `openpyxl` (for the SFCD asset build step below)

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

This downloads the latest XLSX from `naehrwertdaten.ch`, parses ~1 190 food items, and writes `assets/db/sfcd.db`. The asset is already declared in `pubspec.yaml`.

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
| ADR-002 | USDA FoodData Central SR Legacy bundled as a Flutter asset. LLM estimates weights only; kcal/100g resolved from USDA with fuzzy matching. Falls back to LLM value with a warning if no match found. |
| ADR-003 | go_router `StatefulShellRoute.indexedStack` with 4 tabs (Log / Recipes / History / Settings). Full-screen routes (results, scanner, detail screens) are outside the shell. |
| ADR-004 | Images are resized to max 800 px longest side (JPEG 85) before the Gemini API call; a 1200×1200 copy is saved to disk in parallel. Resize runs in a background isolate. |
| ADR-005 | Color palette: primary `#1B4332` (dark green), background `#FFF8F0` (warm cream), accent `#F4A523` (amber), error `#D62828`. |
| ADR-006 | Open Food Facts API is the single barcode product lookup endpoint (covers all Swiss retailers + international). Pepesto API for CHF pricing is optional enrichment (key in Settings → Integrations). |
| ADR-007 | SFCD bundled as `assets/db/sfcd.db`, built at dev time via `tool/build_sfcd.py`. App returns empty autocomplete results gracefully if asset is missing. |
| ADR-008 | `recipe_portion` meal detail reads ingredients from `recipe_items` via `recipe_id` at display time (not duplicated). Editing a recipe after a meal is logged does **not** retroactively change that meal's `total_kcal`. |
| ADR-009 | Photo reference counting in `deleteMeal()`: checks `COUNT(*) FROM meals WHERE photo_path = ?` before deleting the file on disk. Multiple meals can share a path (via "Copy to today"). |

---

## Privacy

- No analytics, no telemetry, no cloud sync
- All data (meals, photos, recipes, cached products) is stored locally on the device
- The Gemini API key is stored in the OS secure enclave (Keychain on iOS, EncryptedSharedPreferences on Android)
- The only outbound network calls are to the Gemini API (photo + prompt) and the Open Food Facts API (barcode lookups)
