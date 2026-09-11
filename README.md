# Canopy to Cohort

I built Canopy to Cohort to answer a focused question: do ordinary regeneration
observations help anticipate a newly recorded sugar-maple sapling in Michigan
northern hardwoods?

[Live project](https://dineshpotla.github.io/canopy-to-cohort/) ·
[Research report](https://dineshpotla.github.io/canopy-to-cohort/report/recruitment.html) ·
[Study map and figures](https://dineshpotla.github.io/canopy-to-cohort/report/spatial-context.html) ·
[Methods and analysis decisions](docs/analysis-decisions.md) ·
[Reproducibility guide](docs/recruitment-reproducibility.md)

I use real Michigan Forest Inventory and Analysis (FIA) data. I test how well
baseline seedling abundance and maple stage structure anticipate entry into the
FIA sapling size class, while separating recorded recruitment from survival,
growth, and observation changes.

I define recruitment as a new live sapling recorded at the next visit. That
definition keeps the question measurable and prevents me from treating an
untagged seedling count as if it were an individual growth history.

## How I approached the question

I started by pinning one Michigan FIA source snapshot and building a linked
cohort of comparable forest-condition visits. I then defined the recruitment
endpoint, checked the sampling frame and condition linkage, and kept ambiguous
records out of the outcome rather than forcing them into zeros.

Next, I fit four fixed benchmark models separately for the full cohort and the
baseline-detected subset. I evaluated them with county-held-out predictions,
paired bootstrap differences, sensitivity checks, and a later-year temporal
assessment. Finally, I linked tagged saplings to their next observed fate so the
recruitment endpoint would not be confused with individual survival or growth.

## Findings in plain language

I found that more seedlings were a useful clue to where new maple saplings
would be recorded, but they did not guarantee that transition. Adding the
abundance of existing maple saplings and larger maples did not clearly improve
prediction. I followed tagged saplings separately, which showed why growth out
of the size class must not be counted as death.

In this study, saplings have trunks at least 1 inch but less than 5 inches in
diameter at breast height. I do not use the results to diagnose regeneration
failure or identify its causes.

## Evidence behind the findings

My completed Michigan [study](report/recruitment.qmd) addresses three questions:
how much information seedling counts provide, whether maple stage structure
adds value, and what linked sapling fates show. I publish the code, aggregate
evidence, and research report together. This is a research draft, not a
peer-reviewed publication or an externally validated tool. I have not assigned
an immutable archive or DOI.

- I audited **922 condition intervals, 903 physical plots,
  and 66 counties**, with 169 qualifying new live saplings in 100 conditions.
  Ten of the original 932 pairs are excluded for unresolved frame consistency
  or ambiguous newly recorded saplings.
- In county-held-out validation, seedling count plus sampling coverage and
  interval achieves
  AUC **0.796 overall and 0.699 among baseline seedling detections**. Counts
  contain information; the pooled result partly benefits from distinguishing
  baseline zero from positive tallies.
- Among 280 conditions with more than twenty recorded baseline seedlings,
  **72 (25.7%)** have a qualifying new live sapling tally at follow-up. The
  remainder is not a stand-level regeneration-failure rate.
- When I add existing maple sapling density and established-maple basal area,
  the Brier score changes by about **−0.0016** in both populations. Full-refit
  county-bootstrap intervals span zero. At the same top-quarter capacity,
  the added-stage model captures 58 versus 60 recruit-bearing conditions
  overall and 43 versus 44 among baseline detections.
- I linked 1,593 tagged baseline saplings; 1,580 have comparable biological
  fates:
  334 recorded dead, 1,188 still live below five inches, and 58 live at or
  above five inches. Frame inconsistencies, species reidentification, and a
  cruiser-error record remain separate from biological fate outcomes.

Together, these results support a limited conclusion: standard counts contain
information about recorded sapling entry, but they do not prove adequate
stocking or advancing cohort replacement. The added value of the tested
maple-stage predictors remains small and uncertain. I make no operational
survey-triage or treatment claim.

## Secondary analyses and optional extensions

I also tested a retrospective comparison aimed at locating conditions with
baseline seedlings but no new sapling recorded at follow-up. Of 672
baseline-detected intervals, 572 have this outcome. At a fixed capacity of 168:

| Strategy | Expected no-entry conditions found |
|---|---:|
| Random selection | 143 |
| Low raw seedling count | 162 |
| Count + design model | 160 |
| Maple-stage model | 163 |

The stage model gains one condition over raw counts, but its paired uncertainty
interval crosses zero. In the later-year test, the simple rule yields 65.18
expected no-entry conditions among 68 selected and both models yield 65. I
integrated cutoff ties rather than choosing a favorable order. No-entry is not
an independently measured survey need or treatment benefit.

My RI measurement audit retains **90 intervals with 14 recruit-bearing
conditions** after baseline sampling, record, and date checks. Ordinary counts
match RI counts at least one foot long in all 311 matched microplot-condition
intervals. Thirteen of the fourteen recruit-bearing conditions had baseline
RI maple seedlings at least five feet long. This is a descriptive association,
not proof of added predictive value because the later-year split has only four
events. I did not fit a height-class model. Annual 2012-2015 supplement access
remains a qualification; inspected 2016-2018 guides cover 37 intervals and four
events, including an archived 2016 copy marked DRAFT.

I leave one follow-on hypothesis open: does **length structure add useful
information beyond ordinary counts on identical sampled areas**? Answering it
requires a better-supported evaluation sample and a defined decision, not more
fitting within these 14 events.

My optional [count-versus-length study design](report/length-study.qmd) specifies
one added feature, the fraction at least five feet long, identical-case
comparisons, plot-balanced paired Brier gain, and evaluation safeguards. A
metadata-only census finds 88 positive-seedling opportunities on 79 plots before
full eligibility checks; only six plots lie outside the current recruitment
cohort. Regional evaluation would require additional inventories and a verified
comparison sample. The Michigan findings do not include a fitted length model
or a regional validation result.
Run `make length-plan` to reproduce the opportunity and precision scenarios.

See the [survey findings](report/recruitment.qmd#survey-priority-comparison),
[paired comparisons](outputs/tables/recruitment-survey-paired-differences.csv),
[RI measurement audit](report/ri-audit.qmd), and
[validation plan](docs/survey-validation-plan.md).

![Recorded entry by baseline seedling count](outputs/figures/10_recruitment_counts.png)

## What is implemented

| Analysis I implemented | Evidence |
|---|---|
| Audited entrant definition, matched microplot opportunity, exclusions, linked sapling fates | [Extraction module](R/recruitment.R), [cohort flow](outputs/tables/recruitment-cohort-flow.csv), [endpoint definitions](outputs/audits/recruitment-definitions.csv) |
| Four fixed benchmarks, separately fitted for all pairs and baseline detections | [Model module](R/recruitment_models.R), [analysis decisions](docs/analysis-decisions.md) |
| County-held-out validation, training-only scaling, paired uncertainty from 300 full-refit county resamples per population | [Validation](outputs/tables/recruitment-model-validation.csv), [paired differences](outputs/tables/recruitment-model-paired-differences.csv), [bootstrap audit](outputs/tables/recruitment-model-bootstrap-audit.csv) |
| Exact-overlap, protocol, and penalty sensitivities; retrospective temporal assessment without shared physical plots | [Sensitivities](outputs/tables/recruitment-model-sensitivities.csv), [temporal assessment](outputs/tables/recruitment-model-temporal.csv) |
| Reproducible findings, citations, source-access notes, and calculation checks | [Report](report/recruitment.qmd), [analysis decisions](docs/analysis-decisions.md), [tests](tests/testthat) |
| Fixed-capacity simple-rule comparisons, full-refit uncertainty, common-horizon sensitivity, and RI availability | [Survey module](R/recruitment_survey.R), [capacity results](outputs/tables/recruitment-survey-summary.csv), [RI coverage](outputs/tables/recruitment-survey-ri-coverage.csv) |
| RI frame/status audit, valid-zero accounting, matched-count reconciliation, and descriptive length support | [RI module](R/regeneration_indicator.R), [measurement report](report/ri-audit.qmd), [analysis decisions](docs/analysis-decisions.md) |

I keep supporting source notes and review records under `research/` for
traceability. They document how I made the decisions and checked the work; they
do not add separate findings or replace independent scientific review.

## Research contribution

I contribute a reproducible regional evaluation of common FIA measurements and
their limits. I quantify how much ordinary maple seedling counts tell us about
recorded sapling entry, test whether existing maple size structure improves
prediction on the same observations, and separately describe the fates of
tagged saplings.

## Reproduce

To reproduce my results, use R 4.4 or newer, Quarto, Make, and sufficient space
for the Michigan FIA SQLite archive. I pin the source snapshot and EVALID 262501
in [configuration](config/config.yml) and the [provenance audit](outputs/audits/data-provenance.csv).

```bash
make setup
make acquire
Rscript scripts/09_build_longitudinal_dataset.R
make recruitment-core
make test
make report
```

If the pinned source and linked cohort already exist, rebuild my recruitment
analysis and report with:

```bash
make recruitment-core
make test
make report
```

The core recruitment target runs these steps:

1. I [build the audited endpoint and linked fates](scripts/13_build_recruitment_dataset.R).
2. I [fit benchmarks, validation, bootstrap, and sensitivities](scripts/14_recruitment_models.R).
3. I [create figures and supporting aggregate data](scripts/15_recruitment_figures.R).
4. I [compare survey-priority strategies](scripts/16_recruitment_survey_audit.R).
5. I [inventory existing regeneration-indicator coverage](scripts/17_audit_regeneration_indicator.R).
6. I [audit RI sampling, length classes, and measurement support](scripts/18_audit_ri_measurements.R).
7. I [reconcile manuscript evidence and export study support](scripts/21_audit_recruitment_paper.R).

`make survey-audit` runs steps 4-5 using the existing model bundle.
`make ri-audit` runs step 6 using the existing recruitment dataset.
`make paper-audit` repeats step 7 without fitting any models.
`make length-plan` separately reproduces my optional count-versus-length design.
The compatibility target `make recruitment` runs the core plus that design.

`make paper-word` rebuilds my editable manuscript from the same source, then
applies the plain academic formatting in `scripts/22_format_recruitment_docx.py`.
This export additionally needs Python with `python-docx`; select that environment
with `PAPER_PYTHON=/path/to/python3` when needed. Word exports and their visual-QA
files remain local; the public manuscript is the HTML research report.
Run `make report-links` after `make report` to check local files and section links.
`make submission-audit` separately checks point predictions and performance
calculations using a second optimizer without replacing the saved models.

`make regional-acquire` can retry the Wisconsin/Minnesota downloads, checks
archive/database integrity and disk space, and pins successful files without
replacing existing sources. It is not part of `make all` and does not run
scientific screening or fit models. Current failures are recorded in the
[acquisition audit](outputs/audits/recruitment-regional-acquisition.csv). This
optional step is separate from the core analysis.

`make report` renders locally; `make publish` publishes the rendered website.

## How I interpret the results

- I define a qualifying new sapling as live at follow-up, at least one and less
  than five inches DBH, and reconciled as a new tally on comparable sampled
  area. I do not individually link it to a baseline seedling or identify its
  seed origin.
- I treat seedlings as untagged, so larger counts may be estimated. New
  entrants that die before follow-up or grow beyond the restricted size class
  are not counted.
- I reconstruct missing direct subplot predecessor fields from plot linkage,
  subplot numbers, and condition-change records. Mapped area agreement is not
  an individual stem-location check.
- I require demonstrated opportunity before treating a surveyed zero as a
  meaningful zero. I do not silently convert ambiguous records into zero
  outcomes or deaths.
- I treat both all-pair and baseline-detected comparisons as principal results.
  A high pooled AUC does not settle discrimination within seedling-bearing
  sites.
- I validate within the fixed Michigan snapshot. Bootstrap intervals refit
  models but omit research-question and model-set selection.
- I use AUC and top-quarter selection as diagnostic summaries, not management
  decision rules. I do not estimate causal effects of browsing, beech, or
  treatment.
- I report unweighted sample summaries, not formal FIA population estimates. I
  neither use nor infer exact plot coordinates.

## How I organized the repository

```text
R/                 my reusable extraction, measurement, and model functions
scripts/           my ordered pipeline entry points
data/              local raw, interim, and processed data
outputs/           aggregate tables, figures, audits, and local model objects
tests/testthat/    calculation, cohort, linkage, and leakage checks
report/            research paper, study figures, supporting reports, and bibliography
research/          supporting scope, source notes, and review records
docs/              methods, reproducibility guide, and analytical data dictionary
config/            source metadata, paths, and thresholds
```

Raw source data, record-level derived data, and model predictions are excluded
from Git. Exported evidence consists of aggregate summaries and figures.

## Sources and licensing

I keep primary research and protocol citations, with access limitations, in the
[report bibliography](report/references.bib) and supporting source notes. I use
public [USDA FIA DataMart](https://research.fs.usda.gov/products/dataandtools/fia-datamart)
records for the recruitment analysis, then join FIA county identifiers to
Michigan county polygons for the study map.

Code is available under the [MIT License](LICENSE). Inputs are not redistributed.
[CITATION.cff](CITATION.cff) identifies the current software version. For
reproducibility, cite the exact Git commit when referring to these results; a
software version is not evidence of journal publication.
