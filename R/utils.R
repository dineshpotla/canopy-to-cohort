`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x
}

project_path <- function(...) {
  here::here(...)
}

project_relative_path <- function(path) {
  root <- paste0(normalizePath(project_path(), winslash = "/", mustWork = TRUE), "/")
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  ifelse(startsWith(normalized, root), substring(normalized, nchar(root) + 1L), normalized)
}

read_config <- function(path = project_path("config", "config.yml")) {
  yaml::read_yaml(path)
}

ensure_dirs <- function(...) {
  paths <- unlist(list(...), use.names = FALSE)
  invisible(vapply(paths, dir.create, logical(1), recursive = TRUE, showWarnings = FALSE))
}

log_step <- function(message) {
  cat(sprintf("\n[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), message))
}

write_csv_atomic <- function(x, path, ...) {
  ensure_dirs(dirname(path))
  tmp <- tempfile(pattern = basename(path), tmpdir = dirname(path))
  readr::write_csv(x, tmp, ...)
  if (!file.rename(tmp, path)) {
    stop("Could not move temporary output into place: ", path, call. = FALSE)
  }
  invisible(path)
}

save_rds_atomic <- function(x, path, compress = "xz") {
  ensure_dirs(dirname(path))
  tmp <- tempfile(pattern = basename(path), tmpdir = dirname(path))
  saveRDS(x, tmp, compress = compress)
  if (!file.rename(tmp, path)) {
    stop("Could not move temporary output into place: ", path, call. = FALSE)
  }
  invisible(path)
}

sha256_file <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  output <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)
  strsplit(output[[1]], "\\s+")[[1]][[1]]
}

find_fia_sqlite <- function(config = read_config()) {
  configured <- project_path(config$files$fia_sqlite)
  if (file.exists(configured)) return(configured)

  candidates <- list.files(
    project_path("data", "raw", "fia"),
    pattern = "\\.(db|sqlite|sqlite3)$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(candidates) != 1L) {
    stop(
      "Expected exactly one extracted FIA SQLite database; found ",
      length(candidates), ". Run scripts/00_acquire_data.R.",
      call. = FALSE
    )
  }
  candidates[[1]]
}

standardize_names <- function(x) {
  names(x) <- tolower(names(x))
  x
}

select_existing <- function(data, columns) {
  dplyr::select(data, dplyr::any_of(columns))
}

first_existing <- function(candidates, available, required = TRUE) {
  hit <- candidates[candidates %in% available]
  if (length(hit)) return(hit[[1]])
  if (required) {
    stop(
      "None of the expected columns exist: ",
      paste(candidates, collapse = ", "),
      call. = FALSE
    )
  }
  NULL
}

read_required_rds <- function(path) {
  if (!file.exists(path)) stop("Required file does not exist: ", path, call. = FALSE)
  readRDS(path)
}
