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

## Comparison of the measured quantities

1. **Zero grid-week ratio.** 16.6% (1000 m) → 34.2% (500 m) → 64.2% (250 m) → 97.6% (10 m).
   The proportion of zero-valued grid-weeks increases monotonically as the grid
   becomes finer.

2. **Mean and median crimes per grid-week.** Mean 7.058 (1000 m) / 2.045 (500 m) /
   0.605 (250 m); median 5 / 1 / 0. For 10 m the mean is 1.132 with a median of 1.

3. **Model error (5-fold mean).** MAE is 2.051 at 1000 m, 0.838 at 500 m and 0.243 at
   250 m; RMSE is 3.385 / 1.567 / 0.661 respectively.

4. **Normalized MAE** (MAE / mean observed crime count) is 0.282 at 1000 m, 0.398 at
   500 m and 0.390 at 250 m. This is the only metric in which the three resolutions
   are on a comparable scale.

5. **R² (5-fold mean).** 0.833 (1000 m), 0.694 (500 m), 0.678 (250 m).

6. **Number of grids used in the model** (grids with total crime ≥ 10): 646 (1000 m),
   2,228 (500 m), 7,518 (250 m).

7. **Runtime.** Preparation 12.87 s / 2.61 s / 0.77 s and model fitting 46.16 s /
   13.22 s / 6.21 s for 250 / 500 / 1000 m. The 10 m sparsity pass took 0.17 s (no
   model was trained).

8. **Grid size at 10 m.** 15,369,652 cells within the bounding box; 166,872 of these
   (1.09%) contain at least one crime record. No model was trained at this
   resolution.
