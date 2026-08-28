# Canopy to Cohort

[![Live research report](https://img.shields.io/badge/live-research_report-285943)](https://dineshpotla.github.io/canopy-to-cohort/report/)
[![R unit tests](https://github.com/dineshpotla/canopy-to-cohort/actions/workflows/r-unit-tests.yml/badge.svg)](https://github.com/dineshpotla/canopy-to-cohort/actions/workflows/r-unit-tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-8B1E3F.svg)](LICENSE)

**Detecting exploratory sugar maple regeneration gaps in Michigan northern hardwood forests using FIA, Daymet, GIS, and statistical modeling**

**[Explore the live research report →](https://dineshpotla.github.io/canopy-to-cohort/report/)**

This is one research-style portfolio project built around a clear ecological question:

> Where do contemporary Michigan northern-hardwood FIA observations combine substantial established sugar maple with little evidence of sugar-maple seedlings, and which measured factors are associated with that mismatch?

## Why this project

The repository demonstrates:

- relational FIA data engineering;
- explicit join and data-integrity audits;
- R and reproducible research workflows;
- spatially responsible use of protected FIA locations;
- interpretable ecological modeling;
- publication-quality figures and research communication.

It is intentionally not a machine-learning leaderboard or dashboard.

**Technical stack:** R, DBI/RSQLite, dplyr, tidyr, ggplot2, lme4,
broom.mixed, DHARMa, Quarto, testthat, and renv.

![Established sugar maple versus observed regeneration](outputs/figures/03_regeneration_quadrant.png)

## Main findings

The latest complete Michigan FIA current evaluation yielded 1,457 eligible
northern-hardwood plot-condition measurements in 78 counties. Of 1,424
conditions with demonstrated microplot sampling, sugar-maple seedlings were
tallied in 815 (57.2%). The transparent primary screen flagged 119 observations
(8.4%) that combined upper-third sugar-maple basal-area share among sampled
conditions with no seedlings tallied; an upper-quartile sensitivity rule
flagged 93 (6.5%).

The supported mixed-effects logistic model used county and plot-visit random
intercepts and converged without a singularity. Higher established sugar-maple
basal area was associated with lower odds of no seedlings being tallied (OR
0.40, 95% CI 0.33–0.49 per SD of log basal area). County-scale temperature and
precipitation also carried associations, but they are broad spatial proxies and
are not interpreted as causal, plot-level climate effects.

![Adjusted model associations](outputs/figures/04_model_effects.png)

## Data and scientific scope

- **FIA:** Michigan state SQLite database from the USDA Forest Service FIA DataMart.
- **Climate:** 1991–2020 Daymet temperature and precipitation normals at an interior representative location for each county.
- **Geography:** FIA county identifiers, Census Gazetteer internal points, and
  `maps` package county polygons.
- **Unit:** one plot-condition measurement (`PLT_CN + CONDID`).
- **Primary response:** whether sugar-maple seedlings were tallied on sampled microplots.

Public FIA coordinates are protected. This project does not plot them or treat them as exact field positions. County climate is a broad proxy.

## Outputs

After `make all`, the project produces:

1. a study-area sample map;
2. a live-tree composition figure;
3. an established-maple versus regeneration hero figure;
4. an odds-ratio effect plot;
5. a supported broad-area gap map;
6. a Quarto project website and research report under `_site/`;
7. join, missingness, provenance, and model-support audits.

The [live rendered report](https://dineshpotla.github.io/canopy-to-cohort/report/)
is the primary research artifact; its source is
[report/index.qmd](report/index.qmd).

## Reproduce

Requirements: R 4.4 or newer, Quarto, Make, and enough disk space for the Michigan FIA SQLite archive.

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

## Interpretation guardrails

- “No seedlings tallied” is not proof of ecological absence.
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

## Data availability and licensing

The analysis code is released under the [MIT License](LICENSE). Source data are
not redistributed in this repository: FIA, Daymet, and Census artifacts remain
governed by their respective providers. Raw, interim, and record-level processed
files are excluded from Git; the repository publishes code, documentation, and
derived aggregate figures only.

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
