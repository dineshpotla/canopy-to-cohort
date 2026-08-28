source("R/utils.R")

config <- read_config()
ensure_dirs(
  project_path("data", "raw", "fia"),
  project_path("data", "raw", "boundaries"),
  project_path("outputs", "audits")
)

download_if_missing <- function(url, destination) {
  if (file.exists(destination) && file.info(destination)$size > 0) {
    log_step(paste("Using cached", destination))
    return(invisible(destination))
  }
  log_step(paste("Downloading", url))
  tmp <- paste0(destination, ".part")
  on.exit(unlink(tmp), add = TRUE)
  utils::download.file(url, tmp, mode = "wb", quiet = FALSE)
  if (!file.rename(tmp, destination)) stop("Could not finalize download: ", destination)
  invisible(destination)
}

fia_zip <- project_path(config$files$fia_zip)
download_if_missing(config$files$fia_download_url, fia_zip)

fia_dir <- dirname(fia_zip)
archive_files <- utils::unzip(fia_zip, list = TRUE)$Name
sqlite_members <- archive_files[grepl("\\.(db|sqlite|sqlite3)$", archive_files, ignore.case = TRUE)]
if (length(sqlite_members) != 1L) {
  stop("Expected one SQLite database in FIA archive; found ", length(sqlite_members), call. = FALSE)
}

extracted <- file.path(fia_dir, sqlite_members[[1]])
if (!file.exists(extracted)) {
  log_step("Extracting FIA SQLite database")
  utils::unzip(fia_zip, files = sqlite_members, exdir = fia_dir)
}

configured_db <- project_path(config$files$fia_sqlite)
if (!identical(normalizePath(extracted), normalizePath(configured_db, mustWork = FALSE))) {
  if (!file.exists(configured_db)) {
    ok <- file.rename(extracted, configured_db)
    if (!ok) stop("Could not place FIA database at configured path.", call. = FALSE)
  }
}

gazetteer_url <- "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2025_Gazetteer/2025_Gaz_counties_national.zip"
gazetteer_zip <- project_path("data", "raw", "boundaries", basename(gazetteer_url))
download_if_missing(gazetteer_url, gazetteer_zip)

provenance <- data.frame(
  dataset = c("FIA Michigan SQLite archive", "US Census county gazetteer"),
  source_url = c(config$files$fia_download_url, gazetteer_url),
  local_path = c(
    config$files$fia_zip,
    file.path("data/raw/boundaries", basename(gazetteer_url))
  ),
  bytes = c(file.info(fia_zip)$size, file.info(gazetteer_zip)$size),
  sha256 = c(sha256_file(fia_zip), sha256_file(gazetteer_zip)),
  retrieved_at_utc = format(
    c(file.info(fia_zip)$mtime, file.info(gazetteer_zip)$mtime),
    tz = "UTC",
    usetz = TRUE
  ),
  release_expected_bytes = c(
    as.numeric(config$release$source_snapshot$fia_zip$bytes),
    as.numeric(config$release$source_snapshot$census_gazetteer$bytes)
  ),
  release_expected_sha256 = c(
    as.character(config$release$source_snapshot$fia_zip$sha256),
    as.character(config$release$source_snapshot$census_gazetteer$sha256)
  ),
  stringsAsFactors = FALSE
)
provenance$release_snapshot_match <-
  provenance$bytes == provenance$release_expected_bytes &
  provenance$sha256 == provenance$release_expected_sha256
write.csv(provenance, project_path("outputs", "audits", "data-provenance.csv"), row.names = FALSE)

if (any(!provenance$release_snapshot_match)) {
  changed <- paste(provenance$dataset[!provenance$release_snapshot_match], collapse = ", ")
  warning(
    changed,
    " differs from the documented release source snapshot. The workflow remains pinned to EVALID ",
    config$release$evalid,
    ", but upstream revisions can change results; see outputs/audits/data-provenance.csv.",
    call. = FALSE
  )
}

log_step("Source acquisition complete")
