# Sensitivity Analysis of Crime Category Weights

**Objective.** The objective of this analysis is to demonstrate the
extent to which route generation changes when alternative weight
configurations are used instead of the baseline weights (Violent: 1.0,
Property: 0.6, Drug/Vice: 0.4, Public-order: 0.3). Four different weight
configurations were evaluated using the same six routing requests (3
scenarios × 2 modes) and the same three routing profiles (Shortest λ=0,
Balanced λ=5, Safest λ=50), yielding a total of **72 route records (4 ×
3 × 2 × 3)**.

## Weight configurations

  Set                 Violent   Property   Drug/Vice   Public-order
  ----------------- --------- ---------- ----------- --------------
  Base                    1.0        0.6         0.4            0.3
  Equal                   1.0        1.0         1.0            1.0
  Compressed              1.0        0.8         0.6            0.4
  Violent-focused         1.0        0.5        0.25           0.15

## Results (`weight_sensitivity_summary.csv`)

  ----------------------------------------------------------------------------------------------------
  Weight set          Changed   Change      Mean      Min.      Mean   Max. risk        Mean      Mean
                       routes     rate   Jaccard   Jaccard   overlap   deviation    distance   runtime
                                                                                   deviation      (ms)
                                                                                         (m) 
  ----------------- --------- -------- --------- --------- --------- ----------- ----------- ---------
  Base                   0/18     0.00     1.000     1.000     1.000       0.000        0.00   7451.80

  Equal                  5/18     0.28     0.943     0.611     0.970       0.170        0.11   7631.85

  Compressed             3/18     0.17     0.947     0.611     0.972       0.179        0.11   7560.28

  Violent-focused        2/18     0.11     0.985     0.758     0.992       0.015        1.06   7445.69
  ----------------------------------------------------------------------------------------------------

## Findings

**1. Routes are largely robust to changes in category weights.** Even
under the Equal configuration, only 5 out of 18 routes (28%) changed.
This number decreased to 2 out of 18 (11%) under the Violent-focused
configuration. The mean Jaccard similarity ranges from 0.94 to 0.99,
indicating that the vast majority of selected route segments remain
unchanged across alternative weighting schemes.

**2. Route changes are concentrated exclusively in the Balanced
profile.** All 10 observed route changes occurred in the Balanced
profile (λ=5). As expected, the Shortest profile (λ=0) remains
unaffected because it is independent of risk weighting. The Safest
profile (λ=50), on the other hand, is sufficiently dominated by risk
minimization to remain largely stable, exhibiting only minor deviations
in Jaccard similarity (0.94--0.98).

**3. The relative ordering of routing profiles is preserved.** Across
all (scenario, mode, weight set) combinations, the distance-based
ordering remains consistent: Shortest ≤ Balanced ≤ Safest. Furthermore,
the normalized risk of the Safest route is lower than that of the
Shortest route in five out of six cases. These findings suggest that
changes in category weights do not disrupt the relative ordering of
routing alternatives but primarily affect the segments selected by the
Balanced profile.

**4. The impact on route distance is negligible.** The mean absolute
distance deviation is 0.11 m under the Equal and Compressed
configurations and 1.06 m under the Violent-focused configuration. Thus,
the choice of crime category weights has virtually no effect on overall
route length.

**5. Computational runtime remains stable.** The mean route generation
time ranges from 7.45 to 7.63 seconds across all weight configurations.
This indicates that changing the weight configuration does not
meaningfully affect computational runtime, as the underlying graph and
number of edges remain unchanged.

## Discussion

The weighting scheme primarily affects the **risk evaluation** of routes
rather than their **structural identity**. This finding supports the
defensibility of the baseline weights proposed in this study
(1.0/0.6/0.4/0.3). Even when alternative criminological priorities are
adopted, the routing algorithm continues to select largely the same
family of routes. Therefore, the proposed baseline weighting scheme
appears reasonably robust to alternative crime category weight
configurations.

**Limitation.** This sensitivity analysis was conducted using only three
scenarios and two transportation modes (3 × 2). Consequently, the
findings should not be interpreted as evidence of general weight
insensitivity across all origin--destination (O-D) pairs. A larger and
more diverse set of O-D pairs is required to establish the
generalizability of these results.

------------------------------------------------------------------------
