# Release & bundled-asset runbook

Covers the operational items from review §7 (T4.8): versioning before store
submission, and how to regenerate the bundled nutrition databases.

## Versioning convention

`pubspec.yaml` `version:` is `<marketing>+<build>` (e.g. `1.0.0+1`), which Flutter
maps to iOS `CFBundleShortVersionString`/`CFBundleVersion` and Android
`versionName`/`versionCode`.

Rules before each store submission:

- **Build number (`+N`)** — increment on **every** upload to TestFlight / Play
  (stores reject duplicate build numbers). Never reuse.
- **Marketing version (`x.y.z`)** — semver:
  - patch `z` — bug-fix-only release;
  - minor `y` — new user-facing feature (e.g. a new tab), backward compatible;
  - major `x` — large redesign or a breaking data migration.
- Tag the commit `v<x.y.z>+<N>` so a build is traceable to source.
- A DB schema bump (`AppDatabase` `version`) must ship in at least a **minor**
  release and have a tested `onUpgrade` path.

## Bundled nutrition databases

Two read-only SQLite assets ship in the APK/IPA (`pubspec.yaml` → `assets:`):

| Asset | Source | Built by |
|---|---|---|
| `assets/db/usda_nutrition.db` | USDA FoodData Central SR Legacy | `scripts/build_usda_db.py` |
| `assets/db/sfcd.db` | Swiss Food Composition Database (German) | `tool/build_sfcd.py` (ADR-007) |

### Regenerate USDA

```bash
cd fork_scale
pip install requests          # one-time
python scripts/build_usda_db.py
```

Downloads the SR Legacy JSON, extracts energy + macros, writes the DB. Commit
the regenerated `assets/db/usda_nutrition.db`.

### Regenerate SFCD

```bash
cd fork_scale
python tool/build_sfcd.py     # see ADR-007 for the source spreadsheet
```

### Size impact (track before release)

The USDA DB dominates download size (~30 MB uncompressed; the full SR Legacy set
is the bulk of it). Before a store build:

- Check the asset sizes: `ls -lh fork_scale/assets/db/`.
- Android: prefer an **app bundle (.aab)**; the asset is not split by ABI, so it
  lands in the base module. Watch the Play "download size" estimate.
- iOS: the asset counts against the IPA / App Thinning size.
- If size becomes a problem, the options (not yet needed) are: trim USDA to the
  foods the LLM actually names, ship a slimmer seed DB and fetch the full set on
  first run, or compress and inflate on first launch.

> The eval harness (`tool/eval/`) measures accuracy; if a trimmed DB is ever
> shipped, re-run it (T1.1) to confirm USDA-match coverage didn't regress.
