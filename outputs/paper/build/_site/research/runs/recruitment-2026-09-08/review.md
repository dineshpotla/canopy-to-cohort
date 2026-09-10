# Review and evidence reconciliation

Review date: 2026-09-08. This is a local research/code review, not journal peer
review, external ecological validation, or execution of the native HyperResearch
harness. The retained query and pre-fit contract define the scope.

## Critique and disposition

The protocol/literature review and a separate pre-fit statistical critique
informed implementation. The lead agent reconciled the code, reran the pipeline,
checked exported results, and verified the rendered report. The delegated work
did not complete a separate final-results sign-off; no such sign-off is claimed.

| Issue raised | Disposition |
|---|---|
| New record identifiers or reconcile code alone can include observation changes. | Require the live maple sapling class, missing TREE predecessor, code 1, intended plot successor, shared microplot checks, and compatible production/measurement provenance. Exclude unresolved new-record conditions. |
| Direct subplot predecessor fields are empty. | Corrected the initial implementation that would have rejected all pairs. Require records at both visits; use verified plot linkage plus matrix subplot number; reject contradictory direct links if populated. Disclose the reconstruction. |
| Stable condition area is not an individual tree-location check. | Report the restricted recorded-tally endpoint; audit microplot proportions and include an exact mapped-overlap sensitivity for events and zeros alike. |
| QA code 7 was at risk of being treated as invalid. | Retain valid supervised production hot checks. The stricter QA-1 row is descriptive sensitivity support, not a reason to discard them. |
| Pooled performance can benefit from baseline zeros. | Make all eligible pairs and baseline-detected pairs principal populations; fit and compare models separately. |
| Small event support and separation risk can destabilize comparisons. | Declare a small fixed model set and slope-only ridge penalty before fitting; check gradients/convergence; test unpenalized and stronger-penalty fits. Do not report ordinary GLM p-values for ridge coefficients. |
| Bootstrap of saved predictions omits fit uncertainty. | Repeat training scaling and all county-held-out fits in each of 300 county resamples per population. Keep folds and model set fixed and state the omitted selection uncertainty. |
| Capacity comparisons can be changed by probability ties. | Use identical capacity and deterministic source-key tie order; export tie-neutral expected capture as well. No management threshold is inferred. |
| Growth beyond the sapling class or species correction can masquerade as mortality. | Follow tagged stems before applying follow-up species/diameter restrictions. Export all fates; mask unresolved biological outcomes. |
| Missing attributes could be mistaken for positive recruits or known fates. | Harden classification and add missing-attribute tests. Require source-pair and protocol comparability for linked biological fates. Current numerical results are unchanged. |
| A new report alone would leave the old project story in place. | Replace overview and README headlines; update direction, decisions, and dictionary; retain the detection report as a clearly labeled pilot. |

## Numerical claim map

All paths below are relative to the repository root. These are local calculation
sources, not findings borrowed from publications.

| Report claim | Reproducible evidence |
|---|---|
| 932 source pairs become 922 eligible pairs on 903 plots; 169 entrants in 100 conditions | `outputs/tables/recruitment-cohort-flow.csv`; `outputs/audits/recruitment-eligibility.csv` |
| Nine frame exclusions and one new-sapling ambiguity exclusion | `outputs/audits/recruitment-eligibility.csv`; `R/recruitment.R` |
| 914 exact-overlap pairs retain all 169 entrants | `outputs/tables/recruitment-cohort-flow.csv`; `outputs/audits/recruitment-frame.csv` |
| Entry occurs in 72 of 280 highest-count conditions; baseline-zero group is 0 of 250 | `outputs/tables/recruitment-model-count-strata.csv`; county-resampling intervals in `recruitment-model-count-strata-intervals.csv` |
| Count-model AUC 0.796 overall and 0.699 among baseline detections | `outputs/tables/recruitment-model-validation.csv` |
| Stage-model Brier changes −0.00163 (−0.00529 to +0.00263) and −0.00159 (−0.00551 to +0.00333) | `outputs/tables/recruitment-model-paired-differences.csv`, metric `brier_score` |
| Equal-capacity capture: 60 vs 58 overall; 44 vs 43 within baseline detections | `outputs/tables/recruitment-model-validation.csv`, `top_capacity` and `top_events` |
| All 600 full-refit resamples succeed | `outputs/tables/recruitment-model-bootstrap-audit.csv`; failure table; `R/recruitment_models.R` |
| Temporal assessment has no shared physical plots and 41 test events | `outputs/tables/recruitment-model-temporal.csv`; `recruitment-model-temporal-support.csv` |
| 1,593 source stems; 1,580 comparable fates = 334 dead + 1,188 live saplings + 58 larger live stems | `outputs/audits/recruitment-sapling-fates.csv`; local ignored linked-stem RDS |
| 1,246 surviving maple diameter differences, median 0.0147 in/year, 346 zero and 13 negative | `outputs/audits/recruitment-sapling-growth.csv` |

The report reads its principal tables and headline model metrics directly from
saved outputs. Tests separately recompute Brier scores from held-out predictions,
check paired differences against model summaries, reconcile count/fate totals,
and test that physical plots do not cross validation folds. Tests do not require
the hypothesized effect to be positive or a model to perform poorly.

## Sentence-to-source check

- Michigan studies motivate a distinction between small seedlings and advancing
  regeneration: Henry (2021), abstract-level access as recorded in the literature
  note. No Michigan population rate is imported from that study.
- Small-diameter stems may be old: Henry and Walters (2023), abstract/highlights.
  Its diameter boundaries are not represented as FIA's sapling definition.
- FIA recruitment prediction and comparisons with six height classes predate
  this project: Harris (2022), primary paper and USDA publication record. The
  report acknowledges useful predictive information, not just contrary evidence.
- Regional small-seedling composition differs from established sapling abundance:
  Harris (2026), USDA abstract. The report does not invent a Michigan rate or a
  species-specific recruitment trend absent from that inspected abstract.
- Reconciliation, plot kind, and QA interpretations: FIADB v9.4 guide, the
  specific sections located in `research/notes/fia-recruitment-protocol.md`.
- Estimated seedling counts and minimum size: national field guide v9.3,
  sections 6.0/6.4. The report discloses that every historical regional edition
  was not checked; failed older-manual retrieval is recorded in the protocol note.
- Event-per-parameter rules are not sufficient sample-size planning: Riley
  (2020). This is a general statistical caution, not an assertion that a clinical
  sample-size method validates the forest study.

No paper establishes the local effect estimates, proves beech causality, or
validates a management rule. The cited FIA studies can overlap in source data;
they are not counted as independent replications of the Michigan analysis.

## Unresolved research limits

The study remains exploratory and conditional on the selected, comparable
Michigan forest conditions. The footprint reconstruction, version-specific
observation rules, estimated counts, variable intervals, small event support,
fixed model forms, and already explored snapshot limit inference. Bootstrap
intervals do not include choice of cohort, question, model set, or fold partition.
There is no external inventory assessment, individual seedling lineage, causal
effect, adequate-stocking threshold, or tested operational survey objective.

The three analytical goals—endpoint, benchmark comparison, and linked fates—have
an implemented first answer. Decision usefulness remains an open goal, not a
missing result to disguise with additional covariates.

## Reproduction and delivery checks

Run `make recruitment`, `make test`, and `make report` after the longitudinal
artifacts exist. The run status file records final verification outcomes.
Figures are inspected after rendering; count labels are placed above uncertainty
bars and margins preserve axis labels. Record-level data and prediction bundles
remain Git-ignored. The report, overview, and supporting documentation are local
outputs; no commit, public deployment, installation, or new release is included.
