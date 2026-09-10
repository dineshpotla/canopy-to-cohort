# Retrospective survey-priority comparison

Extension declared after the first recruitment results, before calculating these
policy comparisons. The continuation request was "goahead". The existing cohort,
outcomes, and model results are already explored; this is not preregistration.
No fieldwork, external data acquisition, publication, or operational deployment
is included.

## Decision proxy and population

The primary diagnostic asks whether a limited follow-up assessment could be
concentrated among **conditions with baseline seedlings but no new live sapling
recorded at the next inventory**. The target is `1 - outcome_recruitment` among
the 672 eligible baseline-detected conditions. This is a record-based proxy,
not independently observed survey need, inadequate stocking, mortality, or a
treatment benefit. A higher yield of this proxy does not prove greater value
of surveying those sites.

Report all 922 eligible conditions as context, where baseline zeros can make
the proxy easier to locate. Also report the opposite objective—locating
conditions with recorded entry—so the chosen direction is not mistaken for
a general management objective. The target and preferred score direction
must always be explicit.

## Fixed comparisons

Compare six strategies without outcome-driven thresholds or fitting new
predictors:

1. Random selection expectation at the same capacity.
2. Baseline raw seedling count.
3. Baseline raw count divided by sampled microplot condition coverage.
4. Baseline maple sapling presence.
5. Existing count + coverage + interval model.
6. Existing maple-stage model.

Lower counts/density/sapling presence and lower predicted recruitment get
higher priority for the no-entry proxy. Reverse direction for recorded entry.
The main capacity is `floor(n * 0.25)` condition intervals, with fixed 10% and
50% sensitivity capacities. These are illustrative condition counts, not
actual survey budgets, costs, or a recommendation to survey 25% of forests.
Report distinct physical plots selected by the deterministic rule; multiple
conditions may share a visit, and travel/access costs are unknown.

## Ties, performance, and uncertainty

Use expected target capture under uniform random selection within the cutoff
tie as the primary comparison, especially for coarse count/presence rules.
Also export deterministic capture using the existing stable source-key order,
the full attainable tie range, and the amount of cutoff-tied mass. Do not
pick a favorable ordering after looking at outcomes. Random expectation is
analytic, not a single lucky random sample.

Report selected target fraction, target capture fraction, expected target count,
non-target count, and improvement over random. Compare model minus raw-count
yield and stage minus count-model yield at matched capacity. State target
prevalence; a common no-entry outcome permits high yield even without prediction.

For county-held-out comparisons, reuse the original outcome-independent county
folds. Bootstrap 300 whole-county resamples per population and repeat training
scaling and model fitting. Recompute tie expectations and policy comparisons
inside each resample. No fold redraw, policy selection, or tuning is permitted.
Report successful/failed resamples. Intervals remain exploratory and conditional
on the declared cohort, model set, policies, and original fold partition.

Reassess the fixed policies on the existing 2023-onward temporal test conditions,
using only models fitted to earlier follow-ups. Report that single split without
claiming untouched external assessment or adding unsupported precision.

## Forecast-time feasibility

Existing predictions use the realized remeasurement interval. In a separate
sensitivity, score all held-out cases at a common seven-year interval while
retaining actual training intervals. Seven years approximates this inventory's
observed median and is declared here, not tuned to improve policy capture.
The observed outcomes still span different durations: this is a ranking
sensitivity, not validation of seven-year event probabilities. Report the same
sensitivity on the temporal test sample. No actual field schedule is assumed.

## Interpretation and stopping rule

Do not compute a clinical-style net-benefit curve with invented forest survey
utilities or imply that AUC establishes decision value. The general distinction
between prediction accuracy and decision consequences is supported by Vickers
and Elkin (2006), DOI 10.1177/0272989X06295361; its clinical application does not
validate the present ecological proxy.

If fitted models fail to improve on a simple rule, retain that result. If they
do improve, require an independently measured survey objective and relevant
validation before claiming usefulness. Do not turn no-entry targeting into
a treatment prescription or keep adding predictors to make the model win.

The next real validation must define the decision owner, measurement and travel
costs, an independently assessed regeneration criterion, and an evaluation
sample that was not used to choose the strategies. Exact FIA plot locations
remain out of scope.
