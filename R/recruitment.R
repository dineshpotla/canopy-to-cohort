# A separate stage-specific dataset; the earlier seedling-detection analysis is
# retained unchanged. No individual seedling identity is inferred from a tally.
extract_recruitment_records <- function(con, pairs) {
  ids <- unique(c(pairs$baseline_plt_cn, pairs$current_plt_cn))
  id_sql <- paste(DBI::dbQuoteString(con, ids), collapse = ",")
  read <- function(sql) standardize_names(DBI::dbGetQuery(con, sql)) |> tibble::as_tibble()
  list(
    plots = read(paste0("SELECT CN AS PLT_CN, KINDCD, DESIGNCD, MANUAL, QA_STATUS, MICROPLOT_LOC FROM PLOT WHERE CN IN (", id_sql, ")")),
    trees = read(paste0("SELECT CN AS TREE_CN, PLT_CN, CONDID, PREV_TRE_CN, PREVCOND, SUBP, TREE, STATUSCD, SPCD, DIA, PREVDIA, RECONCILECD, TPA_UNADJ, AGENTCD, MORTYR FROM TREE WHERE PLT_CN IN (", id_sql, ")")),
    seedlings = read(paste0("SELECT CN AS SEEDLING_CN, PLT_CN, CONDID, SUBP, SPCD, TREECOUNT, TREECOUNT_CALC, TPA_UNADJ FROM SEEDLING WHERE PLT_CN IN (", id_sql, ")")),
    subplots = read(paste0("SELECT CN AS SUBPLOT_CN, PREV_SBP_CN, PLT_CN, SUBP, SUBP_STATUS_CD, MICRCOND, POINT_NONSAMPLE_REASN_CD FROM SUBPLOT WHERE PLT_CN IN (", id_sql, ")")),
    subp_conditions = read(paste0("SELECT PLT_CN, CONDID, SUBP, MICRCOND_PROP FROM SUBP_COND WHERE PLT_CN IN (", id_sql, ")")),
    links = read(paste0("SELECT PLT_CN AS CURRENT_PLT_CN, CONDID AS CURRENT_CONDID, PREV_PLT_CN AS BASELINE_PLT_CN, PREVCOND AS BASELINE_CONDID, SUBP, SUBPTYP_PROP_CHNG FROM SUBP_COND_CHNG_MTRX WHERE SUBPTYP=2 AND SUBPTYP_PROP_CHNG>0 AND PLT_CN IN (", id_sql, ")"))
  )
}

recruitment_tree_class <- function(statuscd, spcd, dia, reconcilecd, prev_tre_cn) {
  dplyr::case_when(
    spcd != 318 | statuscd != 1 | dia < 1 | dia >= 5 ~ "Not a live maple sapling",
    !is.na(prev_tre_cn) ~ "Previously tagged sapling",
    is.na(spcd) | is.na(statuscd) | is.na(dia) ~ "Ambiguous new sapling tally",
    reconcilecd == 1 ~ "New live sapling tally",
    TRUE ~ "Ambiguous new sapling tally"
  )
}

recruitment_sapling_fate <- function(followup_tree_cn, statuscd, spcd, dia, reconcilecd) {
  dplyr::case_when(
    is.na(followup_tree_cn) ~ "Unlinked",
    statuscd == 0 ~ "No longer sampled",
    !is.na(spcd) & spcd != 318 ~ "Species reidentified",
    is.na(statuscd) | is.na(spcd) ~ "Unresolved",
    statuscd == 2 ~ "Recorded dead",
    statuscd == 3 ~ "Recorded removed",
    statuscd == 1 & dia >= 5 ~ "Alive; reached 5 inches",
    statuscd == 1 & dia >= 1 & dia < 5 ~ "Alive; remains sapling",
    TRUE ~ "Unresolved"
  )
}

build_recruitment_dataset <- function(pairs, records) {
  pair_keys <- c("baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid")
  assert_unique_key(pairs, pair_keys, "source recruitment pairs")
  assert_unique_key(records$trees, "tree_cn", "recruitment TREE extract")
  assert_unique_key(records$subplots, c("plt_cn", "subp"), "recruitment SUBPLOT extract")
  assert_unique_key(records$subp_conditions, c("plt_cn", "condid", "subp"), "recruitment SUBP_COND extract")
  keys <- pairs |> dplyr::select(dplyr::all_of(c(pair_keys, "physical_plot_key", "geoid", "interval_years")))
  current_trees <- dplyr::inner_join(keys, records$trees,
    by = c("current_plt_cn" = "plt_cn", "current_condid" = "condid")) |>
    dplyr::mutate(recruitment_class = recruitment_tree_class(.data$statuscd, .data$spcd, .data$dia, .data$reconcilecd, .data$prev_tre_cn))
  baseline_trees <- dplyr::inner_join(keys, records$trees,
    by = c("baseline_plt_cn" = "plt_cn", "baseline_condid" = "condid"))
  baseline_seedlings <- dplyr::inner_join(keys, records$seedlings,
    by = c("baseline_plt_cn" = "plt_cn", "baseline_condid" = "condid")) |>
    dplyr::filter(.data$spcd == 318)
  current_seedlings <- dplyr::inner_join(keys, records$seedlings,
    by = c("current_plt_cn" = "plt_cn", "current_condid" = "condid")) |>
    dplyr::filter(.data$spcd == 318)
  seed_summary <- function(x, prefix) {
    out <- x |> dplyr::group_by(dplyr::across(dplyr::all_of(pair_keys))) |>
      dplyr::summarise(seedling_count = if (anyNA(.data$treecount)) NA_real_ else sum(.data$treecount),
        seedling_missing_count_records = sum(is.na(.data$treecount)),
        seedling_calc_discrepant_records = sum(is.na(.data$treecount_calc) | .data$treecount != .data$treecount_calc, na.rm = TRUE),
        seedling_max_record_count = max(.data$treecount, na.rm = TRUE), .groups = "drop")
    names(out)[!names(out) %in% pair_keys] <- paste0(prefix, "_", names(out)[!names(out) %in% pair_keys])
    out
  }
  baseline_saplings <- baseline_trees |> dplyr::filter(.data$statuscd == 1, .data$spcd == 318, .data$dia >= 1, .data$dia < 5)
  baseline_counts <- baseline_saplings |> dplyr::group_by(dplyr::across(dplyr::all_of(pair_keys))) |>
    dplyr::summarise(baseline_maple_sapling_count = dplyr::n(),
      baseline_maple_sapling_tpa_plot_basis = sum(.data$tpa_unadj), .groups = "drop")
  current_counts <- current_trees |> dplyr::group_by(dplyr::across(dplyr::all_of(pair_keys))) |>
    dplyr::summarise(new_maple_sapling_count = sum(.data$recruitment_class == "New live sapling tally"),
      ambiguous_new_maple_sapling_count = sum(.data$recruitment_class == "Ambiguous new sapling tally"),
      followup_live_tree_count = sum(.data$statuscd == 1),
      followup_maple_sapling_count = sum(.data$statuscd == 1 & .data$spcd == 318 & .data$dia >= 1 & .data$dia < 5, na.rm = TRUE),
      .groups = "drop")

  links <- records$links |> dplyr::inner_join(keys, by = pair_keys)
  for (visit in c("baseline", "current")) {
    plt <- paste0(visit, "_plt_cn")
    cond <- paste0(visit, "_condid")
    s <- records$subplots
    names(s)[names(s) == "plt_cn"] <- plt
    names(s)[!names(s) %in% c(plt, "subp")] <- paste0(visit, "_", names(s)[!names(s) %in% c(plt, "subp")])
    m <- records$subp_conditions
    names(m)[names(m) == "plt_cn"] <- plt
    names(m)[names(m) == "condid"] <- cond
    names(m)[names(m) == "micrcond_prop"] <- paste0(visit, "_micrcond_prop")
    links <- links |> dplyr::left_join(s, by = c(plt, "subp")) |>
      dplyr::left_join(m, by = c(plt, cond, "subp"))
  }
  links <- links |> dplyr::mutate(
    linked_subplot_sampled = .data$baseline_subp_status_cd == 1 & .data$current_subp_status_cd == 1,
    subplot_predecessor_available = !is.na(.data$current_prev_sbp_cn),
    # PREV_SBP_CN is entirely unpopulated in this Michigan snapshot. When
    # absent, the verified plot predecessor plus matrix SUBP is the linkage;
    # when populated, require consistency rather than ignoring contradictions.
    subplot_predecessor_matches = !is.na(.data$baseline_subplot_cn) & !is.na(.data$current_subplot_cn) &
      (is.na(.data$current_prev_sbp_cn) | .data$current_prev_sbp_cn == .data$baseline_subplot_cn),
    link_within_both_frames = .data$subptyp_prop_chng <= .data$baseline_micrcond_prop + 0.0001 &
      .data$subptyp_prop_chng <= .data$current_micrcond_prop + 0.0001,
    exact_microplot_link = abs(.data$subptyp_prop_chng - .data$baseline_micrcond_prop) <= 0.0001 &
      abs(.data$subptyp_prop_chng - .data$current_micrcond_prop) <= 0.0001
  )
  frame <- links |> dplyr::group_by(dplyr::across(dplyr::all_of(pair_keys))) |>
    dplyr::summarise(shared_microplot_count = dplyr::n_distinct(.data$subp),
      shared_microplot_sampled = all(!is.na(.data$linked_subplot_sampled) & .data$linked_subplot_sampled),
      shared_subplot_predecessor_matches = all(!is.na(.data$subplot_predecessor_matches) & .data$subplot_predecessor_matches),
      direct_subplot_predecessors_available = all(.data$subplot_predecessor_available),
      frame_proportions_valid = all(!is.na(.data$link_within_both_frames) & .data$link_within_both_frames),
      exact_microplot_links = all(!is.na(.data$exact_microplot_link) & .data$exact_microplot_link),
      .groups = "drop")
  recruits <- current_trees |> dplyr::filter(.data$recruitment_class == "New live sapling tally") |>
    dplyr::left_join(links |> dplyr::select(dplyr::all_of(c(pair_keys, "subp", "linked_subplot_sampled", "exact_microplot_link"))),
      by = c(pair_keys, "subp"))
  unmatched_recruit_subplots <- recruits |> dplyr::group_by(dplyr::across(dplyr::all_of(pair_keys))) |>
    dplyr::summarise(recruits_outside_shared_subplots = sum(is.na(.data$linked_subplot_sampled) | !.data$linked_subplot_sampled),
      .groups = "drop")
  out <- pairs |> dplyr::left_join(seed_summary(baseline_seedlings, "baseline"), by = pair_keys) |>
    dplyr::left_join(seed_summary(current_seedlings, "followup"), by = pair_keys) |>
    dplyr::left_join(baseline_counts, by = pair_keys) |> dplyr::left_join(current_counts, by = pair_keys) |>
    dplyr::left_join(frame, by = pair_keys) |> dplyr::left_join(unmatched_recruit_subplots, by = pair_keys)
  for (visit in c("baseline", "followup")) {
    target <- if (visit == "baseline") "baseline_plt_cn" else "current_plt_cn"
    p <- records$plots |> dplyr::select("plt_cn", "kindcd", "qa_status", "microplot_loc")
    names(p) <- c(target, paste0(visit, "_kindcd"), paste0(visit, "_qa_status"), paste0(visit, "_microplot_loc"))
    out <- dplyr::left_join(out, p, by = target)
  }
  zero_fill <- c("baseline_seedling_count", "followup_seedling_count", "baseline_maple_sapling_count",
    "baseline_maple_sapling_tpa_plot_basis", "new_maple_sapling_count", "ambiguous_new_maple_sapling_count",
    "followup_live_tree_count", "followup_maple_sapling_count", "recruits_outside_shared_subplots",
    "baseline_seedling_missing_count_records", "followup_seedling_missing_count_records",
    "baseline_seedling_calc_discrepant_records", "followup_seedling_calc_discrepant_records")
  out <- out |> dplyr::mutate(dplyr::across(dplyr::all_of(zero_fill), ~dplyr::coalesce(.x, 0)),
    baseline_seedling_count = dplyr::if_else(.data$baseline_seedling_missing_count_records > 0, NA_real_, .data$baseline_seedling_count),
    followup_seedling_count = dplyr::if_else(.data$followup_seedling_missing_count_records > 0, NA_real_, .data$followup_seedling_count),
    baseline_maple_sapling_tpa = .data$baseline_maple_sapling_tpa_plot_basis / .data$baseline_micrprop_unadj,
    protocol_design_comparable = .data$baseline_designcd == 1 & .data$followup_designcd == 1 &
      .data$baseline_manual >= 5.1 & .data$followup_manual >= 5.1 & .data$followup_kindcd == 2 &
      .data$baseline_kindcd %in% c(1, 2) & .data$baseline_qa_status %in% c(1, 7) & .data$followup_qa_status %in% c(1, 7) &
      !is.na(.data$baseline_microplot_loc) & .data$baseline_microplot_loc == .data$followup_microplot_loc,
    seedling_count_protocol_valid = .data$baseline_seedling_missing_count_records == 0 & .data$followup_seedling_missing_count_records == 0 &
      .data$baseline_seedling_calc_discrepant_records == 0 & .data$followup_seedling_calc_discrepant_records == 0,
    nonstandard_qa_status = .data$baseline_qa_status != 1 | .data$followup_qa_status != 1,
    exact_overlap = .data$exact_microplot_links & abs(.data$baseline_overlap_fraction - 1) <= 0.0001 &
      abs(.data$followup_overlap_fraction - 1) <= 0.0001,
    verified_zero_live_tree_followup = .data$followup_live_tree_count == 0 & .data$followup_comparable &
      .data$primary_pair_eligible & .data$protocol_design_comparable &
      .data$shared_microplot_sampled & .data$frame_proportions_valid & .data$followup_balive == 0,
    # QA codes are exported explicitly; no unsupported assumption that code 7 is
    # an invalid visit is built into eligibility.
    recruitment_eligible = .data$primary_pair_eligible & .data$protocol_design_comparable &
      .data$seedling_count_protocol_valid & .data$shared_microplot_sampled & .data$shared_subplot_predecessor_matches &
      .data$frame_proportions_valid & .data$recruits_outside_shared_subplots == 0 & .data$ambiguous_new_maple_sapling_count == 0,
    recruitment_eligible = dplyr::coalesce(.data$recruitment_eligible, FALSE),
    exclusion_reason = dplyr::case_when(
      !.data$primary_pair_eligible ~ "Source pair ineligible",
      is.na(.data$protocol_design_comparable) | !.data$protocol_design_comparable ~ "Design or remeasurement protocol",
      !.data$seedling_count_protocol_valid ~ "Seedling count discrepancy",
      is.na(.data$shared_microplot_sampled) | !.data$shared_microplot_sampled ~ "Shared subplot sampling unresolved",
      !.data$shared_subplot_predecessor_matches ~ "Subplot predecessor mismatch",
      !.data$frame_proportions_valid ~ "Microplot frame discrepancy",
      .data$recruits_outside_shared_subplots > 0 ~ "Recruit outside shared microplots",
      .data$ambiguous_new_maple_sapling_count > 0 ~ "Ambiguous new live sapling",
      .data$recruitment_eligible ~ "Included",
      TRUE ~ "Unresolved eligibility"
    ),
    outcome_recruitment = dplyr::if_else(.data$recruitment_eligible, as.integer(.data$new_maple_sapling_count > 0), NA_integer_)
  )
  # Correct only fully verified sampled zero-tree visits in this new dataset.
  correct_zero <- out$verified_zero_live_tree_followup & !is.na(out$verified_zero_live_tree_followup)
  zero_tree_fields <- c("followup_total_ba_ft2_ac", "followup_maple_ba_ft2_ac", "followup_maple_sapling_ba_ft2_ac",
    "followup_established_maple_ba_ft2_ac", "followup_nonmaple_ba_ft2_ac", "followup_maple_sapling_records")
  for (field in intersect(zero_tree_fields, names(out))) out[[field]][correct_zero] <- 0
  out$followup_maple_sapling_present[correct_zero] <- FALSE
  out$followup_zero_tree_corrected <- correct_zero
  assert_unique_key(out, pair_keys, "recruitment output pairs")
  stopifnot(nrow(out) == nrow(pairs))

  followup <- records$trees |> dplyr::select("prev_tre_cn", followup_tree_cn = "tree_cn", followup_plt_cn = "plt_cn",
    followup_condid = "condid", followup_statuscd = "statuscd", followup_spcd = "spcd", followup_dia = "dia",
    followup_reconcilecd = "reconcilecd", followup_agentcd = "agentcd", followup_mortyr = "mortyr")
  fates <- baseline_saplings |> dplyr::left_join(followup,
    by = c("tree_cn" = "prev_tre_cn", "current_plt_cn" = "followup_plt_cn")) |>
    dplyr::left_join(out |> dplyr::select(dplyr::all_of(c(pair_keys, "recruitment_eligible", "exact_overlap", "primary_pair_eligible", "protocol_design_comparable",
      "shared_microplot_sampled", "shared_subplot_predecessor_matches", "frame_proportions_valid"))), by = pair_keys) |>
    dplyr::mutate(fate = recruitment_sapling_fate(.data$followup_tree_cn, .data$followup_statuscd,
      .data$followup_spcd, .data$followup_dia, .data$followup_reconcilecd),
      species_reidentified = !is.na(.data$followup_spcd) & .data$followup_spcd != 318,
      tree_link_condition_matches = !is.na(.data$followup_condid) & .data$followup_condid == .data$current_condid,
      fate_eligible = .data$primary_pair_eligible & .data$protocol_design_comparable &
        .data$shared_microplot_sampled & .data$shared_subplot_predecessor_matches & .data$frame_proportions_valid &
        .data$tree_link_condition_matches & .data$fate %in% c("Recorded dead", "Recorded removed", "Alive; reached 5 inches", "Alive; remains sapling"),
      fate_eligible = dplyr::coalesce(.data$fate_eligible, FALSE),
      outcome_death = dplyr::if_else(.data$fate_eligible & .data$followup_statuscd != 3, as.integer(.data$followup_statuscd == 2), NA_integer_),
      outcome_survival = dplyr::if_else(.data$fate_eligible, as.integer(.data$followup_statuscd == 1), NA_integer_),
      reached_five_inches = .data$fate == "Alive; reached 5 inches",
      annual_diameter_increment = dplyr::if_else(.data$fate_eligible & .data$followup_statuscd == 1,
        (.data$followup_dia - .data$dia) / .data$interval_years, NA_real_))
  assert_unique_key(fates, "tree_cn", "tagged recruitment saplings")
  list(pairs = out, fates = fates, links = links, current_trees = current_trees, recruits = recruits)
}
