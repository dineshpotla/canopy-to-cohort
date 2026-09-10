---
title: "Analytical data dictionary"
description: "Fields, units, derivations, and missing-value rules used in the Canopy to Cohort analysis"
toc: true
---

This dictionary documents the record grains and principal fields used in the
recruitment reanalysis, longitudinal detection pilot, and retained cross-sectional foundation. It
describes derived analytical data; record-level FIA observations are
intentionally not distributed with the public repository.

The v2.0 detection analysis is now an exploratory pilot. The
[revised research direction](research-direction.md) is implemented in the
[recruitment report](../report/recruitment.qmd). Record-level recruitment data
and predictions remain local; aggregate results and audits are exported.

## Recruitment endpoint and linked fates

- A conservative new live maple sapling tally has `SPCD=318`, `STATUSCD=1`,
  `1 <= DIA < 5` inches, `RECONCILECD=1`, and no `PREV_TRE_CN`. It must occur
  on comparable sampled area. This is not individual seedling survival, an
  exact recruitment date, or a count of stems that entered and died between visits.
- Baseline saplings are followed using successor `PREV_TRE_CN` to baseline
  `TREE.CN`, restricted to the expected successor plot. Retain fate status,
  reconciliation code, diameter, species corrections, and condition continuity.
  Unlinked or out-of-sample records are not deaths; living stems reaching
  5 inches have left the sapling size class, not disappeared biologically.
- One fully sampled current-pair follow-up has no live TREE rows and missing
  derived sapling metrics. The audit reconciles its absence using source
  records; the new endpoint builder handles this verified zero explicitly.
  This is not authorization to fill all missing tree measurements with zeros.
- Historical feasibility removes the single-evaluation restriction but retains
  baseline northern-hardwood and established-maple eligibility. Its 2,308
  intervals are provisional and reuse physical plots. Protocol and observation
  comparability must be validated before treating them as an analysis cohort.

`data/processed/recruitment_condition_pairs.rds` retains all 932 source pairs,
including excluded observations, at condition-interval grain.
`data/processed/recruitment_sapling_fates.rds` retains 1,593 tagged baseline
stems at stem-interval grain. Neither file is distributed.

| Field | Type / unit | Definition |
|---|---|---|
| `recruitment_eligible` | logical | Passed plot, protocol, shared microplot-frame, and new-record ambiguity checks; 922 intervals qualify. |
| `exclusion_reason` | text | Explicit failed opportunity or unresolved-record rule. Excluded outcomes are `NA`, not zero. |
| `outcome_recruitment` | 0 / 1 / `NA` | At least one qualifying new live maple sapling at follow-up, defined only on eligible intervals. |
| `baseline_seedling_count` | recorded count | Baseline maple `SEEDLING.TREECOUNT` summed by condition, checked against calculated counts; above-five microplot counts may be estimated. |
| `baseline_maple_sapling_tpa` | stems/acre | Baseline live maple sapling `TPA_UNADJ` divided by microplot condition coverage; not a statewide survey weight. |
| `direct_subplot_predecessors_available` | logical | Whether every relevant subplot has a direct predecessor link; all false in this snapshot because the source field is empty. |
| `exact_overlap` | logical | Exact mapped-area match within tolerance at the aggregate and relevant microplot levels; not an individual coordinate check. |
| `fate_eligible` | logical | Tagged stem has a comparable linked biological fate after frame, identity, and record-status checks; distinct from recruitment-pair eligibility. |
| `outcome_survival` | 0 / 1 / `NA` | Linked, comparable baseline sapling is still recorded alive (1), dead or removed (0); `NA` for ambiguous or ineligible fates. Removal is kept distinct from death in `outcome_death`. |
| `reached_five_inches` | logical | Follow-up record is live maple at or above five inches; biological summaries also require `fate_eligible`. |

The [endpoint definitions](../outputs/audits/recruitment-definitions.csv) and
[protocol audit](../outputs/audits/recruitment-protocol.csv) expose the rules.

Recruitment models use `log1p` count, `log1p` maple sapling stem density,
`log1p` established-maple basal area, microplot coverage, and interval.
Each model uses only its declared subset. Scaling is fit within training data;
the full-refit bootstrap repeats scaling. See the
[analysis contract](../research/runs/recruitment-2026-09-08/analysis-contract.md).

## Record grain and keys

### Survey-priority outputs

The `recruitment-survey-*.csv` tables report aggregate strategies on the existing
model populations. They do not contain individual site recommendations.

| Field | Meaning |
|---|---|
| `objective` | Either no recorded entry or recorded entry; score priority reverses accordingly. Neither is independently assessed survey need. |
| `requested_fraction`, `capacity` | Fixed illustrative fraction and `floor(n * fraction)` condition-interval count. Not an actual survey budget. |
| `expected_targets` | Expected target count under uniform allocation within cutoff-score ties. Can be fractional. |
| `selected_target_fraction` | Expected targets divided by capacity; different from the fraction of all targets captured. |
| `target_capture_fraction` | Expected targets divided by all target conditions in the evaluated population. |
| `random_expected_targets` | Capacity times target prevalence, not one simulated random sample. |
| `minimum_targets_over_cutoff_ties`, `maximum_targets_over_cutoff_ties` | Attainable target counts across cutoff-tie allocations; not confidence limits. |
| `deterministic_selected_physical_plots` | Distinct plots selected using stable source-key order, showing why condition capacity is not equal field cost. |
| `lower`, `upper` | Full-refit county-bootstrap percentile limits for selected target fraction or its paired difference, as identified by the output table. |

RI availability tables have a different purpose: `screen` indicates record
presence only. `LENGTH_CLASS_CD`, seedling-source codes, and RI sampling-status
codes remain raw codes in that preliminary export. Their subsequent decoding
and sampling checks are in the separate RI measurement audit below.

### RI measurement outputs

The `recruitment-ri-*.csv` tables describe the checked baseline measurement
subset, not fitted predictions. Record-level data are held in the ignored
`data/processed/recruitment_ri_audit.rds` bundle.

| Field | Meaning |
|---|---|
| `baseline_ri_frame_valid` | Complete code-1 forest-condition RI microplot coverage, valid subplot linkage, and agreement with the condition's sampled proportion. |
| `baseline_ri_available` | Frame and record checks plus the May-September plot-date plausibility screen. Missing RI measurements remain unavailable. |
| `ri_class_1` through `ri_class_6` | Maple tally counts in the six verified length classes; unavailable outside the accepted baseline frame. |
| `ri_all_count` | Total recorded maple RI count across length classes and permitted source groups. Not independent seedlings or genets. |
| `ri_standard_size_count` | Sum of classes 3-6, at least one foot long; compared with ordinary hardwood counts on identical units. |
| `ri_tall_count` | Sum of classes 5-6, at least five feet long; not the one-inch DBH sapling boundary. |
| `ri_zero` | No qualifying RI maple tally on a verified available baseline frame; not no germination or no future recruitment. |
| `annual_ri_guide_reviewed` | Baseline year 2016-2018 has an inspected annual supplement; the 2016 archived copy is a draft. Not universal protocol certification. |
| `event_fraction`, `lower`, `upper` | Descriptive recorded-entry fraction and county-bootstrap limits for the declared group, not prediction accuracy or a causal effect. |

Nine intervals have valid RI maple tally zeros; 832 lack baseline RI and retain
missing length information. Ten ordinary-zero intervals contain RI maple only
below one foot. These observation states are deliberately distinct.

### Analytical units

The primary analytical unit is one baseline–follow-up forest-condition pair.
Each visit retains the composite key `PLT_CN + CONDID`. Tree and seedling records
are first aggregated independently to visit-condition grain and only then joined
to pair records, preventing many-to-many row inflation.

| Field | Type / unit | Definition |
|---|---|---|
| `plt_cn` | character identifier | FIA plot-visit control number. Used as a relational key; not a coordinate. |
| `condid` | integer identifier | Condition number within the plot visit. |
| `geoid` | five-character code | State and county FIPS code used for county-safe spatial joins and the county random intercept. |
| `county_name` | character | FIA county name resolved from the database reference table. |
| `measyear` | year | Calendar year of field measurement. Observations in this release span 2018–2025. |
| `forest_type` | character | Active type in FIA maple/beech/birch group 800 (codes 801, 802, 805, or 809), which this project uses as its operational northern-hardwood cohort. |

### Longitudinal pair keys and quality fields

| Field | Type / unit | Definition |
|---|---|---|
| `baseline_plt_cn`, `baseline_condid` | identifiers | Previous-visit condition key. Primary eligibility and all ecological predictors are defined here. |
| `current_plt_cn`, `current_condid` | identifiers | Current-evaluation condition key supplying the follow-up outcome. |
| `physical_plot_key` | character identifier | Stable state–unit–county–plot key used only to audit multiple conditions within a physical plot. |
| `baseline_pair_degree`, `current_pair_degree` | count | Number of positive microplot condition links on each side, computed before ecological filtering. |
| `strict_one_to_one` | logical | `TRUE` only when both pair degrees equal one. |
| `overlap_prop` | proportion | `SUBPTYP_PROP_CHNG` summed for `SUBPTYP = 2` across the four microplots and divided by four. |
| `baseline_overlap_fraction` | proportion | `overlap_prop / baseline_micrprop_unadj`. |
| `followup_overlap_fraction` | proportion | `overlap_prop / followup_micrprop_unadj`. |
| `primary_pair_eligible` | logical | Baseline eligible with established maple, comparable forested follow-up, strict one-to-one mapping, at least 90% overlap on both sides, and a positive interval. |
| `interval_years` | years | Difference in measurement year plus month fraction; inventory year is the fallback if measurement year is missing. |

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
| `treated` | logical | `TRUE` when any of `TRTCD1`–`TRTCD3` contains a positive treatment code. Used only in the retained cross-sectional model; excluded from the primary longitudinal model. |

## Live-tree and size-class metrics

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
| `maple_sapling_ba_ft2_ac` | ft²/acre | Frame-corrected basal area of live sugar-maple TREE records with DBH 1–4.9 inches. |
| `maple_sapling_present` | logical | `TRUE` when at least one live sugar-maple TREE record has DBH 1–4.9 inches. The longitudinal model uses its baseline value. |
| `overstory_total_ba_ft2_ac` | ft²/acre | Frame-corrected basal area of all live TREE records with DBH ≥ 5 inches. |
| `established_maple_ba_ft2_ac` | ft²/acre | Frame-corrected basal area of live sugar-maple TREE records with DBH ≥ 5 inches. |
| `nonmaple_ba_ft2_ac` | ft²/acre | `total_ba_ft2_ac - maple_ba_ft2_ac`, bounded below at zero. |
| `maple_ba_share` | proportion | Frame-corrected sugar-maple basal area divided by frame-corrected total live-tree basal area. |
| `established_maple_ba_share` | proportion | `established_maple_ba_ft2_ac / overstory_total_ba_ft2_ac`, with zero assigned when no live DBH ≥ 5-inch tree basal area is present. Used only for the descriptive gap screen. |
| `established_maple_records` | count | Number of live sugar-maple TREE records with DBH ≥ 5 inches. Baseline longitudinal eligibility requires at least one. |

American beech is resolved from `REF_SPECIES` as *Fagus grandifolia*, FIA
species code 531. The longitudinal builder also publishes
`beech_ba_ft2_ac`, `beech_sapling_ba_ft2_ac`, and
`beech_established_ba_ft2_ac` for each visit. The primary model uses baseline
American beech sapling basal area.

The derived total is checked against FIA `COND.BALIVE`; the pipeline enforces
strict correlation and absolute-error gates that detect use of a wrong sampling
frame. Implementation:
[`R/basal_area.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/basal_area.R).

## Regeneration metrics and response

| Field | Type / unit | Definition and interpretation |
|---|---|---|
| `maple_seedling_tpa` | trees/acre | Sugar-maple seedling `TPA_UNADJ` summed on the plot basis and divided by `micrprop_unadj`. `NA` when seedling sampling was not demonstrated. |
| `maple_seedling_detected` | 0 / 1 / `NA` | `1` when a sampled condition has positive sugar-maple seedling density; `0` when sampled but none were tallied; `NA` when sampling opportunity is unknown. |
| `outcome_no_seedlings` | 0 / 1 | Retained cross-sectional model response: `1 - maple_seedling_detected`. It means “no seedlings tallied,” not confirmed ecological absence. |
| `established_percentile` | 0–1 | Sample percentile of `established_maple_ba_share` among conditions with usable seedling sampling. |
| `regeneration_percentile` | 0–1 | Sample percentile of `log(1 + maple_seedling_tpa)` among usable conditions. |
| `potential_gap` | logical | `TRUE` when `established_maple_ba_share` is at or above the sample upper-third threshold and no sugar-maple seedlings were tallied. Exploratory, not a validated ecological index. |
| `potential_gap_sensitivity` | logical | Alternative flag using the upper-quartile established-share threshold. |

Implementation: [`R/regeneration.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/regeneration.R)
and [`R/features.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/features.R).

## Longitudinal transition and response fields

| Field | Type / unit | Definition and interpretation |
|---|---|---|
| `baseline_seedling_detected` | 0 / 1 | Sugar-maple seedling detection at the previous visit. |
| `followup_seedling_detected` | 0 / 1 | Sugar-maple seedling detection at the mapped current visit. |
| `seedling_transition` | factor | One of persistent non-detection, appearance, loss, or persistence. |
| `seedling_detection_loss` | 0 / 1 / `NA` | For baseline detections only: `1 - followup_seedling_detected`; `NA` for baseline non-detections. |
| `seedling_detection_appearance` | 0 / 1 / `NA` | For baseline non-detections only: the follow-up state; `NA` for baseline detections. |
| `baseline_other_nonmaple_ba_ft2_ac` | ft²/acre | Baseline non-maple basal area minus American beech sapling basal area, bounded below at zero. Established beech remains in this background stand-structure term. |
| `followup_group_800` | logical | Whether the follow-up condition remains in forest-type group 800. A post-baseline sensitivity descriptor, not an eligibility rule. |

## Climate fields

Climate fields are 1991–2020 Daymet normals from the 1-km cell containing each
Census Gazetteer county internal point. They are county-scale spatial proxies,
not plot-level measurements or county-wide areal averages.

| Field | Unit | Definition |
|---|---|---|
| `mean_annual_temp_c` | °C | Mean across years of daily `(tmin + tmax) / 2`, averaged within year and then across 1991–2020. |
| `mean_annual_precip_mm` | mm/year | Mean annual sum of daily precipitation across 1991–2020. |

Implementation: [`R/climate.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/climate.R).

## Longitudinal model transformations

The model-complete loss cohort contains 677 baseline detections, including 75
loss events. Continuous predictors are standardized after `log1p`
transformation where stated. Cross-validation relearns every center and scale
from its training counties only.

| Model field | Source and transformation |
|---|---|
| `z_baseline_seedling_tpa` | standardized `log(1 + baseline_maple_seedling_tpa)` |
| `maple_sapling_present` | baseline logical indicator, with `FALSE` as the reference |
| `z_established_maple_ba` | standardized `log(1 + baseline_established_maple_ba_ft2_ac)` |
| `z_beech_sapling_ba` | standardized `log(1 + baseline_beech_sapling_ba_ft2_ac)` |
| `z_other_nonmaple_ba` | standardized `log(1 + baseline_other_nonmaple_ba_ft2_ac)` |
| `z_microplot_coverage` | standardized `baseline_micrprop_unadj` |
| `z_interval_years` | standardized `interval_years` |

The primary loss fit is a binomial GLM with county-cluster CR1 confidence intervals.
Five-fold internal validation holds out whole counties. A county
random-intercept GLMM is reported only as sensitivity evidence. Implementation:
[`R/longitudinal_models.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/longitudinal_models.R).

The secondary appearance cohort contains 255 baseline non-detections, including
59 later detections. It reuses `maple_sapling_present`,
`z_established_maple_ba`, `z_microplot_coverage`, and `z_interval_years`; no
baseline seedling-density term is possible because all starting tallies are
zero. Its four-slope model uses county-cluster CR1 intervals and the same
training-only scaling and county-held-out validation protocol. Implementation:
[`R/longitudinal_appearance_models.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/longitudinal_appearance_models.R).

## Retained cross-sectional model transformations

Continuous predictors are standardized after defining the final model-complete
cohort, so one standardized unit refers to the fitted 1,072-condition primary cohort.
Basal-area predictors are transformed with `log(1 + x)` before standardization.
The scaling means, standard deviations, transformations, and cohort size are
published as a separate audit table.

| Model field | Source and transformation |
|---|---|
| `z_maple_ba` | standardized `log(1 + established_maple_ba_ft2_ac)` in the primary model; retained as a linear term after functional-form comparison |
| `maple_sapling_present` | factor with `FALSE` as the reference level |
| `z_nonmaple_ba` | standardized `log(1 + nonmaple_ba_ft2_ac)` |
| `z_microplot_coverage` | standardized `micrprop_unadj` |
| `treated` | factor with `FALSE` as the reference level |
| `z_stand_age` | standardized `stand_age` |
| `disturbed` | factor with `FALSE` as the reference level |
| `z_mean_temp` | standardized `mean_annual_temp_c` |
| `z_precip` | standardized `mean_annual_precip_mm` |
| `z_year` | standardized `measyear` |

The supported release model is a mixed-effects logistic regression with a
county random intercept. It separates established-tree basal area from
sugar-maple sapling presence and reports adjusted probability profiles by
sapling state. Ten-fold internal grouped validation holds out whole counties, relearns
transformations within each training fold, and predicts held-out counties with
fixed effects only. Conventional coefficient inference is supplemented by
Benjamini–Hochberg adjusted p-values and a county-cluster CR1 sensitivity
analysis. Model construction and support gates are in
[`R/models.R`](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/models.R).

The contextual full-cohort baseline uses standardized `log(1 + maple_ba_ft2_ac)`
with a three-degree-of-freedom natural spline. It is not the primary inferential
model because the exposure combines saplings and established trees.

## Length-study planning fields

The [study design](../report/length-study.qmd) and `make length-plan` create
planning outputs, not another fitted model. `length_study_opportunity_metadata.rds`
is local and ignored; published `recruitment-length-*.csv` files are aggregates.

| Field or quantity | Definition and boundary |
|---|---|
| `baseline_condition_visits` | Distinct baseline plot-record/condition pairs in the RI metadata screen; not validated recruitment intervals. |
| `physical_plots` | Distinct state/unit/county/plot combinations; one plot may have several historical visits. |
| `standard_maple_record_present` | At least one positive ordinary maple seedling row at baseline; a presence screen, not full count/frame validation. |
| `successor_count` | Number of distinct successor PLOT records declaring this baseline as predecessor; zero/ambiguous successors remain separate. |
| `in_current_recruitment_plot_set` | Membership in the current 903-plot cohort; nonmembership does not establish untouched evaluation data. |
| Q = H/N | Fraction of reconciled standard-size maple seedlings in RI classes 5-6. Undefined for N = 0; not a fraction surviving to saplings. |
| Paired Brier gain | Count loss minus length loss, averaged within plot then across plots. Positive favors length; differs from condition-average weighting. |
| `loss_difference_sd` | Hypothetical SD of plot-level paired losses in the planning table, not an estimated RI-model quantity. |
| `variance_inflation` | Assumed multiplier of mean-loss variance relative to independent plots; not a measured county design effect. |
| `complete_evaluation_plots` | Rounded normal-approximation precision requirement under specified assumptions; not training size, power, or calibration adequacy. |
| `candidate_plots_at_assumed_retention` | Complete-plot requirement divided by assumed retention and rounded upward; an expected-yield scaling, not guaranteed enrollment. |
| `independent_event_units` | Plug-in Wilson-width calculation at assumed fixed-rule recall; event units rather than total plots and not paired-policy precision. |

## Interpretation boundaries

- `TPA_UNADJ` expands records within the plot design; it is not a statewide survey weight.
- Zeros are assigned only when the relevant sampling opportunity is demonstrated.
- Exact FIA plot locations are confidential. Public FIADB coordinates may be approximate; this analysis neither uses nor infers them, relying only on county identifiers.
- Gap flags and fitted associations are exploratory and are not causal or design-based prevalence estimates.
- The retained cross-sectional size-class associations do not estimate transitions; the v2.0 repeated-condition outcome does not track individual seedlings.
- Detection appearance is an operational gain state, not verified recruitment, colonization, or recovery; its weak validation does not support site-level gain targeting.
- County Wilson intervals are unweighted binomial reference intervals. They ignore FIA survey design and within-county clustering and are descriptive rather than inferential county estimates.

See [Analysis decisions](analysis-decisions.md) for the complete decision log.
