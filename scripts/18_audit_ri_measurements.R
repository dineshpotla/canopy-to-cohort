source("R/utils.R")
source("R/validation.R")
source("R/regeneration_indicator.R")

run_ri_measurement_audit <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(read_config()), flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  pairs <- read_required_rds(project_path("data", "processed", "recruitment_condition_pairs.rds"))
  built <- build_ri_audit(pairs, extract_ri_records(con, pairs[pairs$recruitment_eligible, ]))
  d <- built$pairs
  write <- function(x, name) write_csv_atomic(x, project_path("outputs", "tables", paste0("recruitment-ri-", name, ".csv")))
  summarize <- function(x, label) {
    data.frame(screen = label, conditions = nrow(x), physical_plots = dplyr::n_distinct(x$physical_plot_key),
      counties = dplyr::n_distinct(x$geoid), events = sum(x$outcome_recruitment),
      event_plots = dplyr::n_distinct(x$physical_plot_key[x$outcome_recruitment == 1]),
      new_saplings = sum(x$new_maple_sapling_count),
      standard_seedling_detections = sum(x$baseline_seedling_count > 0))
  }
  screens <- list("Recruitment-eligible intervals" = rep(TRUE, nrow(d)),
    "Baseline RI plot record" = d$baseline_ri_plot,
    "Complete baseline RI condition frame" = d$baseline_ri_frame_valid,
    "Frame and RI record checks pass" = d$baseline_ri_frame_valid & d$baseline_ri_records_valid,
    "Baseline RI available, including date screen" = d$baseline_ri_available,
    "Available baseline RI and standard seedlings detected" = d$baseline_ri_available & d$baseline_seedling_count > 0,
    "Available RI and annual baseline guide inspected (2016-2018)" = d$baseline_ri_available & d$annual_ri_guide_reviewed,
    "RI available at both visits, including date screen" = d$baseline_ri_available & d$followup_ri_available)
  flow <- dplyr::bind_rows(lapply(names(screens), function(name) summarize(d[screens[[name]], ], name)))
  write(flow, "eligibility")
  write(built$visits |> dplyr::count(.data$visit, .data$has_ri_plot, .data$ri_reason, name = "condition_intervals"), "visit-status")
  write(built$frame |> dplyr::filter(.data$ri_pair_id %in% d$ri_pair_id[d$baseline_ri_plot]) |>
    dplyr::count(.data$visit, .data$regen_subp_status_cd, .data$regen_micr_status_cd,
      .data$regen_nonsample_reasn_cd, .data$ri_slice_valid, name = "microplot_condition_intervals"), "frame-status")
  write(d |> dplyr::filter(.data$baseline_ri_plot) |>
    dplyr::group_by(.data$baseline_measyear, .data$baseline_manual, .data$baseline_measmon,
      .data$annual_ri_guide_reviewed, .data$baseline_ri_available) |>
    dplyr::summarise(conditions = dplyr::n(), events = sum(.data$outcome_recruitment), .groups = "drop"), "calendar")
  x <- d[d$baseline_ri_available, ]
  units <- built$units
  reconciliation <- data.frame(
    unit = c("Condition intervals", "Microplot-condition intervals"),
    observations = c(nrow(x), nrow(units)),
    ordinary_count = c(sum(x$baseline_seedling_count), sum(units$core_count)),
    ri_at_least_one_foot = c(sum(x$ri_standard_size_count), sum(units$ri_standard_count)),
    ri_all_lengths = c(sum(x$ri_all_count), sum(units$ri_count)),
    ri_stump_source = c(sum(x$ri_stump_source_count), sum(units$ri_stump_count)),
    exact_count_agreements = c(sum(x$ri_standard_count_difference == 0), sum(units$count_difference == 0)),
    missing_comparisons = c(sum(is.na(x$ri_standard_count_difference)), sum(is.na(units$count_difference))),
    maximum_absolute_difference = c(max(abs(x$ri_standard_count_difference)), max(abs(units$count_difference))))
  write(reconciliation, "count-reconciliation")
  labels <- ifelse(x$ri_all_count == 0, "No RI maple tally on verified frame",
    ifelse(x$ri_standard_size_count == 0, "RI maple only below one foot", "RI maple at least one foot"))
  write(dplyr::bind_rows(lapply(unique(labels), function(g) summarize(x[labels == g, ], g))), "zero-accounting")
  groups <- ifelse(x$ri_tall_count > 0, "RI maple at least five feet present", "No RI maple at least five feet recorded")
  height <- ri_group_summary(x, groups)
  height$population <- "All RI-available intervals"
  positive <- x[x$baseline_seedling_count > 0, ]
  positive_height <- ri_group_summary(positive, ifelse(positive$ri_tall_count > 0,
    "RI maple at least five feet present", "No RI maple at least five feet recorded"))
  positive_height$population <- "Standard baseline seedlings detected"
  write(dplyr::bind_rows(height, positive_height), "height-support")
  write(dplyr::bind_rows(lapply(1:6, function(k) {
    z <- x[x[[paste0("ri_class_", k)]] > 0, ]
    data.frame(length_class = k, recorded_count = sum(x[[paste0("ri_class_", k)]]),
      conditions_with_class = nrow(z), physical_plots = dplyr::n_distinct(z$physical_plot_key),
      events_among_conditions_with_class = sum(z$outcome_recruitment),
      limitation = "Presence groups overlap across length classes; not independent outcomes or conversion rates")
  })), "length-classes")
  test <- x$followup_measyear >= 2023
  test_plots <- x$physical_plot_key[test]
  training <- !test & !x$physical_plot_key %in% test_plots
  write(dplyr::bind_rows(summarize(x[training, ], "Potential development: follow-up before 2023, no test plots"),
    summarize(x[test, ], "Potential later-year assessment: follow-up 2023 onward")), "split-support")
  event_plots <- dplyr::n_distinct(x$physical_plot_key[x$outcome_recruitment == 1])
  # Best-case exact binomial reference: even perfect observed recall from this
  # many independent event plots has limited precision. Not the actual CI.
  write(data.frame(event_plots = event_plots, observed_recall_assumed = 1,
    exact_two_sided_95_lower_if_all_found = if (event_plots > 0) 0.025^(1 / event_plots) else NA_real_,
    interpretation = "Illustrative independent-event-plot binomial calculation, assuming all events captured; not actual recall, a clustered interval, or sample-size justification"), "precision-reference")
  write(built$seedlings |> dplyr::count(.data$valid_ri_record, name = "ri_records_on_source_plots"), "record-checks")
  save_rds_atomic(built, project_path("data", "processed", "recruitment_ri_audit.rds"))
  print(flow)
  print(reconciliation)
  print(dplyr::bind_rows(height, positive_height)[, c("population", "group", "conditions", "events", "lower", "upper")])
  log_step("Saved RI measurement audit; no height-class model fitted")
}

run_ri_measurement_audit()
