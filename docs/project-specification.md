# ForkScale — On-Device Food Calorie Estimator
## Project Specification

---

## 1. Overview

A mobile application (iOS + Android via Flutter) that lets users photograph a plate of food — with a standard fork or knife placed beside it as a physical scale reference — and receive an AI-generated calorie and ingredient breakdown. All meal history is stored locally on-device. No backend, no account, no data leaves the device except the single LLM API call.

---

## 2. Goals

- Estimate calories from a photo in under 5 seconds (API round-trip included)
- Use fork/knife as a physical ruler to improve portion estimation accuracy
- Present results as editable ingredient cards so users can correct the AI
- Store full meal history locally (photo + ingredients + totals)
- Work offline for history browsing; only the analysis step requires network

---

## 3. Platform & Stack

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Flutter 3.x | Single codebase for iOS + Android |
| Language | Dart | Flutter native |
| Vision LLM | Moondream 2 (on-device, primary) | No API cost, no data sent, offline-capable |
| Vision LLM fallback | Gemini 2.5 Flash free tier API | Higher accuracy when online; user-toggleable |
| Local storage | SQLite via `sqflite` | Structured queries for history/search |
| Image storage | App's local file system (`path_provider`) | Photos stored as JPEG next to DB records |
| State management | Riverpod | Testable, no boilerplate |
| On-device ML runtime | ONNX Runtime Mobile / llama.cpp Flutter binding | Runs Moondream 2 quantized (Q4) |

### 3.1 On-Device Model

- Model: **Moondream 2** (quantized Q4\_K\_M, ~1.8 GB)
- Runtime: llama.cpp via `flutter_llama_cpp` or equivalent community binding
- Download: prompted on first launch, stored in app documents directory
- Fallback: if model not yet downloaded or device RAM < 3 GB, auto-route to Gemini API (with user consent prompt)

### 3.2 Gemini Fallback

- Model: `gemini-2.5-flash` via REST (`https://generativelanguage.googleapis.com/v1beta/models/...`)
- API key: user-provided, stored in Flutter Secure Storage (Keychain / Keystore)
- Free tier limits: 10 RPM, 250 RPD — sufficient for personal use
- User can toggle "Always use cloud model" in Settings for better accuracy

---

## 4. Core Features

### 4.1 Capture Screen

- Full-screen camera viewfinder (use `camera` Flutter plugin)
- Overlay UI:
  - Instruction banner: "Place a fork or knife beside the plate"
  - Utensil indicator: icon showing fork (18.5 cm) or knife (21 cm) with a toggle
  - Shutter button, gallery pick button
- After capture: brief loading state ("Analysing…") while LLM call runs

### 4.2 Analysis — LLM Prompt

Send the image plus this system prompt (adapt for Gemini or Moondream):

```
You are a nutrition analyst. A standard dinner [fork (18.5 cm) / knife (21.0 cm)] is visible in the image as a scale reference.

1. Detect the utensil and use its known length to estimate the plate diameter and food portion sizes.
2. Identify every distinct food item on the plate.
3. For each item estimate: weight in grams, calories per 100 g, total calories.
4. Return ONLY valid JSON, no prose, no markdown fences:

{
  "utensil_detected": true,
  "scale_confidence": "high|medium|low",
  "items": [
    {
      "name": "string",
      "weight_g": number,
      "kcal_per_100g": number,
      "total_kcal": number
    }
  ],
  "total_kcal": number,
  "notes": "string or null"
}
```

Parse the JSON response. If parsing fails or `utensil_detected` is false, show a soft warning ("Utensil not clearly visible — estimates may be less accurate") but still display results.

### 4.3 Results Screen

Displayed immediately after analysis:

- **Total calories banner** (large, top) — live-updating as user edits
- **Ingredient cards** (scrollable list), one per item:
  - Food name (editable text field)
  - Weight in grams (editable number field, stepper ±10 g)
  - kcal/100 g (editable, pre-filled from LLM)
  - Total kcal for this item (auto-calculated: `weight_g / 100 * kcal_per_100g`)
  - Delete button
- **"+ Add item" button** — appends a blank card
- **"Save meal" button** — persists to local DB and navigates to History
- **Scale confidence badge** — "High / Medium / Low" shown near the total, tappable for explanation
- **Notes field** — optional free-text (e.g. "lunch", "post-run")

Editing any field instantly recalculates affected totals. No save needed mid-edit — autosave on navigate away.

### 4.4 History Screen

Local timeline of saved meals:

- **List view**: date/time, thumbnail photo, meal name (auto-generated or user-edited), total kcal
- **Day summary bar**: horizontal strip showing total kcal for the selected day vs. a configurable daily goal (default 2000 kcal)
- **Search / filter**: by date range, by food name (SQLite FTS), by kcal range
- Tap a meal → **Meal Detail Screen** (read-only view of photo + ingredient cards + notes, with an "Edit" button to re-open editable view)
- Swipe-to-delete with undo toast

### 4.5 Settings Screen

- **Utensil default**: fork / knife toggle
- **AI model**: On-device (Moondream) / Cloud (Gemini Flash)
  - If Cloud: field to enter/update Gemini API key
- **Daily calorie goal**: number input (default 2000)
- **Storage usage**: shows DB size + photo folder size, with "Clear all history" button
- **Download on-device model**: progress bar, re-download button
- **Export data**: exports all meals as a JSON file to device Downloads

---

## 5. Local Data Model

### 5.1 SQLite Schema

```sql
CREATE TABLE meals (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at  INTEGER NOT NULL,           -- Unix timestamp ms
  photo_path  TEXT NOT NULL,              -- Absolute path to JPEG on disk
  name        TEXT,                       -- User-editable meal name
  notes       TEXT,
  total_kcal  REAL NOT NULL,
  utensil     TEXT NOT NULL DEFAULT 'fork', -- 'fork' | 'knife'
  scale_conf  TEXT,                       -- 'high' | 'medium' | 'low' | null
  model_used  TEXT NOT NULL               -- 'moondream' | 'gemini'
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

CREATE INDEX idx_meals_created ON meals(created_at DESC);
CREATE VIRTUAL TABLE meals_fts USING fts5(name, notes, content=meals, content_rowid=id);
```

### 5.2 Photo Storage

- Directory: `{app_documents}/meal_photos/`
- Filename: `{meal_id}_{timestamp}.jpg`
- Resolution: capture full resolution, store at max 1200×1200 JPEG (quality 85) for history thumbnails; keep original only if user enables "keep originals" in Settings (default: off)
- On meal delete: photo file deleted together with DB row (cascade)

---

## 6. UX Flow (Happy Path)

```
App launch
  └─ (first launch) → Model download prompt → Settings
  └─ (returning)    → Capture Screen

Capture Screen
  → User places fork next to plate
  → Takes photo
  → "Analysing…" overlay (LLM call, 2–8 s)
  → Results Screen

Results Screen
  → User reviews / edits ingredient cards
  → Taps "Save meal"
  → Navigates to History (meal highlighted at top)

History Screen
  → Scrollable timeline
  → Tap meal → Meal Detail Screen
```

---

## 7. Error Handling

| Scenario | Behaviour |
|---|---|
| No internet + Moondream not downloaded | Block analysis, show "Download on-device model in Settings or connect to internet" |
| Gemini API rate limit (429) | Retry once after 60 s; if still failing, offer "Switch to on-device model" |
| Gemini API key missing/invalid | Navigate to Settings with highlighted API key field |
| JSON parse failure from LLM | Show raw LLM text in a debug panel (dev builds); in release show "Could not read results — please retake photo" with retry |
| Photo file missing on Detail Screen | Show placeholder image, keep ingredient data intact |
| Device storage < 100 MB | Warn before saving photo; offer to save text-only (no photo) |

---

## 8. Privacy & Security

- No analytics, no crash reporters, no third-party SDKs beyond the ones listed
- Gemini API key stored in OS secure enclave (Flutter Secure Storage)
- Images never leave the device when using on-device model
- When using Gemini: image is sent to Google's API — disclosed clearly in onboarding and Settings
- No user account, no cloud sync, no telemetry

---

## 9. Milestones

### M1 — Core analysis loop (2 weeks)
- [ ] Flutter project scaffold (Riverpod, routing)
- [ ] Camera capture screen with utensil toggle
- [ ] Gemini Flash API integration + JSON parsing
- [ ] Results screen with editable ingredient cards and live kcal recalculation

### M2 — Local persistence (1 week)
- [ ] SQLite schema + `sqflite` integration
- [ ] Photo save/load pipeline
- [ ] History screen (list + day summary bar)
- [ ] Meal detail screen

### M3 — On-device model (2 weeks)
- [ ] Moondream 2 Q4 download + llama.cpp binding
- [ ] Inference pipeline (image → prompt → JSON parse)
- [ ] Model selector in Settings + automatic fallback logic

### M4 — Polish & edge cases (1 week)
- [ ] All error states implemented
- [ ] Settings screen (goal, export, storage)
- [ ] Onboarding (first-launch model download flow)
- [ ] FTS search in history
- [ ] Performance pass (image resizing off main thread, DB on isolate)

---

## 10. Open Questions for Agent / Developer

1. **Moondream binding**: confirm the best-maintained Flutter/Dart binding for llama.cpp at time of implementation — the ecosystem moves fast.
2. **Gemini model string**: verify the correct model ID at implementation time (`gemini-2.5-flash` or a newer stable alias).
3. **Utensil auto-detection**: the LLM prompt asks the model to detect the utensil, but you may want to add a deterministic CV fallback (e.g. contour detection for a long thin object) if LLM confidence is low.
4. **Portion accuracy study**: consider running 20–30 test photos against a kitchen scale ground truth before launch to characterise typical error margins; surface this as an in-app disclaimer.
5. **iOS App Tracking Transparency**: even though there is no tracking, confirm ATT is not triggered by any dependency.
6. **Android background model load**: loading a 1.8 GB model on first launch may be killed by Android's process manager — test on low-RAM devices and implement chunked download with resume.
