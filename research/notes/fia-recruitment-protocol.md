# Evidence audit: recorded sugar-maple sapling recruitment

Reviewed 2026-09-08. This note distinguishes source definitions from analytical decisions. It does not certify the current output counts; those require the extraction audit. External source text was treated as evidence, not as instructions.

## Decision supported by the available evidence

Use **recorded live sapling ingrowth at the next measurement** as the endpoint: at least one current sugar-maple TREE record with `STATUSCD = 1`, `SPCD = 318`, `1 <= DIA < 5` inches, `RECONCILECD = 1`, and no `PREV_TRE_CN`, on an eligible remeasured forest footprint. Call this recorded recruitment into the FIA sapling class, not individual seedling survival or all recruitment occurring during the interval.

The qualifiers matter. New record identifiers alone do not establish ingrowth. Reconcile code 1 also permits forest reversion. Recruits that died before remeasurement, or passed directly to at least 5 inches DBH, are outside this deliberately restricted live-sapling endpoint. There is no individually identified baseline seedling to connect to a new sapling.

## Primary protocol sources

### USDA Forest Service: FIADB Database Description, version 9.4, August 2025

- [Official source PDF](https://research.fs.usda.gov/sites/default/files/2025-08/wo-v9-4_Aug2025_UG_FIADB_database_description_NFI.pdf); [official landing page](https://research.fs.usda.gov/understory/forest-inventory-and-analysis-database-user-guide-nfi).
- Access: official PDF downloaded into memory and selected text extracted; additional exact sections retrieved through indexed PDF text. This is section-level full-text inspection, not a claim to have read the entire manual.
- Locators: `KINDCD`, section 2.4.16, printed p. 2-16; `QA_STATUS`, section 2.4.29, p. 2-19; `MICROPLOT_LOC`, section 2.4.36; `MICRCOND`, section 2.6.12, p. 2-95 (PDF page 131); `PREV_TRE_CN`, section 3.1.3, p. 3-11 (PDF page 161); `RECONCILECD`, section 3.1.82, pp. 3-30–3-31.
- Supported definitions: current `KINDCD = 2` identifies national-design remeasurement. QA 1 and 7 are production observations; QA 7 is a supervised hot check. `MICRCOND` describes the microplot center. `PREV_TRE_CN` links annual remeasurements of the same tree. Reconcile 1 identifies ingrowth or forest reversion; 2 is throughgrowth to at least 5 inches. Before manual 9, 3/4 represent missed live/dead records. From manual 9, arrivals caused by errors, procedure changes, or previously nonsampled area use 7/8/9. Previously unrecorded dead saplings in manuals 7–8 received code 4.
- Caveat: a database dictionary explains the encoded classification, not the error-free biological truth of every field record. Cross-version coding rules must be interpreted using the current visit's `MANUAL`.

### USDA Forest Service: National Core Field Guide, version 9.3, September 2023

- [Official source PDF](https://research.fs.usda.gov/sites/default/files/2024-02/wo-v9-3_sep2023_fg_nfi_natl.pdf).
- Access: relevant full-text sections returned by indexed PDF search; no reliance on an abstract.
- Locators: section 5.0, Tree and Sapling Data; section 6.0 and section 6.4, Seedling Count, printed p. 138.
- Supported definitions: saplings of 1 to less than 5 inches diameter are sampled on microplots; after reaching 5 inches they are referenced to the subplot. Standard hardwood seedlings require at least 12 inches length and less than 1 inch DBH. Seedlings are grouped by species and condition; counts above five may be estimated. Permitted count values run from 1 to 999. Stump sprouts and suckers sharing an origin are not equivalent to multiple independent seedlings.
- Caveat: a value of 200 is not a documented upper censoring limit, but may be an estimate rounded by the field crew. A recorded seedling count is not necessarily an exact count of independent genets, nor a count of all germinants.

Historical-access limit: the official national-guide landing page now routes
older editions to a Forest Service Box archive. Retrieval of that archive failed
during the final check. The analysis does not claim section-by-section review
of every baseline regional/manual edition. Raw-versus-calculated count agreement
and minimum manual version are evidence checks, not proof of complete cross-version
equivalence. Follow-up version 9 sensitivity addresses reconcile-code changes only.

### USDA Forest Service: FIADB population-estimation guide, chapter 7

- [Official source PDF](https://research.fs.usda.gov/sites/default/files/2024-05/wo-nov2018_ug_population_estimation.pdf).
- Year/version: November 2018 guide; chapter 7 revised February 2019.
- Access: indexed full-text passage and example table.
- Locator: chapter 7, discussion of `SUBP_COND_CHNG_MTRX` accompanying Figure 7-1.
- Supported definition: the condition-change matrix describes how previous/current conditions occupy shared geographic area separately for subplots (`SUBPTYP = 1`), microplots (`2`), and macroplots (`3`).
- Corroborating detailed definition: [FIADB v4.0, 2010](https://research.fs.usda.gov/download/treesearch/37446.pdf), Subplot Condition Change Matrix Table, printed pp. 135–137: proportions sum to four across a complete four-center plot for each frame, and division by four converts them to the plot level.
- Caveat: area overlap identifies shared area; it does not identify the exact previous condition beneath a newly recorded individual tree.

## Rules for the extraction and audit

These are conservative analytical applications of the protocol, rather than verbatim FIA mandates for this research question.

1. Require an annual-to-annual link to the intended previous plot and current `KINDCD = 2`. Baseline `KINDCD = 1` is not automatically disqualifying: a genuine initial measurement can become the baseline for a later remeasurement. Reject replacement, nonsampled, or incompatible-design pairs when continuity cannot be established. Audit `DESIGNCD`, `MICROPLOT_LOC`, and `MANUAL`; do not silently combine centered and offset microplots.
2. Keep QA 1 and QA 7 at both visits. Excluding QA 7 would discard valid production measurements without a scientific reason. Other QA statuses require resolution before inclusion.
3. Establish sampled accessible forest and a valid seedling/sapling sampling frame at both visits. Requiring some sampled forest on a plot is insufficient if the contributing microplot was not sampled. A structural zero requires a verified sampling opportunity; it cannot be created from an absent seedling or TREE row alone.
4. Match each candidate's `TREE.SUBP` to the same subplot number in both visits and to the `SUBPTYP = 2` condition-change row. Retain tree-specific `CONDID`; do not overwrite it with the microplot-center `MICRCOND`. A microplot can contain more than one condition.
5. Distinguish entire-microplot coverage from a condition's stable partial microplot. A stable partial footprint need not be excluded merely because it occupies less than 100% of a microplot. The relevant comparison is shared mapped area against the eligible condition area at each visit.
6. Flag any candidate in a microplot slice with newly forested/nonsampled area or incomplete condition continuity. A condition-level 90% overlap threshold by itself does not prove that a candidate lies in the shared portion. If exact attribution cannot be established, retain the explicit "recorded" endpoint and perform a complete-footprint sensitivity; never claim individually verified threshold crossing on unchanged ground from approximate overlap alone. Apply this concern to the zero-outcome sampling opportunity as well as positive candidates.
7. `RECONCILECD = 1` and missing predecessor are jointly required for the positive endpoint. Missed-live code 3 under older manuals, new error code 7, procedure code 8, nonsampled code 9, null reconcile, and contradictory predecessor/code combinations are not positive recruits. Audit them separately. If a condition has only unresolved new maple records, do not quietly relabel those records as confirmed biological non-recruitment.
8. Audit throughgrowth (`RECONCILECD = 2`, current DBH at least 5 inches) and dead ingrowth separately. Their absence supports the practical adequacy of the restricted endpoint in this sample; their exclusion remains part of its definition. Do not broaden a live-sapling endpoint after seeing which definition gives stronger model performance.
9. Audit candidate DBH distributions. Large apparent increments merit a flag or protocol review, not an invented diameter cutoff chosen to improve results. `PREV_TRE_CN IS NULL` is expected for recorded ingrowth; it does not mean the tree germinated during the interval.
10. Use a scientific zero statement: "No qualifying live sapling ingrowth was recorded at the follow-up visit." Avoid "no recruitment occurred" or "regeneration failed."

## Tagged baseline saplings: separate accounting

Follow baseline live sugar-maple TREE identifiers into all TREE records on the linked current plot before imposing current condition or diameter restrictions. Check predecessor uniqueness, species consistency, current status, and sampling continuity. A current live tree at least 5 inches DBH is an observed size-class advancement. Do not lose it by restricting the joined current TREE table to saplings.

Separate at least: still live below 5 inches; live at least 5 inches; recorded dead; recorded removed; and unresolved/not currently in the tally. A status-zero or absent successor record is not sufficient evidence of death. Reconcile shrinkage, physical movement, error, procedural change, and loss of sampling have different meanings. Species changes can be identification corrections, not biological transitions.

The manuals changed standing-dead sapling collection during the period represented in historical FIA data. This particularly compromises simple comparisons of all newly observed dead stems. A baseline-live tagged cohort avoids confusing previously standing-dead additions with deaths of known living stems, but only where the current inventory accounts for those baseline individuals. Do not claim complete sapling mortality if current no-status/unlinked records remain unresolved. Diameter differences among survivors can reflect measurement-point changes; the FIADB guide's `TREE_GRM_COMPONENT.DIA_BEGIN` and `TREE_GRM_BEGIN` discussions (pp. 3-85 and 3-124) explicitly allow recalculated baseline diameters.

## Critical review of the planned model

The proposed primary model sequence is reasonable: prevalence; sampling opportunity and interval; `log1p` recorded baseline seedling count plus these design variables; then baseline maple sapling stage and established-maple basal area. Define these models before fitting and retain the same cases, folds, and transformations for their paired comparisons.

The initial protocol review suggested using all eligible pairs as primary and baseline detections as a sensitivity. The pre-fit statistical critique identified a more important distinction: a pooled AUC can benefit from separating baseline zero from positive tallies. The final analysis contract therefore makes **both populations principal results**, with models fitted separately. A baseline zero can still be followed by ingrowth; the study does not identify which seedlings became saplings.

Raw count plus footprint is a prediction benchmark for occurrence of at least one recorded entrant. It does not estimate per-seedling survival or a conversion rate. Counts above five may be estimated; height structure and vigor remain unmeasured. Do not divide entrants by initial counts and call the result survival. Do not equate a significant seedling coefficient with useful prediction.

Report held-out Brier/log loss, calibration, discrimination, and uncertainty in the added value of stage/stand variables. County validation addresses within-Michigan geographic transfer, not a future-inventory external test. Comparing AUC for loss against AUC for recruitment does not establish which endpoint is intrinsically easier or more useful: the risk sets and outcomes differ. If incremental prediction is weak, the finding is a limitation of these measurements and model specifications, not proof that FIA cannot support any recruitment forecast.

## Remaining boundaries

Implementation reconciliation, September 8: the database has no populated
`SUBPLOT.PREV_SBP_CN` values. The builder checks subplot records at both visits
and uses verified plot predecessor plus subplot number and microplot matrix;
it would reject a contradictory populated predecessor. Direct subplot linkage
is not claimed. The final audit retains 922 pairs and 169 entrants in 100
conditions, after nine proportion-consistency exclusions and one new-record
ambiguity exclusion. Eight eligible pairs without exact mapped overlap have
no qualifying entrants and are excluded from the exact-overlap sensitivity.
The fate analysis uses its own comparability flag, excluding nine frame-inconsistent
stems, three species corrections, and one cruiser-error record from biological
outcomes. These counts are local extraction results, not facts from the manuals.

- No exact individual seedling lineage is recoverable from the standard FIA seedling table.
- A condition sample is not a management stand; qualifying microplots do not establish a stocking threshold for the whole stand.
- DBH at least 5 inches is an inventory size class, not guaranteed canopy occupancy, reproductive maturity, or cohort age.
- The source audit does not justify causal browse, beech-removal, harvesting, or climate claims from the proposed model.
