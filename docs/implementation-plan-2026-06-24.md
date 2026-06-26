# ForkScale — Implementation Plan to Address the 2026-06-24 Review

**Source:** `docs/review-2026-06-24.md`
**Date:** 2026-06-24
**Goal:** A concrete, sequenced plan that closes every finding in the multi-stakeholder review — from the 9 consolidated priorities down to the per-section ⚪ items.

**How to read this:** Work is grouped into 5 phases ordered by leverage (evidence and honest claims first, polish last). Each task lists scope, files, steps, acceptance criteria, and effort. A traceability matrix in §7 maps every review finding to its task ID so nothing is dropped.

Effort key: **XS** < 1h · **S** = hours · **M** = 1–3 days · **L** = 3+ days.

---

## Phase 0 — Quick wins (do first; mostly XS, unblock the green)

These are cheap, independent, and de-risk later phases.

### T0.1 — CI: gate merges on `analyze` + `test` 🟠
- **Maps to:** §7 (DevOps), Priority #3 (CI half)
- **Files:** new `.github/workflows/flutter-ci.yml`
- **Steps:**
  1. Workflow on `push` + `pull_request`: `subosito/flutter-action` pinned to the project's Flutter version, then `flutter pub get`, `flutter analyze`, `flutter test`.
  2. Add a status badge to the repo README.
- **Acceptance:** A PR with a lint error or failing test is blocked. Current `main` passes (already verified: analyze clean, 21 tests green).
- **Effort:** XS

### T0.2 — Move Gemini key back to secure storage 🟡
- **Maps to:** §6.1 (Security), Priority #5
- **Files:** `lib/core/services/providers.dart` (`geminiApiKeyProvider`), `lib/features/settings/settings_screen.dart` (`_saveApiKey`, `_loadApiKey`/migration block), `docs/project-specification.md` §8, `project_overview.md` memory.
- **Steps:**
  1. Change `geminiApiKeyProvider` to read from `FlutterSecureStorage`.
  2. Reverse the migration: on first run after this change, if a key exists in `SharedPreferences`, write it to secure storage and `remove` it from prefs (mirror of the existing one-time migration, inverted).
  3. `_saveApiKey`: write/delete via secure storage; keep the validate-then-save UX intact.
  4. Update spec §8 to state the key is encrypted at rest again; update the memory note.
- **Acceptance:** Fresh + upgrade installs read/write the key only via secure storage; `grep gemini_api_key` shows no `SharedPreferences` writes; key absent from `shared_prefs/*.xml` on a test device.
- **Effort:** S
- **Alt:** If the original migration *out* of secure storage was due to a real plugin bug, instead write `docs/adr/ADR-010-api-key-storage.md` documenting the decision and close this as "won't fix, justified." Don't leave it implicit.

### T0.3 — Remove vaporware "coming soon" copy ⚪
- **Maps to:** §8.5 (prior review), §1 (positioning)
- **Files:** `settings_screen.dart:419` ("On-device model (coming soon)").
- **Steps:** Delete the label (and any associated disabled row) until M3 is actually scheduled.
- **Acceptance:** No "coming soon" / on-device claims in the UI.
- **Effort:** XS

### T0.4 — `https`-scheme check on remote image download ⚪
- **Maps to:** §6 (Security, image download)
- **Files:** `lib/core/services/image_service.dart` (`downloadAndSave`).
- **Steps:** Reject non-`https` URLs before fetching; return `null`.
- **Acceptance:** Unit test: `http://…` and non-URL inputs return null without a network call.
- **Effort:** XS

### T0.5 — Gemini structured JSON output 🟡
- **Maps to:** §4 (ML, no response schema)
- **Files:** `gemini_service.dart` (`generationConfig`).
- **Steps:** Add `responseMimeType: 'application/json'` and a `responseSchema` matching the documented item shape. Keep `_repairTruncated` as a belt-and-braces fallback.
- **Acceptance:** Markdown-fence stripping becomes dead-but-harmless; parse-failure rate drops in the eval run (T1.1). Covered by parser tests (T1.3).
- **Effort:** S

---

## Phase 1 — Evidence & correctness (the core gaps)

The review's headline: the product's accuracy is unmeasured and the USDA override can silently harm it. This phase makes quality *measurable* and *defensible*.

### T1.1 — Accuracy evaluation harness + baseline 🟠 ⭐
- **Maps to:** §1 (PO), §4 (ML), Priority #1
- **Files:** new `tool/eval/` (dataset manifest + runner), `docs/eval-baseline-2026-06.md`.
- **Steps:**
  1. Assemble 30–50 labelled photos: each with ground-truth total kcal and per-item weights (use packaged foods / scale-weighed plates so truth is real). Store images outside the app bundle; manifest as JSON/CSV.
  2. Build a runner (standalone Dart `tool/eval/run_eval.dart`, or an `integration_test` gated by `--dart-define=GEMINI_KEY=…`) that calls the real `GeminiService.analyzeImage` per photo with the configured utensil length.
  3. Compute and report: MAE and MAPE on total kcal, MAE on per-item weight, utensil-detection rate, parse-failure rate. Emit a markdown report.
  4. Commit the first run as the baseline.
- **Acceptance:** `dart run tool/eval/run_eval.dart` (with a key) produces metrics and a report; baseline committed; runbook documented. Network/key-gated so normal CI skips it.
- **Effort:** L (dataset collection dominates)
- **Note:** This unblocks any "accurate" marketing claim and gives T1.2/T0.5/T1.5 a measurable target.

### T1.2 — USDA match-confidence threshold 🟠
- **Maps to:** §4 (ML), §2 (architect, LIKE scan), Priority #2
- **Files:** `lib/core/services/usda_service.dart`, `gemini_service.dart:163` (consumption).
- **Steps:**
  1. Have `lookup` return candidates with a **score** (token-overlap / Jaccard between query tokens and description tokens, plus a length/specificity penalty) rather than "shortest description wins" (`usda_service.dart:30-33`).
  2. Require a minimum score to accept the USDA value; below it, return null so the LLM value is kept and `usdaMatched=false` (don't mislabel a weak match as authoritative).
  3. Optionally back the lookup with an FTS index on `foods.description` to replace the non-sargable `LIKE '%w%'` scans (build into the asset via the existing asset-build tooling).
- **Acceptance:** Unit tests: `"grilled chicken"` does **not** silently adopt `"chicken, skin only"`; a clearly-matching name does; low-confidence keeps the LLM value. Re-run T1.1 to confirm MAE does not regress (ideally improves).
- **Effort:** M

### T1.3 — Unit tests: Gemini parse/repair + per-field robustness 🟠
- **Maps to:** §3 (QA), §4 (defensive parsing), Priority #3
- **Files:** new `test/gemini_parse_test.dart`; refactor `gemini_service.dart` to expose the parser.
- **Steps:**
  1. Extract the pure parsing from `_parseAndEnrich` into a testable function (e.g. `@visibleForTesting` static, or a separate `parseGeminiJson(String) -> GeminiAnalysisResult` taking an injectable `UsdaService`). Inject a fake `UsdaService` returning null to avoid the DB.
  2. Make item parsing defensive: skip a malformed item (missing/mistyped `name`/`weight_g`) instead of throwing the whole meal away; surface a note.
  3. Fixtures: clean JSON, ```json-fenced, truncated-recoverable, truncated-unrecoverable, missing fields, empty items, non-numeric numbers.
- **Acceptance:** Tests cover each fixture; a meal with one bad item still returns the good ones.
- **Effort:** S

### T1.4 — Tests: BackupService zip-slip + WAL handling 🟠
- **Maps to:** §3 (QA), Priority #3
- **Files:** new `test/backup_service_test.dart`; refactor `backup_service.dart` to expose pure extraction.
- **Steps:**
  1. Extract the archive-iteration/write loop into a pure `extractArchive(Archive archive, String docsPath)` (decoupled from `FilePicker`).
  2. Test: a crafted archive with a `../../evil.txt` entry writes **nothing** outside `docsPath` (assert the guard at `backup_service.dart:73` holds); a normal archive restores files correctly.
  3. Document WAL-sidecar deletion behaviour as a test note (FFI can't fully exercise WAL replay).
- **Acceptance:** Traversal entry is dropped; legit entries land under `docsPath`.
- **Effort:** S

### T1.5 — FTS sanitizer unit test + integration smoke for log→History 🟡
- **Maps to:** §3 (QA — FTS untested, navigation staleness)
- **Files:** new `test/fts_sanitize_test.dart`; new `integration_test/log_flow_test.dart`.
- **Steps:**
  1. Unit-test `_sanitizeFtsQuery` (extract/expose it): unbalanced quotes, FTS operators, empty → safe tokens. (Pure string transform; runs under FFI even though MATCH doesn't.)
  2. One `integration_test`: log a meal (recipe-portion or barcode path), switch to History, assert the new meal + day total appear — guarding the `mealsChangesProvider` refresh path that historically broke (`docs/issues.md`).
- **Acceptance:** Both tests pass locally; integration test added to a (non-CI-blocking) device job.
- **Effort:** M

---

## Phase 2 — Audience readiness (the Swiss/German gap)

### T2.1 — Localization scaffolding (de + en) 🟠
- **Maps to:** §1 (PO), §5 (UX), Priority #4
- **Files:** new `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`; `pubspec.yaml` (`flutter_localizations`, `generate: true`); `lib/main.dart` (`localizationsDelegates`, `supportedLocales`).
- **Steps:**
  1. Add `flutter_localizations` from SDK; enable codegen. (`intl` already present.)
  2. Wire `MaterialApp.router` with delegates + `supportedLocales: [en, de]`.
  3. Pass locale to every `DateFormat` (currently default-locale — `meals_repository.dart` exports, history/insights formatting).
- **Acceptance:** App launches in de and en; dates format per locale; no hardcoded `DateFormat` without a locale.
- **Effort:** M (scaffolding) — string extraction is T2.2.

### T2.2 — String extraction across screens 🟠
- **Maps to:** §5 (UX), Priority #4
- **Files:** all `lib/features/**` + shared widgets.
- **Steps:** Replace hardcoded English with ARB keys, phased by traffic: (1) capture + results + history, (2) barcode + recipes, (3) settings + insights + dialogs/snackbars. Provide German translations (leverage SFCD's German domain terms for food UI).
- **Acceptance:** No user-facing literal strings remain in widget code (enforce with a grep checklist per screen); de translations present for all keys.
- **Effort:** L

---

## Phase 3 — Architecture consolidation (prevent regressions)

### T3.1 — Single canonical schema source 🟡
- **Maps to:** §2 (architect, schema duplicated)
- **Files:** `lib/core/database/app_database.dart`.
- **Steps:** Replace `_createMealsSchema` + `_createTestSchema` with one `_createSchema(db, {required bool withFts})`; production passes `withFts: true`, `openTestDb` passes `false`. The v4 upgrade block stays (it's migration history) but should reuse shared table-DDL constants so fresh-install and migration DDL can't drift.
- **Acceptance:** Table DDL exists once; `flutter test` (FFI, no FTS) and a device run (with FTS) both pass; a deliberate column added in one place appears everywhere.
- **Effort:** S

### T3.2 — Extract a capture controller (testability) 🟡
- **Maps to:** §2 (architect — placeholder controller), §3 (untested capture flow)
- **Files:** `lib/features/capture/capture_controller.dart` (currently a stub), `capture_screen.dart`.
- **Steps:** Move the analyze→persist→error-routing orchestration out of the widget into a `StateNotifier`/controller taking injected `GeminiService`/`ImageService`/`MealsRepository`. Widget keeps camera/UI only.
- **Acceptance:** Controller unit-tested (success, timeout, 401/403, 503, parse-fail, orphan-photo cleanup) with fakes; `capture_controller.dart` is no longer a placeholder.
- **Effort:** M
- **Note:** Also resolves §5.6 (orphaned photo on failure) by making the cleanup path test-covered.

### T3.3 — Finish the state-model unification 🟡
- **Maps to:** §2 (architect), §5.5 (prior — stale history after Capture-tab log)
- **Files:** remaining `setState` write paths (barcode result/builder, recipe editor, settings).
- **Steps:** Audit every write that isn't reflected through `mealsChangesProvider`; route reads through watched providers so screens refresh by construction. Remove now-redundant manual `ref.invalidate` chains where the stream covers them.
- **Acceptance:** The integration test (T1.5) plus a recipe-edit refresh test pass without manual invalidation in those paths.
- **Effort:** M

### T3.4 — Extract shared widgets 🟡
- **Maps to:** §2 / §7.3 (architect — duplication)
- **Files:** `lib/widgets/` (already has `meal_type_selector.dart`); add `AmountStepper`, `PhotoHeader`, `TotalBanner`, and a generic ingredient editor over a small interface shared by `IngredientCard` and `_IngredientRow`.
- **Steps:** Pull duplicated widgets into `widgets/`; migrate call sites (results, meal-edit, barcode result/builder, recipe editor, log-portion sheet).
- **Acceptance:** Each extracted widget has one definition; the duplicated meal-type chip styling converges; LOC drops.
- **Effort:** M

---

## Phase 4 — UX polish, cleanup & honest-claims finish

### T4.1 — Knife/spoon vector icons 🟡
- **Maps to:** §5 (UX, emoji-as-UI)
- **Files:** `capture_screen.dart` (mirror `_ForkIcon`/`_ForkPainter`), history/insights badges.
- **Steps:** Add `_KnifeIcon`/`_SpoonIcon` painters; replace 🔪/🥄 in the toggle, camera guide badge, and any list badges; keep `semanticLabel`s.
- **Acceptance:** No emoji glyphs used as functional controls; consistent rendering across devices.
- **Effort:** S

### T4.2 — Text-scale & contrast audit 🟡
- **Maps to:** §5 (UX)
- **Files:** capture overlay (44px recent-meals strip, fixed font sizes), any fixed-height rows.
- **Steps:** Replace fixed heights with min-height/wrapping; add a scrim behind white-on-viewfinder instructional text; test at 1.3× text scale.
- **Acceptance:** No clipping at 1.3×; overlay text meets contrast over bright photos.
- **Effort:** S

### T4.3 — Input validation feedback 🟡
- **Maps to:** §5 (UX), §8.4 (prior)
- **Files:** `ingredient_card.dart` (`[\d.]` filter), barcode result/manual entry, meal builder.
- **Steps:** Restrict numeric fields to a single decimal (or use a proper formatter); show inline validation instead of silent `tryParse` failures; warn (don't block) on 0-kcal manual barcode entries; make amount clamps consistent across flows.
- **Acceptance:** `1.2.3` is unenterable; clearing a field gives feedback; 0-kcal manual entry warns.
- **Effort:** S

### T4.4 — First-run privacy disclosure 🟡
- **Maps to:** §1 (PO), §6 (Security — photos→Google)
- **Files:** new first-run dialog/onboarding; `main.dart` or router redirect.
- **Steps:** On first launch (or first analysis), show a one-time explainer that photos are sent to Google Gemini for analysis, with a link to the Settings disclosure. Persist acknowledgement in prefs.
- **Acceptance:** New users see the disclosure once before the first upload; re-shows never.
- **Effort:** S

### T4.5 — Remove dead Pepesto / `price_chf` plumbing ⚪
- **Maps to:** §1 (PO), §2 (architect)
- **Files:** `lib/models/meal.dart` (`priceChf` field, `toMap`/`fromMap`), schema note.
- **Steps:** The Settings Pepesto section is already gone. Remove `Meal.priceChf` plumbing. Decide on the column: leave the now-unused `price_chf` column (SQLite can't drop it cheaply pre-3.35) with a `-- deprecated` comment, or add a rebuild migration. Recommend: leave the column, remove the model/UI plumbing, note it deprecated.
- **Acceptance:** No `priceChf` reads/writes in app code; schema comment marks the column deprecated.
- **Effort:** XS

### T4.6 — Act on `scale_confidence` ⚪
- **Maps to:** §4 (ML — confidence unused beyond display)
- **Files:** `results_screen.dart` / capture flow.
- **Steps:** On `low` confidence, nudge the user (e.g. a dismissible banner suggesting they include the utensil and retake) rather than only color-coding.
- **Acceptance:** Low-confidence results surface an actionable nudge.
- **Effort:** S

### T4.7 — Gate raw error-detail dialogs before distribution ⚪
- **Maps to:** §6 (Security — raw API bodies in dialog)
- **Files:** `capture_screen.dart:258` (`_showErrorDetail`).
- **Steps:** Behind a debug/diagnostics flag (or strip response bodies) so raw API text isn't shown to end users in release builds.
- **Acceptance:** Release build shows a friendly error; raw detail only under a diagnostics toggle.
- **Effort:** XS

### T4.8 — Misc cleanup ⚪
- **Maps to:** §5 (dark theme / restart-in-process), §7 (versioning, USDA asset runbook)
- **Items:**
  - Confirm clear/restore re-initializes in-process (no "restart the app" instruction) — `closeAll` is already called; verify the UI path.
  - Optional dark theme to replace per-branch nav-bar recoloring.
  - Establish a version-bump convention before store submission (currently `1.0.0+1`).
  - Document the USDA/SFCD asset regeneration runbook (`tool/build_sfcd.py` per ADR-007) and note APK/IPA size impact of the 30 MB asset.
- **Effort:** S (each)

---

## 5. Suggested sequencing & dependencies

```
Phase 0 (parallel, 1–2 days): T0.1 CI · T0.2 key · T0.3 vaporware · T0.4 https · T0.5 schema-output
        │
        ├─> Phase 1 evidence:  T1.1 eval set ──► T1.2 USDA threshold (verify vs eval)
        │                       T1.3 parse tests ·· T0.5 feeds parse-failure metric
        │                       T1.4 backup tests · T1.5 fts+integration
        │
        ├─> Phase 2 audience:  T2.1 l10n scaffold ──► T2.2 string extraction
        │
        ├─> Phase 3 arch:      T3.1 schema · T3.2 capture controller ──► T3.3 state unify · T3.4 widgets
        │
        └─> Phase 4 polish:    T4.1–T4.8 (after their feature areas settle)
```

Critical path to a defensible public release: **T1.1 → T1.2** (measured accuracy), **T2.1 → T2.2** (localization), **T0.2 + T4.4** (honest privacy). Everything else hardens quality but isn't release-gating.

---

## 6. Effort roll-up

| Phase | Tasks | Rough effort |
|---|---|---|
| 0 — Quick wins | T0.1–T0.5 | ~1–2 days |
| 1 — Evidence & correctness | T1.1–T1.5 | ~1.5 weeks (dataset-dominated) |
| 2 — Audience readiness | T2.1–T2.2 | ~1 week |
| 3 — Architecture | T3.1–T3.4 | ~1 week |
| 4 — Polish & cleanup | T4.1–T4.8 | ~3–4 days |

---

## 7. Traceability — every review finding → task

| Review ref | Finding | Task(s) |
|---|---|---|
| §1 PO | Core value prop unmeasured | T1.1 |
| §1 PO | Spec/privacy drift (key) | T0.2, (spec already updated) |
| §1 PO | On-device/private positioning | T0.3, T4.4 |
| §1 PO | Dead Pepesto `price_chf` | T4.5 |
| §1 PO | Localization launch blocker | T2.1, T2.2 |
| §2 Arch | Two state philosophies | T3.3 |
| §2 Arch | Schema defined twice | T3.1 |
| §2 Arch | USDA LIKE scan, no ranking | T1.2 |
| §2 Arch | `capture_controller` placeholder | T3.2 |
| §2 Arch | Widget duplication | T3.4 |
| §2 Arch | Stringly-typed / static singleton | (acceptable; partially via T3.2 fakes) |
| §3 QA | Parse/repair untested | T1.3 |
| §3 QA | Backup guard untested | T1.4 |
| §3 QA | Navigation staleness untested | T1.5, T3.3 |
| §3 QA | FTS untested | T1.5 |
| §3 QA | No permission-denied tests | T3.2 (controller), device job |
| §3 QA | No CI | T0.1 |
| §4 ML | No accuracy eval | T1.1 |
| §4 ML | USDA blind override | T1.2 |
| §4 ML | 1536px resize drift | T1.1 (decide against measured data); spec note |
| §4 ML | Permissive casts | T1.3 |
| §4 ML | No structured output | T0.5 |
| §4 ML | `scale_confidence` unused | T4.6 |
| §5 UX | No localization | T2.1, T2.2 |
| §5 UX | Emoji knife/spoon | T4.1 |
| §5 UX | Text-scale resilience | T4.2 |
| §5 UX | Low-contrast overlay | T4.2 |
| §5 UX | Numeric input inconsistencies | T4.3 |
| §5 UX | Restart-in-process / dark theme | T4.8 |
| §6 Sec | Key plaintext in prefs | T0.2 |
| §6 Sec | Photos→Google prominence | T4.4 |
| §6 Sec | `downloadAndSave` scheme check | T0.4 |
| §6 Sec | Raw error bodies in dialog | T4.7 |
| §6 Sec | No cert pinning | (noted, out of scope this tier) |
| §7 DevOps | No CI | T0.1 |
| §7 DevOps | USDA asset size/runbook | T4.8 |
| §7 DevOps | Versioning convention | T4.8 |

All ⭐ / 🟠 findings have an owning task; the only items intentionally deferred are cert pinning and the static-singleton refactor (both judged out-of-scope at this product tier in the review itself).
