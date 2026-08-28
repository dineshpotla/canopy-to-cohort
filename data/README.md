# Data acquisition

Raw data are intentionally excluded from Git. The workflow expects the files
below and records source URLs, cached-file timestamps, sizes, and SHA-256 checksums in
`outputs/audits/data-provenance.csv`.

## Forest Inventory and Analysis

- Source: USDA Forest Service FIA DataMart
- File: `data/raw/fia/SQLite_FIADB_MI.zip`
- Direct download: <https://apps.fs.usda.gov/fia/datamart/Databases/SQLite_FIADB_MI.zip>

Run `Rscript scripts/00_acquire_data.R` to download the archive when it is not
already present. The script extracts the SQLite database and discovers its
actual filename rather than assuming the archive layout.

## Climate

The climate workflow uses Daymet V4 R1 annual temperature and precipitation
summaries for 1991–2020. It queries the Daymet cell at the Census internal point
for each Michigan county; it does not spatially average every cell in a county.
Daymet source files are cached under `data/raw/climate/`.

## County boundaries

Michigan county identifiers and internal representative points come from the
U.S. Census Bureau Gazetteer. County polygons for plotting are supplied by the
`maps` R package. The Gazetteer archive is cached under `data/raw/boundaries/`.

## Spatial confidentiality

Public FIA coordinates are protected and are not used for point-level climate
extraction or mapping. FIA observations are linked to climate and summarized
using county identifiers supplied in FIADB.
