# Acquisition only. No recruitment labels or predictor/outcome comparisons.
regional_fia_sources <- function(snapshot_date = "2026-09-09") {
  if (length(snapshot_date) != 1L || is.na(snapshot_date) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", snapshot_date) ||
      is.na(as.Date(snapshot_date, format = "%Y-%m-%d"))) stop("Invalid regional snapshot date.", call. = FALSE)
  data.frame(state = c("WI", "MN"), state_name = c("Wisconsin", "Minnesota"),
    statecd = c(55L, 27L), snapshot_date,
    source_url = paste0("https://apps.fs.usda.gov/fia/datamart/Databases/SQLite_FIADB_", c("WI", "MN"), ".zip"),
    stringsAsFactors = FALSE)
}

regional_archive_member <- function(listing, state) {
  if (length(state) != 1L || !state %in% c("WI", "MN") ||
      !all(c("Name", "Length") %in% names(listing)) || !nrow(listing) ||
      anyNA(listing$Name) || anyNA(listing$Length)) {
    stop("Invalid regional archive listing.", call. = FALSE)
  }
  unsafe <- grepl("(^/|^[A-Za-z]:|\\\\|(^|/)\\.\\.(/|$))", listing$Name)
  db <- grepl("\\.(db|sqlite|sqlite3)$", listing$Name, ignore.case = TRUE)
  expected <- paste0("SQLite_FIADB_", state, ".db")
  if (any(unsafe) || sum(db) != 1L || listing$Name[db] != expected ||
      !is.finite(listing$Length[db]) || listing$Length[db] <= 0) {
    stop("Unexpected or unsafe regional SQLite archive member.", call. = FALSE)
  }
  listing[db, , drop = FALSE]
}

regional_space_guard <- function(available_bytes, required_bytes, reserve_bytes = 4 * 1024^3) {
  x <- list(available_bytes, required_bytes, reserve_bytes)
  if (any(lengths(x) != 1L) || any(!is.finite(unlist(x))) || any(unlist(x) < 0)) {
    stop("Invalid disk-space inputs.", call. = FALSE)
  }
  if (available_bytes < required_bytes + reserve_bytes) {
    stop("Insufficient disk space while retaining the four-GiB safety reserve.", call. = FALSE)
  }
  invisible(TRUE)
}

regional_available_bytes <- function(directory) {
  out <- system2("df", c("-Pk", shQuote(directory)), stdout = TRUE)
  if (!is.null(attr(out, "status")) || length(out) < 2L) stop("Disk-space check failed.", call. = FALSE)
  fields <- strsplit(trimws(tail(out, 1)), "[[:space:]]+")[[1]]
  available <- suppressWarnings(as.numeric(fields[4])) * 1024
  if (!is.finite(available)) stop("Cannot parse available disk space.", call. = FALSE)
  available
}

regional_validate_sqlite <- function(path, statecd) {
  if (!file.exists(path) || file.info(path)$isdir || length(statecd) != 1L ||
      !statecd %in% c(27L, 55L)) stop("Invalid regional SQLite source.", call. = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  check <- DBI::dbGetQuery(con, "PRAGMA quick_check")[[1]]
  if (!identical(check, "ok")) stop("Regional SQLite quick_check failed.", call. = FALSE)
  required <- c("PLOT", "COND", "TREE", "SEEDLING", "PLOT_REGEN", "SUBPLOT_REGEN",
    "SEEDLING_REGEN", "SUBPLOT", "SUBP_COND", "SUBP_COND_CHNG_MTRX", "REF_SPECIES", "REF_FOREST_TYPE")
  missing <- setdiff(required, DBI::dbListTables(con))
  if (length(missing)) stop("Regional source missing tables: ", paste(missing, collapse = ", "), call. = FALSE)
  states <- DBI::dbGetQuery(con, "SELECT DISTINCT STATECD FROM PLOT")[[1]]
  if (!length(states) || anyNA(states) || any(states != statecd)) {
    stop("Regional source state does not match its declared archive.", call. = FALSE)
  }
  # Integrity and table presence are not scientific eligibility checks.
  invisible(TRUE)
}

regional_acquire_one <- function(source) {
  if (!is.data.frame(source) || nrow(source) != 1L ||
      !all(c("state", "statecd", "source_url", "snapshot_date") %in% names(source)) || anyNA(source)) {
    stop("Unapproved regional source.", call. = FALSE)
  }
  state <- source$state
  if (!state %in% c("WI", "MN") || source$statecd != c(WI = 55L, MN = 27L)[[state]] ||
      source$source_url != regional_fia_sources(source$snapshot_date)$source_url[
        match(state, regional_fia_sources(source$snapshot_date)$state)]) {
    stop("Unapproved regional source.", call. = FALSE)
  }
  directory <- project_path("data", "raw", "fia", "regional", source$snapshot_date, state)
  ensure_dirs(directory)
  archive <- file.path(directory, paste0("SQLite_FIADB_", state, ".zip"))
  database <- file.path(directory, paste0("SQLite_FIADB_", state, ".db"))
  pin_path <- file.path(directory, "source-pin.rds")
  if (file.exists(pin_path)) {
    pin <- readRDS(pin_path)
    if (!identical(pin$source_url, source$source_url) ||
        !identical(sha256_file(archive), pin$archive_sha256) ||
        !identical(sha256_file(database), pin$database_sha256)) {
      stop("Pinned regional source changed or is missing; refusing replacement.", call. = FALSE)
    }
    regional_validate_sqlite(database, source$statecd)
    pin$status <- "cached_verified"
    return(pin)
  }
  if (file.exists(archive) || file.exists(database)) {
    stop("Unpinned regional files already exist; inspect provenance before use. No files overwritten.", call. = FALSE)
  }
  archive_limit <- 3 * 1024^3
  regional_space_guard(regional_available_bytes(directory), archive_limit)
  partial <- tempfile(pattern = "download-", tmpdir = directory, fileext = ".part")
  log <- paste0(partial, ".log")
  args <- c("--fail", "--location", "--silent", "--show-error", "--retry", "2",
    "--retry-all-errors", "--retry-delay", "2", "--retry-max-time", "60",
    "--connect-timeout", "20", "--max-time", "1800", "--max-filesize", as.character(archive_limit),
    "--proto", "=https", "--proto-redir", "=https", "--output", shQuote(partial), shQuote(source$source_url))
  log_step(paste("Acquiring", state, "from the official DataMart"))
  result <- system2("curl", args, stdout = log, stderr = log)
  if (result != 0L || !file.exists(partial) || file.info(partial)$size == 0) {
    detail <- if (file.exists(log)) paste(tail(readLines(log, warn = FALSE), 4), collapse = " | ") else "No transfer log"
    stop("Archive download failed (curl ", result, "): ", detail, call. = FALSE)
  }
  member <- regional_archive_member(utils::unzip(partial, list = TRUE), state)
  regional_space_guard(regional_available_bytes(directory), member$Length)
  staging <- tempfile(pattern = "extract-", tmpdir = directory)
  dir.create(staging)
  withCallingHandlers(utils::unzip(partial, files = member$Name, exdir = staging, overwrite = FALSE),
    warning = function(w) stop("Regional ZIP extraction warning: ", conditionMessage(w), call. = FALSE))
  extracted <- file.path(staging, member$Name)
  if (!file.exists(extracted) || file.info(extracted)$size != member$Length) {
    stop("Regional extraction size does not match the archive directory.", call. = FALSE)
  }
  regional_validate_sqlite(extracted, source$statecd)
  pin <- data.frame(state = state, statecd = source$statecd, source_url = source$source_url,
    retrieved_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), status = "acquired_verified",
    archive_path = project_relative_path(archive), database_path = project_relative_path(database),
    archive_member = member$Name, archive_bytes = file.info(partial)$size,
    database_bytes = file.info(extracted)$size, archive_sha256 = sha256_file(partial),
    database_sha256 = sha256_file(extracted), sqlite_quick_check = "ok",
    error_message = NA_character_, stringsAsFactors = FALSE)
  if (!file.rename(partial, archive) || !file.rename(extracted, database)) {
    stop("Could not finalize regional source. Inspect staging files; no overwrite attempted.", call. = FALSE)
  }
  save_rds_atomic(pin, pin_path)
  pin
}
