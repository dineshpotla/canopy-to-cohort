# Submission readiness review

Reviewed September 10, 2026. Scope: focused primary-source comparison,
computational cross-check, manuscript revision, and submission preparation.
This is an AI-assisted project review, not independent peer review or author
approval. No external data were joined, no new explanatory model was selected,
and nothing was submitted or published.

## Decision

Keep the core Michigan paper. Its contribution is an explicit comparison of
ordinary seedling counts and existing maple stages on matched held-out cases,
with audited interpretation of recorded entry and tagged-stem fates. It is a
regional inventory benchmark and measurement study. Whether that contribution
is sufficient for a particular journal remains an editorial and scientific
judgment, not something passing tests can establish.

The result is not a deer mechanism, regeneration-failure rate, or useful
management rule. Additional environmental data remain a separate proposal;
they are not a requirement for this bounded paper.

## Closest literature and revised positioning

[Harris et al. 2022](https://doi.org/10.1016/j.ecolind.2022.109654) is the direct
precedent. The primary full-text methods and Table 1 already include
conspecific stages. The introduction now acknowledges that overlap rather
than implying novelty from those variables. Its study population and model
evaluation differ from ours, so cross-paper AUC comparisons cannot establish
superiority. Access: USDA PDF, sections 2.1–2.5, Tables 1–3, and discussion.

[Harris et al. 2026](https://doi.org/10.1002/eap.70288) supplies regional
context, not independent Michigan validation. Access: USDA abstract and
publisher-indexed methods/results excerpts; complete new full-text review not
claimed. [The 2026 disturbance study](https://doi.org/10.1111/1365-2664.70522)
addresses a longer post-disturbance period. Its methods identify the 14.3-year
interval as a median; the evidence note is corrected accordingly.

The earlier Henry studies continue to motivate the Michigan question and the
distinction between diameter and cohort age. Their managed-stand findings
are not transported as rates for our FIA sample. This is a focused closest-work
check, not a systematic review or proof that no overlapping study exists.

## Statistical review and changes

- The response identifies recorded surviving entrants, not individual seedling
  conversion. Tagged sapling fates cannot explain the fate of untagged seedlings.
  This distinction is now explicit in the limitations.
- The two populations are nested. County folds keep plots/counties separated,
  but adjacent counties need not be spatially or environmentally independent.
- Realized interval remains a follow-up quantity. This is a retrospective,
  variable-duration assessment, not a deployed baseline forecast.
- The added-stage intervals span zero. No equivalence margin was set, and the
  models do not test all nonlinear relationships or interactions. The paper now
  separates these findings from the literature on seedling height distributions.
- The fixed 300-draw percentile intervals have limited Monte Carlo precision.
  Fold assignment and model choices remain fixed; no multiplicity correction
  was applied. These limits are stated rather than disguised by extra digits.

`R/recruitment_submission.R` provides a second computational implementation:
base-R training-only scaling, a BFGS optimizer for the declared ridge objective,
and rank-based AUC. It does not call the production scaler, design builder,
optimizer, or metric functions. It checks all 40 county-held-out fits and eight
temporal fits against saved predictions, plus 16 metric comparisons. It uses
the existing selected rows and splits; it is not an independent data extraction
or scientific replication. It does not recompute bootstrap intervals.

The executable record is
`outputs/audits/recruitment-submission-checks.json`. The existing manuscript
reconciliation and complete R test suite are rerun separately. Test counts,
artifact checksums, and final render status are recorded in `status.json`.

## Journal candidate

**Forest Science, Original Research Article, is a provisional candidate**, based
on the fit between an inventory-measurement study and its forestry remit.
This is our fit assessment, not an editorial invitation. The author has not
selected a journal. A Brief Communication would require substantial shortening.

The [official author guide](https://academic.oup.com/FORESTSCIENCE/pages/General_Instructions),
checked September 10, specifies a 7,000-word main text, 200-word abstract,
100-word Study Implications section, and 15-word title for original research.
It calls for double spacing, continuous line numbers, anonymous review text,
separate table/figure files, and a Literature Cited section. AI assistance
must be disclosed in the manuscript and cover letter. The guide contains
conflicting unit advice; confirm the metric requirement in its article-format
section before conversion. The current Word file is for coauthor review with
embedded tables and comments, not a journal-formatted upload.

The title, abstract, and new Study Implications section are prepared for those
length limits. Final unit conversion, bibliography formatting, anonymization,
line numbering, and separate illustration files await journal selection.

## What must happen before submission

| Item | Current status | What resolves it |
|---|---|---|
| Numerical reconciliation and second-implementation checks | Completed locally; evidence recorded with this revision | Review results and retain the exact version |
| Domain and statistical author sign-off | Not obtained | Human reviewers accept the endpoint, design, uncertainty, and contribution |
| Author list and declarations | Not supplied for this manuscript | Confirm order, affiliations, corresponding author, contributions, funding, conflicts, and full AI disclosure |
| Journal and final packaging | Candidate only | Author selects venue; apply its current submission requirements |
| Versioned data and code availability | Draft statement added; immutable recruitment release absent | Approve release contents and snapshot-access arrangement; archive and insert persistent identifier |
| Submission approval | Not obtained | All authors approve the final manuscript and associated files |

The previous software citation metadata does not establish a public release
of the revised recruitment analysis. See the
[reproducibility handoff](../../../docs/recruitment-reproducibility.md) for the
exact local workflow and release requirements. Do not publish raw third-party
deer PDFs, personal task history, or record-level files as an automatic side
effect of manuscript preparation.

## Document revision record

The canonical Quarto manuscript now has a shorter abstract, Study Implications,
clearer closest-study comparison, expanded statistical/endpoint limitations,
an AI-assistance disclosure, and a snapshot-specific availability statement.
Four Word comments mark the contribution, uncertainty, disclosure, and archive
items for human review. Core point estimates and fitted-model artifacts are
unchanged. The previous manuscript and Word copy are preserved locally under
`outputs/paper/before-submission-review-oFJqzB/`.

Before the analytical-detail expansion, local verification passed 474 R test expectations, 15 Python test cases,
43 manuscript evidence checks, 48 second-implementation fits, and 16 metric
comparisons. The maximum prediction discrepancy was 0.00000211 against a
0.00001 tolerance. All 13 Word pages were visually checked; the document
contains seven editable tables, two figures with alternative text, two native
editable equations, and four anchored review comments. The original source
archive checksum was rechecked, and the core model, cohort, and fate-file
checksums are unchanged. This revision did not rerun the full research pipeline
or bootstrap intervals and is not a clean-environment reproduction.

## Analytical detail expansion

The subsequent [analytical-detail revision](analytics-detail-review.md) responds
to the user's concern that the paper underreported the completed analysis.
It expands methods and results and adds an analytical appendix, bringing
coefficients, calibration, uncertainty, fold support, sensitivity comparisons,
joint strata, and all six primary survey strategies into the Word manuscript.
The current document has sixteen tables and six review comments. The R suite
now passes 480 expectations and the manuscript audit passes 50 checks; current
Word tests, page review, and artifact checksums are recorded in `status.json`.
The core results and the remaining submission requirements are unchanged.
