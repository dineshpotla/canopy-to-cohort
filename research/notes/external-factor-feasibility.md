# External factors: acquisition and feasibility audit

Audit date: 2026-09-10. Scope: obtain public sources, verify their measurement
meaning, and assess compatibility with the completed Michigan recruitment
cohort. No external-factor model was fitted. The core manuscript, fitted-model
object, and Word paper remain unchanged.

## Decision

Deer pressure is a defensible extension to investigate, but we do not yet have a
validated deer-exposure variable for the FIA cohort. Historical harvest data
are obtainable. Direct twig-browse data and a defensible geographic crosswalk
remain the important gaps. More columns alone will not strengthen the paper.

The next research question should be framed as a proposal, not a new result:
**Among conditions with recorded sugar-maple seedlings, does a pre-baseline
deer-pressure proxy improve out-of-county prediction of subsequent recorded
sapling recruitment beyond seedling counts?** Snow and stand context can be
prespecified competing explanations. This would remain an observational,
retrospective prediction study, not identification of a causal deer effect.

## What was actually obtained

| Source | Acquisition result | Compatibility with our cohort |
| --- | --- | --- |
| Michigan DNR harvest surveys | Eleven original reports, hunting seasons 2008–2018, downloaded through the Archives of Michigan | Historical years are available, but published geography is DMU, not county FIPS. No spatial join approved. |
| Henry and Walters northern-hardwood data | All three Dryad version-2 files downloaded; SHA-256 hashes match repository metadata | 141 stands, 423 stand-by-size-class rows, summer 2017 inventory. Broad regions only; no county, coordinates, or FIA crosswalk. Cannot join directly. |
| Existing FIA browse-impact field | Read from the local `PLOT_REGEN` table with a read-only connection | Available at baseline for 90 of 922 conditions, on 87 physical plots in 32 counties; only 14 recruitment-event conditions. |
| Farinosi and Walters twig browsing | Relevant study and measurement protocol identified | No public raw-data download located in the focused search. Availability must be confirmed with the investigators. No message sent. |

The source register records the exact archive item, download URL, original
filename, local copy, size, checksum, and verification time. Raw PDFs and
record-level source tables stay in ignored local data directories. The
[state archive](https://michigan.access.preservica.com/uncategorized/SO_9e2f796a-1dea-4390-be96-6b3d87ad0529/)
provides public access but asks researchers to contact it for permission to
publish its material. Do not redistribute the archived PDFs without resolving
that notice. The [Dryad data](https://doi.org/10.5061/dryad.612jm647z) are CC0.

The harvest transcription contains 1,012 DMU/year rows from 33 appendix pages.
Two extraction readers agree on the numerical values for 1,011 rows. The one
row omitted by the secondary reader (2012, page 55, DMU 069) was checked against
the rendered page and pinned to the source-file hash. Targeted rendered-page
checks also verified superscript alignment, the 2014 component differences,
and the 2016 map/footnote issue below. This is not a claim that every page of all
eleven reports received a full visual or substantive review.

## Historical harvest: useful, but not a direct browse measure

The reports provide DMU-level estimates of hunters, days hunted, antlerless deer,
antlered bucks, and combined harvest, each with a published 95% confidence
half-width. Preserve those quantities separately. Antlered bucks are the closest
published field to the seminar's male-harvest proxy, but are not literally all
male deer. The antlered/antlerless classification is defined by antlers.

Important constraints from the downloaded reports:

- DMUs include county units, subcounty units, and combined areas. A numeric join
  between DMU code and FIA county FIPS would be wrong. Names and boundaries must
  be harmonized by season, including special units and islands.
- In 2013, DMU 273 is printed as zero because its estimates were combined with
  DMU 073. Preserve the receiving unit; do not interpret this as an independently
  observed absence of harvest. See report 3585, Appendix B, printed page 55.
- The 2016 report retains the same combination footnote but also prints a
  nonzero DMU 273 row (876 total deer) and maps that unit. This inconsistency
  needs DNR clarification. Both the numbers and the footnote are retained and
  explicitly flagged; the note is not applied as an approved geographic merge.
- Some 2014 published combined totals differ from the two published components
  by more than one deer. The visual check confirms that these are source values.
  They are retained, with differences flagged; no total is silently replaced.
- Survey estimates exclude deer taken under Deer Management Assistance permits.
  Unknown harvest locations are allocated, and response-rate adjustments vary
  across surveys. Hunters visiting multiple DMUs cannot be added as unique
  people. The confidence half-width is not a standard error; covariance is not
  supplied for arbitrary aggregations or harvest/effort ratios.
- Harvest reflects regulations, hunting access, effort, and reporting as well as
  deer abundance. Harvest per land area and harvest per hunting day measure
  different things. Neither is a count of deer browsing the sampled FIA plot.

The sources for these checks are the original reports, including
[2013](https://michigan.access.preservica.com/uncategorized/IO_8979d49b-e1fa-4de0-adac-ee1e9ea1b33d/),
[2014](https://michigan.access.preservica.com/uncategorized/IO_1ab0b273-a3f3-47a7-a7f4-acdff1d85f51/), and
[2018](https://michigan.access.preservica.com/uncategorized/IO_a7d864d5-2a30-4cf9-8201-5e20c8b6b256/).
The contradictory 2016 entry is in
[report 3639](https://michigan.access.preservica.com/uncategorized/IO_31b52276-83ac-4f26-baec-2e43e986517b/),
pages 13 and 63. Annual code counts change from 100 in 2012 to 84 in 2013;
code-set changes are exported separately and are not assumed to exhaust all
boundary changes.
Current mandatory-reporting counts must not be spliced onto historical survey
estimates without a separate protocol audit.

### Calendar coverage

The cohort contains 922 eligible conditions on 903 physical plots in 66 Michigan
counties. Baseline visits span 2011–2018. For this availability audit, use the
three preceding completed hunting seasons; this is an explicit candidate window,
not a fitted or optimized choice. Because some seasons continue into January,
shift all January visits back one extra season. There are 36 such visits; none
occur in the cohort's 2011 baseline group. Consequently, required source seasons
still span 2008–2017. All 922 conditions have the necessary **report years**.

That is not 922 successfully matched deer exposures. Geographic harmonization
is still unapproved. Publication dates also matter: a report released after the
FIA visit can describe prior exposure but was not available for a real-time
prediction at that visit. Any later prediction analysis must label that
distinction and either respect release dates or remain explicitly retrospective.

## Public northern-hardwood data: an independent source, not extra FIA records

The Dryad inventory has 45 EUP, 48 WUP, and 48 NLP stands. Every stand has three
size-class rows. Predictors repeat across those rows; treating them as 423
independent sites would triple the sample incorrectly. There are no missing
cells in the released table.

`deer.use` is modeled winter pellet-transect occupancy, expressed as percent,
not a count of browsed twigs. It ranges from about 2.34% to 59.97% across the 141
stands. The publication describes prediction using pellet observations from
2017 and 2019 and climate/landscape information. It must not be treated as an
independent measured deer response when validating the same environmental
predictors used to construct it. The study's size classes also differ from FIA's
1–<5-inch sapling-entry outcome.
[Dataset and documentation](https://doi.org/10.5061/dryad.612jm647z);
[primary article](https://doi.org/10.1002/ecs2.4621).

A dictionary inconsistency is retained: `ord` is described as quality classes
1–4, while the units column says 1–3; the actual data contain 1, 2, 3, and 4.
Resolve this before using site quality. Without more geography and protocol
alignment, the dataset is useful for contextual or separate stand-level work,
not for validating our longitudinal FIA outcome or supplying county exposures.

## Twig-browse data and the seminar

The other project task, “Summarize seminar in detail,” retains the original
auto-caption output for [the seminar](https://www.youtube.com/watch?v=r0xqUvq1Q80).
Around minutes 35–39, Claudia discusses species-level browsed twigs from Mike
and Evan's northern-hardwood study, limited regional coverage, and male-harvest,
landscape, and snow proxies. Captions are not an independently released dataset.

The closest identifiable study is
[Farinosi and Walters (2023)](https://research.fs.usda.gov/treesearch/66283).
It describes 140 northern Michigan sites, experimental silviculture, and
species-specific available and browsed twigs on two-year-old growth of stems
50–137 cm tall, plus pellet surveys. This is a strong match to the seminar's
description, but the exact seminar analysis/version has not been confirmed.
The public 141-stand Dryad inventory is related work, not this raw twig table.
The [MSU study update](https://msu-prod.dotcmscloud.com/news/northern-hardwood-study-collaboration-with-msu-and-mdnr-extended)
also documents collection and analysis of browsing data. A request draft is
saved separately and has not been sent.

Existing FIA `BROWSE_IMPACT` is a plot-level impact score, not species-specific
twig damage. Baseline codes are 1: one condition; 2: 55; 3: 32; 4: two; missing:
832. All 90 observed baseline scores coincide with valid baseline RI availability.
Follow-up scores exist for 88 conditions but cannot be used as baseline
predictors. Low event support and possible dependence of impact scoring on
regeneration abundance/structure limit its use as independent causal evidence.

## Other environmental data

These products were checked for documented access and temporal suitability;
no new rasters or climate extracts were downloaded in this audit:

- [SNODAS](https://nsidc.org/data/g02158/versions/1): daily 1-km modeled snow
  properties from September 2003 onward. Historical coverage includes our
  candidate windows. Snow depth can affect both deer behavior and seedlings
  directly, so it is not a deer-only mechanism variable.
- [Daymet](https://daymet.ornl.gov/getdata): public climate access. The project
  already has 1991–2020 summaries at Census county internal points. Those are
  not plot measurements or visit-specific drought exposure. New exposure
  windows and extraction support would need to be defined separately.
- [Annual NLCD](https://www.usgs.gov/centers/eros/science/annual-national-land-cover-database):
  historical land-cover products are available. Use a pre-baseline year, not
  the latest map, and do not imply precise plot-buffer exposure from a county
  point or public displaced FIA coordinates.

[Harris, Pastore, and D'Amato (2025)](https://research.fs.usda.gov/treesearch/69473)
provide a relevant precedent for harvest, snow, and land-cover proxies, not
proof that the same effects occur in our Michigan cohort. Before downloading
additional products, resolve the geographic support and use a small,
prespecified predictor set with county-held-out evaluation.

The local cohort already has nonmissing baseline beech-sapling basal area,
overstory basal area, stand age, site class, and physiographic class for all 922
conditions. These are availability findings, not newly estimated effects.
Disturbance/treatment year fields have structural missingness when no such
event was recorded; missing years are not silently filled with zero.

## Reproduction and handoff

1. Source URLs and checksums: `outputs/audits/recruitment-external-sources.csv`.
   Raw files are under `data/raw/external/`.
2. Run the bundled Python on `scripts/24_audit_external_sources.py` to audit
   saved sources. The optional `--import-downloads DIRECTORY` copies the exact
   browser filenames into the raw store, refusing different existing bytes.
3. Run `Rscript scripts/25_audit_external_factor_coverage.R` for local
   browse support, pre-baseline season requirements, and existing-field
   availability. Outputs have the `recruitment-external-` prefix.
4. The extracted DMU table and source text are in `data/interim/external/`.
   They are working transcriptions, not registered model inputs. PDF page
   numbers, units, footnotes, missingness, and unresolved comparisons remain
   visible. Tests exercise calendar boundaries, strict joins, missing values,
   source immutability, and PDF extraction edge cases.

Next decision: approve a historical DMU-to-county crosswalk and exposure
definition, or pursue investigator access for direct browsing data. Do not
rewrite the core paper's findings as evidence of a deer effect at this stage.
