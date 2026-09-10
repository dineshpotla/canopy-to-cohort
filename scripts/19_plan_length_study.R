source("R/utils.R")
source("R/validation.R")
source("R/fia_extract.R")
source("R/length_study_design.R")

run_length_study_plan <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(read_config()), flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  d <- extract_ri_opportunity_metadata(con, current_northern_hardwood_types(con)$value)
  current <- read_required_rds(project_path("data", "processed", "recruitment_ri_audit.rds"))$pairs
  d$in_current_recruitment_plot_set <- d$physical_plot_key %in% current$physical_plot_key
  pair_key <- function(x) paste(x$baseline_plt_cn, x$baseline_condid, x$current_plt_cn, sep = ":")
  d$in_current_ri_pair_set <- pair_key(d) %in% pair_key(current[current$baseline_ri_available, ])
  write <- function(x, name) write_csv_atomic(x,
    project_path("outputs", "tables", paste0("recruitment-length-", name, ".csv")))
  summary <- function(x, label) data.frame(screen = label,
    baseline_condition_visits = dplyr::n_distinct(x$baseline_condition_key),
    baseline_plot_visits = dplyr::n_distinct(x$baseline_plt_cn),
    physical_plots = dplyr::n_distinct(x$physical_plot_key), counties = dplyr::n_distinct(x$geoid),
    limitation = "RI record/date opportunity only; no new recruitment outcomes queried; condition/frame/protocol eligibility not established; historical Michigan source already explored")
  compatible <- d$followup_plot_compatible & d$date_window
  positive <- compatible & d$standard_maple_record_present == 1
  flow <- dplyr::bind_rows(
    summary(d, "Baseline RI record, sampled northern hardwoods, established maple"),
    summary(d[d$single_successor, ], "Exactly one linked successor plot visit"),
    summary(d[d$followup_plot_compatible, ], "Successor plot sampled under national design"),
    summary(d[compatible, ], "Recorded interval 4.5-8.5 years"),
    summary(d[positive, ], "Also a positive ordinary baseline maple seedling record"),
    summary(d[positive & !d$in_current_recruitment_plot_set, ], "Positive-count opportunities outside current 903-plot cohort"),
    summary(d[d$successor_count == 0, ], "Separate branch: no linked successor in this snapshot"))
  write(flow, "opportunity-flow")
  write(d |> dplyr::group_by(.data$baseline_measyear, .data$followup_measyear,
      .data$successor_count, .data$followup_plot_compatible, .data$date_window) |>
    dplyr::summarise(baseline_condition_visits = dplyr::n_distinct(.data$baseline_condition_key),
      physical_plots = dplyr::n_distinct(.data$physical_plot_key), .groups = "drop"), "opportunity-calendar")
  write(d[positive, ] |> dplyr::group_by(.data$in_current_recruitment_plot_set, .data$in_current_ri_pair_set) |>
    dplyr::summarise(baseline_condition_visits = dplyr::n_distinct(.data$baseline_condition_key),
      physical_plots = dplyr::n_distinct(.data$physical_plot_key), .groups = "drop"), "opportunity-overlap")
  inputs <- expand.grid(loss_difference_sd = c(0.05, 0.10, 0.20), half_width = c(0.005, 0.010, 0.020),
    variance_inflation = c(1, 1.5, 2), retention = c(0.8, 1))
  precision <- dplyr::bind_rows(lapply(seq_len(nrow(inputs)), function(i)
    do.call(paired_loss_precision, as.list(inputs[i, ]))))
  write(precision, "paired-precision")
  recall_inputs <- expand.grid(proportion = c(0.5, 0.8), half_width = c(0.05, 0.10))
  write(dplyr::bind_rows(lapply(seq_len(nrow(recall_inputs)), function(i)
    do.call(recall_precision_events, as.list(recall_inputs[i, ])))), "recall-precision")
  save_rds_atomic(d, project_path("data", "processed", "length_study_opportunity_metadata.rds"))
  print(flow[, 1:5])
  print(precision[precision$half_width == 0.01 & precision$variance_inflation == 1.5 & precision$retention == 0.8, 1:8])
  log_step("Saved outcome-free opportunity census and hypothetical precision scenarios; no model fitted")
}

run_length_study_plan()
