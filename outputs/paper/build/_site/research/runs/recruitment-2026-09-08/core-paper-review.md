# Core paper completion review

Date: September 9, 2026. Review type: lead-agent numerical, source, and manuscript
review, not independent peer review or author sign-off.

## Research outcome

The three bounded core questions are answered. Ordinary counts improve pooled
recorded-entry prediction beyond observation design; their within-detection
Brier improvement is uncertain. Added maple stages show small, uncertain
increments over the count benchmark. Linked tagged-stem fates distinguish
recorded death, live saplings, and surviving growth beyond the size-class boundary.
These results support completing the Michigan paper without a new regional
inventory, height-model search, or management claim.

## Evidence and claim checks

| Manuscript claim | Reconciled evidence | Interpretation limit |
|---|---|---|
| 922 intervals on 903 plots in 66 counties; 169 entrants in 100 conditions | Rebuilt endpoint, cohort flow, and paper support | Selected, unweighted Michigan sample |
| Baseline 2011–2018 and follow-up 2018–2025; median interval 7 years | Paper support derived from eligible records | Realized variable duration, not a seven-year forecast |
| Count-model AUC 0.796 overall and 0.699 within baseline detections | Recomputed from the stored county-held-out predictions | Within-detection discrimination is the harder comparison |
| Added-stage Brier differences approximately −0.0016 | Identical-case contrasts and full-refit percentile intervals | Both intervals cross zero; not an equivalence finding |
| Only 72 of 280 high-count conditions have entry | Count-stratum numerators and denominators | The complement is not a regeneration-failure estimate |
| 1,580 comparable fates comprise 334 dead, 1,188 live saplings, and 58 larger survivors | Linked-stem records and fate accounting | Neither causes of death nor canopy recruitment established |
| Small survey-priority point gain is uncertain | Fixed-capacity, tie-neutral, full-refit comparisons and temporal assessment | No-entry is not independently measured survey need |
| RI length association is descriptive | 90 intervals, 14 events, and matched-count reconciliation | Only four later-year events; no height model fitted |

The dedicated paper audit performs 43 checks, including recalculation of
probability, rank, calibration, and capacity metrics; source-to-model row and
outcome agreement; original convergence; county/plot fold separation; temporal
separation; all paired differences; bootstrap completion; and linked-fate/growth
accounting. The full test suite additionally tests leakage, scaling, endpoint
eligibility, reconciliation, and the calculation primitives. Automated checks
support reproducibility, not independent scientific validation.

## Literature and source use

The framing was checked against primary publisher or Forest Service records
for Henry et al. (2021), Henry and Walters (2023), Harris et al. (2022), and
Harris et al. (2026). Their abstracts and bibliographic records support the
limited claims retained: small versus larger regeneration, diameter versus
cohort age, previous recruitment prediction using height classes, and contrasts
between small-seedling composition and established sapling abundance. A complete
new full-text systematic review is not claimed. Existing literature and protocol
notes preserve access limitations; stand-study rates are not imported into the
Michigan FIA cohort. The manuscript does not claim invention of FIA recruitment
prediction or validated operational usefulness.

Historical core/manual screening and RI annual-guide access remain qualified.
Unrecovered RI supplements concern the secondary length audit, not a hidden
height model. No regional source, sample-size result, or fitted model is invented
to fill the failed archive acquisition.

## Manuscript changes

The canonical source now has an abstract, three explicit objectives, methods,
core and secondary results, discussion, limitations, conclusion, and reproducible
evidence links. It distinguishes equal-condition scoring from the different
plot-balanced future length protocol, and joint calibration diagnostics from
calibration-in-the-large. The detection pilot is preserved separately. Project
pages now label regional and operational work as optional extensions.

An editable Word copy is generated from the same Quarto source. Repository-only
links become plain labels in the standalone Word copy; web and citation links
remain. The web paper retains working evidence downloads. Word formatting is
reproduced by `scripts/22_format_recruitment_docx.py`; page-image QA is kept local.
Exact test counts, render checks, and final artifact status are recorded in
`status.json` after verification.

Author names, affiliations, funding, conflicts, journal requirements, and a
submission decision require author input; none is fabricated. This completion
is a local research manuscript, not publication or peer-review acceptance.
