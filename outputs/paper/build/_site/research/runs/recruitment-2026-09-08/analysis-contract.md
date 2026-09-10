# Recruitment analysis contract

Recorded on 2026-09-08 before fitting the new recruitment comparisons. Existing
feasibility outcomes and the 2026-09-07 detection analysis have already been
examined; this is an exploratory, retrospective analysis, not preregistration.

## Question and endpoints

How much do ordinary regeneration measurements tell us about recorded new
sugar-maple saplings at the next inventory, and what do tagged sapling fates
reveal about changes in size-class presence?

The primary outcome is at least one **new live maple sapling tallied at
follow-up**, not individual seedling survival, all recruitment during the
interval, seed-origin establishment, or eventual canopy recruitment. New
live TREE records with SPCD 318, DIA 1 to less than 5 inches, RECONCILECD 1,
and no predecessor are candidates; comparable previously sampled forest
microplot area and production/remeasurement provenance must also be checked.
Do not silently classify ambiguous entries, record corrections, or missed
trees as recruits. Retain an exclusion flow and sensitivity definitions.

Start with the existing 932 current-evaluation condition pairs. Historical
expansion is not required for this first completed analysis: its older
protocols and repeated-interval dependence need their own validation. Neither
sample prevalence nor model predictions are FIA survey-weighted estimates.

Analyze two populations side by side: all endpoint-eligible pairs, and eligible
pairs with baseline seedlings detected. The second population is essential:
all 101 candidate recruit-bearing conditions in the preliminary screen had
baseline seedlings, so pooled AUC may reward distinguishing baseline zeros.
Do not compare AUC values across different outcomes as evidence of superiority.

## Fixed model sequence

1. Intercept-only prevalence.
2. Baseline sampled microplot coverage and interval duration.
3. The same terms plus `log1p` raw baseline sugar-maple seedling TREECOUNT.
4. The same terms plus `log1p` baseline maple sapling stem density and `log1p`
   established-maple basal area.

These are four fixed models, not a stepwise search. Beech, climate, treatments,
splines, and interaction searches are not required to create a positive result.
Density must be derived from the relevant FIA expansion and sampled area;
neither a record count nor basal area is relabeled stem density.

Use ridge logistic regression with objective

`sum_i [log(1 + exp(eta_i)) - y_i * eta_i] + lambda/2 * sum_j beta_j^2`,

where the sum over coefficients excludes the intercept and `lambda=1`.
Continuous predictors are transformed and standardized in the training
sample only. The fixed penalty stabilizes fits; it is not claimed to be
optimally tuned. Inspect convergence, gradients, finite coefficients,
calibration, and penalty sensitivity. Do not report ordinary unpenalized-GLM
p-values for penalized coefficients or equate event-per-term ratios with
sample-size adequacy. No causal management interpretation is permitted.

## Validation and uncertainty

Use five county-held-out folds, assigned using sample sizes only. Keep the same
assignment for all models in a population; no outcome-driven fold redraws.
Every physical plot stays in one fold. A fold lacking one outcome has undefined
AUC, not an excuse to search for another partition. Pooled held-out metrics
remain usable when both outcomes exist overall.

Report Brier score, log loss, ROC AUC, average precision, and calibration.
At the same capacity of `floor(n/4)` conditions, compare the proportion with
recorded recruitment, its complement with no recorded new entrant, and the
fraction of recruit-bearing conditions captured. Ties need a deterministic
rule and explicit treatment; this capacity is a diagnostic, not a management
threshold. Empirical seedling-count bins are 0, 1, 2–5, 6–20, and >20, alongside
baseline sapling presence. No-entry fractions are not biological failure rates.

Paired model differences must use identical held-out observations. Resample
whole counties for uncertainty. Prefer refitting scaling and all four models
inside each replicate while retaining each county's original fold, including
all copies of a resampled county. If a computational limitation requires
bootstrapping fixed predictions instead, label that uncertainty conditional
and explicitly state that fitting uncertainty is excluded.

Sensitivity analyses: exact-overlap footprint; follow-up MANUAL>=9;
unpenalized or stronger ridge fits if numerically stable; and a fixed 2023
follow-up-year split. The temporal comparison is a retrospective assessment in
an explored snapshot, not independent future validation. Report its event,
plot, county, protocol, and interval support; do not hide distribution shift.

## Linked saplings and reporting

Classify tagged baseline saplings into alive within class, alive at >=5 inches,
recorded dead, recorded removed, no longer sampled, unresolved, and taxonomic
correction where applicable. Avoid counting species reidentification as death.
Summaries of growth condition on valid comparable measurements and survival;
zero or negative rounded diameter differences are not proof of suppression.

Deliver executable source-to-results code, aggregate evidence tables, tests,
a primary recruitment report, and revised headline findings. Preserve the
detection report as a secondary pilot. Every principal number must resolve to
an output table or reproducible calculation. Independent critique must check
measurement validity, model comparisons, omitted counter-evidence, and
sentence-to-source support. Record unresolved issues without inventing a
positive conclusion. No public deployment or commit is included.
