# Analytical detail revision

Date: September 10, 2026. The user identified that the manuscript did not
describe the completed analytics in enough detail. This revision expands
the same Michigan paper; it does not select new models or add external data.

## Identified gap

The previous Word manuscript had seven tables and conveyed the principal
findings, but important numerical evidence was available only through linked
repository exports. Repository-relative links are intentionally converted to
plain labels in standalone Word files, so those exports did not make the paper
self-contained for a reader reviewing only the manuscript.

## Material brought into the paper

| Analytical component | Added detail | Existing evidence |
| --- | --- | --- |
| Cohort and missingness | Analytical unit, 932-to-922 exclusion accounting, alternative subset denominators, no silent complete-case changes or predictor imputation | Recruitment code, cohort flow, analysis contract |
| Predictor construction | Five definitions, units, transformations, scaling, model equations, penalty, optimizer and model dimensions | `R/recruitment.R`, `R/recruitment_models.R` |
| Evaluation | Explicit Brier/log-loss definitions, AUC/AP tie treatment, pooled scoring, deterministic folds and frequency-weighted county bootstrap | `R/recruitment_models.R` |
| Calibration | Six complete design/count/stage diagnostics with mean probability, joint intercept, slope and O/E | Model validation export |
| Count-bin uncertainty | Existing empirical county intervals now appear beside numerators and denominators | Count-stratum interval export |
| Model uncertainty | Absolute Brier/AUC intervals for all four models and both populations | Model interval export |
| Additional matched contrasts | All twelve log-loss, AUC and AP differences and intervals | Paired model export |
| Sensitivities and time split | Eight matched count-stage sensitivity rows, all temporal benchmarks, sample/protocol shifts | Sensitivity, temporal and split-support exports |
| Descriptive coefficients and strata | All 28 population-specific coefficients and all ten joint count-sapling cells | Coefficient and joint-stratum exports |
| Linked fates | Comparable-stem percentages, survivor growth quantiles, zero/negative difference proportions | Fate and growth audits |
| Secondary survey analysis | All six fixed strategies at the primary capacity, uncertainty, denominators and cutoff-tie method | Survey summary and implementation |
| Secondary evidence limits | RI measurement comparability and explicit separation from unjoined environmental data | Existing RI audits and external-factor feasibility notes |

The main text now distinguishes the positive within-detection count-versus-design
log-loss, AUC and AP evidence from the uncertain Brier difference. Stage-addition
intervals span zero across those metrics. This is fuller reporting of the
existing results, not an improved result obtained by changing the analysis.

## Verification and scope

The manuscript contains sixteen editable tables, two original scientific
figures, native equations, and six anchored review comments. Seven additional
paper-audit checks reconcile the exposed coefficients, fold diagnostics,
absolute-interval point estimates, and joint strata against the saved model
bundle. The growth check now also verifies the 10th and 90th percentiles.
The bounds of stored bootstrap intervals are checked for consistency but not
recomputed from new draws. Python tests compare rendered Word table values
with the corresponding exports, including sensitivity denominators, paired
contrasts, coefficients, and all six survey strategies.

The full R suite passed 480 expectations without failures, warnings, or skips;
the manuscript audit passed all 50 checks. Final document test and page-review
counts and checksums are recorded in `status.json`. The saved core model,
condition cohort, and linked-fate RDS checksums remain unchanged. No full
research-pipeline rerun, bootstrap rerun, new predictor search, external-factor
fit, public archive, commit, or submission is included.

The prior Word copy and affected source files are preserved in
`outputs/paper/before-analytics-detail-SZPxXd/`. The canonical manuscript
remains `report/recruitment.qmd`. Human scientific review and the author,
journal, and archive decisions in the submission-readiness review still apply.
