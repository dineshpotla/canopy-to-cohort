# Survey-priority evidence and limitations

Reviewed 2026-09-08. This note records sources and interpretation for the
retrospective capacity comparison, not a survey recommendation.

## Decision value is not discrimination

Andrew J. Vickers and Elena B. Elkin (2006), **Decision Curve Analysis: A Novel
Method for Evaluating Prediction Models**, Medical Decision Making 26(6):565–574.
[Original publication](https://doi.org/10.1177/0272989X06295361).

Access: publisher metadata and abstract returned by indexed search. Direct
publisher retrieval timed out; the attempted PMC page presented a browser
check. No full-text reading is claimed for this source in this extension.

The paper distinguishes accuracy from decision consequences and derives a
net-benefit comparison using threshold probabilities that encode relative
error consequences. This supports requiring a decision objective before
claiming practical value. It does not provide forestry costs, stocking
criteria, survey priorities, or evidence that the Michigan model is useful.
The present analysis therefore compares capture at a fixed illustrative
capacity and does not invent a net-benefit threshold.

## Height measurements as a candidate next information source

Lucas B. Harris, Christopher W. Woodall, and Anthony W. D'Amato (2022),
**Increasing the utility of tree regeneration inventories: Linking seedling
abundance to sapling recruitment**, Ecological Indicators 145:109654.
[USDA primary record](https://research.fs.usda.gov/treesearch/67377),
[DOI](https://doi.org/10.1016/j.ecolind.2022.109654).

Access in this extension: complete official USDA abstract and publication
metadata. The preceding literature review also inspected full-paper methods,
as recorded in `seedling-recruitment-literature.md`.

The paper compares one-class and six-height-class inventories for five
species, finding better recruitment models with height information and
particular importance of taller seedlings. It motivates a comparison of
additional measurements, not an arbitrary search for more stand covariates.
It does not prove Michigan survey value, establish a universal stocking
threshold, or turn height into the FIA one-inch diameter boundary.

## Local evidence

The primary comparison uses 672 baseline-detected intervals and their
county-held-out predictions. No-entry prevalence is 572/672 = 85.1%, giving
143 expected no-entry conditions under random selection of 168. Low raw counts
yield 162 expected such conditions; the count model yields 160 and the stage
model 163. Stage minus raw-count yield is +0.60 percentage points with a 95%
full-refit county-bootstrap interval of −3.66 to +2.28 percentage points.
It is not evidence of equivalence, superiority, or a treatment benefit.

The comparison uses uniform expectation over ties. Raw-count capture can range
from 160 to 163 at the cutoff; the expected value is 162. At 50% capacity raw
counts yield 319.23 expected no-entry conditions versus 315 for either model.
In the later-year test, raw counts yield 65.18 versus 65 for either model.
The common seven-year scoring sensitivity gives slightly different rankings;
the actual observed outcome intervals remain variable.

These numbers resolve to `outputs/tables/recruitment-survey-*.csv`. Uncertainty
refits the models and recalculates tied capture, but does not include the choice
of decision proxy, policies, model set, or fold partition. No-entry is not an
independent measure of survey need. No future survey, external validation,
cost assessment, causal effect, or model deployment has been completed.

## Local RI availability screen

Script `scripts/17_audit_regeneration_indicator.R` opens the pinned Michigan
SQLite snapshot read-only. Of the 922 recruitment-eligible intervals, 90 have
RI plot records at both visits, on 87 physical plots in 32 counties. These
intervals contain 14 recruit-bearing conditions; 71 also have standard baseline
seedling detections. Baseline maple RI condition records are present in 81
intervals. Aggregate support is recorded in
`outputs/tables/recruitment-survey-ri-coverage.csv`, with calendar, sampling-status,
and length/source-class inventories in the other `recruitment-survey-ri-*.csv`
files. The latter inventories describe the source tables, not an audited cohort.

This is a record-presence screen only. Historical code definitions, baseline
sampling opportunity, comparable condition coverage, and valid RI zeros remain
unaudited. The 14-event overlap does not establish sufficient precision for a
multi-height prediction model. These are already explored Michigan outcomes,
not a separate validation sample. The next milestone is therefore a protocol
and sampling-frame audit with a support/precision gate before any height model.
