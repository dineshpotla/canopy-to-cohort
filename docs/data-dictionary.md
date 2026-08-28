---
title: "Analytical data dictionary"
description: "Fields, units, derivations, and missing-value rules used in the Canopy to Cohort analysis"
toc: true
---

This dictionary documents the record grain and the principal fields used in the
analysis. It describes derived analytical data; record-level FIA observations
are intentionally not distributed with the public repository.

## Record grain and keys

The analytical unit is one measured forest condition within one FIA plot visit.
The composite key is `plt_cn + condid`. Tree and seedling records are aggregated
to that grain before they are joined, preventing many-to-many row inflation.

| Field | Type / unit | Definition |
|---|---|---|
| `plt_cn` | character identifier | FIA plot-visit control number. Used as a relational key; not a coordinate. |
| `condid` | integer identifier | Condition number within the plot visit. |
| `geoid` | five-character code | State and county FIPS code used for county-safe spatial joins and the county random intercept. |
| `county_name` | character | FIA county name resolved from the database reference table. |
| `measyear` | year | Calendar year of field measurement. Observations in this release span 2018–2025. |
| `forest_type` | character | Active type in FIA maple/beech/birch group 800 (codes 801, 802, 805, or 809), which this project uses as its operational northern-hardwood cohort. |

## Sampling and stand context

| Field | Type / unit | Definition and missing-value rule |
|---|---|---|
| `condprop_unadj` | proportion | Unadjusted plot-area share assigned to the condition. Retained for FIA area context; it is not used as a universal tree-frame denominator. |
| `micrprop_unadj` | proportion | Unadjusted share of microplot sampling assigned to the condition. A value greater than zero demonstrates seedling sampling opportunity. |
| `subpprop_unadj` | proportion | Unadjusted share of subplot sampling assigned to the condition; used for live trees measured on subplots. |
| `macrprop_unadj` | proportion | Unadjusted share of macroplot sampling assigned to the condition; used only when a populated macroplot breakpoint applies. |
| `seedling_sampled` | logical | `TRUE` only when `micrprop_unadj > 0`. An absent seedling record may become zero only under this condition. |
| `stand_age` | years | FIA stand-age estimate (`STDAGE`). Missing values remain missing and are never silently imputed. |
| `disturbed` | logical | `TRUE` when any of `DSTRBCD1`–`DSTRBCD3` contains a positive disturbance code. |
| `treated` | logical | `TRUE` when any of `TRTCD1`–`TRTCD3` contains a positive treatment code. Retained for context but not used in the supported primary model. |

## Established-tree metrics

Live trees have `STATUSCD = 1`. Sugar maple is resolved from `REF_SPECIES` as
*Acer saccharum*, FIA species code 318. For tree \(i\), the plot-basis basal-area
contribution is

\[
0.005454 \times \mathrm{DIA}_i^2 \times \mathrm{TPA\_UNADJ}_i.
\]

| Field | Unit | Definition |
|---|---|---|
| `total_ba_ft2_ac` | ft²/acre | Sum of frame-corrected live-tree contributions: microplot records divide by `micrprop_unadj`, subplot records by `subpprop_unadj`, and applicable macroplot records by `macrprop_unadj`. |
| `maple_ba_ft2_ac` | ft²/acre | Sugar-maple component of the frame-corrected live-tree density. |
| `nonmaple_ba_ft2_ac` | ft²/acre | `total_ba_ft2_ac - maple_ba_ft2_ac`, bounded below at zero. |
| `maple_ba_share` | proportion | Frame-corrected sugar-maple basal area divided by frame-corrected total live-tree basal area. |

The derived total is checked against FIA `COND.BALIVE`; the pipeline enforces
strict correlation and absolute-error gates that detect use of a wrong sampling
frame. Implementation:
[`R/basal_area.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/basal_area.R).

## Regeneration metrics and response

| Field | Type / unit | Definition and interpretation |
|---|---|---|
| `maple_seedling_tpa` | trees/acre | Sugar-maple seedling `TPA_UNADJ` summed on the plot basis and divided by `micrprop_unadj`. `NA` when seedling sampling was not demonstrated. |
| `maple_seedling_detected` | 0 / 1 / `NA` | `1` when a sampled condition has positive sugar-maple seedling density; `0` when sampled but none were tallied; `NA` when sampling opportunity is unknown. |
| `outcome_no_seedlings` | 0 / 1 | Primary model response: `1 - maple_seedling_detected`. It means “no seedlings tallied,” not confirmed ecological absence. |
| `established_percentile` | 0–1 | Sample percentile of `maple_ba_share` among conditions with usable seedling sampling. |
| `regeneration_percentile` | 0–1 | Sample percentile of `log(1 + maple_seedling_tpa)` among usable conditions. |
| `potential_gap` | logical | `TRUE` when `maple_ba_share` is at or above the sample upper-third threshold and no sugar-maple seedlings were tallied. Exploratory, not a validated ecological index. |
| `potential_gap_sensitivity` | logical | Alternative flag using the upper-quartile established-share threshold. |

Implementation: [`R/regeneration.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/regeneration.R)
and [`R/features.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/features.R).

## Climate fields

Climate fields are 1991–2020 Daymet normals from the 1-km cell containing each
Census Gazetteer county internal point. They are county-scale spatial proxies,
not plot-level measurements or county-wide areal averages.

| Field | Unit | Definition |
|---|---|---|
| `mean_annual_temp_c` | °C | Mean across years of daily `(tmin + tmax) / 2`, averaged within year and then across 1991–2020. |
| `mean_annual_precip_mm` | mm/year | Mean annual sum of daily precipitation across 1991–2020. |

Implementation: [`R/climate.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/climate.R).

## Model transformations

Continuous predictors are standardized after defining the final model-complete
cohort, so one standardized unit refers to the fitted 1,424-condition cohort.
Basal-area predictors are transformed with `log(1 + x)` before standardization.
The scaling means, standard deviations, transformations, and cohort size are
published as a separate audit table.

| Model field | Source and transformation |
|---|---|
| `z_maple_ba` | standardized `log(1 + maple_ba_ft2_ac)`; modeled with a three-degree-of-freedom natural spline |
| `z_nonmaple_ba` | standardized `log(1 + nonmaple_ba_ft2_ac)` |
| `z_microplot_coverage` | standardized `micrprop_unadj` |
| `z_stand_age` | standardized `stand_age` |
| `disturbed` | factor with `FALSE` as the reference level |
| `z_mean_temp` | standardized `mean_annual_temp_c` |
| `z_precip` | standardized `mean_annual_precip_mm` |
| `z_year` | standardized `measyear` |

The supported release model is a mixed-effects logistic regression with a
county random intercept. It reports the nonlinear maple association as an
adjusted probability curve rather than interpreting spline-basis coefficients.
Ten-fold internal grouped validation holds out whole counties, relearns
transformations within each training fold, and predicts held-out counties with
fixed effects only. Conventional coefficient inference is supplemented by
Benjamini–Hochberg adjusted p-values and a county-cluster CR1 sensitivity
analysis. Model construction and support gates are in
[`R/models.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/models.R).

## Interpretation boundaries

- `TPA_UNADJ` expands records within the plot design; it is not a statewide survey weight.
- Zeros are assigned only when the relevant sampling opportunity is demonstrated.
- Exact FIA plot locations are confidential. Public FIADB coordinates may be approximate; this analysis neither uses nor infers them, relying only on county identifiers.
- Gap flags and fitted associations are exploratory and are not causal or design-based prevalence estimates.
- County Wilson intervals are unweighted binomial reference intervals. They ignore FIA survey design and within-county clustering and are descriptive rather than inferential county estimates.

See [Analysis decisions](analysis-decisions.md) for the complete decision log.
