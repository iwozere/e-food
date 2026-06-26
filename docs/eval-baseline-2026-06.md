# ForkScale accuracy baseline — NOT YET POPULATED

> This is a placeholder. The harness (`fork_scale/tool/eval/run_eval.dart`) is
> built and runnable, but a baseline requires a labelled dataset of weighed
> plates (30–50 photos) that does not yet exist. See
> `fork_scale/tool/eval/README.md` for how to collect it and generate this
> report.

## What this file will contain once the dataset exists

| Metric | Meaning |
|---|---|
| Total-kcal MAE | Mean absolute error of the meal's total calories (kcal) |
| Total-kcal MAPE | Mean absolute percentage error of the total |
| Per-item weight MAE | Mean absolute error of per-item portion weight (g) |
| Utensil-detection rate | Fraction of photos where the utensil was detected |
| Parse-failure rate | Fraction of photos whose JSON response failed to parse |

Plus a per-photo breakdown table.

## How to generate

```bash
cd fork_scale
GEMINI_KEY=AIza... dart run tool/eval/run_eval.dart \
    --manifest tool/eval/data/manifest.json \
    --out docs/eval-baseline-2026-06.md
```

This will overwrite this placeholder with the real baseline. Commit the result
and treat it as the regression reference for prompt/model/USDA changes.
