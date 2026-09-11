---
title: "Analysis decisions"
description: "Cohort selection, recruitment definitions, model comparisons, and validation for the Michigan sugar-maple study."
aliases:
  - /docs/research-direction.html
toc: true
---

I used repeated public FIA observations to evaluate three questions: how much
ordinary seedling counts tell us about recorded sapling entry, whether maple
size structure adds predictive information, and what happens to tagged
baseline saplings. This page documents the decisions behind the
[research paper](../report/recruitment.qmd).

## Source and cohort

I used the Michigan FIADB SQLite snapshot identified in
[configuration](https://github.com/dineshpotla/canopy-to-cohort/blob/main/config/config.yml)
and the [provenance audit](../outputs/audits/data-provenance.csv). The source
archive has SHA-256
`2c1eb908a47436d4edd0f3ba9e3d647b79a4f36cef972c5ba83277300817aee1`.

Evaluation 262501 supplies the current-evaluation cohort. I selected baseline
accessible forests in maple/beech/birch group 800 with live sugar maple at
least five inches in diameter. The selected forest-type codes are 801, 802,
805, and 809; sugar maple is `SPCD=318`. Follow-up forest type may change.

I required an intended plot predecessor, one-to-one condition mapping, at
least 90% mapped microplot-area overlap relative to each visit, and an interval
of 4.5–8.5 years. A forest condition is a mapped part of a plot with similar
forest characteristics. One plot can contribute more than one condition.

The source contains 932 condition pairs. Nine fail the conservative shared-area
check and one contains ambiguous new saplings. Excluding these leaves
**922 intervals on 903 physical plots in 66 counties**. The
[cohort flow](../outputs/tables/recruitment-cohort-flow.csv) records these
counts and the alternative restrictions. Baseline measurements span
2011–2018 and follow-ups span 2018–2025.

## Sampling and linkage checks

Both visits must use the national design, an unchanged microplot arrangement,
manual version at least 5.1, and demonstrated sampled forest. Follow-ups must
be remeasurements. I retained production QA codes 1 and 7; code 7 identifies
a supervised production check.

The direct subplot predecessor field, `PREV_SBP_CN`, is empty in this
snapshot. I reconstructed continuity from the verified plot predecessor,
subplot number, and `SUBP_COND_CHNG_MTRX` microplot links. The mapped shared
proportion cannot exceed the corresponding condition proportion at either
visit. Any populated predecessor identifier must agree with its expected link.

The [frame audit](../outputs/audits/recruitment-frame.csv) and
[protocol audit](../outputs/audits/recruitment-protocol.csv) record these
checks. The 914 exact-overlap intervals form a sensitivity subset.

I assigned zero only after establishing sampling opportunity and verifying
the relevant records. One fully checked follow-up with no live TREE records
and `BALIVE=0` has an explicit zero correction. The model code stops on
missing required predictors; it does not impute them or silently change
the observations across models.

## Recorded recruitment endpoint

I defined the binary outcome as at least one qualifying new live maple
sapling at follow-up. Each qualifying TREE record must have:

- `SPCD=318` and `STATUSCD=1`;
- diameter at least 1 inch and less than 5 inches;
- `RECONCILECD=1` and no predecessor TREE record;
- a comparable shared sampled microplot.

The cohort contains **169 qualifying saplings in 100 conditions**. This
endpoint records surviving entrants present at remeasurement. It cannot
identify which individual baseline seedlings became saplings or count
entrants that died or exceeded the size class between visits. Reconcile
code 1 alone does not establish recruitment on comparable forested area.

The [endpoint definitions](../outputs/audits/recruitment-definitions.csv)
document the rules and their interpretation.

## Predictors and model comparisons

I fit the same four logistic benchmarks separately to all 922 eligible
intervals and the 672 intervals with baseline seedlings. The second population
tests whether measurements distinguish entry among conditions that already
contained seedlings. Both populations contain the same 100 conditions with
recorded entry and overlap rather than providing independent replications.

| Model | Predictors |
|---|---|
| Prevalence | Training-sample event fraction |
| Observation design | Baseline microplot coverage and elapsed interval |
| Count and design | Observation design plus ordinary maple seedling count |
| Maple stages and design | Count and design plus maple sapling density and established-maple basal area |

The ordinary count sums `SEEDLING.TREECOUNT`; the audit checks agreement
with `TREECOUNT_CALC`. Sapling density accounts for microplot condition
coverage. Established-maple basal area uses live stems at least five inches
in diameter and the appropriate sampled area.

I apply `log(1 + x)` to count, sapling density, and basal area. Centering and
scaling use training data only and repeat within each bootstrap fit. The
ridge objective is summed binomial negative log likelihood plus one-half
the sum of squared slopes. The intercept is unpenalized and the primary
penalty is fixed at one. I did not tune it to improve these findings.

The [data dictionary](data-dictionary.md) lists the source fields and units.
The [model module](https://github.com/dineshpotla/canopy-to-cohort/blob/main/R/recruitment_models.R)
implements these comparisons.

## Validation and uncertainty

I held out whole counties in five folds. Assignment balances condition counts
without using outcomes, and every physical plot stays in one fold. Each
population has its own deterministic partition. All models within a population
use identical observations and folds.

Brier score and log loss evaluate probability error; AUC and average precision
evaluate ranking. The scores give equal weight to condition intervals.
They are unweighted sample summaries. Joint calibration intercept and slope,
mean predicted probability, and observed-to-expected ratios describe calibration.

Paired uncertainty uses 300 resamples of whole counties per population.
Each draw repeats training scaling and model fitting while preserving the
county folds, model set, and penalty. All 600 draws succeeded. Negative
model-minus-reference Brier differences favor the added information.
Separate descriptive count-bin intervals use 2,000 county resamples.

I had explored this source snapshot before fixing the recruitment comparisons.
The analysis is retrospective, and its bootstrap does not include uncertainty
from choosing the question, cohort, or model set. It does not provide external
validation. I specified no equivalence margin or minimum useful improvement
and applied no multiple-comparison correction.

See the [validation results](../outputs/tables/recruitment-model-validation.csv)
and [paired differences](../outputs/tables/recruitment-model-paired-differences.csv).

## Sensitivity and temporal comparisons

The fixed checks restrict observations to exact overlap or follow-up manual
version at least 9, or change the penalty to 0 or 4. Each comparison uses
matched observations. The [sensitivity table](../outputs/tables/recruitment-model-sensitivities.csv)
reports the resulting denominators and scores.

The retrospective temporal comparison trains on follow-ups before 2023 and
tests follow-ups from 2023 onward. No physical plot crosses that split, although
counties can recur. Protocol and sample composition also change across years.

Elapsed interval is known at follow-up. These comparisons assess conditional
next-visit outcomes over variable durations; they do not validate a fixed
forecast horizon available at baseline.

## Linked sapling fates

I linked tagged baseline maple saplings to TREE records on their expected
successor plot before screening follow-up species, status, or diameter.
Fate eligibility has its own checks: an ambiguous new entrant does not alone
invalidate an existing stem's link.

Of 1,593 baseline saplings, 1,580 have comparable biological fates:
334 recorded dead, 1,188 alive within the sapling class, and 58 alive at or
above five inches. Nine stems fail frame consistency, three have a species
reidentification, and one has a no-longer-sampled reconciliation. These
13 remain in the accounting without biological outcome assignments.

Annual diameter difference divides follow-up minus baseline diameter by
elapsed years for comparable surviving maples. Recorded death and size-class
advancement describe distinct outcomes. The study does not estimate a mortality
mechanism or infer canopy replacement from growth beyond five inches.

## Supporting analyses

The [survey comparison](../report/recruitment.qmd#survey-priority-comparison)
evaluates fixed selection rules on the same observations. Its primary
comparison integrates ties at 25% condition capacity; 10% and 50% are fixed
alternatives. The target of no recorded entry does not independently establish
survey need, field cost, or treatment benefit.

The [RI measurement audit](../report/ri-audit.qmd) checks sampling coverage,
dates, record codes, and seedling lengths in a subset of 90 intervals with
14 recorded-entry conditions. Ordinary counts match the RI counts at least
one foot long on all 311 comparable microplot-condition intervals. The audit
retains length classes and source categories. It does not fit a length model.

## Geography and interpretation

The [study map](../report/spatial-context.qmd) joins FIA county identifiers
to county polygons and displays counts of eligible condition intervals.
Exact FIA plot coordinates are neither used nor inferred. Map colors show
sample support and cannot establish county regeneration rates or rankings.

The results apply to the selected Michigan sample. They do not provide
FIA survey-weighted statewide estimates, identify causes of absent entry,
or validate a forest treatment. Adding maple size measurements did not clearly
improve prediction under the specified comparisons; uncertainty spanning zero
does not establish equivalence.

The [reproducibility guide](recruitment-reproducibility.md) describes the
pinned inputs, computation, and verification commands.
