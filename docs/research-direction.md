---
title: "Research direction and goals"
date: "2026-09-09"
---

## Decision

The bounded Michigan core research is complete as of September 9, 2026. The
[revised paper](../report/recruitment.qmd) answers the count-information,
incremental-stage, and linked-fate questions. Regional data acquisition and
length-model validation are deferred optional extensions, not prerequisites
for completing this paper. The results do not justify another pivot merely
because added-model improvements are small or uncertain.

Change the primary question to **whether observed sugar-maple regeneration leads
to recorded recruitment into the sapling size class**. Retain the existing
seedling-detection analysis as an exploratory measurement study. Its numerical
results remain useful, but the earlier claim that it establishes a field-triage
tool is withdrawn.

The project's goal is:

> Determine how well ordinary FIA seedling and sapling observations anticipate
> new sugar-maple sapling recruitment in Michigan northern hardwoods, measure
> what additional stand information contributes, and distinguish recruitment,
> survival, growth, and observation changes.

The intended contribution is a transparent Michigan evaluation of regeneration
indicators. Its novelty must come from a useful comparison and credible
validation. Linking repeated FIA visits or fitting a prediction model is already
established in the literature.

The direction decision was made on September 7. The first recruitment analysis
was implemented on September 8; its results are summarized below and in the
[recruitment report](../report/recruitment.qmd). The existing data have been
explored; this is not a preregistration or external validation.

## Results after implementing the pivot

The final audited recruitment cohort has 922 condition intervals on 903 physical
plots across 66 counties. It contains 169 qualifying new live maple saplings in
100 conditions. Nine source pairs fail the conservative shared-frame proportion
check and one contains ambiguous new sapling records. The preliminary feasibility
counts later in this document are preserved as the earlier screen, not final results.

Seedling count plus coverage and interval has county-held-out AUC 0.796 overall
and 0.699 among 672 baseline-detected conditions. Adding existing maple sapling
density and established-maple basal area yields AUC 0.806 and 0.711, respectively.
The paired Brier improvements are about 0.0016 in both populations, with full-refit
county-bootstrap intervals spanning zero. At equal top-quarter capacity the
stage model captures fewer recruit-bearing conditions than the count benchmark.
These findings do not support organizing the project around added model complexity.

Counts nevertheless contain information. Of 280 conditions with more than twenty
recorded baseline seedlings, 72 have a qualifying new sapling at follow-up.
Abundant seedlings therefore do not guarantee recorded entry, but the remaining
208 conditions cannot be labeled biological failures from these observations.
The companion fate audit separates 334 recorded deaths, 1,188 surviving saplings,
and 58 live stems advancing beyond the sapling class among 1,580 comparable stems.

The central contribution is now an implemented measurement-and-prediction study:
**what standard regeneration counts tell us, what maple stage variables add,
and what neither observation establishes about successful cohort replacement.**
Continue with a defined decision and external assessment if operational use is
the goal. Do not pivot again merely because incremental effects are modest.

## Secondary survey comparison and optional next goal

An explicit, retrospective priority comparison is now implemented. Its main
target is no recorded entry among the 672 baseline-detected conditions, at a
fixed 25% capacity. Expected target capture is 143 for random selection,
162 for low raw counts, 160 for the count model, and 163 for the stage model.
Stage minus raw-count yield is +0.60 percentage points (95% full-refit county
interval −3.66 to +2.28). This is not a demonstrated practical improvement.
The later-year test gives 65.18 expected targets for raw counts versus 65 for
either model, among 68 selected conditions.

The extension also tests the opposite objective, fixed 10%/50% capacities,
cutoff-tie uncertainty, and a common seven-year scoring horizon. No-entry
remains a record-based proxy, not an independent finding that a site needs
surveying. Actual field costs and useful survey outcomes remain unmeasured.

The measurement audit has sharpened an optional follow-on hypothesis:

> Determine whether baseline seedling length structure adds useful recruitment
> information beyond ordinary counts on the same sampled area, evaluated on a
> separate and adequately supported sample.

The [RI audit](../report/ri-audit.qmd) retains 90 baseline condition intervals,
14 events, and 311 sampled microplot-condition intervals. Ordinary maple counts
exactly equal the sum of RI classes at least one foot long on every matched
unit; length distribution, not the collapsed total, is the candidate extra
information. Thirteen of the fourteen events occur in the 44 conditions with
baseline maple seedlings at least five feet long, versus one event in 46
conditions without them. This is not an adjusted or held-out count-versus-length
comparison.

No height-class model is fitted. The later-year split would leave ten development
events and four assessment events. Historical annual supplements were inspected
for 2016-2018 (37 intervals, four events), including an archived 2016 draft,
but not individually recovered for 2012-2015. The baseline measurement audit
is complete with those qualifications;
independent forecasting usefulness is not established.

The [survey validation plan](survey-validation-plan.md) records this milestone,
the next matched comparison, and the independent decision evidence required before
an operational claim. Earlier Wisconsin/Minnesota acquisition was authorized,
but that extension is now deferred to prioritize the core paper. Broader
extensions and fieldwork remain separate scope decisions.

## Count-versus-length design

The optional comparison is specified in the [study design](../report/length-study.qmd):
ordinary count, sampling coverage, and elapsed interval versus the same model
plus the fraction of standard-size seedlings at least five feet long. The
primary population has ordinary seedlings detected, and the primary metric is
plot-balanced paired Brier gain. This is a conditional next-visit comparison,
not a validated baseline forecast at an exact seven-year horizon.

The metadata-only historical screen finds 88 positive-seedling opportunities
on 79 physical plots, before full RI/condition/endpoint checks. Only seven visits
on six plots are outside the current 903-plot recruitment cohort. No new
recruitment outcomes were extracted. That small extension does not supply an
independent Michigan evaluation set.

The protocol includes hypothetical precision scenarios and a gate requiring
a minimum meaningful gain before evaluation; it does not invent field costs
or claim that one sample-size rule suffices. The user has authorized the
Wisconsin/Minnesota feasibility screen under the same definitions. Such an
extension would assess regional transport, not validate Michigan-specific
performance. Both archive downloads currently fail with empty responses, so no
new state inventory was acquired and regional sample support remains unknown.
The [access review](../research/runs/recruitment-2026-09-08/regional-access-review.md)
records the blocker and reproducible retry step.

## Why the previous direction needs revision

1. **The outcome was too far from the ecological problem.** A positive seedling
   tally becoming zero measures a change in a sampled size class. It can reflect
   mortality, sampling variation, or growth out of that class. Continued seedling
   presence can coexist with little recruitment into larger trees. The pilot
   therefore does not directly establish regeneration failure or recovery.
2. **Most prediction gain was already available from a simple benchmark.** In
   the existing county-held-out results, density + coverage + interval achieved
   AUC 0.8447 and Brier 0.08253. The full seven-slope model achieved 0.8557 and
   0.08151. The simpler benchmark accounts for 94.2% of the full model's Brier
   improvement over prevalence. Added stand variables reduced benchmark Brier
   by only 1.24%. Whether that difference is useful requires uncertainty and a
   defined decision, not just the headline AUC. A paired county bootstrap of
   existing held-out predictions gives a Brier difference of −0.00102 with a
   95% interval of −0.00585 to +0.00475 (negative favors the full model). This
   conditional interval includes zero; it does not prove equivalence. At equal
   capacity of 169 conditions, the full model captures 55 losses versus 53 for
   the strong benchmark. Sixty of 75 losses began with five or fewer tallied
   seedlings, directly reconciled against `SEEDLING.TREECOUNT`.
3. **The beech story was promoted too early.** A conditional association is worth
   investigating, but its modest incremental prediction does not establish an
   actionable mechanism. The old stage comparator excludes beech sapling basal
   area from its competitor total. A fair species-specific check also needs a
   model with total non-maple basal area, then asks what beech adds. That audit
   leaves full-model performance almost unchanged: it does not erase the beech
   association, but incremental uncertainty remains substantial.
4. **A weak small model does not establish a limit of the whole database.** The
   four-term appearance model performed poorly. That result concerns the tested
   model, cohort, and validation partition; it does not show that no FIA-based
   method can predict new detections.
5. **Passing software checks did not settle the research question.** Ten events
   per slope is a rough accounting statistic, not a guarantee of reliable
   prediction. Sample-size planning also depends on outcome frequency, candidate
   complexity, clustering, and expected model performance. See
   [Riley et al. (2020)](https://doi.org/10.1136/bmj.m441). Tests should reproduce
   calculations; they should not require the appearance model to remain weak.

## What the relevant research actually supports

| Primary source | Consequence for this project |
|---|---|
| [Henry et al. (2021), Michigan regeneration](https://doi.org/10.1016/j.foreco.2020.118541) | Small seedlings can be plentiful while larger regeneration is scarce. Study advancement and the conditions associated with it. |
| [Henry and Walters (2023), Michigan age structure](https://doi.org/10.1016/j.foreco.2023.121356) | Small-diameter maples can be old, suppressed stems. Sapling presence alone is not evidence of recent establishment; the paper's size classes differ from FIA's. |
| [Harris et al. (2022), seedling inventories and sapling recruitment](https://research.fs.usda.gov/treesearch/67377) | This directly relevant prior study already predicts FIA recruitment and compares ordinary tallies with six height classes. Taller seedlings were more informative. A Michigan analysis must acknowledge that precedent. |
| [Harris et al. (2025), browsing by size class](https://research.fs.usda.gov/treesearch/69473) | Browse relationships vary with regeneration size. A single coarse seedling tally loses information. Mechanism claims require independent browse measurements. |
| [Gauthier (2025), Canadian maple and beech saplings](https://doi.org/10.1002/ece3.71386) | Beech is a candidate explanation. Different geography, diameter definitions, and the use of relative abundance limit direct transfer to Michigan seedling loss. |
| [Harris et al. (2026), regional regeneration trends](https://research.fs.usda.gov/treesearch/81033) | Small seedlings and sapling abundance can imply different future forest composition. The mismatch is a useful research problem. |
| [Harris et al. (2026), regeneration after disturbance](https://research.fs.usda.gov/treesearch/81034) | Advance-regeneration forecasting after disturbance is also established work. A generic harvest or longitudinal model is not an unoccupied research niche. |

The FIA Regeneration Indicator is a possible companion dataset. Before using its
browse-impact score, check its construction: scarcity of regeneration can enter
the assessment, creating circularity if the same scarcity is modeled as the
response. Height, diameter, and age thresholds are not interchangeable.

## Initial feasibility screen, before the endpoint audit

The following are exploratory record counts, not survey-weighted estimates or
final recruitment-cohort results. Reproduce them with
[`scripts/12_audit_recruitment_feasibility.R`](../scripts/12_audit_recruitment_feasibility.R).

| Candidate analysis in the existing 932 pairs | Initial support | Decision |
|---|---|---|
| Newly recorded live maple saplings, 1 to <5 inches DBH, with `RECONCILECD=1` and no predecessor TREE record | 171 stems in 101 conditions, across 23 counties | Candidate screen; subsequent protocol and frame checks retain 169 stems in 100 conditions. |
| Follow tagged baseline maple saplings | 1,593 stems in 573 conditions; 1,255 followed as alive, 337 dead, one cruiser-error record | Useful companion for survival and growth; audit species reidentification and sampling-frame exit. |
| Sapling detection newly appearing where no saplings were detected at baseline | 14 of 359 conditions | Too sparse to organize a broad predictor model around this restriction. |
| Existing seedling-detection loss | 75 of 677 baseline detections | Retain as an observation-process comparison. |

All 101 recruit-bearing conditions in the current-pair screen had seedlings at
baseline. The 255 baseline non-detections had no qualifying recruits in this
screen; this does not establish zero underlying probability. A conditional
analysis among the 677 baseline detections is feasible, while an all-condition
model needs an explicit approach to separation and uncertainty.

Fifty-nine linked live baseline saplings crossed 5 inches DBH. Of 76 conditions
with a corrected later absence of maple saplings, 15 contained such larger
survivors. Sapling disappearance therefore cannot be assigned wholesale to
mortality. Three living stems were reidentified as red maple, and one fully
sampled, zero-live-tree follow-up had missing derived sapling metrics; its zero
must be reconciled from the source records before a new endpoint is built.

Historical screening identifies 2,308 candidate condition intervals on 1,102
physical plots. There are 345 new live sapling tallies in 230 intervals across
180 plots and 32 counties. Follow-ups span 2009–2025. These intervals reuse
physical plots and are not independent observations. The final cohort must
check protocols, actual measurement dates, shared area, predecessors, old
forest-type codes, and repeated conditions before its size is fixed. In
particular, 110 intervals fall outside the pilot's 4.5–8.5-year bounds.

## Questions and completion criteria

| Priority | Question | What counts as completion |
|---|---|---|
| 1. Define the outcome | Which new TREE tallies represent recruitment into the sapling class on comparable sampled area? | An audited recruitment table, exclusion flow, protocol definitions, and source checks for ingrowth, missed trees, changed area, and species corrections. |
| 2. Test information value | How much do seedling abundance and sapling structure improve recruitment prediction beyond observation opportunity and existing stocking? | Identical held-out records for a small declared sequence of models; paired Brier differences, calibration, AUC, and uncertainty reported for every comparison. |
| 3. Explain size-class change | How much sapling disappearance represents death, surviving growth into a larger class, or record changes? | A linked-stem fate table with denominators and ambiguous records retained separately; growth summaries limited to valid comparable measurements. |
| 4. Evaluate usefulness | Are ordinary regeneration indicators adequate for identifying conditions that warrant a more detailed survey? | A declared survey objective and capacity, comparison with a simple abundance rule, and validation that matches the intended use. Until then, no operational triage claim. |

The implemented analysis follows a small benchmark sequence: observation
coverage and interval; then starting seedling abundance; then existing maple
sapling structure and established-maple abundance. Both the full cohort and the
baseline-detected subgroup are principal analyses. Fixed ridge shrinkage, paired
full-refit county resampling, exact-frame and protocol sensitivities, and a
retrospective temporal split are documented in the
[analysis contract](../research/runs/recruitment-2026-09-08/analysis-contract.md).
No competitor or beech term was added after observing the results.

Goals 1–3 are complete for the bounded Michigan study, subject to its stated
measurement and internal-validation limits. The revised paper integrates
their results and uncertainty. Goal 4 has an explicit proxy target and
fixed-capacity comparisons with simple rules. It remains open operationally:
survey need, costs, and external usefulness have not been established. That
separate requirement does not block the core measurement-and-prediction paper.

For historical intervals, declare later measurements for temporal assessment
before comparing models. Separately assess transfer to unseen counties or plots;
a later visit to a known plot answers a different question from a new location.
Keep every physical plot together for geographic validation, account for reused
plots in uncertainty, and report the sample's geographic support. Because the
current outcomes have already been examined, describe a temporal split of this
snapshot as a retrospective robustness check, not untouched external validation.

## Scope and stopping rules

- Start with the existing Michigan database and common FIA measurements.
  Wisconsin/Minnesota feasibility acquisition is now authorized. Additional
  geographies, new environmental joins, and fieldwork remain separate decisions.
- Do not equate the first 1-inch TREE tally with a tagged seedling's survival,
  seed origin, age, or eventual canopy recruitment. New large subplot tallies
  can arise from the change in sampled area at 5 inches.
- Analyze invalid or changed observation opportunities separately from
  biological outcomes. Inspect exact-overlap and comparable-protocol
  sensitivities before interpreting recruitment differences.
- Publish an imprecise or negative result if added variables fail to improve the
  strong benchmark. Do not keep adding covariates until a preferred story wins.
- If recruitment support or linkage quality becomes inadequate, report a
  descriptive recruitment/fate audit and measurement limits. Do not substitute
  an easier endpoint while keeping the same ecological claim.
- Keep mechanism and treatment claims as hypotheses. A causal intervention
  study requires a different design.

## Status and reproducibility

The existing detection models are exploratory pilot results. The direction
review, endpoint rebuild, first recruitment models, and linked-fate accounting
are complete locally. Operational usefulness and external validation remain
unresolved. No new publication or deployment is implied.

The survey-priority extension and RI record-availability screen are also
complete locally. Run `make survey-audit` after the recruitment models exist.
The [capacity results](../outputs/tables/recruitment-survey-summary.csv),
[paired differences](../outputs/tables/recruitment-survey-paired-differences.csv),
and [RI availability](../outputs/tables/recruitment-survey-ri-coverage.csv)
document that extension. The subsequent [RI measurement audit](../report/ri-audit.qmd)
is complete with historical-source qualifications; run `make ri-audit` after
the recruitment dataset exists. Length information's added forecasting value
and its usefulness for an actual survey decision remain untested.

Run `make recruitment`, `make test`, and `make report` after the longitudinal
artifacts exist to regenerate and check the new analysis. The
[research vault](../research/README.md) records the HyperResearch-inspired method,
source access, analysis contract, and review trail. This is a local adaptation,
not execution of HyperResearch's native harness.

Run `make direction-audit` after the longitudinal artifacts exist to regenerate
the comparison and feasibility evidence. The incremental prediction audit
reuses the pilot's county folds. Any bootstrap intervals from its saved
predictions are conditional on those fitted folds and omit model-development
and fold-selection uncertainty.

The aggregate [benchmark comparison](../outputs/audits/research-direction-model-summary.csv),
[conditional uncertainty](../outputs/audits/research-direction-conditional-bootstrap.csv),
[current recruitment feasibility](../outputs/audits/recruitment-feasibility-current-summary.csv),
and [historical feasibility](../outputs/audits/recruitment-feasibility-historical-summary.csv)
provide the numerical evidence behind this decision.

Earlier v2.0 release checks document successful software execution and numerical
reconciliation. They do not establish that the earlier research interpretation
was sufficiently supported. This direction document supersedes that interpretation.
