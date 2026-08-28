source("R/utils.R")

required <- c(
  "DBI", "RSQLite", "dplyr", "tidyr", "purrr", "readr", "stringr",
  "ggplot2", "maps", "lme4", "broom", "broom.mixed", "performance",
  "DHARMa", "testthat", "here", "renv", "yaml", "scales", "patchwork",
  "knitr", "rmarkdown"
)

installed <- rownames(utils::installed.packages())
missing <- setdiff(required, installed)
if (length(missing)) {
  log_step(paste("Installing", length(missing), "R packages"))
  utils::install.packages(
    missing,
    repos = "https://cloud.r-project.org",
    Ncpus = max(1L, min(4L, parallel::detectCores(logical = FALSE)))
  )
}

still_missing <- setdiff(required, rownames(utils::installed.packages()))
if (length(still_missing)) {
  stop("R packages failed to install: ", paste(still_missing, collapse = ", "), call. = FALSE)
}

ensure_dirs(
  project_path("data", "raw", "fia"),
  project_path("data", "raw", "climate"),
  project_path("data", "raw", "boundaries"),
  project_path("data", "interim"),
  project_path("data", "processed"),
  project_path("outputs", "figures"),
  project_path("outputs", "tables"),
  project_path("outputs", "models"),
  project_path("outputs", "audits")
)

log_step(paste("R environment ready:", R.version.string))
