# Crime Category Weight Sensitivity Analysis — Summary

**Objective.** To demonstrate the extent to which route generation changes when
alternative weight sets are used instead of the baseline weights (Violent 1.0,
Property 0.6, Drug/Vice 0.4, Public-order 0.3). The same six route requests
(3 scenarios × 2 modes) and the same three route profiles (Shortest λ=0,
Balanced λ=5, Safest λ=50) were run under 4 weight sets →
**4 × 3 × 2 × 3 = 72 route records**.

## Weight sets

| Set | Violent | Property | Drug/Vice | Public-order |
|---|---|---|---|---|
| Base | 1.0 | 0.6 | 0.4 | 0.3 |
| Equal | 1.0 | 1.0 | 1.0 | 1.0 |
| Compressed | 1.0 | 0.8 | 0.6 | 0.4 |
| Violent-focused | 1.0 | 0.5 | 0.25 | 0.15 |

## Results (`weight_sensitivity_summary.csv`)

| Weight set | Routes changed | Change ratio | Mean Jaccard | Min Jaccard | Mean overlap | Max risk deviation | Mean distance deviation (m) | Mean time (ms) |
|---|---|---|---|---|---|---|---|---|
| Base | 0/18 | 0.00 | 1.000 | 1.000 | 1.000 | 0.000 | 0.00 | 7451.80 |
| Equal | 5/18 | 0.28 | 0.943 | 0.611 | 0.970 | 0.170 | 0.11 | 7631.85 |
| Compressed | 3/18 | 0.17 | 0.947 | 0.611 | 0.972 | 0.179 | 0.11 | 7560.28 |
| Violent-focused | 2/18 | 0.11 | 0.985 | 0.758 | 0.992 | 0.015 | 1.06 | 7445.69 |

## Comparison of the measured quantities

1. **Number of routes changed vs. Base.** Equal 5/18 (28%), Compressed 3/18 (17%),
   Violent-focused 2/18 (11%).

2. **Edge-set Jaccard similarity vs. Base.** Mean 0.943 (Equal), 0.947 (Compressed),
   0.985 (Violent-focused); minimum 0.611 / 0.611 / 0.758.

3. **Overlap ratio vs. Base** (common segments / shorter route): mean 0.970 (Equal),
   0.972 (Compressed), 0.992 (Violent-focused).

4. **Maximum absolute deviation in normalized risk vs. Base:** 0.170 (Equal),
   0.179 (Compressed), 0.015 (Violent-focused).

5. **Mean absolute deviation in route distance vs. Base:** 0.11 m (Equal), 0.11 m
   (Compressed), 1.06 m (Violent-focused).

6. **Mean route generation time:** 7451.80 ms (Base), 7631.85 ms (Equal),
   7560.28 ms (Compressed), 7445.69 ms (Violent-focused).

7. **Where the changes occur.** 6 of the 10 changed routes are in the Balanced (λ=5)
   profile and 4 are in the Safest (λ=50) profile. No route changes in the Shortest
   (λ=0) profile. Per-record values are in `weight_sensitivity_routes.csv`.

8. **Profile ranking.** The distance ordering Shortest ≤ Balanced ≤ Safest holds for
   every (scenario, mode, weight set) combination (18/18 triplets). The Safest route
   has a strictly lower normalized risk than the Shortest route in 16 of 24
   scenario/mode/weight-set cells (20 of 24 when ties are included; the corresponding
   column `safest_better_than_shortest_cases` in the summary CSV uses the
   non-strict ≤ comparison and reports 5/6 per weight set).

## Scope

The analysis covers 3 O-D scenarios × 2 modes (walk, car) × 3 route profiles under
4 weight sets. It does not cover additional O-D pairs or additional profiles.
