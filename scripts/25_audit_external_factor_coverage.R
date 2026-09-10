source("R/utils.R")
source("R/external_factors.R")

run_external_factor_coverage <- function() {
  x <- readRDS(project_path("data", "processed", "recruitment_ri_audit.rds"))$pairs
  stopifnot(nrow(x) > 0, !anyNA(x$geoid), !anyNA(x$physical_plot_key))
  con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(), flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  browse <- DBI::dbGetQuery(con, "SELECT PLT_CN, BROWSE_IMPACT FROM PLOT_REGEN")
  x <- external_browse_join(x, browse)
  reports <- readr::read_csv(project_path("outputs", "audits", "recruitment-external-harvest-reports.csv"), show_col_types = FALSE)
  available_years <- reports$season_year[reports$dmu_rows > 0]
  windows <- external_harvest_window(x$baseline_measyear, x$baseline_measmon)
  x <- cbind(x, windows)
  x$harvest_years_available <- vapply(seq_len(nrow(x)), function(i) {
    all(seq.int(x$first_season[i], x$last_season[i]) %in% available_years)
  }, logical(1))
  write <- function(value, suffix) write_csv_atomic(value,
    project_path("outputs", "audits", paste0("recruitment-external-", suffix, ".csv")))
  summarize <- function(z, group) data.frame(group = group, conditions = nrow(z),
    physical_plots = dplyr::n_distinct(z$physical_plot_key), counties = dplyr::n_distinct(z$geoid),
    conditions_with_recorded_recruitment = sum(z$outcome_recruitment),
    event_plots = dplyr::n_distinct(z$physical_plot_key[z$outcome_recruitment == 1]),
    limitation = "Availability only; no browse-outcome association estimated")
  groups <- list(core = rep(TRUE, nrow(x)),
    baseline_browse_observed = !is.na(x$baseline_browse_impact),
    baseline_browse_and_valid_RI = !is.na(x$baseline_browse_impact) & x$baseline_ri_available,
    followup_browse_observed = !is.na(x$followup_browse_impact),
    baseline_positive_seedlings_and_browse = x$baseline_seedling_count > 0 & !is.na(x$baseline_browse_impact))
  support <- dplyr::bind_rows(lapply(names(groups), function(g) summarize(x[groups[[g]], ], g)))
  write(support, "browse-support")
  browse_codes <- x |>
    dplyr::mutate(browse_code = ifelse(is.na(.data$baseline_browse_impact), "missing", as.character(.data$baseline_browse_impact))) |>
    dplyr::group_by(.data$baseline_measyear, .data$browse_code) |>
    dplyr::summarise(conditions = dplyr::n(), physical_plots = dplyr::n_distinct(.data$physical_plot_key), .groups = "drop")
  write(browse_codes, "browse-calendar")
  county_windows <- x |>
    dplyr::group_by(.data$geoid, .data$county_name, .data$baseline_measyear,
      .data$first_season, .data$last_season, .data$january_shift, .data$required_seasons) |>
    dplyr::summarise(conditions = dplyr::n(), physical_plots = dplyr::n_distinct(.data$physical_plot_key),
      all_required_reports_available = all(.data$harvest_years_available), .groups = "drop") |>
    dplyr::mutate(spatial_join_approved = FALSE,
      limitation = "Report-year coverage, not matched DMU exposure; historical boundaries and report release timing unresolved")
  write(county_windows, "county-season-requirements")
  calendar <- x |>
    dplyr::group_by(.data$baseline_measyear) |>
    dplyr::summarise(conditions = dplyr::n(), physical_plots = dplyr::n_distinct(.data$physical_plot_key),
      counties = dplyr::n_distinct(.data$geoid), january_visits_shifted = sum(.data$january_shift),
      first_required_season = min(.data$first_season), last_required_season = max(.data$last_season),
      conditions_with_all_report_years = sum(.data$harvest_years_available), .groups = "drop")
  write(calendar, "harvest-calendar")
  fields <- intersect(c("baseline_beech_sapling_ba_ft2_ac", "baseline_overstory_total_ba_ft2_ac",
    "baseline_stand_age", "baseline_site_class_cd", "baseline_physclcd",
    paste0("baseline_dstrbcd", 1:3), paste0("baseline_dstrbyr", 1:3),
    paste0("baseline_trtcd", 1:3), paste0("baseline_trtyr", 1:3)), names(x))
  write(dplyr::bind_rows(lapply(fields, function(f) data.frame(variable = f,
    conditions = nrow(x), nonmissing = sum(!is.na(x[[f]])), missing = sum(is.na(x[[f]])),
    distinct_nonmissing_values = dplyr::n_distinct(x[[f]], na.rm = TRUE),
    limitation = "Recorded availability only; zeros and disturbance/treatment codes require protocol interpretation"))), "existing-context-fields")
  print(support[, 1:6])
  print(calendar)
  log_step("External-factor feasibility tables saved. No external predictors joined, models fitted, or paper changed.")
}

run_external_factor_coverage()
