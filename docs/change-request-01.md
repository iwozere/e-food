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

### CR-01-C — Meal type tag ✅ implemented (CR-02-A)

Auto-detected from time of day (breakfast / lunch / snack / dinner). ChoiceChip row
on the results screen lets the user override before saving. Shown in history tile
subtitle and meal detail chips. See change-request-02.md for full spec.

---

### CR-01-D — Daily progress bar ✅ implemented

Today's total kcal vs the configured daily goal shown at the top of the history screen
as a `_DaySummaryBar`: colored progress bar + `total / goal kcal` text, using the
`getDayTotalKcal` repository method and the `daily_goal` SharedPreferences key.

---

### CR-01-E — Weekly calorie bar chart ✅ implemented

**Solution:**
- `fl_chart` added as a dependency.
- `getWeeklyKcal()` repository method returns last-7-days totals (one DB call per day).
- `_WeeklyChart` widget in the history screen shows a compact (140 px) bar chart above
  the search field.
- Today's bar is highlighted in accent amber; a dashed red line marks the daily goal.
- Tapping a bar filters the history list to that day; tapping the same bar again clears
  the filter. A chip shows the active day filter and can be dismissed.

**Effort:** medium (~2 h)

---

### CR-01-F — Export to CSV ✅ implemented

**Solution:**
- `share_plus` added as a dependency.
- `exportCsv()` repository method queries all analyzed meals, builds a CSV
  (Date, Time, Meal Type, Total kcal, Utensil, Starred, Items), writes to the temp
  directory, and returns the file path.
- **Export to CSV** button added to Settings → Storage section. Invokes the system
  share sheet (`Share.shareXFiles`).

**Effort:** medium (~1 h)

---

### CR-01-G — Camera overlay / framing guide ✅ implemented

**Solution:**
- `_CameraGuide` widget (a `CustomPainter` overlay) stacked on top of the camera
  preview when not analyzing.
- Draws a thin white circle (37 % of screen width radius, centered at ~42 % height)
  as a plate guide, and a small rounded rectangle to its left as the utensil guide.
- Emoji label for the active utensil (🍴 / 🔪 / 🥄) and "Plate" text are overlaid
  via `Positioned` widgets.
- Opacity kept at 45 % so the guide is visible but not distracting.

**Effort:** medium (~1 h)

---

### CR-01-H — Favorite meals / quick re-log ✅ implemented

**Solution:**
- `starred INTEGER NOT NULL DEFAULT 0` column added to `meals` table (DB migration
  v2 → v3).
- `Meal.starred` bool field; `MealsRepository.starMeal()` toggles it.
- History list tile trailing: small star icon above the kcal count — tap to star/unstar
  without leaving the list.
- **Starred** filter chip in the history screen header filters the list to starred meals.
- AppBar of the meal detail screen shows a star `IconButton` to toggle from the detail view.
- **Re-log today** `OutlinedButton` at the bottom of the meal detail screen: confirmation
  dialog → new `Meal` row created with `DateTime.now()`, auto-detected meal type, and the
  same items/photo as the original. Navigates to the new meal's detail screen.

**Effort:** medium-large (~3 h)

---

## Implementation status

All CR-01 items complete as of 2026-05-14.
