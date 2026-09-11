---
title: "Analytical data dictionary"
description: "Fields, units, derivations, and missing-value rules for the Michigan sugar-maple recruitment study."
toc: true
---

This dictionary documents the data used in the
[recruitment study](../report/recruitment.qmd): paired forest conditions,
recorded sapling entry, model predictors, and linked sapling fates. Record-level
data and predictions remain local; public outputs contain aggregate evidence.

## Analytical units and keys

The primary analytical unit is one forest condition observed across two linked
visits. A physical plot can contain multiple conditions. Tree and seedling
summaries join to the condition pair at the appropriate level to avoid
multiplying observations through many-to-many joins.

`data/processed/recruitment_condition_pairs.rds` retains 932 source pairs,
including excluded observations. Of these, 922 qualify for analysis, representing
903 physical plots and 66 counties. The source spans baseline measurements in
2011–2018 and follow-ups in 2018–2025.

| Field | Type / unit | Definition |
|---|---|---|
| `baseline_plt_cn`, `baseline_condid` | Identifiers | Baseline plot-visit and condition key; ecological eligibility and predictors come from this visit. |
| `current_plt_cn`, `current_condid` | Identifiers | Follow-up plot-visit and condition key supplying the recruitment outcome. |
| `physical_plot_key` | Character identifier | State, unit, county, and plot combination; used to check repeated contributions and separation of training and test plots. |
| `geoid` | Five-character code | State and county FIPS code used for map joins, county folds, and county resampling. |
| `county_name` | Text | County name resolved from FIA reference data. |
| `baseline_measyear`, `followup_measyear` | Year | Measurement years for the paired visits. |
| `interval_years` | Years | Elapsed interval from measurement year and month; inventory year supplies a fallback when measurement year is missing. |

## Sampling and eligibility

| Field | Type / unit | Definition |
|---|---|---|
| `primary_pair_eligible` | Logical | Baseline ecological eligibility, comparable sampled forest at follow-up, one-to-one condition mapping, and sufficient relative overlap. |
| `baseline_micrprop_unadj`, `followup_micrprop_unadj` | Proportion | Unadjusted microplot-area fraction assigned to the condition at each visit. |
| `overlap_prop` | Proportion | Sum of microplot condition-change proportions across the four microplots, divided by four. |
| `baseline_overlap_fraction`, `followup_overlap_fraction` | Proportion | Shared overlap divided by the condition's microplot coverage at the respective visit; source eligibility requires at least 0.90 on both sides. |
| `protocol_design_comparable` | Logical | National design, manual versions at least 5.1, permitted production QA codes, remeasurement, and unchanged microplot arrangement. |
| `shared_microplot_sampled` | Logical | Both visits demonstrate sampling on every relevant shared microplot. |
| `shared_subplot_predecessor_matches` | Logical | Verified plot/subplot links and agreement of any populated direct subplot predecessor. |
| `direct_subplot_predecessors_available` | Logical | Every relevant direct subplot predecessor is populated; false throughout this snapshot because `PREV_SBP_CN` is empty. |
| `frame_proportions_valid` | Logical | Each shared microplot proportion fits within both visits' mapped condition proportions. |
| `exact_overlap` | Logical | Aggregate and individual microplot mapped proportions agree within tolerance; used for sensitivity analysis. |
| `recruitment_eligible` | Logical | Passed source-pair, protocol, sampled-area, count, and new-record checks; 922 intervals qualify. |
| `exclusion_reason` | Text | Explicit reason for exclusion or unresolved eligibility; preserves the accounting for all 932 pairs. |

The analysis excludes nine pairs with inconsistent microplot proportions and
one with ambiguous new saplings. Missing or ambiguous opportunities do not
become negative recruitment outcomes. The model requires complete, finite
predictor fields and stops rather than silently dropping different observations.

## Recruitment endpoint

A qualifying new live sugar-maple sapling has `SPCD=318`, `STATUSCD=1`,
diameter at least 1 inch and less than 5 inches, `RECONCILECD=1`, and no
predecessor TREE record. It must occur on a comparable shared sampled microplot.

| Field | Type / unit | Definition |
|---|---|---|
| `new_maple_sapling_count` | Count | Qualifying new live maple sapling records assigned to the condition pair; interpretation requires `recruitment_eligible`. |
| `ambiguous_new_maple_sapling_count` | Count | Newly recorded live maple saplings that lack a resolved entrant classification; positive values prevent recruitment eligibility. |
| `outcome_recruitment` | 0 / 1 / `NA` | At least one qualifying entrant on an eligible interval; excluded intervals retain `NA`. |
| `followup_zero_tree_corrected` | Logical | Explicit correction of derived tree quantities for a source-verified sampled follow-up with no live TREE records and `BALIVE=0`. |

The retained cohort contains 169 qualifying saplings in 100 conditions.
These records describe surviving entrants present at the next visit. They
do not link individual baseline seedlings to later trees or identify entrants
that died before remeasurement.

The [endpoint definitions](../outputs/audits/recruitment-definitions.csv) and
[protocol audit](../outputs/audits/recruitment-protocol.csv) document the rules.
Implementation:
[`R/recruitment.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/recruitment.R).

## Model predictors and transformations

| Source field | Unit and derivation | Model field / transformation |
|---|---|---|
| `baseline_micrprop_unadj` | Fraction of nominal microplot area in the baseline condition | `z_coverage`; identity, then training standardization |
| `interval_years` | Elapsed years between visits, known at follow-up | `z_interval`; identity, then training standardization |
| `baseline_seedling_count` | Baseline maple `SEEDLING.TREECOUNT` summed across condition microplots and checked against `TREECOUNT_CALC` | `z_seedling_count`; `log(1 + x)`, then training standardization |
| `baseline_maple_sapling_tpa` | Live maple sapling `TPA_UNADJ` summed and divided by baseline microplot coverage; stems per acre | `z_sapling_tpa`; `log(1 + x)`, then training standardization |
| `baseline_established_maple_ba_ft2_ac` | Basal area of live maples at least five inches in diameter, corrected for sampled area; square feet per acre | `z_established_ba`; `log(1 + x)`, then training standardization |

Four logistic models use training prevalence, design variables, design plus
count, and design plus count plus maple stages. Each model uses its declared
subset of the five predictors. All eligible intervals and the 672 intervals
with positive baseline counts have separately fitted comparisons.

Training means and standard deviations determine scaling of both training
and held-out observations. A constant training predictor uses a scale of one.
Bootstrap fits repeat this process. The primary ridge penalty equals one and
leaves the intercept unpenalized.

Ordinary counts may include field estimates above five seedlings per record.
`TPA_UNADJ` expands observations within the plot design and is not a
statewide survey weight. Neither raw count nor seedling density identifies
independent seed-origin individuals.

Implementation:
[`R/recruitment_models.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/recruitment_models.R).

## Validation outputs

The `recruitment-model-*.csv` files report aggregate model evidence. Their
populations overlap; scores weight condition intervals equally.

| Field or quantity | Interpretation |
|---|---|
| `population`, `model` | The analysis population and one of the four declared benchmarks. |
| `observations`, `events` | Evaluated condition intervals and intervals with recorded entry. An event is not a stem count. |
| `brier_score` | Mean squared difference between recorded outcome and predicted probability; lower values indicate less error. |
| `log_loss` | Mean negative log probability of the observed outcome; lower values indicate less error. |
| `roc_auc`, `average_precision` | Ranking metrics; average precision also depends on event prevalence. |
| `calibration_intercept`, `calibration_slope` | Joint regression of outcomes on held-out predicted log odds; diagnostic estimates. |
| `mean_predicted_probability`, `observed_expected_ratio` | Average predicted probability and observed events divided by summed predicted probabilities. |
| `difference` | Named model minus reference score on identical observations; a negative Brier difference favors the added information. |
| `lower`, `upper` | Percentile limits for the quantity identified by the table, from resampling whole counties and refitting models. |

County folds keep each physical plot together. The temporal assessment
instead separates follow-ups before 2023 from those in 2023 onward with no
shared physical plots. Neither assessment provides untouched external
validation of this fixed source snapshot.

## Linked sapling fates

`data/processed/recruitment_sapling_fates.rds` contains 1,593 baseline stems
at stem-interval level. Links use successor `PREV_TRE_CN` and the expected
successor plot. The 1,580 comparable stems have 334 recorded deaths,
1,188 live saplings, and 58 live stems reaching at least five inches.

| Field | Type / unit | Definition |
|---|---|---|
| `tree_cn`, `followup_tree_cn` | Identifiers | Baseline TREE record and its linked successor. |
| `fate` | Text | Recorded death, removal, live persistence, live advancement, or an explicit unresolved/record-correction category. |
| `fate_eligible` | Logical | Comparable frame, condition link, species, and recorded biological state; assessed separately from recruitment eligibility. |
| `outcome_survival` | 0 / 1 / `NA` | Still alive (1), dead or removed (0), or ineligible/unresolved (`NA`). |
| `outcome_death` | 0 / 1 / `NA` | Recorded death among eligible stems; removals retain `NA` in this endpoint. |
| `reached_five_inches` | Logical | Live follow-up maple at or above five inches; biological summaries also require `fate_eligible`. |
| `annual_diameter_increment` | Inches/year | Follow-up minus baseline diameter divided by elapsed years for comparable surviving maples. |

Species reidentification, inconsistent sampling frames, and no-longer-sampled
records remain in the accounting. A missing or ineligible successor is not
assigned a biological death.

## Supporting survey and measurement outputs

The `recruitment-survey-*.csv` tables compare fixed selection strategies.

| Field | Meaning |
|---|---|
| `objective` | Recorded entry or no recorded entry; determines the ranking direction. |
| `requested_fraction`, `capacity` | Fixed selection fraction and its condition-interval count. |
| `expected_targets` | Expected number of target conditions after averaging selection uniformly across cutoff ties. |
| `selected_target_fraction` | Expected targets divided by selection capacity. |
| `target_capture_fraction` | Expected targets divided by all target conditions. |
| `lower`, `upper` | County-bootstrap limits for the quantity identified by the table, including paired strategy differences where specified. |

The `recruitment-ri-*.csv` tables describe a measurement subset of 90
intervals with 14 recorded-entry conditions. They contain no fitted length
model. Record-level measurement data remain in the local
`data/processed/recruitment_ri_audit.rds` bundle.

| Field | Meaning |
|---|---|
| `baseline_ri_frame_valid` | Complete RI forest-condition microplot coverage, consistent links, and matching sampled proportions. |
| `baseline_ri_available` | Frame and record checks plus the May–September plot-date plausibility screen. |
| `ri_class_1` through `ri_class_6` | Recorded maple counts in the six length classes. |
| `ri_standard_size_count` | Sum of classes 3–6, at least one foot long; reconciled with ordinary counts on identical units. |
| `ri_tall_count` | Sum of classes 5–6, at least five feet long. |
| `ri_zero` | No qualifying maple tally on a verified available RI frame. |
| `annual_ri_guide_reviewed` | Baseline year has an inspected annual supplement; 2016–2018 guides were inspected, including a 2016 draft. |

Nine available intervals have verified RI maple zeros. The 832 intervals
without available baseline RI retain missing length information. Ten
ordinary-count-zero intervals contain RI maples only below one foot.

## Geographic and interpretation boundaries

The study map counts eligible recruitment intervals by `geoid`. Its colors
describe sample coverage. The analysis does not use or infer exact FIA plot
coordinates or estimate county regeneration rates.

The outcomes and scores are descriptive or predictive results for the selected
Michigan sample. They do not provide survey-weighted population estimates,
individual seedling survival, a causal effect, or an operational treatment rule.

See [Analysis decisions](analysis-decisions.md) for the cohort and comparison
rules and the [research paper](../report/recruitment.qmd) for their results.
