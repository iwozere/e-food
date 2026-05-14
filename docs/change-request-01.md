# Change Request 01 — Feature Extensions

## Context

ForkScale uses a fork or knife placed beside the plate as a physical scale reference.
The AI (Gemini 2.5 Flash) reads the utensil's known length to estimate portion sizes.
This document records feature ideas raised on 2026-05-13 and tracks their implementation status.

---

## Features

### CR-01-A — Custom utensil length + spoon support ✅ implemented

**Problem:** Fork and knife lengths are hardcoded (18.5 cm / 21 cm). Real cutlery varies
by country, brand, and style (dessert fork vs dinner fork, bread knife vs chef's knife).
A user whose fork is actually 16 cm gets systematically wrong portion estimates.

**Solution:**
- Add spoon as a third utensil type (default 20.0 cm — typical tablespoon / soup spoon).
- Expose per-utensil length fields in Settings → Capture.
- Pass the configured length into the Gemini prompt at analysis time.
- The capture screen toggle shows the three options with short labels; the actual cm
  value is configured once in settings and applied silently on every shot.

**Effort:** small (~2 h)

---

### CR-01-B — Manual ingredient correction ✅ implemented

**Problem:** The AI occasionally misidentifies a food or estimates the wrong weight.
Users need to fix values before saving without retaking the photo.

**Solution (already partially in place; hardened here):**
- Results screen ingredient cards have always-editable weight and kcal/100g fields
  with ±10 g step buttons.
- When a user edits kcal/100g, the USDA-match badge is cleared (the value is now
  theirs, not from the database).
- An "edited" badge appears on any card the user has touched, making it clear which
  values are user-verified vs AI-generated.
- Editing propagates to the running total banner in real time.

**Effort:** small (~1 h)

---

### CR-01-C — Meal type tag (not yet implemented)

Add a breakfast / lunch / dinner / snack tag to each meal on the results screen before
saving. Store as a new `meal_type` column in the `meals` table. Display in history list
and detail screen. Useful for spotting calorie patterns by meal.

**Effort:** small (~1 h) — requires a DB migration (add column + default value for
existing rows).

---

### CR-01-D — Daily progress bar (not yet implemented)

Show today's total kcal vs the configured daily goal on the capture screen or at the
top of the history screen. Already have `daily_goal` in SharedPreferences and DB access.
Needs a single `FutureProvider` that sums today's meals.

**Effort:** small (~1 h)

---

### CR-01-E — Weekly calorie bar chart (not yet implemented)

A 7-day bar chart in the history screen using `fl_chart` (common Flutter package).
Tap a bar to jump to that day. Shows users their pattern at a glance.

**Effort:** medium (~4 h) — new dependency + chart widget.

---

### CR-01-F — Export to CSV (not yet implemented)

Share all meal history as a CSV file via the system share sheet (`share_plus` package).
Privacy-friendly: local only, user chooses destination.

**Effort:** medium (~3 h) — new dependency + CSV serialisation.

---

### CR-01-G — Camera overlay / framing guide (not yet implemented)

A `CustomPainter` overlay on the camera preview suggesting where to place the plate
and utensil. Reduces positioning errors → better AI accuracy → fewer corrections needed.

**Effort:** medium (~4 h) — custom painter, no new dependencies.

---

### CR-01-H — Favorite meals / quick re-log (not yet implemented)

Star any meal in history. Starred meals appear in a Favorites list. A "Re-log today"
button copies the meal to the current date without re-photographing. Useful for users
who eat the same lunch repeatedly.

**Effort:** medium-large (~6 h) — new DB column, new history filter, re-log logic.

---

## Priority recommendation

Implement in this order for maximum user trust and retention:

1. **CR-01-A** Custom utensil length + spoon ← done
2. **CR-01-B** Manual ingredient correction ← done
3. **CR-01-C** Meal type tag — next quick win
4. **CR-01-D** Daily progress bar — next quick win
5. **CR-01-E / F / G / H** — plan for a later sprint
