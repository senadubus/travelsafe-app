# Revision Sensitivity Analysis — TravelSafe

This folder contains the two sensitivity analyses performed in response to the
reviewer report on the **TravelSafe** paper, together with the reproducibility
materials:

1. **Grid resolution sensitivity analysis** (250 / 500 / 1000 m + 10 m sparsity)
2. **Crime category weight sensitivity analysis** (Base / Equal / Compressed / Violent-focused)

> This work is not intended to change the results in Table 3 of the paper. It was
> carried out to answer, numerically, the reviewer's questions regarding grid size
> and weighting preferences.

---

## 1. Data and period

| Item | Value |
|---|---|
| Crime source | City of Chicago "Crimes — 2001 to Present" (Open Data Portal) |
| Analysis period | **2021-01-04 – 2025-08-04** (weekly, Monday start) |
| Bounding box | lat 41.63732681153954 – 42.02280114700859, lng −87.94558663867282 – −87.51375507892669 |
| Raw records | 1,094,336 |
| Road network | OpenStreetMap → PostgreSQL/PostGIS (`road_nodes`, `road_segments`) |
| Database | PostgreSQL + PostGIS + pgRouting (`travelsafe`) |
| Reference latitude (m↔degree) | 41.85° (111,320 m/deg; cos correction for lng) |

**Crime category weights (Base):** Violent 1.0 · Property 0.6 · Drug/Vice 0.4 · Public-order 0.3

**Model:** XGBoost — `n_estimators=400, learning_rate=0.03, max_depth=5,
min_child_weight=15, subsample=0.7, colsample_bytree=0.5, reg_alpha=1.0, reg_lambda=5.0`,
target `z = log1p(y) − log1p(y^(4))` (paper Eq. 2), 5-fold chronological `TimeSeriesSplit`.

---

## 2. Folder structure

```
revision-sensitivity-analysis/
├── README.md                          ← this file
├── grid_resolution_summary.md         ← grid analysis summary (findings + interpretation)
├── weight_sensitivity_summary.md      ← weight analysis summary
├── weight_sensitivity_analysis_EN.md  ← extended weight analysis report (EN)
├── sql/
│   ├── schema_full.sql                ← pg_dump --schema-only (full schema)
│   ├── schema_core.sql                ← 10 core tables used in the analyses
│   └── queries.sql                    ← SQL queries used in the analyses
├── scripts/
│   ├── grid_resolution_comparison.py  ← analysis 1 (250/500/1000 m + 10 m sparsity)
│   ├── test_weight_sensitivity.py     ← analysis 2 (4 weight sets × 6 requests × 3 profiles)
│   ├── reference_xgboost_weekly_main_script.py  ← main XGBoost training script (reference)
│   └── reference_osm_road_import.py   ← OSM road network import script (reference)
├── data/
│   ├── grid_resolution_summary.csv        ← per-resolution metrics (+ fold std, 10 m sparsity row)
│   ├── grid_resolution_cv_metrics.csv     ← per-fold metrics (3 resolutions × 5 folds)
│   ├── weight_sensitivity_routes.csv      ← per-route results (72 records)
│   ├── weight_sensitivity_summary.csv     ← per-weight-set summary + ranking preservation
│   └── grid_resolution_comparison.csv     ← auxiliary comparison table
└── logs/
    ├── run_log_grid_resolution.txt        ← console output of analysis 1
    └── run_log_weight_sensitivity.txt     ← console output of analysis 2
```

> **Note:** The `schema_*.sql` files were generated from the live database with
> `pg_dump --schema-only` and are an exact record of the tables and indexes. The
> original setup scripts had not been stored separately.

---

## 3. Analysis 1 — Grid resolution

**Objective:** Compare the 250 / 500 / 1000 m resolutions while keeping the same
data period, cleaning rules (total crime per grid ≥ 10), crime categories, target
definition and XGBoost settings. No full model is trained for 10 m; only the
sparsity analysis is performed.

**Run:**
```bash
cd revision-sensitivity-analysis/scripts
python grid_resolution_comparison.py
```
Requirements: `psycopg2`, `pandas`, `numpy`, `scikit-learn`, `xgboost`, `python-dotenv`;
`DATABASE_URL` in `app/.env` (or the `DB_PARAMS` block inside the script).

**Outputs:**
- `data/grid_resolution_summary.csv` — all metrics per resolution (+ fold std, 10 m sparsity row)
- `data/grid_resolution_cv_metrics.csv` — per-fold metrics (3 resolutions × 5 folds = 15 rows)
- `grid_resolution_summary.md` — short summary and interpretation

**Results (summary):**

| m | Zero ratio | MAE | RMSE | R² | Normalized MAE | Grids in model |
|---|---|---|---|---|---|---|
| 250 | 64.2% | 0.243 | 0.661 | 0.678 | 0.390 | 7,518 |
| 500 | 34.2% | 0.838 | 1.567 | 0.694 | 0.398 | 2,228 |
| 1000 | 16.6% | 2.051 | 3.385 | 0.833 | **0.282** | 646 |
| 10 | 97.6% | — | — | — | — | — |

10 m: 15,369,652 cells, only 1.09% active → far too sparse for weekly prediction.

---

## 4. Analysis 2 — Weight sensitivity

**Objective:** Measure the effect of different criminological priorities on route
selection. The same 3 scenarios × 2 modes × 3 profiles (Shortest λ=0, Balanced λ=5,
Safest λ=50) are run under 4 weight sets → **72 route records**.

| Set | Violent | Property | Drug/Vice | Public-order |
|---|---|---|---|---|
| Base | 1.0 | 0.6 | 0.4 | 0.3 |
| Equal | 1.0 | 1.0 | 1.0 | 1.0 |
| Compressed | 1.0 | 0.8 | 0.6 | 0.4 |
| Violent-focused | 1.0 | 0.5 | 0.25 | 0.15 |

**Run:**
```bash
cd revision-sensitivity-analysis/scripts
python test_weight_sensitivity.py
```

**Outputs:**
- `data/weight_sensitivity_routes.csv` — for each (weight set, scenario, mode, profile):
  route distance, normalized risk, generation time, `changed_vs_base`,
  `jaccard_vs_base`, `overlap_ratio_vs_base`
- `data/weight_sensitivity_summary.csv` — per-weight-set summary + ranking preservation
- `weight_sensitivity_summary.md` — short summary and interpretation

**Results (summary):**

| Set | Routes changed | Mean Jaccard | Max risk deviation | Mean distance deviation |
|---|---|---|---|---|
| Equal | 5/18 (28%) | 0.943 | 0.170 | 0.11 m |
| Compressed | 3/18 (17%) | 0.947 | 0.179 | 0.11 m |
| Violent-focused | 2/18 (11%) | 0.985 | 0.015 | 1.06 m |

**Changes occur only in the Balanced profile**; Shortest is independent of risk and
never changes. The distance ranking (Shortest ≤ Balanced ≤ Safest) is preserved for
every weight set and every scenario/mode combination.

---

## 5. Limitations

- The weight analysis covers only 3 O-D scenarios × 2 modes; a general claim of
  "weight insensitivity" would require more O-D pairs.
- The absolute numbers in the grid analysis may not match the values in Table 3 of
  the paper exactly, because a different panel/origin construction is used than in
  the main `crime_grid_weekly` pipeline; the comparison is **internally consistent**.
- No model was trained for 10 m (not required, as the reviewer also noted); only
  sparsity indicators are reported.
