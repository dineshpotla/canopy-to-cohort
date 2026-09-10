---
title: "Survey validation plan"
toc: true
---

## Objective

This is an optional follow-on plan. The Michigan core research and revised
paper are complete; operational validation is not a prerequisite for reporting
their bounded findings. Regional acquisition is deferred under the user's
core-paper priority.

Determine whether additional regeneration measurements improve a specified
survey decision enough to justify their collection cost, compared with a simple
seedling-count rule. The existing recruitment models do not yet demonstrate
such an advantage. This plan defines a possible subsequent study; no new survey, external
validation, or operational deployment has occurred.

The current [survey-priority comparison](../report/recruitment.qmd#survey-priority-comparison)
uses no new sapling recorded at follow-up as a diagnostic target. It is not
independently assessed survey need. At 25% capacity among 672 baseline-detected
conditions, low counts identify an expected 162 no-entry conditions, the count
model 160, and the stage model 163. The one-condition stage gain is uncertain
and is not reproduced in the later-year test using realized intervals.

## Local data feasibility

The Michigan snapshot contains `PLOT_REGEN`, `SUBPLOT_REGEN`, and
`SEEDLING_REGEN`, including recorded length classes and seedling-source codes.
Presence of a row is not the same as a verified sampled opportunity. Within
the 922 recruitment-eligible intervals, the initial record-presence screen gives:

| Record-presence screen | Conditions | Physical plots | Recruit-bearing conditions |
|---|---:|---:|---:|
| Baseline RI plot record | 90 | 87 | 14 |
| RI plot records at both visits | 90 | 87 | 14 |
| Baseline condition has any-species RI seedling record | 89 | 86 | 14 |
| Baseline condition has a maple RI seedling record | 81 | 79 | 14 |

Only 71 of the 90 intervals also have standard baseline seedling detections.
Standard and RI definitions cannot be substituted for one another, and an
absent maple RI row must not become a zero without a valid frame. These counts
come from the [availability audit](../outputs/tables/recruitment-survey-ri-coverage.csv),
not from a completed height-class cohort or independent test sample.

The subsequent [measurement audit](../report/ri-audit.qmd) goes beyond that
record screen: all 90 baseline intervals pass the implemented RI frame,
record, and May-September date checks. They cover 311 microplot-condition
intervals; all ordinary counts match the RI counts at least one foot long.
Nine verified RI maple tally zeros remain zeros; ten additional ordinary-zero
conditions contain RI seedlings only below one foot. Four follow-up RI
frame/date flags leave 86 both-visit intervals without changing the baseline
predictor cohort. Individual 2012-2015 annual supplements remain an access gap.

The 14-event overlap does not establish adequate support for a multi-height
prediction model. Selecting only this subset changes the population, and all
of its outcomes were already part of the explored Michigan cohort. It is not
external validation simply because the extra predictors were unused earlier.

## Completed measurement milestone and remaining limits

The local audit has produced an eligibility flow, code/measurement reconciliation,
and descriptive support tables. The checklist below records its required
components; historical annual-guide coverage remains qualified, and it does
not authorize a new model:

1. Resolve historical RI length-class and source-code definitions from the
   applicable guides. Standard hardwood minimum length and FIA sapling DBH
   boundaries are not interchangeable with RI height classes.
2. Verify `REGEN_MICR_STATUS_CD`, older subplot-status fields, condition coverage,
   dates, and sampled microplots at the baseline used for recruitment prediction.
   Missing status and absent species records require explicit rules.
3. Reconcile total RI counts, length classes, vegetative-origin categories,
   and ordinary seedling tallies without forcing agreement across different
   minimum-size definitions. Do not include the browse-impact score as an
   independent cause without checking whether regeneration scarcity enters it.
4. Publish an eligibility flow and event/plot support. Use the same conditions
   for simple-count and height-information comparisons; do not compare metrics
   from different populations as if only the predictor changed.
5. Assess precision and model complexity before fitting. If the audited subset
   remains too weak for the proposed comparison, report the descriptive
   measurement audit and stop. Do not fill the gap with an optimistic model.

The descriptive result is 13 recruit-bearing conditions among 44 with baseline
maple at least five feet long, versus one among 46 without. A later-year split
would have ten development events and four assessment events. That does not
support a strong claim about incremental forecasting value. The next study
must evaluate length information against ordinary counts on a better-supported,
separate sample, with a meaningful target and gain specified before evaluation.

Height information is a grounded candidate: the regional FIA study by
[Harris, Woodall, and D'Amato (2022)](https://research.fs.usda.gov/treesearch/67377)
found better recruitment models with height classes than with ordinary combined
counts. That precedent motivates the measurement comparison; it does not prove
the Michigan subset is adequate or that a field survey would be cost-effective.

## Requirements for an operational study

The [count-versus-length design](../report/length-study.qmd) now specifies the
research comparison and executable precision scenarios. Its historical Michigan
metadata census finds 88 positive-seedling opportunities on 79 plots before full
eligibility checks, only six plots outside the current recruitment cohort.
These are not new event counts or an independent evaluation set. The user has
authorized a Wisconsin/Minnesota feasibility screen, not fitting on those rows.
Archive access currently blocks that screen; see the
[access review](../research/runs/recruitment-2026-09-08/regional-access-review.md).
The conditional next-visit research target remains distinct from the operational
requirements below.

Before describing a ranking as a survey tool, the following must be specified
with the intended decision owner. These choices are not supplied by the
current database analysis.

| Requirement | Why it matters |
|---|---|
| Management or research question | Locating low advancement, locating successful recruits, estimating prevalence, and learning mechanisms require different sampling strategies. |
| Independently assessed target | No recorded entry is not automatically a stocking deficit, survey need, or treatable problem. Specify the field criterion and horizon without using the prediction to define the answer. |
| Unit of action | A management stand or physical visit is not a FIA condition interval. Define eligibility and cost at the actual sampling unit. |
| Measurements and timing | Specify repeatable size/height, vigor, stocking, and damage observations and the forecasting date. Use a planned horizon rather than a realized future interval. |
| Cost and error consequences | Travel, access, measurement time, missed problem sites, and unnecessary visits determine whether an incremental gain matters. There is no universal 25% budget. |
| Separate evaluation sample | Reserve locations, inventory periods, or a prospective sample before choosing models and cutoffs. Shared plots must not cross development and evaluation. |

Accuracy metrics alone do not establish value. Decision-analytic methods relate
predictions to meaningful error consequences; a threshold chosen solely to make
a model look good is not such a preference.
[Vickers and Elkin (2006)](https://doi.org/10.1177/0272989X06295361) provide the
general methodological rationale, not forestry utilities or a recommended
decision threshold for this project.

## Evaluation design

Keep low raw count and count per sampled coverage as fixed comparators. Declare
which direction is useful for the independent target. If height data are
evaluated, add only the scientifically motivated, supportable representation
selected before observing evaluation outcomes; tune within development data.

Measure the target on a probability-based evaluation sample or a design with
known selection probabilities. Assessing only model-selected sites cannot
reveal missed sites or provide an unbiased model-versus-simple-rule comparison.
Retain a random or stratified component across score levels, and document
nonresponse and inaccessible sites. Exact FIA locations are not inferred.

Compare selected-target yield, missed-target fraction, calibration where
probabilities are relevant, and actual cost per useful finding at matched
plot/stand-level capacity. Use clustered uncertainty appropriate to the new
sample and analyze predefined target subgroups. Report ties and protocol
changes. A held-out later inventory on a known plot is a different assessment
from transfer to a new location.

Choose sample size through a precision/power assessment for the paired gain
that would change the decision, using realistic target frequency and within-site
dependence. Do not claim adequacy from a fixed events-per-variable rule. The
current 14 RI-overlap events are a feasibility warning, not a sample-size plan.

## Decision gates

Proceed to a field-facing tool only if the measurement audit passes, a real
decision is specified, and the separate evaluation shows a useful improvement
over the simple benchmark after accounting for collection cost and uncertainty.
Failure to demonstrate an improvement is an informative result; retain the
simple strategy or conclude that the target needs better measurement.

The separate scope decision now authorizes Wisconsin/Minnesota inventory
acquisition and feasibility screening. It does not authorize field coordination,
fieldwork, or further geography changes. The baseline measurement audit is complete
with the stated historical-access qualification. The 14-event subset should
not be promoted into a larger fitted model or a management claim.

## Reproducibility

Run `make survey-audit` after the recruitment model bundle exists. Script 16
reproduces the capacity comparison and full-refit uncertainty; script 17
reproduces the RI availability screen. The separate `make ri-audit` target
reproduces the measurement and support audit. The
[survey contract](../research/runs/recruitment-2026-09-08/survey-contract.md)
and [source note](../research/notes/survey-priority-evidence.md) separate the
declared choices, local results, and external evidence.
