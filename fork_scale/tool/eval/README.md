# Accuracy evaluation harness

Turns "is ForkScale accurate?" into tracked numbers (review §1, §4). It runs the
real Gemini call for each labelled photo and reports error vs ground truth.

## 1. Build a dataset (the real work)

Collect **30–50** photos where the truth is *measured*, not guessed:

- Weigh each item on a kitchen scale **before** plating, or use packaged foods
  with printed weights/calories.
- Shoot each plate with a fork/knife/spoon in frame, exactly as a user would.
- Store the images under `tool/eval/data/` (this folder is git-ignored by
  default — keep large image sets out of the repo or in Git LFS).

## 2. Write the manifest

A JSON array; one object per photo. See `sample_manifest.json`.

```jsonc
[
  {
    "image": "data/plate01.jpg",        // path relative to the manifest
    "utensil": "fork",                   // fork | knife | spoon
    "utensil_length_cm": 18.5,
    "truth_total_kcal": 540,             // measured ground-truth total
    "items": [                            // optional, enables per-item weight MAE
      { "name": "white rice", "truth_weight_g": 150 }
    ]
  }
]
```

## 3. Run it

```bash
cd fork_scale
GEMINI_KEY=AIza... dart run tool/eval/run_eval.dart \
    --manifest tool/eval/data/manifest.json \
    --out docs/eval-baseline-2026-06.md
```

It reports **total-kcal MAE & MAPE**, **per-item weight MAE**, **utensil-detection
rate**, and **parse-failure rate**, and writes a markdown report. Throttled to ~1
request / 7 s for the free-tier limit.

## 4. Commit the baseline

Commit the generated report as the baseline. Re-run after any prompt, model, or
USDA-matching change (T0.5, T1.2) and diff the metrics to catch regressions.

## Notes / limitations

- Measures the **model layer** (LLM weight × kcal/100g). The app additionally
  overrides kcal/100g via USDA (`UsdaService`); wiring USDA into the headless
  harness is a follow-up so the override's net effect on MAE can be measured.
- The prompt and response schema are imported from
  `lib/core/services/gemini_prompt.dart`, so the harness can never drift from
  what the app actually sends.
- Network/key-gated: it never runs in the default `flutter test` suite.
