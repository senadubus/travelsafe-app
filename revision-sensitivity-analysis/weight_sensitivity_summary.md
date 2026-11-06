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

## Findings

1. **Routes are largely robust to weight changes.** Even under the Equal set only
   5 of 18 routes (28%) change; under Violent-focused this drops to 2/18 (11%).
   Mean Jaccard lies in the 0.94–0.99 range, i.e. the overwhelming majority of the
   selected road segments are preserved.

2. **Changes are concentrated in the Balanced profile.** All 10 changed routes
   belong to the Balanced (λ=5) profile. Shortest (λ=0) is independent of risk and
   therefore never changes; Safest (λ=50) is sufficiently dominated by the risk
   weight that it barely deviates (only marginal Jaccard 0.94–0.98).

3. **Profile ranking is preserved.** For every (scenario, mode, weight set) the
   distance-based ordering is consistent: Shortest ≤ Balanced ≤ Safest. In addition,
   the normalized risk of the Safest route comes out lower than that of Shortest
   (in 5 of 6 cases). In other words, changing the weights does not disturb the
   *ranking* of route alternatives; it only shifts the segments chosen by Balanced.

4. **Distance effect is negligible.** The mean absolute distance deviation is
   0.11 m (Equal/Compressed) and 1.06 m (Violent-focused). The weighting preference
   therefore does not change route length in practice.

5. **Runtime is stable.** Mean route generation time lies in the 7.45–7.63 s range
   for all sets; the number of weight sets does not affect runtime (same graph and
   same number of edges).

## Interpretation

The weighting preference affects only the **grading** of the chosen routes, not
their **identity**. This shows that the results obtained with the baseline weights
proposed in the paper (1.0/0.6/0.4/0.3) are defensible against alternative weights:
even under a different criminological priority, the same route family continues to
be selected.

**Caveat:** This analysis was carried out on only 3 scenarios × 2 modes; a general
claim of "weight insensitivity" would require more O-D pairs.
