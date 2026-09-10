# Canopy to Cohort

Do ordinary regeneration observations anticipate new sugar-maple saplings in
Michigan northern hardwoods?

[Live project](https://dineshpotla.github.io/canopy-to-cohort/) ·
[Research report](https://dineshpotla.github.io/canopy-to-cohort/report/recruitment.html) ·
[Research direction and goals](docs/research-direction.md) ·
[Research evidence](research/README.md)

The goal is to determine how well baseline seedling abundance and maple stage
structure anticipate recorded recruitment into the FIA sapling size class, and
to distinguish recruitment from survival, growth, and observation changes.
The original seedling-detection models remain a supporting exploratory pilot.

## Findings in plain language

More seedlings were a useful clue to where new maple saplings would be recorded,
but did not guarantee that transition. Adding the abundance of existing maple
saplings and larger maples did not clearly improve prediction. Following tagged
saplings separately also showed why growth out of the size class must not be
counted as death.

Here, recruitment means a new live sapling recorded at the next visit, not a
baseline seedling individually tracked into a tree. Saplings have trunks at
least 1 inch but less than 5 inches in diameter at breast height. The results
do not diagnose regeneration failure or identify its causes.

## Evidence behind the findings

Status, September 10, 2026: the bounded Michigan core analysis is complete and
the [paper](report/recruitment.qmd) has been revised around three answered
questions: seedling-count information, added maple-stage value, and linked
sapling fates. Code, aggregate evidence, and the research report are publicly
available. This is a research draft, not a peer-reviewed publication or an
externally validated tool. No immutable archive or DOI has been assigned.

- The audited cohort contains **922 condition intervals, 903 physical plots,
  and 66 counties**, with 169 qualifying new live saplings in 100 conditions.
  Ten of the original 932 pairs are excluded for unresolved frame consistency
  or ambiguous newly recorded saplings.
- Seedling count plus sampling coverage and interval achieves county-held-out
  AUC **0.796 overall and 0.699 among baseline seedling detections**. Counts
  contain information; the pooled result partly benefits from distinguishing
  baseline zero from positive tallies.
- Of 280 conditions with more than twenty recorded baseline seedlings,
  **72 (25.7%)** have a qualifying new live sapling tally at follow-up. The
  remainder is not a stand-level regeneration-failure rate.
- Adding existing maple sapling density and established-maple basal area
  changes Brier score by about **−0.0016** in both populations. Full-refit
  county-bootstrap intervals span zero. At the same top-quarter capacity,
  the added-stage model captures 58 versus 60 recruit-bearing conditions
  overall and 43 versus 44 among baseline detections.
- Of 1,593 tagged baseline saplings, 1,580 have comparable biological fates:
  334 recorded dead, 1,188 still live below five inches, and 58 live at or
  above five inches. Frame inconsistencies, species reidentification, and a
  cruiser-error record remain separate from biological fate outcomes.

The supported conclusion is that standard counts are a limited indicator of
recorded sapling entry—not proof of adequate stocking or advancing cohort
replacement. The added value of the tested maple-stage predictors remains
small and uncertain. No operational survey-triage or treatment claim follows.

## Secondary analyses and optional extensions

The retrospective comparison makes the objective explicit: locating conditions with
baseline seedlings but no new sapling recorded at follow-up. Of 672 such
baseline-detected intervals, 572 have this outcome. At a fixed capacity of 168:

| Strategy | Expected no-entry conditions found |
|---|---:|
| Random selection | 143 |
| Low raw seedling count | 162 |
| Count + design model | 160 |
| Maple-stage model | 163 |

The stage model's gain over raw counts is one condition; its paired uncertainty
interval crosses zero. In the later-year test, the simple rule yields 65.18
expected no-entry conditions among 68 selected and both models yield 65.
The comparison integrates cutoff ties rather than choosing a favorable order.
No-entry is not independently measured survey need or treatment benefit.

The RI measurement audit now retains **90 intervals with 14 recruit-bearing
conditions** after baseline sampling, record, and date checks. Ordinary counts
match RI counts at least one foot long in all 311 matched microplot-condition
intervals. Thirteen of the fourteen recruit-bearing conditions had baseline
RI maple seedlings at least five feet long. This is a descriptive association,
not proof of added predictive value: the later-year split has only four events.
No height-class model is fitted. Annual 2012-2015 supplement access remains a
qualification; inspected 2016-2018 guides cover 37 intervals and four events,
including an archived 2016 copy marked DRAFT.

An optional follow-on hypothesis is whether **length structure adds useful information beyond
ordinary counts on identical sampled areas**. Establishing that requires a
better-supported evaluation sample and a defined decision, not more fitting
within these 14 events.

The [count-versus-length study design](report/length-study.qmd) now fixes one
added feature (the fraction at least five feet long), identical-case comparisons,
plot-balanced paired Brier gain, and evaluation safeguards. A metadata-only
historical census finds 88 positive-seedling opportunities on 79 plots before
full eligibility checks; only six plots lie outside the current recruitment
cohort. Wisconsin/Minnesota feasibility work is deferred under the core-paper
priority. Earlier authorized download attempts returned empty responses; no
regional files or sample-size findings are available. Those inventories are
not required for the Michigan paper; see the [access status](report/length-study.qmd#regional-acquisition-status).
No new height model is fitted.
Run `make length-plan` to reproduce the opportunity and precision scenarios.

See the [survey findings](report/recruitment.qmd#survey-priority-comparison),
[paired comparisons](outputs/tables/recruitment-survey-paired-differences.csv),
[RI measurement audit](report/ri-audit.qmd), and
[validation plan](docs/survey-validation-plan.md).

![Recorded entry by baseline seedling count](outputs/figures/10_recruitment_counts.png)

## What is implemented

| Component | Evidence |
|---|---|
| Audited entrant definition, matched microplot opportunity, exclusions, linked sapling fates | [Extraction module](R/recruitment.R), [cohort flow](outputs/tables/recruitment-cohort-flow.csv), [endpoint definitions](outputs/audits/recruitment-definitions.csv) |
| Four fixed benchmarks, separately fitted for all pairs and baseline detections | [Model module](R/recruitment_models.R), [analysis contract](research/runs/recruitment-2026-09-08/analysis-contract.md) |
| County-held-out validation, training-only scaling, paired uncertainty from 300 full-refit county resamples per population | [Validation](outputs/tables/recruitment-model-validation.csv), [paired differences](outputs/tables/recruitment-model-paired-differences.csv), [bootstrap audit](outputs/tables/recruitment-model-bootstrap-audit.csv) |
| Exact-overlap, protocol, and penalty sensitivities; retrospective temporal assessment without shared physical plots | [Sensitivities](outputs/tables/recruitment-model-sensitivities.csv), [temporal assessment](outputs/tables/recruitment-model-temporal.csv) |
| Reproducible findings, citations, source-access notes, and calculation checks | [Report](report/recruitment.qmd), [research evidence](research/README.md), [tests](tests/testthat) |
| Fixed-capacity simple-rule comparisons, full-refit uncertainty, common-horizon sensitivity, and RI availability | [Survey module](R/recruitment_survey.R), [capacity results](outputs/tables/recruitment-survey-summary.csv), [RI coverage](outputs/tables/recruitment-survey-ri-coverage.csv) |
| RI frame/status audit, valid-zero accounting, matched-count reconciliation, and descriptive length support | [RI module](R/regeneration_indicator.R), [measurement report](report/ri-audit.qmd), [claim review](research/runs/recruitment-2026-09-08/ri-review.md) |

The [research record](research/README.md) preserves the analysis scope, source
notes, competing explanations, and numerical and citation checks. These checks
document the work; they do not replace independent scientific review.

## Why the direction changed

The previous response was loss of seedling detection, not recruitment. In its
932 repeated pairs, 75 of 677 baseline detections became non-detections. The
full model's AUC of 0.856 was only slightly above the density + coverage +
interval benchmark's 0.845. Its beech association remains exploratory and does
not establish a management mechanism.

The [detection pilot](report/index.qmd) preserves those results. The earlier
cross-sectional analysis remains as a methodological foundation. Neither is
recast as the newly implemented recruitment analysis.

FIA recruitment prediction is already established in the literature. This
project's contribution is a Michigan evaluation of common measurements and
their limits, not a claim to have invented longitudinal recruitment modeling.
The [direction document](docs/research-direction.md) records the evidence for
the pivot. Operational usefulness remains a separate unvalidated extension,
not a missing core research result.

## Reproduce

Requirements: R 4.4 or newer, Quarto, Make, and sufficient space for the Michigan
FIA SQLite archive. The source snapshot and EVALID 262501 remain pinned in
[configuration](config/config.yml) and the [provenance audit](outputs/audits/data-provenance.csv).

```bash
make setup
make acquire
make all
```

If the common FIA products already exist, run `make longitudinal` first. Then
rebuild the recruitment analysis and report with:

```bash
make recruitment-core
make test
make report
```

The core recruitment target runs:

1. [Build the audited endpoint and linked fates](scripts/13_build_recruitment_dataset.R).
2. [Fit benchmarks, validation, bootstrap, and sensitivities](scripts/14_recruitment_models.R).
3. [Create figures and supporting aggregate data](scripts/15_recruitment_figures.R).
4. [Compare survey-priority strategies](scripts/16_recruitment_survey_audit.R).
5. [Inventory existing regeneration-indicator coverage](scripts/17_audit_regeneration_indicator.R).
6. [Audit RI sampling, length classes, and measurement support](scripts/18_audit_ri_measurements.R).
7. [Reconcile manuscript evidence and export study support](scripts/21_audit_recruitment_paper.R).

`make survey-audit` runs steps 4-5 using the existing model bundle.
`make ri-audit` runs step 6 using the existing recruitment dataset.
`make paper-audit` repeats step 7 without fitting any models.
`make length-plan` separately reproduces the optional count-versus-length design.
The compatibility target `make recruitment` runs the core plus that design.

`make paper-word` rebuilds the editable manuscript from the same source, then
applies the plain academic formatting in `scripts/22_format_recruitment_docx.py`.
This export additionally needs Python with `python-docx`; select that environment
with `PAPER_PYTHON=/path/to/python3` when needed. Word exports and their visual-QA
files remain local; the public manuscript is the HTML research report.
Run `make report-links` after `make report` to check local files and section links.
`make submission-audit` separately checks point predictions and performance
calculations using a second optimizer without replacing the saved models.

`make regional-acquire` can retry the separately authorized Wisconsin/Minnesota
downloads, checks archive/database integrity and disk space, and pins successful
files without replacing existing sources. It is not part of `make all` and
does not run scientific screening or fit models. Current failures are recorded
in the [acquisition audit](outputs/audits/recruitment-regional-acquisition.csv).
No regional retry is part of core-paper completion.

`make direction-audit` reproduces the earlier pilot reassessment and candidate
recruitment feasibility counts. Those preliminary counts are not the final
922-pair recruitment cohort. `make report` renders locally; it does not publish.

## Interpretation guardrails

- A qualifying new sapling is live at follow-up, at least one and less than
  five inches DBH, and reconciled as a new tally on comparable sampled area.
  It is not individually linked to a baseline seedling or known to be seed-origin.
- Seedlings are untagged; larger counts may be estimated. New entrants that
  die before follow-up or grow beyond the restricted size class are not counted.
- Missing direct subplot predecessor fields require reconstruction from plot
  linkage, subplot numbers, and condition-change records. Mapped area agreement
  is not an individual stem-location check.
- Surveyed zeros require demonstrated opportunity. Ambiguous records are not
  silently converted to zero outcomes or deaths.
- Both all-pair and baseline-detected comparisons are principal results.
  A high pooled AUC does not settle discrimination within seedling-bearing sites.
- Validation is internal to an already explored Michigan snapshot. Bootstrap
  intervals refit models but omit research-question and model-set selection.
- AUC and top-quarter selection are diagnostic, not a management decision rule.
  No causal effect of browsing, beech, or treatment is estimated.
- Counts are unweighted sample summaries, not formal FIA population estimates.
  Exact plot coordinates are neither used nor inferred.

## Project structure

```text
R/                 reusable extraction, measurement, and model functions
scripts/           ordered pipeline entry points
data/              local raw, interim, and processed data
outputs/           aggregate tables, figures, audits, and local model objects
tests/testthat/    calculation, cohort, linkage, and leakage checks
report/            recruitment report, detection pilot, and bibliography
research/          research scope, analysis contracts, source notes, and reviews
docs/              direction, decisions, and analytical data dictionary
config/            source metadata, paths, and thresholds
```

Raw source data, record-level derived data, and model predictions are excluded
from Git. Exported evidence consists of aggregate summaries and figures.

## Sources and licensing

Primary research and protocol citations, with access limitations, are in the
[report bibliography](report/references.bib) and
[source notes](research/notes/seedling-recruitment-literature.md).
Inputs come from the [USDA FIA DataMart](https://research.fs.usda.gov/products/dataandtools/fia-datamart);
the retained climate foundation also uses Daymet and Census data.

Code is available under the [MIT License](LICENSE). Inputs are not redistributed.
[CITATION.cff](CITATION.cff) identifies the current software version. Cite the
exact Git commit when referring to these results; a software version is not
evidence of journal publication. Earlier release tags describe the detection
study and should not be cited as releases of the recruitment results.
