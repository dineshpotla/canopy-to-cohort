source("R/utils.R")
source("R/validation.R")
source("R/recruitment.R")

run_recruitment_build <- function() {
  config <- read_config()
  con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(config), flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  source_pairs <- read_required_rds(project_path(config$files$longitudinal_data))
  built <- build_recruitment_dataset(source_pairs, extract_recruitment_records(con, source_pairs))
  d <- built$pairs
  f <- built$fates
  save_rds_atomic(d, project_path("data", "processed", "recruitment_condition_pairs.rds"))
  save_rds_atomic(f, project_path("data", "processed", "recruitment_sapling_fates.rds"))
  audit <- function(x, name) write_csv_atomic(x, project_path("outputs", "audits", paste0("recruitment-", name, ".csv")))
  audit(d |> dplyr::count(.data$exclusion_reason, .data$recruitment_eligible, name = "condition_intervals"), "eligibility")
  audit(d |> dplyr::count(.data$baseline_manual, .data$followup_manual, .data$baseline_kindcd, .data$followup_kindcd,
    .data$baseline_qa_status, .data$followup_qa_status, .data$baseline_microplot_loc, .data$followup_microplot_loc,
    .data$seedling_count_protocol_valid, name = "condition_intervals"), "protocol")
  audit(d |> dplyr::count(.data$shared_microplot_sampled, .data$shared_subplot_predecessor_matches, .data$frame_proportions_valid,
    .data$direct_subplot_predecessors_available, .data$exact_overlap, .data$recruits_outside_shared_subplots, name = "condition_intervals"), "frame")
  audit(d |> dplyr::count(.data$baseline_seedling_count, .data$recruitment_eligible, .data$outcome_recruitment,
    name = "condition_intervals"), "seedling-count-support")
  audit(built$current_trees |> dplyr::filter(.data$spcd == 318, .data$statuscd == 1, .data$dia >= 1, .data$dia < 5) |>
    dplyr::count(.data$recruitment_class, .data$reconcilecd, predecessor_present = !is.na(.data$prev_tre_cn), name = "trees"), "reconcile-codes")
  audit(built$current_trees |> dplyr::filter(.data$spcd == 318, is.na(.data$prev_tre_cn)) |>
    dplyr::mutate(stage = dplyr::if_else(.data$dia >= 5, "At least 5 inches", "Below 5 inches")) |>
    dplyr::count(.data$statuscd, .data$reconcilecd, .data$stage, name = "trees"), "other-new-records")
  audit(built$recruits |> dplyr::count(.data$dia, name = "trees"), "entrant-diameters")
  audit(d |> dplyr::filter(.data$followup_zero_tree_corrected) |>
    dplyr::count(.data$followup_balive, .data$followup_micrprop_unadj, .data$followup_trtcd1, .data$followup_trtyr1,
      .data$followup_seedling_detected, name = "conditions"), "zero-tree-corrections")
  audit(f |> dplyr::count(.data$fate, .data$followup_statuscd, .data$followup_reconcilecd,
    .data$followup_spcd, .data$fate_eligible, name = "trees"), "sapling-fates")
  audit(f |> dplyr::filter(.data$fate_eligible, .data$followup_statuscd == 1) |>
    dplyr::summarise(survivors = dplyr::n(), zero_increment = sum(.data$annual_diameter_increment == 0),
      negative_increment = sum(.data$annual_diameter_increment < 0), median_increment_inches_year = stats::median(.data$annual_diameter_increment),
      p10 = stats::quantile(.data$annual_diameter_increment, 0.1), p90 = stats::quantile(.data$annual_diameter_increment, 0.9)), "sapling-growth")
  audit(d |> dplyr::group_by(.data$recruitment_eligible, .data$seedling_transition) |>
    dplyr::summarise(conditions = dplyr::n(), recruit_conditions = sum(.data$new_maple_sapling_count > 0),
      new_saplings = sum(.data$new_maple_sapling_count), .groups = "drop"), "seedling-transition-overlap")
  audit(tibble::tribble(~topic, ~definition, ~limitation,
    "Outcome", "New live maple 1<=DIA<5; RECONCILECD=1; no PREV_TRE_CN; comparable shared microplots.", "Surviving new tally at follow-up, not individual seedling conversion or all arrivals during interval.",
    "Seedlings", "Sum raw TREECOUNT for maple; zero only on the source verified sampled forest frame; TREECOUNT_CALC agreement audited.", "Species tallies contain no individual seedling links; seedling count is measured over varying microplot area.",
    "Frame", "Both shared SUBPLOT records sampled; plot predecessor plus matrix SUBP linkage; populated subplot predecessors must agree; matrix proportions <= both SUBP_COND proportions.", "PREV_SBP_CN is entirely missing in this snapshot; no direct subplot predecessor claim. Partial-footprint pairs retained under >=90% rule; exact-overlap sensitivity identifies unchanged mapped fractions.",
    "QA", "Keep PLOT QA_STATUS 1 and 7 (standard production or supervised production hot check).", "QA7 is not an independent duplicate or an invalid production visit; remaining statuses require exclusion or review.",
    "Fates", "Baseline maple saplings linked by expected successor PLOT and PREV_TRE_CN; recorded death separated from removals, no-sample codes, reidentification, and growth>=5.", "Recorded dead does not establish cause; >=5 inches does not prove canopy recruitment.",
    "Source", "FIADB snapshot configured in config/config.yml; USDA FIADB User Guide v9.4 RECONCILECD section.", "https://research.fs.usda.gov/sites/default/files/2025-08/wo-v9-4_Aug2025_UG_FIADB_database_description_NFI.pdf"
  ), "definitions")
  cohorts <- list("Source strict pairs" = rep(TRUE, nrow(d)), "Reconciled recruitment cohort" = d$recruitment_eligible,
    "Exact-overlap sensitivity" = d$recruitment_eligible & d$exact_overlap,
    "QA_STATUS=1 both visits sensitivity" = d$recruitment_eligible & !d$nonstandard_qa_status)
  flow <- purrr::imap_dfr(cohorts, function(keep, label) {
    x <- d[!is.na(keep) & keep, ]
    tibble::tibble(cohort = label, conditions = nrow(x), physical_plots = dplyr::n_distinct(x$physical_plot_key),
      counties = dplyr::n_distinct(x$geoid), recruit_conditions = sum(x$new_maple_sapling_count > 0),
      new_saplings = sum(x$new_maple_sapling_count), baseline_seedling_detections = sum(x$baseline_seedling_count > 0))
  })
  write_csv_atomic(flow, project_path("outputs", "tables", "recruitment-cohort-flow.csv"))
  print(flow)
  log_step(paste("Saved", nrow(d), "source pairs;", sum(d$recruitment_eligible), "recruitment eligible;", nrow(f), "tagged sapling fates."))
}

run_recruitment_build()
