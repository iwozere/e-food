# ForkScale — Roadmap

Potential improvements, ordered roughly by effort and impact. None of these are committed — they are ideas for future development.

---

## Medium-term

### Macro tracking
`cached_products` already stores `protein_g`, `carbs_g`, `fat_g` per 100g for barcode meals. Extending `meal_items` with macro columns and propagating values from Gemini (or USDA) for camera meals would enable:
- Per-meal macro breakdown in Meal Detail
- Daily macro totals in the History day bar (protein / carbs / fat / kcal)
- Optional macro goal settings

### Meal reminders / nudges
A local notification at a configurable time ("You haven't logged lunch yet") using `flutter_local_notifications`. Optional; opt-in in Settings.

---

## Long-term

### On-device model (deferred M3)
Moondream 2 as the primary analysis model with Gemini as cloud fallback. Blocked on a stable `flutter_llama_cpp` (or equivalent) binding. Revisit when the Flutter/llama.cpp ecosystem matures. Would remove the Gemini API dependency for offline-first users.

### Apple Health / Google Fit integration
Write logged calorie totals to Apple Health (HealthKit) or Google Fit (Health Connect) as dietary energy entries. Requires platform-specific permissions and entitlements. The calorie data is already in SQLite — the integration is plumbing only.

### Backup and restore
Export the full database + photo folder to iCloud Drive (iOS) or Google Drive (Android) as a zip archive, and restore from it on a new device. Would close the only remaining gap vs. cloud-based food logging apps while keeping data under user control.

### Home screen widget (iOS)
A small widget showing today's kcal total vs. goal, updated whenever the app logs a meal. Requires `home_widget` or WidgetKit (iOS 14+). Android support via Glance.

### Shopping list from recipes
From a Recipe Detail screen, generate a shopping list of ingredients grouped by category (produce, dairy, etc.) and sharable as plain text. Ingredient categorisation could be rule-based (keyword matching) or LLM-assisted.

### Multi-language support
The SFCD database is German-only, which limits autocomplete usefulness for non-German speakers. Adding English translations (SFCD publishes `name_en` in its export) and localising the app UI (at minimum German + English) would broaden the audience. `flutter_localizations` is already a Flutter dependency.

### Nutritional label OCR
Point the camera at a printed nutrition label → extract kcal/100g without typing. Could use the Gemini vision API with a label-specific prompt, or an on-device OCR library. Would complement the barcode flow for products without machine-readable codes.
