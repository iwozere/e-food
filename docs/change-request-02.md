# Change Request 02 — Meal Type + Pending Queue

## Context

Two usability gaps identified on 2026-05-14:

1. Meals have no time-of-day label — no way to distinguish breakfast from dinner in history or spot per-meal-type calorie patterns. (CR-01-C was scoped but never implemented.)
2. When Gemini is temporarily unavailable (503) or rate-limited (429), the captured photo is silently discarded. Users forget what they ate before they can retry.

---

## Features

### CR-02-A — Meal type tag ✅ implemented

**Problem:** Without a meal-type label, calorie history is a flat list with no time-of-day context.

**Solution:**
- Add `meal_type TEXT` column to `meals` table (DB migration v1 → v2).
- Four values: `breakfast`, `lunch`, `dinner`, `snack`.
- Auto-detected from time of day on the results screen:
  - 05:00–09:59 → breakfast
  - 10:00–14:59 → lunch
  - 15:00–17:59 → snack
  - 18:00–04:59 → dinner
- A `ChoiceChip` row on the results screen lets the user override the auto-detected type before saving.
- Shown as a chip in the meal detail screen and as a prefix label in the history list tile.

**Effort:** small (~1 h)

---

### CR-02-B — Pending meal queue ✅ implemented

**Problem:** On a 503 or 429 error the photo has already been saved to disk, but the app discards it with a generic error message. The user has no recovery path.

**Solution:**
- Add `pending INTEGER NOT NULL DEFAULT 0` column to `meals` table (same migration).
- On a retryable Gemini error (503 / 429), the error SnackBar gains a **"Save for later"** action.
  - Tapping it writes a skeleton `Meal` row (`pending=1`, `total_kcal=0`, no items) using
    the photo path that was already saved during that analysis attempt.
- Pending meals appear in history with a clock badge and *"Pending · tap to analyze"* subtitle.
- Opening a pending meal shows the photo, capture time, and meal type chip plus an
  **"Analyze now"** button.
  - Tapping re-runs the full Gemini flow and pushes to the results screen.
  - On save the pending row is updated in-place (`pending=0`, items populated) — no
    duplicate photo file.

**Effort:** medium (~2 h)

---

## DB migration

Version 1 → 2 adds two nullable / defaulted columns — safe for all existing rows:

```sql
ALTER TABLE meals ADD COLUMN meal_type TEXT;
ALTER TABLE meals ADD COLUMN pending   INTEGER NOT NULL DEFAULT 0;
```

Existing rows: `meal_type = NULL` (no label shown), `pending = 0` (treated as analyzed).
