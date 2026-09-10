# Survey extension review

Reviewed 2026-09-08 by the lead agent. This extends the existing recruitment
analysis; it is not independent peer review, external validation, or a native
HyperResearch harness run. No separate final-results sign-off is claimed.

## Critique and disposition

| Risk | Disposition |
|---|---|
| Predictive accuracy may not improve a real decision. | Compare six fixed strategies at matched illustrative capacity. State that no recorded entry is a retrospective proxy, not independently measured survey need or a stocking deficit. No utility threshold or treatment benefit is invented. |
| A sophisticated model can look useful against a weak benchmark. | Retain raw seedling counts, counts per sampled coverage, sapling presence, and random expectation alongside the existing count and stage models. |
| Choosing a favorable order within count ties inflates capture. | Use uniform expected capture at the boundary, with attainable minimum/maximum and deterministic source-key results exported separately. Random selection is an analytic expectation, not a key-order draw. |
| Saved-prediction resampling omits model-fit uncertainty. | Refit training scaling and all county-held-out models in each of 300 whole-county resamples per population; all 600 draws succeed. Folds, policy set, and model forms remain fixed. |
| A one-condition gain may be mistaken for robust superiority. | Report paired uncertainty, the opposite objective, 10%/50% capacities, and later-year performance. The three primary paired intervals include zero; neither superiority nor equivalence is established. |
| Realized follow-up duration is unavailable at the forecasting date. | Add a common seven-year scoring sensitivity while leaving training intervals unchanged. The observed outcomes still have variable durations, so this does not validate seven-year risks. |
| Equal condition capacity may not mean equal visit cost. | Export distinct physical-plot counts for deterministic selection. Do not present condition intervals as a real field budget. |
| The literature's height-class result could be imported as local proof. | Inventory local RI record support first: 90 overlapping intervals, 14 recruit-bearing conditions. Treat this as availability only; require a protocol/frame audit and precision assessment before any model. |
| An unused predictor might make previously explored outcomes appear external. | Explicitly identify the RI overlap as part of the explored Michigan cohort, not a separate validation sample. |

## Numerical claim map

All paths are relative to the repository root. Publications motivate the
questions; these numerical results come from local calculations.

| Claim | Evidence |
|---|---|
| Primary population: 672 intervals, 572 no-entry targets, capacity 168 | `outputs/tables/recruitment-survey-summary.csv` |
| Expected no-entry counts: random 143; raw count 162; count per coverage 161.05; sapling presence 156.75; count model 160; stage model 163 | Same summary, baseline-detected population, no-entry objective, fraction 0.25 |
| Stage minus raw-count selected yield: +0.60 percentage points, 95% interval −3.66 to +2.28 | `outputs/tables/recruitment-survey-paired-differences.csv` |
| Raw-count cutoff can yield 160–163 targets; expectation 162 | Summary tie-range and expected-target columns |
| Raw-count selection spans 168 plots; stage selection 167 | Summary deterministic physical-plot column; not a random-tie plot-count expectation |
| Later-year no-entry counts: raw 65.18; either model 65, selecting 68 of 275 | `outputs/tables/recruitment-survey-temporal.csv` |
| Common-horizon primary counts: raw 162; count model 161; stage model 163 | `outputs/tables/recruitment-survey-common-horizon.csv` |
| All 600 full-refit county draws succeed | `outputs/tables/recruitment-survey-bootstrap-audit.csv`; empty failure table |
| RI plot records at both visits: 90 intervals, 87 plots, 14 recruit-bearing conditions | `outputs/tables/recruitment-survey-ri-coverage.csv` |

Tests check tie expectations, weighted draws against expanded observations,
objective direction, physical-plot accounting, common-horizon training scaling,
and exported arithmetic. They do not require a preferred policy to win.

## Source and delivery checks

The source note records actual access: Vickers and Elkin (2006) publisher
metadata/abstract, not a full-text read; Harris et al. (2022) official USDA
abstract/metadata in this extension, with earlier paper access recorded
separately. Neither source supplies local survey costs or establishes local
operational benefit.

`make survey-audit` completes without warnings, `make test` passes 302
expectations with no failures/warnings/skips, and `make report` renders seven
pages. A read-only local resource/fragment check finds no broken references
among 1,467 checks. Both new comparison tables and the validation-plan page
were visually inspected. These are lead-agent checks, not independent review.

The revised research goal is to assess whether additional measurements improve
a specified decision over simple counts. The immediate in-scope milestone is
the RI protocol/frame audit, with a stop gate if event support is insufficient.
Field coordination, new geography, deployment, and external validation have not
been performed. No commit or publication is included.
