# Analysis decisions

This log records choices that materially affect the scientific interpretation.
It is updated from the actual FIA schema and cohort diagnostics; species,
forest-type, status, disturbance, and treatment fields are checked against FIA
reference tables or the FIADB user guide.

## Core paper completion on 9 September 2026

The user prioritizes the Michigan core research and paper over regional
acquisition. The [completion contract](../research/runs/recruitment-2026-09-08/core-paper-contract.md)
keeps the endpoint, two populations, model sequence, folds, penalty, full-refit
uncertainty, and temporal assessment. No new predictors or length models are
fitted. The paper is organized around ordinary-count information, added
maple-stage value, and linked tagged-stem fates.

Main metrics give equal weight to condition intervals, not plots or FIA
expansion weights. This differs from the plot-balanced metric proposed for
the optional length study. Realized interval yields a conditional retrospective
next-visit target, not a validated fixed-horizon forecast. Joint calibration
intercept and slope are distinguished from calibration-in-the-large.

`make recruitment-core` reproduces the Michigan analyses and paper audit
without regional acquisition or length planning. The audit recomputes metrics
from stored predictions and reconciles cohort, resampling, and fate summaries.
Regional and operational validation are future work, not reasons to withhold
the bounded core results. No publication or independent final sign-off is claimed.

## Authorized regional feasibility: 9 September 2026

The user authorized Wisconsin and Minnesota public-inventory acquisition and
feasibility screening. The [regional contract](../research/runs/recruitment-2026-09-08/regional-feasibility-contract.md)
preserves the species, forest types, same-area comparison, and outcome-blinded
boundary. No regional model fitting or field coordination is included.

Both archive transfers currently fail with empty HTTP responses. Reachable
update histories do not substitute for records; no regional sample counts are
inferred. `make regional-acquire` records failures explicitly and, on successful
retrieval, guards disk space, archive paths, SQLite integrity, source state,
and immutable file hashes. It is separate from the Michigan pipeline. See the
[access review](../research/runs/recruitment-2026-09-08/regional-access-review.md).
The scientific screen remains pending, not completed or statistically negative.

## Count-versus-length study design: 9 September 2026

The [design contract](../research/runs/recruitment-2026-09-08/length-study-contract.md)
and [study protocol](../report/length-study.qmd) specify the next comparison;
no additional recruitment outcomes or length models are produced.

- Use ordinary seedling count, coverage, and elapsed interval as the simple
  benchmark; add only the fraction of standard-size seedlings in RI classes
  5-6. Restrict the primary comparison to positive ordinary counts and verified
  same-area definitions. Do not encode an undefined zero-denominator fraction.
- Retain the recorded next-visit endpoint and label its realized-duration
  adjustment as retrospective and conditional, not an exact-horizon forecast.
- Predeclare date-based choice of one interval per plot within a period,
  plot-balanced training and paired Brier evaluation, and no shared plot across
  development/assessment. Positive Brier gain favors length; field utility and
  a minimum meaningful gain are not inferred from that sign.
- Census only RI opportunity metadata in the local snapshot. Of 88 positive-
  seedling opportunities on 79 plots, seven visits on six plots are outside the
  current 903-plot cohort. Additional frame/condition/protocol checks remain.
  These rows do not constitute an independent evaluation sample.
- Export 54 hypothetical paired-loss precision scenarios and separate plug-in
  Wilson recall-width illustrations. They do not establish power, calibration
  adequacy, training sample size, actual RI effect size, or guaranteed retention.
- Recommend a separately scoped Wisconsin/Minnesota feasibility screen; a
  geographic extension tests transport and is not Michigan-specific validation.

Run `make length-plan`. No new state inventory, model, publication, or field
coordination is included in this completed design.

## RI measurement audit: 9 September 2026

The [RI contract](../research/runs/recruitment-2026-09-08/ri-contract.md)
fixes a measurement audit before any new height model. The
[audit report](../report/ri-audit.qmd) is the resulting descriptive study.

- Retain the existing 922-interval recruitment endpoint and eligible population.
  Baseline RI is screened independently of follow-up RI; TREE endpoint sampling
  remains governed by the recruitment audit.
- Require code-1 RI coverage of every contributing forest-condition microplot,
  consistent core/RI subplot links, reconstructed condition area, valid
  condition/subplot-condition foreign keys, and valid count/source/length codes.
  A missing retired subplot-status field is allowed; a contradictory populated
  field is not. Unknown or nonsampled RI is unavailable, not zero.
- Screen plot dates for May-September; no separate RI field date is present.
  Treat date failures as unresolved plausibility flags, not proof of actual
  out-of-season RI collection.
- Keep all six classes and source categories; compare ordinary counts to RI
  classes 3-6 on identical units. The resulting 311/311 exact matches establish
  numerical redundancy, not independent field validation or an audited database
  derivation mechanism.
- Prespecify classes 5-6 as the taller group. Report associations for all 90
  available baseline intervals and for the 71 ordinary-detected intervals.
  Use 2,000 county resamples for descriptive intervals, not forecast validation.
- Record historical coverage: 2016-2018 supplements inspected, including an
  archived 2016 draft; individual 2012-2015 supplements remain unrecovered.
  Do not equate the stored core `PLOT.MANUAL` number with a P2+ annual edition.
- Stop before fitting height models: 14 total event plots split into ten
  development and four later-year events. A larger sample and a meaningful
  paired gain are needed before claiming incremental usefulness.

No external inventory, fieldwork, management rule, or publication is included.

## Survey-priority extension: 8 September 2026

The [survey contract](../research/runs/recruitment-2026-09-08/survey-contract.md)
declares a retrospective decision proxy after the first recruitment results:
locating no recorded entry among baseline-detected conditions. It does not
redefine the biological endpoint or establish actual survey need.

- Compare random expectation, raw count, count per sampled coverage, sapling
  presence, and the two existing count/stage models. No extra predictor search.
- Use 25% condition-interval capacity as the main comparison and 10%/50% as
  fixed alternatives. Report the reversed objective of locating recorded entry.
- Integrate uniform random selection within cutoff ties for the main target
  counts. Retain deterministic source-key capture, attainable tie bounds, and
  distinct selected plots; do not equate conditions with a fieldwork budget.
- Reuse original county folds and run 300 full-refit county resamples per
  population, including repeat scaling and selection. All 600 succeed.
- Retain the earlier temporal test. A common seven-year scoring sensitivity
  changes only test predictors, not training intervals or scaling; actual
  outcome durations remain variable, so seven-year probabilities are unvalidated.
- Do not invent utility weights or a net-benefit threshold for surveying.
  The selected proxy is common, and a strong simple rule is the reference.
- Inventory the local RI tables only for record availability. Ninety eligible
  intervals have baseline RI plot records and 14 recorded-entry events. No
  absent RI row is recoded as zero, and no height model is fitted from this screen.

Stage-model yield exceeds the raw-count rule by one expected condition at
168-condition capacity, with paired uncertainty spanning zero. This motivated
the subsequent RI measurement audit above; the
[validation plan](survey-validation-plan.md) still does not authorize an
operational ranking release.

## Recruitment reanalysis: 8 September 2026

The new [recruitment report](../report/recruitment.qmd) implements the direction
review below. The [analysis contract](../research/runs/recruitment-2026-09-08/analysis-contract.md)
records the fixed endpoint, benchmark sequence, and interpretation limits.

- The endpoint is a newly tallied live sugar-maple TREE record with
  `1 <= DIA < 5`, `RECONCILECD=1`, and no predecessor. It is not the fate of
  an individually tagged baseline seedling.
- Sampling checks use the intended plot predecessor, sampled forest status,
  national design, unchanged microplot arrangement, subplot numbers, and
  microplot condition-change proportions. `SUBPLOT.PREV_SBP_CN` is entirely
  empty in this database, so continuity is reconstructed, not directly verified
  through that field. Production QA codes 1 and 7 are retained.
- The source has 932 pairs. Nine fail the conservative shared-proportion check
  and one has ambiguous new saplings, leaving 922 intervals and 169 entrants
  in 100 conditions. Unresolved opportunities are not negative outcomes.
- Both all eligible pairs and the 672 pairs with baseline seedlings detected
  are principal model populations. All 100 recruit-bearing conditions are in
  the latter. A zero observed event rate in baseline non-detections is not
  treated as a known probability of zero.
- Four fixed logistic models compare prevalence, observation opportunity,
  recorded seedling count, and maple stage structure. The penalty is summed
  binomial negative log likelihood plus `1/2 * sum(beta^2)` for slopes only.
  Counts and sapling density are `log1p` transformed; scaling is learned within
  each training sample. No coefficient p-values are attached to ridge fits.
- Five folds hold out counties; their allocation uses counts, not outcomes.
  Paired uncertainty uses 300 county resamples per population, refitting
  scaling and all four models. Original folds and the model set stay fixed.
  All 600 resamples succeed. The bootstrap omits question/model-set selection
  uncertainty and is not an independent validation dataset.
- Brier score, log loss, AUC, average precision, calibration, and equal-capacity
  capture are reported on identical held-out observations within each population.
  Probability ties use stable key order, with tie-neutral capture also exported.
- Exact mapped overlap, follow-up manual version 9 onward, and penalties 0 and
  4 are sensitivities. A retrospective pre-2023/2023-onward split shares no
  physical plots. The data snapshot was previously explored.
- Tagged baseline saplings are searched on the expected successor plot before
  filtering follow-up species, diameter, or status. Frame-ineligible, reidentified,
  and cruiser-error records stay in the accounting but receive no biological
  fate outcome. The fate cohort has its own eligibility flag; an ambiguous new
  arrival does not by itself invalidate an existing tagged stem's follow-up.
- One source-verified sampled zero with `BALIVE=0` corrects missing derived
  follow-up tree metrics in the new data only. This is not general imputation.

The stage models' small added Brier improvements have intervals spanning zero,
and they capture no more recruit-bearing conditions at equal capacity. The
analysis is not extended with extra predictors to obtain a preferred result.

## Direction review: 7 September 2026

The [research direction and goals](research-direction.md) supersede the earlier
interpretation. It proposed evaluating recorded sapling recruitment
and linked-stem fates, now implemented as described above. The detection analysis below
is retained as an exploratory pilot, and its operational field-triage claim is
withdrawn. Audit scripts 11 and 12 reproduce the benchmark reassessment and
candidate-endpoint counts. Existing outcomes have been explored, so neither
the reanalysis nor a later temporal split of this snapshot is untouched validation.

The full detection model improves Brier by only 0.00102 over starting abundance,
coverage, and interval; a conditional county-bootstrap interval spans zero.
Using total non-maple basal area as the comparator does not erase the beech
association. Its uncertainty and limited added prediction argue against a
beech-centered research agenda, not against testing beech as one hypothesis.

## Declared pilot boundaries

1. The primary analytical key is a baseline and follow-up condition pair. Each
   visit retains its `PLT_CN + CONDID` key.
2. The pilot's primary response is loss of sugar-maple seedling detection between
   sampled visits. A separate secondary response captures detection appearance
   among baseline non-detections. Neither is tracked mortality, recruitment, or
   confirmed ecological absence.
3. The regeneration-gap flag is a descriptive screen, not a validated index or
   the regression response.
4. Climate is a county-scale proxy and cannot be interpreted as plot exposure.
5. Maps summarize the analyzed sample, not design-based county or statewide
   population estimates.
6. Exact FIA plot locations are neither used nor inferred.
7. Formal FIA population estimation remains a future extension. Transition
   counts and predictions are sample analyses, not statewide prevalence.

## Source and cohort

- **FIADB source.** Michigan's SQLite FIADB archive was retrieved from the FIA
  DataMart. The acquisition audit records the URL, byte size, retrieval time,
  and SHA-256 checksum.
- **Evaluation.** Release v2.0.0 pins EVALID 262501, “MICHIGAN 2025:
  2019-2025: CURRENT AREA, CURRENT VOLUME.” The evaluation inventory window is
  2019–2025; assigned measurement records span 2018–2025. A configuration
  change is required to analyze a different evaluation.
- **Operational northern-hardwood cohort.** FIA forest-type group 800 is the
  maple / beech / birch group. Active retained types resolve from
  `REF_FOREST_TYPE`: 801 sugar maple / beech / yellow birch, 802 black cherry,
  805 hard maple / basswood, and 809 red maple / upland.
- **Sugar maple.** `REF_SPECIES` resolves *Acer saccharum* to SPCD 318.
- **Seedling opportunity.** A condition is sampled only when
  `MICRPROP_UNADJ > 0`. An absent sugar-maple SEEDLING row becomes zero only
  under that demonstrated opportunity.

## Detection-pilot longitudinal design

- **Time ordering.** Ecological eligibility and every ecological predictor are
  defined at baseline. Follow-up is screened only for a valid outcome
  observation—sampled accessible forest with positive microplot coverage—and
  is never used to define baseline forest type, established-maple status, or
  predictor values. Interval length is an exposure-time design covariate known
  only after the follow-up measurement.
- **Condition linkage.** `SUBP_COND_CHNG_MTRX` is the authoritative linkage.
  `SUBPTYP = 2` is used because the response is measured on microplots. Matrix
  rows are aggregated to one baseline–follow-up condition pair before any tree
  or seedling records are joined.
- **Pair quality.** Baseline-side and follow-up-side pair degrees are calculated
  on the full microplot matrix before ecological filtering. The primary cohort
  requires degree one on both sides. This prevents a split or merge from being
  disguised as a one-to-one pair after filtering.
- **Footprint continuity.** Pair overlap is the sum of
  `SUBPTYP_PROP_CHNG` across the four microplots divided by four. Eligibility
  requires overlap divided by both visits' `MICRPROP_UNADJ` to be at least
  0.90. This relative rule retains small but spatially stable conditions. The
  932 primary pairs all exceed 0.991 on both ratios.
- **Baseline cohort.** The baseline plot must be sampled; the condition must be
  accessible forest in active forest-type group 800 with positive microplot
  coverage and at least one live sugar-maple TREE record at DBH ≥5 inches.
- **Follow-up observation.** The mapped follow-up plot must be sampled and the
  condition must be accessible forest with positive microplot coverage. It is
  not required to remain in group 800 because that classification is
  post-baseline; 915 of 932 pairs nevertheless do so.
- **Transition states.** Detection is derived independently at each visit.
  The four states are persistent non-detection (196), appearance (59), loss
  (75), and persistence (602). The primary loss model uses the 677 conditions
  detected at baseline.
- **Pilot predictors.** The seven v2 slopes are
  standardized `log1p` baseline seedling density, baseline sugar-maple sapling presence,
  standardized `log1p` established-maple basal area, standardized `log1p`
  American beech sapling basal area, standardized `log1p` non-maple basal area
  excluding beech saplings, standardized baseline microplot coverage, and
  standardized interval length. Retaining established beech in the residual
  stand-structure term makes the sapling hypothesis a size-class-specific
  contrast. All tree and stand predictors are baseline-only.
- **Event support.** Seventy-five loss events provide 10.7 events per slope.
  Splines, treatment, climate, forest-type indicators, disturbance, and stand
  age are excluded from the primary loss model to protect that event budget.
  This ratio is descriptive, not an adequacy guarantee. Future model planning
  must account for clustering, outcome frequency, expected performance, and
  shrinkage; tests verify arithmetic rather than certify a ten-event threshold.
- **Inference.** The primary binomial GLM reports county-cluster CR1 confidence
  intervals. A county random-intercept fit is a non-singular sensitivity model,
  not a required gate for the forecasting specification.
- **Validation.** Five deterministic folds withhold whole counties. Every fold
  relearns continuous transformations using training counties only, and every
  held-out fold contains both loss and persistence events.
- **Causal boundary.** Coefficients are prognostic associations. American beech
  is a mechanism hypothesis for targeted follow-up, not evidence that beech
  removal would prevent loss. Inter-visit treatment is excluded because timing
  and confounding by indication do not support a causal contrast.
- **Repeated-count boundary.** The loss model is conditioned on a positive
  baseline tally and then uses that tally's density as a predictor. Low positive
  counts are mechanically more likely to become zero under repeated sampling,
  so the density association can reflect regression to the mean or count
  variability as well as biological change.

## Secondary appearance design

- **Conditional question.** The appearance cohort contains the 255 primary
  condition pairs without a baseline sugar-maple seedling detection. The
  outcome is one for a positive follow-up tally and zero for persistent
  non-detection; 59 appearances are observed.
- **Lean specification.** The four pilot slopes are:
  baseline sugar-maple sapling presence, standardized `log1p` established-maple
  basal area, standardized baseline microplot coverage, and standardized
  interval length. Beech and general competitor terms are excluded because the
  beech hypothesis concerns loss and the smaller appearance cohort cannot
  support a broad model.
- **Event support.** The full cohort provides 14.75 appearances per slope. The
  leanest county-held-out training set retains 42 appearances, or 10.5 per
  slope.
- **Inference and validation.** County-cluster CR1 intervals and the same
  five-fold county-held-out procedure are used. Transformations are relearned
  within each training fold.
- **Result boundary.** The model barely improves Brier score over fold-specific
  prevalence and has held-out AUC 0.566 with calibration slope 0.460. It is
  a weak result for this tested specification, cohort, and partition—not a
  predictive limit of the database or a usable site-ranking tool.

## Cross-sectional size-class foundation

The retained v1.3.0 model separates FIA TREE size classes instead of treating
all live sugar-maple basal area as established canopy structure.

- **Established-tree cohort.** The primary cohort requires at least one live
  sugar-maple TREE record with DBH ≥ 5 inches, FIA's subplot-tree threshold.
  This rule is inventory-defined, independent of the seedling outcome, and
  retains 1,072 sampled conditions in 66 counties.
- **Sapling stage.** Sugar-maple sapling presence means at least one live TREE
  record with DBH 1–4.9 inches. Presence is kept separate from established-tree
  basal area.
- **Competitor basal area.** The model uses live non-maple basal area. It does
  not subtract established sugar maple from total basal area because that would
  misclassify sugar-maple saplings as competitors.
- **Basal-area frames.** Each live-tree plot-basis contribution is
  `0.005454 * DIA^2 * TPA_UNADJ`. Condition density uses `MICRPROP_UNADJ` for
  microplot trees, `SUBPPROP_UNADJ` for subplot trees, and `MACRPROP_UNADJ` only
  above an applicable populated macroplot breakpoint. Derived total live basal
  area must pass strict agreement gates against `COND.BALIVE`.

The previous full-cohort model is retained as an explicitly labeled baseline.
Its nonlinear curve mixes 1–4.9-inch sugar-maple saplings into its basal-area
predictor and includes conditions without established sugar maple. It therefore
mixes species absence with regeneration continuity and is not the primary model.

## Retained cross-sectional model

- **Response.** `outcome_no_seedlings = 1 - maple_seedling_detected`.
- **Fixed effects.** Standardized `log1p` established sugar-maple basal area,
  sugar-maple sapling presence, standardized `log1p` non-maple basal area,
  microplot condition coverage, recorded treatment, stand age, disturbance,
  county temperature and precipitation proxies, and measurement year.
- **Functional form.** A linear standardized `log1p` established-tree term is
  selected. A two-degree-of-freedom spline did not improve fit. Binary sapling
  presence had lower AIC than no sapling term, continuous sapling basal area,
  or presence plus positive sapling amount.
- **Treatment.** The FIA treatment indicator is included because it is complete,
  scientifically relevant, and supported by 151 primary-cohort observations.
  It remains observational and is never described as a management effect.
- **Grouping.** County GEOID is the retained random intercept. Adding a plot
  visit intercept produced zero estimated variance, a singular fit, and no AIC
  improvement.
- **Inference.** Conventional fixed-effect summaries use model-based Wald 95%
  intervals. A fixed-effect logistic model with county-cluster CR1 covariance
  is reported as sensitivity evidence.
- **Validation.** Ten deterministic folds hold out whole counties. Every fold
  relearns transformations from training data and predicts held-out counties
  with fixed effects only. This is internal geographic validation, not external
  validation.
- **Forest type.** Indicators are evaluated through an omnibus sensitivity;
  the dominant type 801 is also refit alone. Sparse type cells are not
  interpreted individually.
- **Diagnostics.** DHARMa checks cover uniformity, dispersion, outliers, and
  residual quantiles. A county-plus-plot random-structure comparison and
  collinearity audit are published.

## Descriptive gap screen

The high-established threshold is the upper third of frame-corrected
established sugar-maple basal-area share among seedling-sampled conditions. The
share denominator includes only live trees with DBH ≥ 5 inches. An upper-quartile
alternative is reported. The sample-relative threshold is never reused to
construct the inferential cohort.

## Spatial decision

The Daymet normal uses the cell at each Census Gazetteer county internal point.
It is a county proxy, not a county-wide areal mean. Plot-level residual spatial
autocorrelation cannot be tested without plot coordinates. A naïve test on
county-aggregated residuals was rejected because it is unstable and does not
represent plot-scale dependence.
