# RI measurement audit review

Reviewed 2026-09-09 by the lead agent. This is a source, measurement, and
feasibility audit under the [declared contract](ri-contract.md), not independent
peer review, external validation, or native HyperResearch harness execution.
The pre-existing recruitment endpoint and model results are unchanged.

## Critique and disposition

| Risk | Disposition |
|---|---|
| An RI plot row can be mistaken for a sampled condition. | Require code-1 RI coverage for every contributing positive-area microplot-condition slice, compatible core sampling, matching subplot keys, and reconstructed area. Check baseline and follow-up separately. |
| Retired or contradictory status codes can create false exclusions or zeros. | A blank retired subplot status is compatible with an explicit valid microplot status. Reject missing/ambiguous microplot status, contradictory populated legacy status, and nonsampling reasons. |
| Missing or invalid tallies can be silently converted to zero. | Validate species, maple source codes, lengths, integer counts, and condition/subplot-condition foreign keys. Duplicate keys stop the audit; invalid records make the plot's RI unavailable. Zero-fill absent maple records only after frame and record checks. |
| Current dictionary definitions can be projected onto every historical field year. | Record separate annual-guide coverage. Relevant 2016-2018 sections were inspected; the archived 2016 copy is DRAFT. Individual 2012-2015 supplements remain an access gap. Do not certify every historical protocol. |
| A plot date might not be the actual RI observation date. | Use May-September only as a date-plausibility screen. Do not infer out-of-season RI collection from a plot date alone. |
| Requiring follow-up RI can unnecessarily shrink a baseline-predictor cohort. | Retain the 90 valid baseline intervals. Report the 86 both-visit subset separately; four follow-up RI flags do not change the audited TREE endpoint. |
| Comparing different size definitions can manufacture information gain. | Compare ordinary counts with RI classes 3-6 on identical units. Keep smaller classes and all-size totals separate. |
| Exact count agreement may be presented as independent validation. | Report numerical redundancy only. A shared or derived tally mechanism is plausible but was not established by inspecting database-generation code. |
| A strong descriptive height association may be mistaken for added forecasting value. | Fix the at-least-five-foot grouping before tabulation, report the ordinary-detected subset, and explicitly retain count/interval/site confounding. Fit no height model. |
| Four assessment events can produce impressive but unstable validation scores. | Report event support and a clearly hypothetical precision reference. Treat the already explored later-year partition as a feasibility screen, not an untouched test set. |
| A familiar ecological hypothesis may be called novel. | Acknowledge Harris et al. (2022)'s regional height-class prediction precedent. A future contribution must be a useful, credible comparison, not height-class use alone. |

## Numerical claim map

Paths are relative to the repository root. These figures are local calculations,
not findings imported from the literature or survey-weighted Michigan estimates.

| Claim | Evidence |
|---|---|
| Baseline RI available: 90 intervals, 87 physical plots, 32 counties, 14 recruit-bearing conditions/event plots, 30 recorded new saplings | `outputs/tables/recruitment-ri-eligibility.csv` |
| Ordinary-detected RI subset: 71 intervals and all 14 events | Same eligibility table |
| Annual-guide-inspected 2016-2018 subset: 37 intervals and four events, with the 2016 draft qualification | Eligibility and `recruitment-ri-calendar.csv`; protocol evidence note |
| No RI baseline plot record for 832 of the 922 eligible intervals | `outputs/tables/recruitment-ri-visit-status.csv` |
| Both-visit RI subset: 86 intervals and 13 events; two follow-up frame flags and two date flags | Eligibility and visit-status tables |
| Ordinary count equals RI classes 3-6 in all 90 conditions and all 311 microplot-condition intervals; both totals 2,658 | `outputs/tables/recruitment-ri-count-reconciliation.csv` |
| All-size RI total 9,489, including four tallied stump-source seedlings | Same reconciliation table; these are recorded counts, not independent-genet counts |
| Nine verified all-size RI tally zeros; ten further conditions have RI maple only below one foot | `outputs/tables/recruitment-ri-zero-accounting.csv` |
| At least five feet present: 13 events/44 conditions; not recorded: one/46 | `outputs/tables/recruitment-ri-height-support.csv` |
| Descriptive event fractions 29.5% (95% county-bootstrap interval 18.9%-42.9%) versus 2.2% (0%-8.5%) | Same height-support table; no adjustment or forecast validation |
| Within ordinary-detected conditions, the shorter-only comparison is one event/27 conditions | Same height-support table; not a matched or adjusted comparison with abundance |
| Possible development/assessment support: 53/37 intervals and ten/four events, without shared physical plots | `outputs/tables/recruitment-ri-split-support.csv` and split implementation |
| Hypothetical perfect recall of 14 independent event plots has a two-sided exact 95% lower bound of 76.8% | `outputs/tables/recruitment-ri-precision-reference.csv`; not actual recall or a power justification |

## Source and software checks

The [protocol evidence note](../../notes/ri-protocol-evidence.md) provides exact
source access, page locators, document hashes, status-wording inconsistencies,
and the historical-access and draft qualifications. Relevant official PDF
tables were read and visually inspected. Browse-impact construction and shared
count information are not promoted into independent causal evidence.

`make ri-audit` completes without R warnings and fits no new model. `make test`
passes 356 expectations with zero failures, warnings, or skips. Tests include
invalid status/source/species/count/key/area cases, unavailable versus valid-zero
measurements, follow-up independence, and exported numerical reconciliation.
These checks reproduce defined calculations; they do not certify biology or
establish operational usefulness. The final rendering and local-link check
are recorded in [run status](status.json).

## Decision

Complete the local baseline measurement milestone with the source qualifications.
Retain length structure as a specific added-information hypothesis, not a
validated rule. A separate, adequately supported same-sample count-versus-length
comparison and a meaningful decision target are required before forecasting or
survey-tool claims. No additional inventory acquisition, field coordination,
model fitting, commit, or publication occurred in this audit.
