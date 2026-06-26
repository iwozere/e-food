# Implementation status & remaining follow-ups — 2026-06-25

Tracks execution of `docs/implementation-plan-2026-06-24.md`. All shipped work
keeps `flutter analyze` clean and the test suite green (58 tests).

## Done

| Task | Summary |
|---|---|
| T0.1 | GitHub Actions CI (`.github/workflows/flutter-ci.yml`): analyze + test on push/PR; README badge. |
| T0.2 | Gemini key moved back to `FlutterSecureStorage`; inverted one-time migration in `geminiApiKeyProvider`; spec §8 + memory updated. |
| T0.3 | Removed "On-device model (coming soon)" vaporware label. |
| T0.4 | `ImageService.downloadAndSave` rejects non-`https` URLs; unit-tested. |
| T0.5 | Gemini `responseMimeType` + `responseSchema` (structured JSON). |
| T1.1 | Eval harness (`tool/eval/run_eval.dart` + manifest + runbook); baseline placeholder. **Dataset collection (weighed plates) is the remaining human task.** |
| T1.2 | USDA match-confidence scorer + threshold (weak matches keep the LLM value); unit-tested. |
| T1.3 | Extracted pure `GeminiService.parseResponse`; defensive per-item parsing (skips malformed, surfaces a note); 8 fixture tests. |
| T1.4 | Extracted pure `BackupService.extractArchive`; zip-slip + restore tests. |
| T1.5 | `MealsRepository.sanitizeFtsQuery` unit tests; log→History refresh test (repo + provider wiring). |
| T2.1 | Localization scaffolding (en + de), `flutter_localizations`, codegen, `MaterialApp` delegates. |
| T2.2 | **First pass:** Settings + Capture fully localized with German. Remainder documented in `l10n-extraction-status.md`. |
| T3.1 | Single canonical schema source (`_createSchema(db, {withFts})` + DDL constants reused in migrations). |
| T3.2 | `CaptureController` with typed outcomes + orphan-photo cleanup; 10 unit tests; widget reduced to UI. |
| T4.1 | Vector `ForkIcon`/`KnifeIcon`/`SpoonIcon` (`widgets/utensil_icons.dart`) replacing 🔪/🥄 in capture + settings. |
| T4.4 | First-run privacy disclosure dialog (photos → Google Gemini); acknowledgement persisted. |
| T4.5 | Removed dead `Meal.priceChf` plumbing; DB column marked deprecated. |
| T4.6 | Low scale-confidence → dismissible nudge with Retake action. |
| T4.7 | Raw error-detail dialog gated behind `kDebugMode`. |

## Previously-deferred items — now complete (2026-06-25, second pass)

All items below were finished after the first pass; analyze stays clean and the
suite is green (64 tests).

### T2.2 — String extraction (complete)
All 12 screens localized with German: capture, settings, results, ingredient
card, history, meal detail, meal edit, insights, recipes (list/detail/editor),
log-portion sheet, barcode (scanner/result/builder), plus `MealTypeSelector`.
`DateFormat` calls now take the active locale; `initializeDateFormatting()` runs
in `main()` so `de` dates work. Shared `mealTypeLabel` helper.

### T3.3 — State-model unification (complete for recipes)
Added `RecipesRepository.changes` + `recipesChangesProvider`; the recipe list
and detail providers watch it and refetch by construction. Manual
`ref.invalidate`/`onRefresh` chains removed from the recipe screens. Covered by
`test/recipes_changes_test.dart`. (Meals already had `mealsChangesProvider`.)

### T3.4 — Shared widgets (complete)
Extracted to `lib/widgets/`: `TotalBanner` (results + meal-edit), `utensil_icons`
(`ForkIcon`/`KnifeIcon`/`SpoonIcon`), `meal_type_label` helper; plus
`core/util/decimal_input_formatter.dart`. All call sites migrated.

### T4.2 — Text-scale & contrast (complete)
Capture recent-meals strip height now scales with the user's text scale (capped
at 1.6×); white-on-viewfinder text already sits on `black54`/`black38` scrims.

### T4.3 — Input validation (complete)
`DecimalInputFormatter` (digits + a single decimal point; `1.2.3` unenterable)
replaces the loose `[\d.]` filter across ingredient card, recipe editor, and
recipe yield. 0-kcal manual barcode entry warns (doesn't block). Tested in
`test/decimal_input_formatter_test.dart`.

### T4.8 — Misc (complete)
Confirmed clear/restore re-init in-process (no "restart" copy anywhere). Added
`docs/release-and-assets.md` (versioning convention + USDA/SFCD regeneration
runbook + size guidance). Optional dark theme intentionally left (it was
optional in the review).

## Intentionally out of scope (per the review)
Certificate pinning; the stringly-typed/static-singleton DB refactor — both
judged out-of-scope at this product tier in `review-2026-06-24.md`.
