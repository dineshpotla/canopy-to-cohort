# Length-study design review

Reviewed 2026-09-09 by the lead agent. This continuation creates a protocol,
metadata census, and hypothetical precision calculations. It does not fit a
length model or claim independent peer review or external validation.

## Evidence and access

| Source | Access and supported use |
|---|---|
| Harris, Woodall, and D'Amato (2022), *Increasing the utility of tree regeneration inventories: Linking seedling abundance to sapling recruitment* | [Official USDA abstract/metadata](https://research.fs.usda.gov/treesearch/67377) rechecked; earlier full-text access is recorded in `research/notes/seedling-recruitment-literature.md`. Supports the length hypothesis and prior-art acknowledgment, not local sample size or superiority of the proposed one-term feature. |
| Riley et al. (2024), *Evaluation of clinical prediction models (part 3)* | [University-hosted publisher PDF](https://pure-oai.bham.ac.uk/ws/portalfiles/portal/217741108/bmj-2023-074821.full.pdf), DOI `10.1136/bmj-2023-074821`; printed pp. 1-2 and 4-6 read, including Figure 3 and Box 1. Printed p. 4 rendered and visually inspected. Supports tailored assessment precision and separate calibration requirements. The local paired-loss formula is a labeled mean-precision derivation, not the paper's complete criteria. |
| NIST/SEMATECH, *7.2.4.1 Confidence intervals* | [Official handbook](https://www.itl.nist.gov/div898/handbook/prc/section2/prc241.htm), Wilson formulas and terminology note read. Used for plug-in interval widths, not guaranteed or clustered precision. |
| USDA, *FIADB Update History: Michigan* | [Official history](https://apps.fs.usda.gov/fiadb-api/fiadb_update_history?statecd=26), read 2026-09-09. Addition of 262025 is dated 2026-04-27; later entries concern soils and down-wood. Those notes identify no newer recruitment cycle. This is not a fresh-database content comparison. |
| USDA, *FIA DataMart* | [Official product page](https://research.fs.usda.gov/products/dataandtools/fia-datamart) read. Establishes the acquisition route, not verified RI support in Wisconsin/Minnesota. Direct retrieval of the legacy SQLite-list page failed; no state file was downloaded. |

Direct BMJ/PMC access failed or returned a verification page. The accessible
publisher PDF in the university repository was used instead. No access control
was bypassed. Clinical examples are not forestry targets or numeric minimums.

## Critique and disposition

| Risk | Disposition |
|---|---|
| Historical rows are mistaken for an independent test set. | Census physical plots and overlap with the 903-plot cohort. Retain the prior exploration of the Michigan source; unused rows/predictors are not external validation. |
| Metadata presence is promoted into endpoint eligibility. | Call the 88 positive-seedling rows opportunities. No new follow-up TREE/recruitment values are queried. Source, frame, condition-link, and endpoint checks remain required. |
| H/N mixes length structure with a different minimum size. | N is the ordinary count verified against RI classes 3-6; H is classes 5-6. Below-one-foot seedlings are a separate question. |
| An undefined fraction becomes a false short-seedling observation. | Return missing Q for N = 0 and restrict the primary comparison to N > 0. Invalid counts or disagreement stop calculation. |
| Repeated conditions inflate support and weight. | Use one date-selected interval per plot within a period, plot-balanced training/evaluation, and grouping of all plot visits across development/assessment. |
| Realized duration enters a claimed baseline forecast. | Define a conditional retrospective next-visit comparison. Planned-horizon forecasting remains separate. |
| A convenient sample-size result is presented as adequate. | Export 54 scenarios with hypothetical SD, inflation, retention, and precision. They do not establish training size, calibration precision, power, or decision benefit. |
| Wilson width is interpreted as a symmetric margin around recall. | Label half total width and show endpoints. Plug-in widths are not expected or guaranteed widths. Event units are not total plots. |
| A useful-gain threshold is selected from evaluation results. | Require delta before evaluation. Statistical Brier gain is not field utility. |
| Length seems helpful only because the abundance model is too rigid. | Predeclare a matched three-degree-of-freedom log-count spline sensitivity before new evaluation; use development-only knots/scaling. Report both contrasts and include the larger five/six-slope pair in development planning. |
| A regional result becomes a Michigan validation claim. | Separate regional transport from Michigan-specific validation; geography approval precedes new-state acquisition. |

## Numerical claim map

| Claim | Evidence |
|---|---|
| 234 baseline condition visits, 221 plot visits, 116 physical plots, 38 counties | `outputs/tables/recruitment-length-opportunity-flow.csv`, first row |
| Exactly one successor for 128 condition visits | Same flow table |
| 114 opportunities on 95 plots have a sampled national-design successor and 4.5-8.5-year interval | Same flow; not validated condition intervals |
| Positive ordinary seedlings: 88 opportunities on 79 plots | Same flow |
| 71 existing RI pairs; ten additional visits on current-cohort plots; seven visits on six outside-cohort plots | `recruitment-length-opportunity-overlap.csv`; plots can recur across groups |
| 106 baseline condition visits have no linked successor | Flow and `recruitment-length-opportunity-calendar.csv`; not a promised future cohort |
| SD 0.10, half-width 0.01, inflation 1.5: 577 complete evaluation plots; 722 candidates at 80% retention | `recruitment-length-paired-precision.csv`; hypothetical, not fitted RI quantities |
| SD 0.05/0.20 under those other assumptions: 145/2,305 complete plots | Same precision table |
| Recall 0.8: 60/245 independent event units for half-total-width 0.10/0.05 | `recruitment-length-recall-precision.csv`; plug-in Wilson, not power or paired recall precision |

## Software and delivery

`make length-plan` completed without R warnings. The suite passes 409 test
expectations with no failures, warnings, or skips. New tests cover feature
definitions, plot-balanced loss, county consistency, rounding, agreement with
R's uncorrected score interval, minimal plug-in event counts, outcome-free SQL,
and exported totals. A county-consistency test caught a summarization-order
error; it was fixed before delivery.

[Run status](status.json) records final rendering and reference checks.
Record-level metadata remain ignored. Existing recruitment/RI results are
unchanged. A separate scope decision is required before a Wisconsin/Minnesota
feasibility screen; no new inventory, model, commit, or publication is included.
