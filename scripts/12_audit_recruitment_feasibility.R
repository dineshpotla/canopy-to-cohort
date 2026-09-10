# Read-only FIADB feasibility audit. This does not fit a model or establish a
# validated historical analysis cohort. Only aggregate results are exported.
source("R/utils.R")
source("R/validation.R")
source("R/fia_extract.R")
source("R/longitudinal.R")

audit_recruitment_feasibility <- function() {
  config <- read_config()
  con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(config), flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  pairs <- read_required_rds(project_path(config$files$longitudinal_data))
  stopifnot(all(pairs$followup_comparable), all(pairs$plot_prev_link_matches))
  write_audit <- function(data, suffix) {
    write_csv_atomic(data, project_path("outputs", "audits", paste0("recruitment-feasibility-", suffix, ".csv")))
  }
  count_conditions <- function(x) dplyr::n_distinct(paste(x$current_plt_cn, x$current_condid, sep = ":"))
  metrics <- function(metric, value, note) tibble::tibble(metric, value, note)
  ids <- unique(c(pairs$baseline_plt_cn, pairs$current_plt_cn))
  trees <- DBI::dbGetQuery(con, paste0(
    "SELECT CN, PLT_CN, CONDID, PREV_TRE_CN, PREVCOND, SUBP, TREE, STATUSCD, SPCD, ",
    "DIA, PREVDIA, RECONCILECD, TPA_UNADJ FROM TREE WHERE PLT_CN IN (",
    paste(DBI::dbQuoteString(con, ids), collapse = ","), ")"
  )) |>
    standardize_names() |>
    tibble::as_tibble()
  assert_unique_key(trees, "cn", "audit TREE extract")
  keys <- pairs |>
    dplyr::select(dplyr::all_of(c("baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid",
      "physical_plot_key", "geoid", "seedling_transition", "baseline_seedling_detected", "interval_years")))
  current <- dplyr::inner_join(keys, trees, by = c("current_plt_cn" = "plt_cn", "current_condid" = "condid"))
  live_maple <- current |> dplyr::filter(.data$spcd == 318, .data$statuscd == 1)
  recruits <- live_maple |>
    dplyr::filter(.data$dia >= 1, .data$dia < 5, .data$reconcilecd == 1, is.na(.data$prev_tre_cn))
  recruit_counts <- recruits |>
    dplyr::count(.data$current_plt_cn, .data$current_condid, name = "new_saplings")
  sapling_counts <- live_maple |>
    dplyr::filter(.data$dia >= 1, .data$dia < 5) |>
    dplyr::count(.data$current_plt_cn, .data$current_condid, name = "current_saplings")
  audited_pairs <- pairs |>
    dplyr::left_join(recruit_counts, by = c("current_plt_cn", "current_condid")) |>
    dplyr::left_join(sapling_counts, by = c("current_plt_cn", "current_condid")) |>
    dplyr::mutate(
      new_saplings = dplyr::coalesce(.data$new_saplings, 0L),
      current_saplings = dplyr::coalesce(.data$current_saplings, 0L),
      audited_followup_sapling_present = .data$current_saplings > 0,
      sapling_detection_loss = .data$baseline_maple_sapling_present & !.data$audited_followup_sapling_present
    )
  stopifnot(nrow(audited_pairs) == nrow(pairs))
  baseline_saplings <- dplyr::inner_join(keys, trees,
    by = c("baseline_plt_cn" = "plt_cn", "baseline_condid" = "condid")) |>
    dplyr::filter(.data$spcd == 318, .data$statuscd == 1, .data$dia >= 1, .data$dia < 5)
  followup_fields <- trees |>
    dplyr::select(followup_tree_cn = "cn", followup_plt_cn = "plt_cn", followup_condid = "condid", "prev_tre_cn",
      followup_statuscd = "statuscd", followup_spcd = "spcd", followup_dia = "dia", followup_reconcilecd = "reconcilecd")
  fates <- baseline_saplings |>
    dplyr::left_join(followup_fields, by = c("cn" = "prev_tre_cn", "current_plt_cn" = "followup_plt_cn")) |>
    dplyr::left_join(audited_pairs |> dplyr::select("current_plt_cn", "current_condid", "sapling_detection_loss"),
      by = c("current_plt_cn", "current_condid")) |>
    dplyr::mutate(
      species_reidentified = !is.na(.data$followup_spcd) & .data$followup_spcd != 318,
      fate = dplyr::case_when(
        is.na(.data$followup_tree_cn) ~ "Unlinked; unresolved",
        .data$followup_statuscd == 0 ~ "No longer in sample; reconcile separately",
        .data$followup_statuscd == 2 ~ "Recorded dead",
        .data$followup_statuscd == 3 ~ "Recorded removed",
        .data$followup_statuscd == 1 & .data$followup_dia >= 5 ~ "Alive; grew to at least 5 inches",
        .data$followup_statuscd == 1 & .data$followup_dia >= 1 & .data$followup_dia < 5 ~ "Alive; still 1 to less than 5 inches",
        TRUE ~ "Other; unresolved"
      )
    )
  assert_unique_key(fates, "cn", "one expected follow-up per baseline sapling")
  stopifnot(nrow(fates) == nrow(baseline_saplings))
  survivors <- fates |> dplyr::filter(.data$followup_statuscd == 1)
  graduated <- survivors |> dplyr::filter(.data$followup_dia >= 5)
  no_live_visit <- current |> dplyr::group_by(.data$current_plt_cn, .data$current_condid) |>
    dplyr::summarise(tree_records = dplyr::n(), live_records = sum(.data$statuscd == 1),
      dead_records = sum(.data$statuscd == 2), .groups = "drop") |>
    dplyr::filter(.data$live_records == 0) |>
    dplyr::inner_join(audited_pairs, by = c("current_plt_cn", "current_condid"))

  write_audit(dplyr::bind_rows(
    metrics("Current condition intervals", nrow(pairs), "Previously constructed strict microplot cohort; unweighted records."),
    metrics("Current physical plots", dplyr::n_distinct(pairs$physical_plot_key), "Multiple conditions may share one physical plot."),
    metrics("Baseline seedling detections", sum(pairs$baseline_seedling_detected), "Aggregate species tallies; seedlings are not individually linked."),
    metrics("New live maple saplings", nrow(recruits), "SPCD=318; STATUSCD=1; 1<=DIA<5; RECONCILECD=1; PREV_TRE_CN null."),
    metrics("Conditions with new live maple saplings", count_conditions(recruits), "Endpoint is new sapling tally within an already sampled forest condition."),
    metrics("Counties with new live maple saplings", dplyr::n_distinct(recruits$geoid), "Event support may be geographically concentrated."),
    metrics("Recruit conditions with baseline seedling detection", count_conditions(recruits |> dplyr::filter(.data$baseline_seedling_detected == 1)), "Not a probability that an individual seedling survives or grows."),
    metrics("Seedling-loss conditions with new saplings", count_conditions(recruits |> dplyr::filter(.data$seedling_transition == "Loss")), "Seedling disappearance and verified new sapling tally may coexist."),
    metrics("Tagged baseline maple saplings", nrow(baseline_saplings), "SPCD=318; STATUSCD=1; 1<=DIA<5 at baseline."),
    metrics("Conditions containing tagged baseline saplings", count_conditions(baseline_saplings), "Sapling records are clustered within conditions and plots."),
    metrics("Physical plots containing tagged baseline saplings", dplyr::n_distinct(baseline_saplings$physical_plot_key), "Tree record count is not an independent sample size."),
    metrics("Unlinked baseline saplings", sum(is.na(fates$followup_tree_cn)), "Join on PREV_TRE_CN and expected follow-up PLOT CN; missing links never imply death."),
    metrics("Linked saplings on a different condition", sum(fates$followup_condid != fates$current_condid, na.rm = TRUE), "Frame comparability diagnostic."),
    metrics("Tagged saplings recorded alive at follow-up", sum(fates$followup_statuscd == 1, na.rm = TRUE), "Includes stems reidentified to another species, which are flagged separately."),
    metrics("Tagged saplings recorded dead at follow-up", sum(fates$followup_statuscd == 2, na.rm = TRUE), "Recorded fate; does not establish cause of death or distinguish treatment effects."),
    metrics("Tagged saplings recorded removed at follow-up", sum(fates$followup_statuscd == 3, na.rm = TRUE), "Recorded removal status is distinct from recorded death."),
    metrics("Tagged saplings no longer in sample", sum(fates$followup_statuscd == 0, na.rm = TRUE), "Must interpret RECONCILECD separately from death."),
    metrics("Survivors reidentified to another species", sum(survivors$species_reidentified), "Retain as identity uncertainty; exclude or harmonize explicitly in a species-specific model."),
    metrics("Tagged survivors reaching at least 5 inches", nrow(graduated), "Individual diameter-stage progression, not proof of canopy recruitment."),
    metrics("Corrected sapling-detection-loss conditions", sum(audited_pairs$sapling_detection_loss), "A sampled zero-live-tree visit is counted as sapling absence."),
    metrics("Sapling-loss conditions with a graduated survivor", count_conditions(graduated |> dplyr::filter(.data$sapling_detection_loss)), "Sapling disappearance may reflect growth out of the size class."),
    metrics("Graduated stems in sapling-loss conditions", sum(graduated$sapling_detection_loss), "Survivor diameter >=5 inches at follow-up."),
    metrics("Sapling-loss conditions with species reidentification", count_conditions(survivors |> dplyr::filter(.data$sapling_detection_loss, .data$species_reidentified)), "Taxonomic corrections can change species detection."),
    metrics("Survivors with negative diameter difference", sum(survivors$followup_dia < survivors$dia), "Measurement error and remeasurement protocols require audit before a growth model."),
    metrics("Survivors with zero diameter difference", sum(survivors$followup_dia == survivors$dia), "Rounded diameter differences; interval length varies."),
    metrics("Median annual survivor diameter difference inches", stats::median((survivors$followup_dia - survivors$dia) / survivors$interval_years), "Descriptive only; conditions on survival and includes reidentified stems."),
    metrics("Verified follow-up conditions with no live TREE records", nrow(no_live_visit), "Accessible forest and positive shared microplot footprint; inspect BALIVE and tally status below.")
  ), "current-summary")
  write_audit(fates |> dplyr::count(.data$fate, .data$followup_statuscd, .data$followup_reconcilecd,
    .data$followup_spcd, .data$species_reidentified, name = "tree_records"), "tagged-sapling-fates")
  write_audit(audited_pairs |> dplyr::count(.data$baseline_maple_sapling_present,
    .data$audited_followup_sapling_present, name = "conditions"), "sapling-transitions")
  write_audit(audited_pairs |> dplyr::group_by(.data$seedling_transition) |>
    dplyr::summarise(conditions = dplyr::n(), conditions_with_new_saplings = sum(.data$new_saplings > 0),
      new_sapling_records = sum(.data$new_saplings), .groups = "drop"), "seedling-ingrowth-overlap")
  write_audit(live_maple |> dplyr::mutate(diameter_stage = dplyr::if_else(.data$dia < 5, "1 to less than 5 inches", "At least 5 inches"),
    previous_tree_link = !is.na(.data$prev_tre_cn)) |>
    dplyr::count(.data$reconcilecd, .data$diameter_stage, .data$previous_tree_link, name = "records"), "current-reconcile-codes")
  write_audit(no_live_visit |> dplyr::count(.data$followup_cond_status_cd, .data$followup_balive,
    .data$followup_micrprop_unadj, .data$followup_trtcd1, .data$followup_trtyr1, .data$followup_seedling_detected,
    .data$tree_records, .data$dead_records, name = "conditions"), "zero-live-tree-visits")

  # Reuse the exact current pair extractor, changing only its evaluation scope.
  # This expansion is provisional: old protocols and temporal selection still
  # require a separate validation before any pooled historical model is fit.
  original_cte <- longitudinal_pair_cte
  historical_extractor <- extract_longitudinal_pair_candidates
  extractor_env <- new.env(parent = environment(historical_extractor))
  extractor_env$longitudinal_pair_cte <- function(evalid) {
    old <- original_cte(evalid)
    target <- paste0("SELECT DISTINCT PLT_CN FROM POP_PLOT_STRATUM_ASSGN WHERE EVALID = ", as.integer(evalid))
    stopifnot(grepl(target, old, fixed = TRUE))
    sub(target, "SELECT CN AS PLT_CN FROM PLOT WHERE MANUAL >= 1", old, fixed = TRUE)
  }
  environment(historical_extractor) <- extractor_env
  all_pairs <- historical_extractor(con, config$release$evalid)
  established <- DBI::dbGetQuery(con,
    "SELECT DISTINCT PLT_CN AS baseline_plt_cn, CONDID AS baseline_condid FROM TREE WHERE SPCD=318 AND STATUSCD=1 AND DIA>=5")
  active_forest_codes <- current_northern_hardwood_types(con)$value
  historical <- all_pairs |>
    dplyr::semi_join(established, by = c("baseline_plt_cn", "baseline_condid")) |>
    dplyr::filter(.data$baseline_cond_status_cd == 1, .data$baseline_plot_status_cd == 1,
      .data$baseline_fortypcd %in% active_forest_codes, .data$baseline_manual >= 1, .data$baseline_designcd == 1,
      .data$followup_manual >= 1, .data$followup_designcd == 1, .data$baseline_micrprop_unadj > 0,
      .data$followup_cond_status_cd == 1, .data$followup_plot_status_cd == 1, .data$followup_micrprop_unadj > 0,
      .data$strict_one_to_one, .data$baseline_overlap_fraction >= 0.9, .data$followup_overlap_fraction >= 0.9,
      .data$plot_prev_link_matches, is.finite(.data$interval_years), .data$interval_years > 0)
  historical_ingrowth <- DBI::dbGetQuery(con, paste(
    "SELECT PLT_CN AS current_plt_cn, CONDID AS current_condid, COUNT(*) AS new_saplings FROM TREE",
    "WHERE SPCD=318 AND STATUSCD=1 AND DIA>=1 AND DIA<5 AND RECONCILECD=1 AND PREV_TRE_CN IS NULL GROUP BY PLT_CN, CONDID"
  ))
  historical <- historical |>
    dplyr::left_join(historical_ingrowth, by = c("current_plt_cn", "current_condid")) |>
    dplyr::mutate(new_saplings = dplyr::coalesce(.data$new_saplings, 0L))
  assert_unique_key(historical, c("baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid"),
    "provisional historical condition intervals")
  historical_events <- historical |> dplyr::filter(.data$new_saplings > 0)
  write_audit(dplyr::bind_rows(
    metrics("All positive historical microplot condition links", nrow(all_pairs), "Current PLOT.MANUAL>=1; scope is all qualifying database visits, not one EVALID."),
    metrics("Provisional historical condition intervals", nrow(historical), "Baseline active group-800 forest code and live maple DIA>=5; forest sampled both visits; national design 1 both visits; manuals>=1; one-to-one mapping; relative overlap>=0.9 both; predecessor match; positive finite interval."),
    metrics("Physical plots", dplyr::n_distinct(historical$physical_plot_key), "Repeated intervals and multiple conditions are not independent plots."),
    metrics("Counties", dplyr::n_distinct(historical$geoid), "Unweighted feasibility sample; not a statewide population estimate."),
    metrics("Intervals with new saplings", nrow(historical_events), "Conservative RECONCILECD=1, live maple 1<=DIA<5, null prior tree key."),
    metrics("New sapling records", sum(historical$new_saplings), "Only surviving new tally stems; arrivals that died between visits are unobserved."),
    metrics("Physical plots with new saplings", dplyr::n_distinct(historical_events$physical_plot_key), "Useful support is events across independent plots, not just tree counts."),
    metrics("Counties with new saplings", dplyr::n_distinct(historical_events$geoid), "Geographic event support."),
    metrics("Earliest baseline measurement year", min(historical$baseline_measyear), "Historical feasibility only."),
    metrics("Latest baseline measurement year", max(historical$baseline_measyear), "Historical feasibility only."),
    metrics("Earliest follow-up measurement year", min(historical$followup_measyear), "Historical feasibility only."),
    metrics("Latest follow-up measurement year", max(historical$followup_measyear), "Historical feasibility only."),
    metrics("Minimum interval years", min(historical$interval_years), "Measurement year plus month difference; no narrow interval filter applied."),
    metrics("Median interval years", stats::median(historical$interval_years), "Model would need to account for variable exposure duration."),
    metrics("Maximum interval years", max(historical$interval_years), "Long intervals need separate comparability review."),
    metrics("Intervals outside 4.5 to 8.5 years", sum(historical$interval_years < 4.5 | historical$interval_years > 8.5), "Existing current-cohort interval bounds; no exclusion made for this feasibility audit.")
  ), "historical-summary")
  write_audit(historical |> dplyr::mutate(followup_period = cut(.data$followup_measyear, c(2000, 2009, 2014, 2019, 2025))) |>
    dplyr::group_by(.data$followup_period) |>
    dplyr::summarise(condition_intervals = dplyr::n(), intervals_with_new_saplings = sum(.data$new_saplings > 0),
      new_sapling_records = sum(.data$new_saplings), .groups = "drop"), "historical-periods")
  write_audit(historical |> dplyr::count(.data$physical_plot_key, name = "condition_intervals") |>
    dplyr::count(.data$condition_intervals, name = "physical_plots"), "historical-repeat-support")
  write_audit(tibble::tribble(
    ~topic, ~evidence_or_definition, ~limitation_or_required_work, ~source,
    "Seedlings", "SEEDLING contains species counts per microplot, not individually linked seedling records.", "Cannot infer individual seedling survival, growth, or the fraction converting to saplings.", "FIADB SEEDLING schema; R/longitudinal.R",
    "Conservative new sapling endpoint", "TREE SPCD=318, STATUSCD=1, 1<=DIA<5, RECONCILECD=1, PREV_TRE_CN null, comparable sampled forest footprint.", "New live sapling tally at follow-up is a condition-level establishment proxy; exact crossing date and intervening deaths are unobserved.", "FIADB User Guide v9.4, section 3.1.82; https://research.fs.usda.gov/sites/default/files/2025-08/wo-v9-4_Aug2025_UG_FIADB_database_description_NFI.pdf",
    "Larger new TREE records", "RECONCILECD=1 also occurs on new >=5-inch trees sampled on larger subplots.", "Do not interpret these as measured seedling-to-sapling transitions; they may have been untallied saplings outside the microplot. Code 2 through-growth needs separate review.", "FIADB User Guide v9.4, RECONCILECD and national plot design",
    "Reconciliation versions", "Starting MANUAL=9.0, RECONCILECD 1-2 exclude procedure/definition changes and cruiser error; codes 7/8 handle those cases. Missed-live code 3 is retired from version 9.0.", "Audit each historical manual period; a null PREV_TRE_CN alone never establishes biological recruitment.", "FIADB User Guide v9.4, section 3.1.82",
    "Tagged tree fates", "Join follow-up PREV_TRE_CN to baseline TREE.CN and expected successor PLOT.CN; retain STATUSCD and RECONCILECD.", "Do not label STATUSCD=0, unlinked records, or species reidentifications as mortality; audit dead-sapling protocol changes before pooling historical fates.", "FIADB TREE and PLOT schema; FIADB User Guide STATUSCD/RECONCILECD",
    "Sampled zero-tree visit", "The audit recomputes follow-up sapling absence from TREE in conditions already verified sampled and comparable, and exports aggregate BALIVE/treatment/tally diagnostics.", "Zero is defensible only on a verified sampled frame; do not globally fill absent measurements with zero.", "Current cohort COND, PLOT, and TREE records",
    "Historical scope", paste0("Active group-800 codes used: ", paste(active_forest_codes, collapse = ", "), "; both visits DESIGNCD=1, MANUAL>=1; current EVALID filter removed."), "Not a validated pooled cohort: audit old forest-type codes, seedling protocols, sample-kind/duplicate records, condition transitions, interval outliers, and overlap before modeling.", "Existing longitudinal extractor with only evaluation scope generalized",
    "Selection", "Baseline requires maple >=5 inches and current active northern-hardwood forest type; follow-up requires sampled forest and stable microplot condition mapping.", "Does not represent all Michigan forest or converted/nonsampled/strongly remapped conditions; examine excluded-condition bias and survey design.", "R/longitudinal.R; this audit",
    "Recommended question", "Which baseline conditions predict new sugar-maple sapling tally and retention or diameter growth of already established saplings?", "Use separate stage-specific endpoints and clustered validation; declare a retrospective temporal check before model comparisons. This snapshot has already been explored, so it is not untouched validation. Compare against starting abundance and sampling effort.", "Feasibility audit; proposed research direction, not fitted inference"
  ), "provenance-notes")
  log_step(paste("Recruitment feasibility audit complete:", nrow(pairs), "current pairs;", count_conditions(recruits),
    "current recruit conditions;", nrow(historical), "provisional historical intervals;", nrow(historical_events), "historical recruit intervals."))
}

audit_recruitment_feasibility()
