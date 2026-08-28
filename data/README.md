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

The DataMart state URL is mutable. Releases v1.0.0 through v1.2.0 used a 1,180,933,421-byte
archive with SHA-256
`2c1eb908a47436d4edd0f3ba9e3d647b79a4f36cef972c5ba83277300817aee1`
and pins EVALID 262501. Acquisition compares current files with the release
snapshot and warns on a mismatch. A current-data rerun is still supported, but
it is not described as byte-for-byte reproduction of these releases.

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

Exact FIA plot locations are confidential. Public FIADB coordinates may be
approximate; this analysis neither uses nor infers them. FIA observations are
linked to climate and summarized only through county identifiers supplied in
FIADB.
