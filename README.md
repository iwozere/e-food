# ForkScale

A mobile app (iOS + Android) that estimates the calories in a meal from a single photo. Place a **fork or knife** beside the plate as a physical scale reference, snap a picture, and get an ingredient-by-ingredient calorie breakdown in under five seconds — all stored locally, no account required.

---

## How it works

1. **Capture** — the camera screen prompts you to place a fork (18.5 cm) or knife (21 cm) next to the plate before shooting.
2. **Analyse** — the photo is sent to Gemini 2.5 Flash, which uses the utensil as a ruler to estimate plate size and portion weights, then identifies every food item on the plate.
3. **Enrich** — calorie density (kcal/100 g) is looked up from a bundled USDA FoodData Central database rather than trusted from the AI, so nutrition figures are auditable and consistent.
4. **Review & edit** — results appear as editable ingredient cards. Adjust any weight or calorie value; totals recalculate live.
5. **Save** — meals are persisted to an on-device SQLite database alongside a resized JPEG. Nothing leaves the device except the single Gemini API call.

---

## Key design choices

| Decision | Choice | Why |
|---|---|---|
| Framework | Flutter 3.x / Dart | Single codebase for iOS + Android |
| State management | Riverpod | Testable providers, no boilerplate |
| Navigation | go_router | Declarative, deep-link-ready |
| Vision AI | Gemini 2.5 Flash (cloud) | Reliable JSON output; free tier covers personal use |
| Nutrition data | USDA FoodData Central SQLite (~30 MB, bundled) | AI hallucinates kcal values; USDA is authoritative |
| Local storage | sqflite (SQLite) + `path_provider` | Structured queries, full-text search, no cloud sync |
| Image pipeline | `image` package in background `Isolate` | Resize to 800 px for API call, 1200 px for storage, off the main thread |
| API key storage | Flutter Secure Storage (Keychain / Keystore) | OS secure enclave; never written to disk in plaintext |

For the full rationale behind these choices, including trade-offs considered and options rejected, see [docs/architecture-decisions.md](docs/architecture-decisions.md).

---

## Project structure

```
e-food/
├── docs/
│   ├── project-specification.md   # Full product spec: features, data model, UX flows, milestones
│   └── architecture-decisions.md  # ADRs: deviations from spec agreed before implementation
│
└── fork_scale/                    # Flutter application
    ├── assets/
    │   └── db/
    │       └── usda_nutrition.db  # Bundled USDA nutrition database (run scripts/build_usda_db.py to rebuild)
    │
    ├── scripts/
    │   └── build_usda_db.py       # Downloads USDA SR Legacy JSON and builds usda_nutrition.db
    │
    ├── android/                   # Android host project
    │   └── app/
    │       └── src/main/
    │           └── AndroidManifest.xml
    ├── ios/
    │   └── Runner/
    │       └── Info.plist
    │
    └── lib/
        ├── main.dart
        ├── models/
        │   ├── meal.dart           # Meal entity (maps to SQLite `meals` table)
        │   ├── meal_item.dart      # Ingredient line-item
        │   └── analysis_result.dart# Transient result from Gemini, passed to Results screen
        │
        ├── core/
        │   ├── database/
        │   │   ├── app_database.dart      # Opens meals DB + copies USDA asset on first launch
        │   │   └── meals_repository.dart  # CRUD, FTS search, day-total queries
        │   ├── router/
        │   │   └── app_router.dart        # go_router route map
        │   ├── services/
        │   │   ├── gemini_service.dart    # Gemini REST call, JSON parse, key validation
        │   │   ├── image_service.dart     # Resize in Isolate (800 px API / 1200 px storage)
        │   │   ├── usda_service.dart      # Fuzzy kcal/100 g lookup against USDA DB
        │   │   └── providers.dart         # Riverpod providers (API key, services, daily goal)
        │   └── theme/
        │       └── app_theme.dart         # Color palette and Material 3 theme
        │
        └── features/
            ├── capture/
            │   └── capture_screen.dart    # Camera viewfinder, utensil toggle, gallery pick
            ├── results/
            │   ├── results_screen.dart    # Editable ingredient cards, live kcal total, save
            │   ├── results_notifier.dart  # StateNotifier for in-flight edits
            │   └── ingredient_card.dart   # Single editable card (name, weight stepper, kcal)
            ├── history/
            │   ├── history_screen.dart    # Timeline list, day summary bar, search
            │   └── meal_detail_screen.dart# Read-only meal view with photo header
            └── settings/
                └── settings_screen.dart  # API key (with live validation), utensil default, daily goal, storage
```

---

## Getting started

### Prerequisites

- Flutter 3.x (`flutter doctor` should report no issues for Android/iOS)
- A **Gemini API key** — free, no credit card required:
  1. Sign in at [aistudio.google.com](https://aistudio.google.com) with any Google account.
  2. Click **Get API key → Create API key**.
  3. Copy the key (starts with `AIza…`) and paste it into the app's **Settings** screen.
  > Free tier limits: 10 requests/minute, 250 requests/day — sufficient for personal use.
- Android: SDK platform 35+, NDK 28.x (installed via SDK Manager)
- iOS: Xcode 15+, CocoaPods

### 1 — Build the USDA nutrition database

The bundled `assets/db/usda_nutrition.db` ships with 20 seed rows for development. Before running in production, replace it with the full ~8 800-food dataset:

```bash
cd fork_scale
pip install requests          # one-time
python scripts/build_usda_db.py
```

The script downloads the USDA FoodData Central SR Legacy JSON (~45 MB), extracts energy values, and writes `assets/db/usda_nutrition.db`.

### 2 — Run the app

```bash
cd fork_scale
flutter pub get
flutter run
```

On first launch, open **Settings** and paste your Gemini API key. The app validates the key against the Gemini models endpoint before saving it.

---

## Screens

| Screen | Route | Description |
|---|---|---|
| Capture | `/` | Full-screen camera with utensil toggle and gallery fallback |
| Results | `/results` | Editable ingredient cards; live-updating calorie total |
| History | `/history` | Scrollable meal timeline; day summary bar vs. daily goal |
| Meal detail | `/history/:id` | Photo + ingredients read-only view |
| Settings | `/settings` | API key, utensil default, daily goal, storage management |

---

## Documents

- [Project specification](docs/project-specification.md) — goals, full feature list, data model, UX flow, error-handling table, milestones
- [Architecture decisions](docs/architecture-decisions.md) — ADR-001 through ADR-005: deferred on-device model, USDA nutrition database, go_router, image resize strategy, color palette
