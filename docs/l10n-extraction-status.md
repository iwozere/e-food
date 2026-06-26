# Localization (l10n) status — T2.1 / T2.2

**Date:** 2026-06-25

## Done (T2.1 — scaffolding, complete)

- `flutter_localizations` added; `generate: true` in `pubspec.yaml`.
- `l10n.yaml` + `lib/l10n/app_en.arb` (template) + `lib/l10n/app_de.arb`.
- `MaterialApp.router` wired with `AppLocalizations.localizationsDelegates`
  and `supportedLocales` (en, de); title via `onGenerateTitle`.
- Generated `AppLocalizations` in `lib/l10n/app_localizations*.dart`.
- App builds and runs in both `en` and `de` (device language switch).

## Done (T2.2 — first extraction pass)

Fully localized, with German translations, as the reference pattern:

- **Settings** (`features/settings/settings_screen.dart`) — every label,
  button, dialog, and snackbar.
- **Capture** (`features/capture/capture_screen.dart`) — hint banner, tooltips,
  all error/snackbar copy, analysing overlay, recent-meals strip, camera-guide
  labels, accessibility semantics.

## Complete (2026-06-25)

All user-facing screens are now localized (en + de): results + ingredient card,
history, meal detail, meal edit, recipes (list/detail/editor), log-portion sheet,
barcode (scanner/result/builder), insights, and the shared `MealTypeSelector`.

### Locale-aware date formatting — done

`DateFormat(...)` calls in History and Meal Detail now pass
`Localizations.localeOf(context).toLanguageTag()`, and `main()` calls
`initializeDateFormatting()` so non-default locales (de) work. Remaining default-
locale `DateFormat` usage is limited to `meals_repository.dart` CSV export, which
runs without a `BuildContext`; it can adopt `Intl.getCurrentLocale()` if export
localization is later required.

## Verification

`flutter analyze` clean and `flutter test` green (64 tests). Optional next step:
add a per-screen golden/widget test asserting both locales render.
