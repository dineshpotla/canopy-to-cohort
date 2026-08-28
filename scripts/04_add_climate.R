source("R/utils.R")
source("R/validation.R")
source("R/climate.R")

config <- read_config()
boundary_dir <- project_path("data", "raw", "boundaries")
gazetteer_zips <- list.files(boundary_dir, pattern = "Gaz_counties_national\\.zip$", full.names = TRUE, ignore.case = TRUE)
if (length(gazetteer_zips) != 1L) {
  stop("Expected one Census county Gazetteer archive. Run scripts/00_acquire_data.R.", call. = FALSE)
}

counties <- read_michigan_counties(gazetteer_zips[[1]], sprintf("%02d", config$project$state_fips))
if (nrow(counties) != 83L) stop("Expected 83 Michigan counties; found ", nrow(counties), call. = FALSE)
save_rds_atomic(counties, project_path("data", "processed", "michigan_counties.rds"))

years <- seq.int(config$climate$start_year, config$climate$end_year)
climate <- build_county_climate(
  counties,
  years,
  project_path("data", "raw", "climate", "daymet-single-pixel")
)

assert_unique_key(climate, "geoid", "county climate")
assert_range(climate$mean_annual_temp_c, -5, 15, allow_na = FALSE, label = "Michigan mean annual temperature")
assert_range(climate$mean_annual_precip_mm, 300, 2000, allow_na = FALSE, label = "Michigan annual precipitation")
if (any(climate$climate_years != length(years))) stop("Some counties lack the full climate normal period.")

write_csv_atomic(climate, project_path(config$files$county_climate))
write_csv_atomic(
  missingness_summary(climate),
  project_path("outputs", "audits", "county-climate-missingness.csv")
)

daymet_files <- file.path(
  project_path("data", "raw", "climate", "daymet-single-pixel"),
  paste0(
    "daymet_", climate$geoid, "_",
    config$climate$start_year, "_", config$climate$end_year, ".csv"
  )
)
if (!all(file.exists(daymet_files))) stop("One or more cached Daymet inputs are missing.", call. = FALSE)
daymet_provenance <- tibble::tibble(
  dataset = paste("Daymet county internal-point series", climate$geoid),
  source_url = purrr::pmap_chr(
    climate[c("representative_latitude", "representative_longitude")],
    ~ daymet_single_pixel_url(..1, ..2, years)
  ),
  local_path = vapply(daymet_files, project_relative_path, character(1)),
  bytes = as.numeric(file.info(daymet_files)$size),
  sha256 = vapply(daymet_files, sha256_file, character(1)),
  retrieved_at_utc = format(file.info(daymet_files)$mtime, tz = "UTC", usetz = TRUE)
)
provenance_path <- project_path("outputs", "audits", "data-provenance.csv")
base_provenance <- if (file.exists(provenance_path)) {
  readr::read_csv(provenance_path, show_col_types = FALSE) |>
    dplyr::filter(!startsWith(.data$dataset, "Daymet county internal-point series"))
} else {
  tibble::tibble()
}
write_csv_atomic(
  dplyr::bind_rows(base_provenance, daymet_provenance),
  provenance_path
)

log_step("County internal-point Daymet climate normals complete")
