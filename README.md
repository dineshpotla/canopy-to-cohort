# Canopy to Cohort

[![Live research report](https://img.shields.io/badge/live-research_report-285943)](https://dineshpotla.github.io/canopy-to-cohort/report/)
[![R data-free unit tests](https://github.com/dineshpotla/canopy-to-cohort/actions/workflows/r-unit-tests.yml/badge.svg)](https://github.com/dineshpotla/canopy-to-cohort/actions/workflows/r-unit-tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-8B1E3F.svg)](LICENSE)

**Tracing established trees, saplings, and seedlings in Michigan northern hardwood forests using FIA, Daymet, GIS, and statistical modeling**

**[Explore the live research report →](https://dineshpotla.github.io/canopy-to-cohort/report/)**

This is one research-style portfolio project built around a clear ecological question:

> Among seedling-sampled northern-hardwood conditions with established sugar maple, which stand, cohort, management, and broad climate characteristics are associated with a zero sugar-maple seedling tally?

## 60-second technical tour

| Capability | What is implemented | Evidence |
|---|---|---|
| Large relational data | Schema-aware extraction from Michigan's approximately 5.4 GB expanded FIADB SQLite database | [`R/fia_extract.R`](R/fia_extract.R), [`scripts/01_inspect_fia.R`](scripts/01_inspect_fia.R) |
| Data quality | Key assertions, pre-aggregation before joins, sampling-opportunity logic, provenance hashes, and hand-check samples | [`R/validation.R`](R/validation.R), [`tests/testthat/`](tests/testthat/) |
| Statistical modeling | Size-class-aware county mixed-effects logistic regression, candidate-form comparison, diagnostics, robust inference, and county-grouped cross-validation | [`R/models.R`](R/models.R), [model results](https://dineshpotla.github.io/canopy-to-cohort/report/#adjusted-associations) |
| Spatial integration | County-level FIA geography joined to 1991–2020 Daymet climate normals without using or inferring plot coordinates | [`R/climate.R`](R/climate.R), [spatial results](https://dineshpotla.github.io/canopy-to-cohort/report/#broad-geographic-pattern) |
| Research communication | A manuscript-style Quarto report, decision log, analytical data dictionary, figures, and automated tests | [live report](https://dineshpotla.github.io/canopy-to-cohort/report/), [data dictionary](https://dineshpotla.github.io/canopy-to-cohort/docs/data-dictionary.html) |

## Why this project

The repository demonstrates:

- relational FIA data engineering;
- explicit join and data-integrity audits;
- R and reproducible research workflows;
- spatially responsible handling of confidential FIA locations;
- interpretable ecological modeling;
- publication-quality figures and research communication.

It is intentionally not a machine-learning leaderboard or dashboard.

**Technical stack:** R, DBI/RSQLite, dplyr, tidyr, ggplot2, lme4,
broom.mixed, DHARMa, Quarto, testthat, and renv.

## Analysis architecture

```mermaid
flowchart LR
    A["Official FIA SQLite<br/>~5.4 GB expanded"] --> B["Schema and evaluation audit"]
    C["Daymet + Census<br/>1991–2020"] --> D["County climate proxy"]
    B --> E["Plot-condition cohort<br/>PLT_CN + CONDID"]
    D --> E
    E --> F["Exploratory gap screen<br/>established-tree share"]
    E --> G["Tree → sapling → seedling model<br/>county effects"]
    F --> H["Sensitivity, figures, and maps"]
    G --> H
    H --> I["Quarto research report"]
```

![Established sugar maple versus observed regeneration](outputs/figures/03_regeneration_quadrant.png)

## Main findings

Release v1.3.0 pins the Michigan 2025 current evaluation (EVALID 262501;
inventory window 2019–2025; assigned measurement records 2018–2025). It yielded
1,457 plot-condition measurements in FIA's maple/beech/birch forest-type group,
used here as the operational northern-hardwood cohort, across 78 counties. Of 1,424
conditions with demonstrated microplot sampling, sugar-maple seedlings were
tallied in 815 (57.2%). The descriptive screen uses established-tree basal-area
share (DBH ≥ 5 inches) and flagged 131 observations (9.2%); an upper-quartile
sensitivity rule flagged 102 (7.2%). The screen is separate from model-cohort
selection and is not treated as a validated ecological index.

Tree records are expanded with the FIA condition proportion for their actual
sampling frame (microplot, subplot, or applicable macroplot). The resulting
condition basal area reproduces FIA `COND.BALIVE` with MAE 0.00013 ft²/acre
and maximum absolute error 0.00070 ft²/acre across all 1,457 conditions.

The primary model restricts inference to 1,072 sampled conditions with at least
one live sugar-maple TREE record at DBH ≥ 5 inches. It separates established-tree
basal area from sugar-maple sapling presence (DBH 1–4.9 inches). Raw seedling
non-detection was 45.7% without saplings and 18.1% with them. In the adjusted
county random-intercept model, sapling presence had OR 0.33 (95% CI 0.24–0.45),
while established-tree basal area alone had OR 0.90 (95% CI 0.75–1.08). Ten-fold
validation holds out entire counties (Brier score 0.177; ROC AUC 0.749;
calibration slope 0.889). A full-cohort nonlinear curve is retained only to show
why mixing FIA tree size classes changes the scientific interpretation.

![Adjusted model associations](outputs/figures/04_model_effects.png)

## Data and scientific scope

- **FIA:** Michigan state SQLite database from the USDA Forest Service FIA DataMart.
- **Climate:** 1991–2020 Daymet temperature and precipitation normals at an interior representative location for each county.
- **Geography:** FIA county identifiers, Census Gazetteer county internal points, and
  `maps` package county polygons.
- **Unit:** one plot-condition measurement (`PLT_CN + CONDID`).
- **Primary response:** whether sugar-maple seedlings were tallied on sampled microplots.

Exact FIA plot locations are confidential. Public FIA coordinates may be
approximate; this analysis neither uses nor infers them. County identifiers
alone support the climate join and maps, and county climate remains a broad proxy.

## Outputs

After `make all`, the project produces:

1. a study-area sample map;
2. a live-tree composition figure;
3. an established-maple versus regeneration hero figure;
4. a primary sapling-continuity profile plus a clearly labeled full-cohort baseline;
5. a supported broad-area gap map and county uncertainty plot;
6. a Quarto project website and research report under `_site/`;
7. join, missingness, provenance, source-snapshot, and model-support audits.

The [live rendered report](https://dineshpotla.github.io/canopy-to-cohort/report/)
is the primary research artifact; its source is
[report/index.qmd](report/index.qmd).

Curated, non-confidential release evidence is checked into the repository:
[source provenance](outputs/audits/data-provenance.csv),
[selected evaluation](outputs/audits/selected-evaluation.csv),
[join audits](outputs/audits/fia-join-audit.csv),
[frame-specific basal-area validation](outputs/audits/basal-area-validation.csv),
[model support](outputs/tables/model-support.csv),
[primary model profile](outputs/tables/model-maple-effect-curve.csv),
[sapling-form comparison](outputs/tables/model-sapling-form-comparison.csv),
[county-grouped validation](outputs/tables/model-cross-validation-summary.csv),
[sensitivity results](outputs/tables/gap-threshold-sensitivity.csv), and the
[release validation record](outputs/audits/release-validation.csv).

## Reproduce

### Review without downloading FIA

Use the [live report](https://dineshpotla.github.io/canopy-to-cohort/report/)
and the checked-in aggregate evidence above. GitHub Actions installs the
lightweight test dependencies and runs the data-free subset; tests requiring
derived data or a fitted model skip cleanly. The v1.3.0 full local build and
exact expectation counts are recorded in the release-validation file. After
`make setup`, the same data-free subset can
be run locally with `make test` before downloading FIA.

The report source reads excluded derived files, so `make report` cannot render
from a fresh clone until the full data pipeline has completed.

### Full rebuild

Requirements: R 4.4 or newer, Quarto, Make, and enough disk space for the
Michigan FIA SQLite archive. Release v1.3.0 was tested with R 4.6.1 and Quarto
1.9.38.

```bash
make setup
make acquire
make all
```

`make setup` restores the package versions recorded in `renv.lock`; subsequent
R commands automatically use the project library through `renv`.

Raw source files are downloaded into `data/raw/` and excluded from Git. The
Michigan SQLite archive is about 1.1 GB compressed and expands to roughly
5.4 GB, so plan for at least 8 GB of free disk space. See
[data/README.md](data/README.md) for sources and expected locations.

The published release is tied to the exact source sizes and SHA-256 checksums in
[`outputs/audits/data-provenance.csv`](outputs/audits/data-provenance.csv) and to
EVALID 262501 in [`config/config.yml`](config/config.yml). FIA's state archive
URL is mutable: `make acquire` fetches the current official archive and warns if
it differs from the v1.0.0–v1.3.0 source snapshot. The evaluation remains pinned, but
upstream corrections can still change a rerun. Byte-for-byte reproduction
therefore requires source files matching the published manifest; otherwise the
commands perform a documented rerun against the current official data.

## Interpretation guardrails

- “No seedlings tallied” is not proof of ecological absence.
- The primary result is cross-sectional cohort association, not an observed transition.
- Treatment is observational and is not interpreted as a management effect.
- The regeneration-gap indicator is exploratory and sample-relative.
- Associations are not causal effects.
- County maps summarize analyzed observations, not design-based prevalence.
- Formal statewide FIA estimates require evaluation and population-estimation procedures not claimed by this analysis.

## Project structure

```text
R/                 reusable analysis functions
scripts/           ordered pipeline entry points
data/              raw, interim, and processed data
outputs/           figures, tables, models, and audits
tests/testthat/     data and calculation tests
report/             Quarto research report
config/             transparent analysis thresholds and paths
```

The central scientific and implementation decisions are recorded in [docs/analysis-decisions.md](docs/analysis-decisions.md).
The published fields, units, derivations, and interpretation boundaries are documented in [docs/data-dictionary.md](docs/data-dictionary.md).

## Data availability and licensing

The analysis code is released under the [MIT License](LICENSE). Source data are
not redistributed in this repository: FIA, Daymet, and Census artifacts remain
governed by their respective providers. Raw, interim, and record-level processed
files are excluded from Git; the repository publishes code, documentation,
derived aggregate figures, and curated non-confidential validation summaries.

The website is deployed from the pre-rendered `_site/` directory to the
`gh-pages` branch. This keeps the multi-gigabyte FIA database out of GitHub while
preserving a fast, stable portfolio artifact. Maintainers with a completed local
build can update it with `make publish`.

## Citation

Citation metadata are provided in [CITATION.cff](CITATION.cff).

## Sources

- [USDA Forest Service FIA DataMart](https://research.fs.usda.gov/products/dataandtools/fia-datamart)
- [FIADB Database Description and User Guide](https://research.fs.usda.gov/understory/forest-inventory-and-analysis-database-user-guide-nfi)
- [Daymet V4 R1](https://doi.org/10.3334/ORNLDAAC/2129)
- [U.S. Census Gazetteer files](https://www.census.gov/geographies/reference-files/time-series/geo/gazetteer-files.html)
