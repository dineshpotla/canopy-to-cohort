# RI measurement availability is established before missing species tallies are
# assigned zero. This module does not fit models or infer individual lineages.
extract_ri_records <- function(con, pairs) {
  ids <- unique(c(pairs$baseline_plt_cn, pairs$current_plt_cn))
  sql_ids <- paste(DBI::dbQuoteString(con, ids), collapse = ",")
  read <- function(table, columns) {
    standardize_names(DBI::dbGetQuery(con,
      paste0("SELECT ", columns, " FROM ", table, " WHERE PLT_CN IN (", sql_ids, ")")))
  }
  list(
    species = standardize_names(DBI::dbGetQuery(con, "SELECT SPCD FROM REF_SPECIES")),
    plots = read("PLOT_REGEN", "CN AS RI_PLOT_CN, PLT_CN, INVYR, BROWSE_IMPACT"),
    subplots = read("SUBPLOT_REGEN", "CN AS RI_SUBP_CN, PLT_CN, SBP_CN, SUBP, REGEN_SUBP_STATUS_CD, REGEN_MICR_STATUS_CD, REGEN_NONSAMPLE_REASN_CD"),
    seedlings = read("SEEDLING_REGEN", "CN AS RI_SEEDLING_CN, PLT_CN, CND_CN, SCD_CN, SUBP, CONDID, SPCD, SEEDLING_SOURCE_CD, LENGTH_CLASS_CD, SEEDLINGCOUNT"),
    core_subplots = read("SUBPLOT", "CN AS CORE_SBP_CN, PLT_CN, SUBP, SUBP_STATUS_CD"),
    conditions = read("COND", "CN AS CORE_CND_CN, PLT_CN, CONDID, COND_STATUS_CD"),
    subp_conditions = read("SUBP_COND", "CN AS CORE_SCD_CN, PLT_CN, CONDID, SUBP, MICRCOND_PROP"),
    core_seedlings = read("SEEDLING", "CN AS CORE_SEEDLING_CN, PLT_CN, CONDID, SUBP, SPCD, TREECOUNT, TREECOUNT_CALC")
  )
}

ri_valid_forest_status <- function(micro_status, legacy_status, nonsample_reason) {
  !is.na(micro_status) & micro_status == 1 &
    (is.na(legacy_status) | legacy_status == 1) & is.na(nonsample_reason)
}

ri_validate_records <- function(records) {
  assert_unique_key(records$plots, "plt_cn", "RI plot records")
  assert_unique_key(records$subplots, c("plt_cn", "subp"), "RI subplot records")
  assert_unique_key(records$core_subplots, c("plt_cn", "subp"), "core subplot records")
  assert_unique_key(records$conditions, c("plt_cn", "condid"), "condition records")
  assert_unique_key(records$subp_conditions, c("plt_cn", "condid", "subp"), "subplot-condition records")
  assert_unique_key(records$seedlings, "ri_seedling_cn", "RI seedling identifiers")
  assert_unique_key(records$seedlings, c("plt_cn", "condid", "subp", "spcd", "seedling_source_cd", "length_class_cd"), "RI seedling tally groups")
  x <- records$seedlings |>
    dplyr::left_join(records$conditions, by = c("plt_cn", "condid")) |>
    dplyr::left_join(records$subp_conditions, by = c("plt_cn", "condid", "subp"))
  x$valid_ri_record <- with(x, !is.na(ri_seedling_cn) & !is.na(spcd) & spcd %in% records$species$spcd &
    !is.na(length_class_cd) & length_class_cd %in% 1:6 &
    !is.na(seedling_source_cd) & seedling_source_cd %in% 1:3 &
    !(spcd == 318 & seedling_source_cd == 3) &
    is.finite(seedlingcount) & seedlingcount >= 1 & seedlingcount <= 999 &
    abs(seedlingcount - round(seedlingcount)) < 1e-8 &
    !is.na(cnd_cn) & !is.na(core_cnd_cn) & cnd_cn == core_cnd_cn &
    !is.na(scd_cn) & !is.na(core_scd_cn) & scd_cn == core_scd_cn &
    !is.na(cond_status_cd) & cond_status_cd == 1 &
    is.finite(micrcond_prop) & micrcond_prop > 0 & micrcond_prop <= 1)
  x$valid_ri_record[is.na(x$valid_ri_record)] <- FALSE
  x
}

ri_audit_visit <- function(mapping, records, checked_seedlings) {
  # mapping has one row per condition interval, not necessarily one per visit.
  area <- mapping |> dplyr::left_join(records$subp_conditions, by = c("plt_cn", "condid"))
  invalid_area <- unique(area$ri_pair_id[!is.finite(area$micrcond_prop) | area$micrcond_prop < 0 | area$micrcond_prop > 1])
  frame <- area |>
    dplyr::filter(is.finite(.data$micrcond_prop), .data$micrcond_prop > 0) |>
    dplyr::left_join(records$core_subplots, by = c("plt_cn", "subp")) |>
    dplyr::left_join(records$subplots, by = c("plt_cn", "subp"))
  frame$ri_slice_valid <- with(frame, ri_valid_forest_status(regen_micr_status_cd,
    regen_subp_status_cd, regen_nonsample_reasn_cd) &
    !is.na(ri_subp_cn) & !is.na(sbp_cn) & !is.na(core_sbp_cn) & sbp_cn == core_sbp_cn &
    !is.na(subp_status_cd) & subp_status_cd == 1 & micrcond_prop <= 1)
  frame$ri_slice_valid[is.na(frame$ri_slice_valid)] <- FALSE
  counts <- frame |> dplyr::group_by(.data$ri_pair_id) |>
    dplyr::summarise(contributing_microplots = dplyr::n(),
      sampled_ri_microplots = sum(.data$ri_slice_valid),
      reconstructed_coverage = sum(.data$micrcond_prop) / 4,
      coverage_matches = abs(.data$reconstructed_coverage - dplyr::first(.data$coverage)) <= 0.0001,
      all_slices_valid = all(.data$ri_slice_valid), .groups = "drop")
  # An invalid/orphaned RI record anywhere on a contributing plot is flagged;
  # it is not dropped in a way that could silently manufacture a target zero.
  bad_plots <- unique(checked_seedlings$plt_cn[!checked_seedlings$valid_ri_record])
  out <- mapping |> dplyr::left_join(counts, by = "ri_pair_id")
  out$has_ri_plot <- out$plt_cn %in% records$plots$plt_cn
  out$records_valid <- !out$plt_cn %in% bad_plots
  out$in_season <- !is.na(out$measmon) & out$measmon >= 5 & out$measmon <= 9
  out$frame_valid <- with(out, has_ri_plot & !is.na(all_slices_valid) & all_slices_valid &
    !is.na(coverage_matches) & coverage_matches & !ri_pair_id %in% invalid_area)
  out$ri_available <- out$frame_valid & out$records_valid & out$in_season
  out$ri_reason <- dplyr::case_when(!out$has_ri_plot ~ "No RI plot record",
    !out$frame_valid ~ "Incomplete or contradictory RI microplot frame",
    !out$records_valid ~ "Invalid RI record or foreign key",
    !out$in_season ~ "Plot date outside May-September or missing",
    TRUE ~ "RI measurement available")
  list(visits = out, frame = frame)
}

build_ri_audit <- function(pairs, records) {
  d <- pairs[pairs$recruitment_eligible, ]
  keys <- c("baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid")
  assert_unique_key(d, keys, "RI source condition intervals")
  d$ri_pair_id <- seq_len(nrow(d))
  checked <- ri_validate_records(records)
  visit_results <- lapply(c("baseline", "followup"), function(visit) {
    source_prefix <- if (visit == "followup") "current" else visit
    mapping <- data.frame(ri_pair_id = d$ri_pair_id,
      plt_cn = d[[paste0(source_prefix, "_plt_cn")]], condid = d[[paste0(source_prefix, "_condid")]],
      coverage = d[[paste0(visit, "_micrprop_unadj")]], measmon = d[[paste0(visit, "_measmon")]])
    result <- ri_audit_visit(mapping, records, checked)
    result$visits$visit <- visit
    result$frame$visit <- visit
    result
  })
  visits <- dplyr::bind_rows(lapply(visit_results, `[[`, "visits"))
  frames <- dplyr::bind_rows(lapply(visit_results, `[[`, "frame"))
  baseline <- visits[visits$visit == "baseline", ]
  followup <- visits[visits$visit == "followup", ]
  stopifnot(identical(baseline$ri_pair_id, d$ri_pair_id), identical(followup$ri_pair_id, d$ri_pair_id))
  d$baseline_ri_plot <- baseline$has_ri_plot
  d$baseline_ri_frame_valid <- baseline$frame_valid
  d$baseline_ri_records_valid <- baseline$records_valid
  d$baseline_ri_in_season <- baseline$in_season
  d$baseline_ri_available <- baseline$ri_available
  d$followup_ri_available <- followup$ri_available
  d$baseline_ri_reason <- baseline$ri_reason
  # Relevant annual-supplement sections were inspected for these years;
  # the 2016 archived copy is a draft. Older years retain an access gap.
  d$annual_ri_guide_reviewed <- d$baseline_measyear %in% 2016:2018
  maple <- checked[!is.na(checked$spcd) & checked$spcd == 318, ]
  tallies <- dplyr::inner_join(baseline[, c("ri_pair_id", "plt_cn", "condid")], maple,
    by = c("plt_cn", "condid"))
  measure <- function(predicate) {
    x <- tallies[predicate & !is.na(predicate), ]
    total <- x |> dplyr::group_by(.data$ri_pair_id) |>
      dplyr::summarise(value = sum(.data$seedlingcount), .groups = "drop")
    value <- total$value[match(d$ri_pair_id, total$ri_pair_id)]
    value[is.na(value)] <- 0
    value[!d$baseline_ri_available] <- NA_real_
    value
  }
  for (class in 1:6) d[[paste0("ri_class_", class)]] <- measure(tallies$length_class_cd == class)
  d$ri_all_count <- measure(rep(TRUE, nrow(tallies)))
  d$ri_standard_size_count <- measure(tallies$length_class_cd >= 3)
  d$ri_tall_count <- measure(tallies$length_class_cd >= 5)
  d$ri_other_source_count <- measure(tallies$seedling_source_cd == 1)
  d$ri_stump_source_count <- measure(tallies$seedling_source_cd == 2)
  d$ri_standard_count_difference <- d$ri_standard_size_count - d$baseline_seedling_count
  d$ri_zero <- d$baseline_ri_available & !is.na(d$ri_all_count) & d$ri_all_count == 0

  # The finer matched-unit comparison includes valid sampled units with no
  # maple rows in either table; missing counts never become zero.
  units <- frames[frames$visit == "baseline" & frames$ri_pair_id %in% d$ri_pair_id[d$baseline_ri_available], ]
  core <- records$core_seedlings[!is.na(records$core_seedlings$spcd) & records$core_seedlings$spcd == 318, ] |>
    dplyr::group_by(.data$plt_cn, .data$condid, .data$subp) |>
    dplyr::summarise(core_count = sum(.data$treecount), core_calc = sum(.data$treecount_calc), .groups = "drop")
  ri <- maple |> dplyr::group_by(.data$plt_cn, .data$condid, .data$subp) |>
    dplyr::summarise(ri_count = sum(.data$seedlingcount),
      ri_standard_count = sum(.data$seedlingcount[.data$length_class_cd >= 3]),
      ri_stump_count = sum(.data$seedlingcount[.data$seedling_source_cd == 2]), .groups = "drop")
  core$has_core_row <- TRUE
  ri$has_ri_row <- TRUE
  units <- units |> dplyr::left_join(core, by = c("plt_cn", "condid", "subp")) |>
    dplyr::left_join(ri, by = c("plt_cn", "condid", "subp"))
  for (field in c("core_count", "core_calc")) units[[field]][is.na(units$has_core_row)] <- 0
  for (field in c("ri_count", "ri_standard_count", "ri_stump_count")) units[[field]][is.na(units$has_ri_row)] <- 0
  units$count_difference <- units$ri_standard_count - units$core_count
  list(pairs = d, visits = visits, frame = frames, units = units, seedlings = checked)
}

ri_group_summary <- function(data, group, resamples = 2000L, seed = 20260909L) {
  if (!nrow(data) || length(group) != nrow(data) || anyNA(group) || anyNA(data$geoid) ||
      anyNA(data$outcome_recruitment) || any(!data$outcome_recruitment %in% 0:1) ||
      length(resamples) != 1L || !is.finite(resamples) || resamples < 1 || resamples != round(resamples)) {
    stop("Invalid RI descriptive-summary inputs.", call. = FALSE)
  }
  groups <- unique(group)
  counties <- unique(data$geoid)
  set.seed(seed)
  draws <- replicate(resamples, tabulate(sample.int(length(counties), length(counties), replace = TRUE), nbins = length(counties)))
  dplyr::bind_rows(lapply(groups, function(g) {
    keep <- group == g
    x <- data[keep, ]
    w <- draws[match(x$geoid, counties), , drop = FALSE]
    n <- colSums(w)
    p <- colSums(w * x$outcome_recruitment) / n
    p <- p[is.finite(p)]
    data.frame(group = g, conditions = nrow(x), physical_plots = dplyr::n_distinct(x$physical_plot_key),
      counties = dplyr::n_distinct(x$geoid), events = sum(x$outcome_recruitment),
      event_plots = dplyr::n_distinct(x$physical_plot_key[x$outcome_recruitment == 1]),
      recorded_new_saplings = sum(x$new_maple_sapling_count),
      event_fraction = mean(x$outcome_recruitment),
      lower = if (length(p)) unname(stats::quantile(p, 0.025)) else NA_real_,
      upper = if (length(p)) unname(stats::quantile(p, 0.975)) else NA_real_,
      estimable_resamples = length(p), resamples = resamples,
      limitation = "Descriptive county bootstrap; no model fitted; sparse groups or boundary estimates can understate uncertainty")
  }))
}
