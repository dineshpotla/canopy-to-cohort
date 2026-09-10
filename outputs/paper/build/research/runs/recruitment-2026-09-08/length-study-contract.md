# Count-versus-length study design contract

Declared 2026-09-09 after the local RI measurement audit, before the following
metadata census and planning calculations. Existing Michigan outcomes have
already been explored. This protocol is prospective with respect to a future
separate evaluation, not a preregistration of the Michigan results.

## Scope of this continuation

Create an executable, cited study-design artifact and planning calculations.
Inventory RI baseline opportunities and successor-visit dates in the existing
Michigan database without querying new recruitment outcomes. Treat record
presence as an upper bound, not validated condition linkage or eligible events.
Do not fit a length model, download another inventory, contact field staff,
install a harness, commit, or publish.

## Fixed scientific comparison

Use the existing conservative recorded-live-sapling-entry definition. The primary
population has standard-size baseline maple seedlings (N > 0), verified RI and
ordinary counts on identical sampled area, and comparable follow-up observation.
Keep the Michigan northern-hardwood/adult-maple scope for planning; no broadening
of the scientific population is implied by counting more database rows.

The simple model uses log(1+N), sampled microplot coverage, and elapsed interval.
The length model adds one continuous term: the fraction of standard-size
seedlings in RI classes 5-6, H/N. Both models use identical cases, training-only
scaling, the same fixed ridge penalty of 1, and no data-driven feature selection.
N is the ordinary count; unresolved count-definition disagreement stops the
comparison before fitting rather than being excluded to force agreement.
All-zero counts and RI seedlings below one foot remain a separate measurement
question, not a way to define an otherwise undefined H/N.

The primary estimand is the paired improvement in Brier loss at the recorded
next visit, conditional on the realized 4.5-8.5-year interval. This is not an
exact seven-year risk or a deployable baseline forecast. A future baseline
forecast needs a genuinely planned horizon and separately observed assessment.
Use a physical-plot-balanced mean of condition-level paired losses so plots
with several conditions do not automatically receive more weight. This changes
weighting from the earlier condition-average benchmark and must be labeled.

Report positive Brier gain as favoring length. Calibration and discrimination
are separate diagnostics. Statistical improvement does not establish ecological
importance or cost-effectiveness; any minimum useful gain remains a declared
design choice rather than a threshold discovered in evaluation outcomes.

## Planning calculations and validation boundary

Show paired-loss precision scenarios, not power or training-size claims. Use
normal-approximation mean precision with assumed physical-plot loss-difference
SDs 0.05, 0.10, 0.20; half-widths 0.005, 0.010, 0.020; variance inflation
factors 1, 1.5, 2; and complete-case retention 0.8 or 1. These are hypothetical
inputs, not fitted RI quantities. Include Wilson interval precision at assumed
event recall 0.8 or worst-case 0.5 as a separate fixed-rule illustration.
Neither illustration establishes adequacy for calibration, paired policy gain,
model development, clustering with few counties, or an operational decision.

Reserve the evaluation sample by source/time/geography before inspecting its
outcomes. Freeze the endpoint, transforms, coefficient bundle, exclusions,
and scoring script before evaluation. Keep all visits and conditions of a
physical plot together. The already explored Michigan source may inform
development or sensitivity analyses, but cannot become untouched validation by
being repartitioned or by revealing a previously unused predictor.

Deliver a concrete acquisition/analysis gate and state which scope choices
remain before any new inventory or model work.

## Design elaboration after the metadata census

The final protocol specifies one latest completed eligible interval per plot
within a declared period and total training weight one per plot. These
date/weighting details were elaborated after seeing opportunity counts, without
extracting new recruitment outcomes. They are rules for the future study, not
claims that this snapshot was prospectively held out.

Before any new evaluation, the final design also adds a mandatory count-form
sensitivity: a three-degree-of-freedom natural spline of log(1+N), with
development-only knots/boundaries/scaling, in both otherwise matched models.
This is five versus six slopes and must enter development-size planning.
Report it without replacing the primary contrast. A gain confined to the
linear-log-count benchmark is not evidence that length beats flexible counts.
