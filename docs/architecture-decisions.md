# ForkScale — Architecture Decisions

Decisions made during initial planning that diverge from or extend the project specification.

---

## ADR-001: Defer on-device Moondream model (M3)

**Decision:** Ship M1 + M2 with Gemini API as the sole analysis backend. M3 (Moondream 2 + llama.cpp binding) is deferred indefinitely.

**Rationale:** No well-maintained `flutter_llama_cpp` binding exists on pub.dev. Attempting M3 now would likely block shipping. The on-device model can be revisited once the Flutter/llama.cpp ecosystem matures or a stable binding is published.

**Impact:**
- `Settings > AI model` selector is simplified to a single toggle: "On-device (unavailable)" greyed out, with a "Coming soon" label.
- The `model_used` column in the `meals` table will always be `'gemini'` for now.
- No model download flow needed in onboarding.

---

## ADR-002: USDA FoodData Central for nutritional values

**Decision:** Bundle a curated SQLite snapshot of USDA FoodData Central as a read-only asset. The Gemini LLM identifies food items and estimates portion weights; calorie density (kcal/100g) is resolved from this local database, not from the LLM response.

**Rationale:** LLMs hallucinate nutrition numbers. USDA data is authoritative, auditable, and does not require network access after first install.

**Implementation notes:**
- Source: USDA FoodData Central "SR Legacy" dataset (public domain). Pre-processed into a single `usda_nutrition.db` SQLite file (~30 MB compressed).
- Lookup flow: LLM returns `name` for each food item → fuzzy-match against USDA `description` column → return `kcal_per_100g`. If no match found (confidence < threshold), fall back to LLM-provided value with a visual warning on the ingredient card.
- The `items` array in the LLM JSON response still carries `kcal_per_100g` as a fallback field, but it is overridden when a USDA match is found.
- Ship the pre-built `usda_nutrition.db` as a Flutter asset; copy to app documents on first launch so it can be opened by `sqflite`.

---

## ADR-003: go_router for navigation

**Decision:** Use `go_router` (Flutter team's official declarative routing package) instead of imperative `Navigator.push`.

**Rationale:** Cleaner deep-link support, type-safe routes, easier back-stack control for the Capture → Results → History flow. Compatible with Riverpod.

**Route map:**
```
/                   → CaptureScreen
/results            → ResultsScreen  (receives AnalysisResult via extra)
/history            → HistoryScreen
/history/:id        → MealDetailScreen
/settings           → SettingsScreen
```

---

## ADR-004: Image resize before Gemini API call

**Decision:** Resize the captured image to a maximum of 800 px on the longest side (JPEG quality 85) before sending to the Gemini API. Full-resolution storage is a separate operation.

**Rationale:** Reduces API latency, lowers free-tier quota consumption (Gemini charges per token including image tokens), and keeps round-trip time closer to the 5-second goal. The fork/knife scale reference is still clearly visible at 800 px.

**Implementation:** Use the `image` Dart package to resize in a background `Isolate` before the API call. Storage write (1200×1200) happens in parallel.

---

## ADR-005: Color palette and design language

**Decision:** Dark green (`#1B4332`) primary, warm cream (`#FFF8F0`) background, amber accent (`#F4A523`).

**Rationale:** Conveys freshness and food context without the sterile look of generic health apps. High contrast between primary and background meets WCAG AA.

| Token | Hex | Usage |
|---|---|---|
| `colorPrimary` | `#1B4332` | App bar, buttons, active states |
| `colorBackground` | `#FFF8F0` | Screen backgrounds |
| `colorSurface` | `#FFFFFF` | Cards |
| `colorAccent` | `#F4A523` | Calorie totals, highlights, CTAs |
| `colorError` | `#D62828` | Error states |
| `colorOnPrimary` | `#FFFFFF` | Text/icons on primary |
