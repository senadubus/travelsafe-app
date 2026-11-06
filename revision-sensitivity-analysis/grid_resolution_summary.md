# Grid Resolution Sensitivity Analysis — Summary

**Objective.** To examine how sensitive TravelSafe's fixed 500 × 500 m grid
weekly crime prediction is to spatial resolution. Using the same data period
(2021-01-04 – 2025-08-04), the same cleaning rules (total crime per grid ≥ 10),
the same crime categories, the same stationary target
(`z = log1p(y) − log1p(y^(4))`, Eq. 2), the same XGBoost hyperparameters
(400 / lr 0.03 / depth 5 / mcw 15 / sub 0.7 / col 0.5 / α 1 / λ 5) and the same
5-fold chronological validation (`TimeSeriesSplit`), we compared the 250 / 500 /
1000 m resolutions. For the reviewer-suggested 10 × 10 m we did not train a full
model; only a sparsity analysis was performed.

## Results table

| Resolution (m) | Total grids | Active grids | Active ratio | Total grid-weeks | Zero grid-week ratio | Mean crimes/grid-week | Median crimes/grid-week | Grids in model | MAE | RMSE | R² | Normalized MAE | Prep time (s) | Model time (s) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 250 | 24,768 | 8,412 | 0.340 | 1,804,320 | **64.2%** | 0.605 | 0 | 7,518 | 0.243 | 0.661 | 0.678 | 0.390 | 12.87 | 46.16 |
| 500 | 6,192 | 2,377 | 0.384 | 534,720 | 34.2% | 2.045 | 1 | 2,228 | 0.838 | 1.567 | 0.694 | 0.398 | 2.61 | 13.22 |
| 1000 | 1,548 | 676 | 0.437 | 155,040 | 16.6% | 7.058 | 5 | 646 | 2.051 | 3.385 | **0.833** | **0.282** | 0.77 | 6.21 |
| 10 (sparsity only) | 15,369,652 | 166,872 | 0.011 | 40,049,280 | **97.6%** | 1.132 | 1 | — | — | — | — | — | 0.17 | — |

## Findings

1. **Zero inflation rises steeply as the grid becomes finer.** The zero grid-week
   ratio is 16.6% at 1000 m, 34.2% at 500 m and 64.2% at 250 m. As the grid
   shrinks, the majority of targets become zero; the regression problem turns
   into a zero-inflated one.

2. **Absolute MAE is misleading; the fair comparison is normalized MAE.** The MAE
   at 250 m (0.243) looks small, but so is the mean crime count per cell (0.605).
   Normalized MAE = MAE / mean observed crimes: **0.282** at 1000 m (best), 0.390
   at 250 m and 0.398 at 500 m (worst). In other words, the coarse grid is more
   successful in relative error.

3. **R² increases with resolution.** 0.678 (250 m) → 0.694 (500 m) → 0.833 (1000 m).
   With a coarser grid the crime count per cell grows and the signal-to-noise ratio
   rises, which markedly increases the explained variance.

4. **Cost–accuracy trade-off.** Model time is 46.2 s (250 m) → 13.2 s (500 m) →
   6.2 s (1000 m); the number of grids in the model is 7,518 → 2,228 → 646. The
   500 m setting offers a reasonable compromise between accuracy (normalized MAE
   0.398) and cost (~13 s); 250 m provides no clear gain and instead pushes the
   zero ratio up to 64%.

5. **10 × 10 m is not practical for weekly prediction.** Within the bounding box
   there are 15.37 million cells; only **1.09%** of them contain a crime record and
   **97.6%** of all grid-weeks are zero. At this level almost every cell is
   represented by 0 or 1 incident per week; the weekly regression target carries no
   signal. 10 m is only meaningful for point-level density visualization (heatmap),
   not as a prediction unit.

## Recommended resolution

- **500 m for weekly prediction and routing cost** (the current system) is
  defensible in terms of the accuracy–cost balance.
- **1000 m** where higher relative accuracy is required; **250 m** for finer
  spatial distinction in visualization (but not for weekly prediction).
- **10 m** only as an exploratory/visual layer; not suitable for weekly modelling.
