longitudinal_pair_cte <- function(evalid) {
  evalid <- as.integer(evalid)
  if (length(evalid) != 1L || is.na(evalid)) {
    stop("A single integer EVALID is required.", call. = FALSE)
  }
  paste0(
    "WITH eval_plots AS (",
    " SELECT DISTINCT PLT_CN FROM POP_PLOT_STRATUM_ASSGN WHERE EVALID = ", evalid,
    "), pair_overlap AS (",
    " SELECT m.PLT_CN AS CURRENT_PLT_CN, m.CONDID AS CURRENT_CONDID,",
    " m.PREV_PLT_CN AS BASELINE_PLT_CN, m.PREVCOND AS BASELINE_CONDID,",
    " SUM(COALESCE(m.SUBPTYP_PROP_CHNG, 0.0)) / 4.0 AS OVERLAP_PROP,",
    " COUNT(DISTINCT m.SUBP) AS LINKED_MICROPLOTS",
    " FROM SUBP_COND_CHNG_MTRX m",
    " JOIN eval_plots e ON e.PLT_CN = m.PLT_CN",
    " WHERE m.SUBPTYP = 2 AND COALESCE(m.SUBPTYP_PROP_CHNG, 0.0) > 0",
    " GROUP BY m.PLT_CN, m.CONDID, m.PREV_PLT_CN, m.PREVCOND",
    "), current_degree AS (",
    " SELECT CURRENT_PLT_CN, CURRENT_CONDID, COUNT(*) AS CURRENT_PAIR_DEGREE",
    " FROM pair_overlap GROUP BY CURRENT_PLT_CN, CURRENT_CONDID",
    "), baseline_degree AS (",
    " SELECT BASELINE_PLT_CN, BASELINE_CONDID, COUNT(*) AS BASELINE_PAIR_DEGREE",
    " FROM pair_overlap GROUP BY BASELINE_PLT_CN, BASELINE_CONDID",
    ") "
  )
}

extract_longitudinal_pair_candidates <- function(con, evalid) {
  sql <- paste0(
    longitudinal_pair_cte(evalid),
    "SELECT",
    " po.BASELINE_PLT_CN, po.BASELINE_CONDID, po.CURRENT_PLT_CN, po.CURRENT_CONDID,",
    " po.OVERLAP_PROP, po.LINKED_MICROPLOTS,",
    " bd.BASELINE_PAIR_DEGREE, cd.CURRENT_PAIR_DEGREE,",
    " bp.INVYR AS BASELINE_INVYR, bp.MEASYEAR AS BASELINE_MEASYEAR,",
    " bp.MEASMON AS BASELINE_MEASMON, bp.MEASDAY AS BASELINE_MEASDAY,",
    " bp.PLOT_STATUS_CD AS BASELINE_PLOT_STATUS_CD, bp.MANUAL AS BASELINE_MANUAL,",
    " bp.DESIGNCD AS BASELINE_DESIGNCD, bp.MACRO_BREAKPOINT_DIA AS BASELINE_MACRO_BREAKPOINT_DIA,",
    " cp.INVYR AS FOLLOWUP_INVYR, cp.MEASYEAR AS FOLLOWUP_MEASYEAR,",
    " cp.MEASMON AS FOLLOWUP_MEASMON, cp.MEASDAY AS FOLLOWUP_MEASDAY,",
    " cp.PLOT_STATUS_CD AS FOLLOWUP_PLOT_STATUS_CD, cp.MANUAL AS FOLLOWUP_MANUAL,",
    " cp.DESIGNCD AS FOLLOWUP_DESIGNCD, cp.MACRO_BREAKPOINT_DIA AS FOLLOWUP_MACRO_BREAKPOINT_DIA,",
    " cp.PREV_PLT_CN AS PLOT_DECLARED_PREV_PLT_CN,",
    " bc.STATECD, bc.UNITCD, bc.COUNTYCD, bc.PLOT, cn.COUNTYNM,",
    " bc.COND_STATUS_CD AS BASELINE_COND_STATUS_CD, bc.FORTYPCD AS BASELINE_FORTYPCD,",
    " bc.CONDPROP_UNADJ AS BASELINE_CONDPROP_UNADJ,",
    " bc.MICRPROP_UNADJ AS BASELINE_MICRPROP_UNADJ,",
    " bc.SUBPPROP_UNADJ AS BASELINE_SUBPPROP_UNADJ,",
    " bc.MACRPROP_UNADJ AS BASELINE_MACRPROP_UNADJ,",
    " bc.STDAGE AS BASELINE_STAND_AGE, bc.STDSZCD AS BASELINE_STAND_SIZE_CD,",
    " bc.SITECLCD AS BASELINE_SITE_CLASS_CD, bc.SLOPE AS BASELINE_SLOPE,",
    " bc.ASPECT AS BASELINE_ASPECT, bc.PHYSCLCD AS BASELINE_PHYSCLCD,",
    " bc.BALIVE AS BASELINE_BALIVE,",
    " bc.DSTRBCD1 AS BASELINE_DSTRBCD1, bc.DSTRBYR1 AS BASELINE_DSTRBYR1,",
    " bc.DSTRBCD2 AS BASELINE_DSTRBCD2, bc.DSTRBYR2 AS BASELINE_DSTRBYR2,",
    " bc.DSTRBCD3 AS BASELINE_DSTRBCD3, bc.DSTRBYR3 AS BASELINE_DSTRBYR3,",
    " bc.TRTCD1 AS BASELINE_TRTCD1, bc.TRTYR1 AS BASELINE_TRTYR1,",
    " bc.TRTCD2 AS BASELINE_TRTCD2, bc.TRTYR2 AS BASELINE_TRTYR2,",
    " bc.TRTCD3 AS BASELINE_TRTCD3, bc.TRTYR3 AS BASELINE_TRTYR3,",
    " cc.COND_STATUS_CD AS FOLLOWUP_COND_STATUS_CD, cc.FORTYPCD AS FOLLOWUP_FORTYPCD,",
    " cc.CONDPROP_UNADJ AS FOLLOWUP_CONDPROP_UNADJ,",
    " cc.MICRPROP_UNADJ AS FOLLOWUP_MICRPROP_UNADJ,",
    " cc.SUBPPROP_UNADJ AS FOLLOWUP_SUBPPROP_UNADJ,",
    " cc.MACRPROP_UNADJ AS FOLLOWUP_MACRPROP_UNADJ,",
    " cc.STDAGE AS FOLLOWUP_STAND_AGE, cc.STDSZCD AS FOLLOWUP_STAND_SIZE_CD,",
    " cc.BALIVE AS FOLLOWUP_BALIVE,",
    " cc.DSTRBCD1 AS FOLLOWUP_DSTRBCD1, cc.DSTRBYR1 AS FOLLOWUP_DSTRBYR1,",
    " cc.DSTRBCD2 AS FOLLOWUP_DSTRBCD2, cc.DSTRBYR2 AS FOLLOWUP_DSTRBYR2,",
    " cc.DSTRBCD3 AS FOLLOWUP_DSTRBCD3, cc.DSTRBYR3 AS FOLLOWUP_DSTRBYR3,",
    " cc.TRTCD1 AS FOLLOWUP_TRTCD1, cc.TRTYR1 AS FOLLOWUP_TRTYR1,",
    " cc.TRTCD2 AS FOLLOWUP_TRTCD2, cc.TRTYR2 AS FOLLOWUP_TRTYR2,",
    " cc.TRTCD3 AS FOLLOWUP_TRTCD3, cc.TRTYR3 AS FOLLOWUP_TRTYR3",
    " FROM pair_overlap po",
    " JOIN current_degree cd ON cd.CURRENT_PLT_CN = po.CURRENT_PLT_CN",
    "  AND cd.CURRENT_CONDID = po.CURRENT_CONDID",
    " JOIN baseline_degree bd ON bd.BASELINE_PLT_CN = po.BASELINE_PLT_CN",
    "  AND bd.BASELINE_CONDID = po.BASELINE_CONDID",
    " LEFT JOIN PLOT bp ON bp.CN = po.BASELINE_PLT_CN",
    " LEFT JOIN PLOT cp ON cp.CN = po.CURRENT_PLT_CN",
    " LEFT JOIN COND bc ON bc.PLT_CN = po.BASELINE_PLT_CN AND bc.CONDID = po.BASELINE_CONDID",
    " LEFT JOIN COND cc ON cc.PLT_CN = po.CURRENT_PLT_CN AND cc.CONDID = po.CURRENT_CONDID",
    " LEFT JOIN (",
    "  SELECT STATECD, COUNTYCD, MIN(COUNTYNM) AS COUNTYNM",
    "  FROM COUNTY GROUP BY STATECD, COUNTYCD",
    " ) cn ON cn.STATECD = bc.STATECD AND cn.COUNTYCD = bc.COUNTYCD",
    " ORDER BY po.BASELINE_PLT_CN, po.BASELINE_CONDID, po.CURRENT_PLT_CN, po.CURRENT_CONDID"
  )

  standardize_names(DBI::dbGetQuery(con, sql)) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      baseline_plt_cn = as.character(.data$baseline_plt_cn),
      current_plt_cn = as.character(.data$current_plt_cn),
      plot_declared_prev_plt_cn = as.character(.data$plot_declared_prev_plt_cn),
      geoid = sprintf("%02d%03d", .data$statecd, .data$countycd),
      county_name = as.character(.data$countynm),
      physical_plot_key = paste(.data$statecd, .data$unitcd, .data$countycd, .data$plot, sep = "-"),
      interval_years = (dplyr::coalesce(.data$followup_measyear, .data$followup_invyr) -
        dplyr::coalesce(.data$baseline_measyear, .data$baseline_invyr)) +
        (dplyr::coalesce(.data$followup_measmon, 7) - dplyr::coalesce(.data$baseline_measmon, 7)) / 12,
      baseline_overlap_fraction = .data$overlap_prop / .data$baseline_micrprop_unadj,
      followup_overlap_fraction = .data$overlap_prop / .data$followup_micrprop_unadj,
      strict_one_to_one = .data$baseline_pair_degree == 1L & .data$current_pair_degree == 1L,
      plot_prev_link_matches = .data$baseline_plt_cn == .data$plot_declared_prev_plt_cn
    ) |>
    dplyr::select(-dplyr::all_of("countynm"))
}

extract_longitudinal_trees <- function(con, evalid) {
  sql <- paste0(
    longitudinal_pair_cte(evalid),
    ", visit_keys AS (",
    " SELECT DISTINCT BASELINE_PLT_CN AS PLT_CN, BASELINE_CONDID AS CONDID FROM pair_overlap",
    " UNION",
    " SELECT DISTINCT CURRENT_PLT_CN AS PLT_CN, CURRENT_CONDID AS CONDID FROM pair_overlap",
    ")",
    " SELECT CAST(t.PLT_CN AS TEXT) AS PLT_CN, t.CONDID, CAST(t.CN AS TEXT) AS TREE_CN,",
    " CAST(t.SPCD AS INTEGER) AS SPCD, t.DIA, t.TPA_UNADJ, t.STATUSCD,",
    " p.DESIGNCD, p.MACRO_BREAKPOINT_DIA",
    " FROM TREE t",
    " JOIN visit_keys k ON k.PLT_CN = t.PLT_CN AND k.CONDID = t.CONDID",
    " JOIN PLOT p ON p.CN = t.PLT_CN",
    " WHERE t.STATUSCD = 1 AND t.SPCD IS NOT NULL"
  )
  standardize_names(DBI::dbGetQuery(con, sql)) |>
    tibble::as_tibble() |>
    dplyr::mutate(plt_cn = as.character(.data$plt_cn), tree_cn = as.character(.data$tree_cn))
}

extract_longitudinal_seedlings <- function(con, evalid) {
  sql <- paste0(
    longitudinal_pair_cte(evalid),
    ", visit_keys AS (",
    " SELECT DISTINCT BASELINE_PLT_CN AS PLT_CN, BASELINE_CONDID AS CONDID FROM pair_overlap",
    " UNION",
    " SELECT DISTINCT CURRENT_PLT_CN AS PLT_CN, CURRENT_CONDID AS CONDID FROM pair_overlap",
    ")",
    " SELECT CAST(s.PLT_CN AS TEXT) AS PLT_CN, s.CONDID, CAST(s.CN AS TEXT) AS SEEDLING_CN,",
    " CAST(s.SPCD AS INTEGER) AS SPCD, s.SUBP, s.TREECOUNT, s.TREECOUNT_CALC, s.TPA_UNADJ",
    " FROM SEEDLING s",
    " JOIN visit_keys k ON k.PLT_CN = s.PLT_CN AND k.CONDID = s.CONDID"
  )
  standardize_names(DBI::dbGetQuery(con, sql)) |>
    tibble::as_tibble() |>
    dplyr::mutate(plt_cn = as.character(.data$plt_cn), seedling_cn = as.character(.data$seedling_cn))
}

longitudinal_visit_conditions <- function(pairs) {
  assert_columns(
    pairs,
    c(
      "baseline_plt_cn", "baseline_condid", "baseline_micrprop_unadj",
      "baseline_subpprop_unadj", "baseline_macrprop_unadj",
      "current_plt_cn", "current_condid", "followup_micrprop_unadj",
      "followup_subpprop_unadj", "followup_macrprop_unadj"
    ),
    "longitudinal pair candidates"
  )
  baseline <- pairs |>
    dplyr::transmute(
      plt_cn = .data$baseline_plt_cn,
      condid = .data$baseline_condid,
      micrprop_unadj = .data$baseline_micrprop_unadj,
      subpprop_unadj = .data$baseline_subpprop_unadj,
      macrprop_unadj = .data$baseline_macrprop_unadj
    )
  followup <- pairs |>
    dplyr::transmute(
      plt_cn = .data$current_plt_cn,
      condid = .data$current_condid,
      micrprop_unadj = .data$followup_micrprop_unadj,
      subpprop_unadj = .data$followup_subpprop_unadj,
      macrprop_unadj = .data$followup_macrprop_unadj
    )
  dplyr::bind_rows(baseline, followup) |>
    dplyr::distinct(.data$plt_cn, .data$condid, .keep_all = TRUE)
}

aggregate_species_basal_area <- function(trees, conditions, target_spcd, prefix) {
  assert_columns(
    trees,
    c("plt_cn", "condid", "spcd", "dia", "tpa_unadj", "statuscd"),
    "longitudinal tree extract"
  )
  assert_columns(
    conditions,
    c("plt_cn", "condid", "micrprop_unadj", "subpprop_unadj", "macrprop_unadj"),
    "longitudinal visit conditions"
  )
  target_spcd <- as.integer(target_spcd)
  if (length(target_spcd) != 1L || is.na(target_spcd)) {
    stop("A single target species code is required.", call. = FALSE)
  }
  if (length(prefix) != 1L || !grepl("^[a-z][a-z0-9_]*$", prefix)) {
    stop("A snake-case output prefix is required.", call. = FALSE)
  }

  observed <- trees |>
    dplyr::filter(
      .data$statuscd == 1L,
      .data$spcd == .env$target_spcd,
      !is.na(.data$dia), .data$dia >= 0,
      !is.na(.data$tpa_unadj), .data$tpa_unadj >= 0
    ) |>
    dplyr::left_join(conditions, by = c("plt_cn", "condid")) |>
    dplyr::mutate(
      macro_breakpoint_dia = dplyr::coalesce(.data$macro_breakpoint_dia, Inf),
      sampling_basis = tree_sampling_basis(.data$dia, .data$macro_breakpoint_dia),
      condition_proportion = tree_condition_proportion(
        .data$sampling_basis,
        .data$micrprop_unadj,
        .data$subpprop_unadj,
        .data$macrprop_unadj
      ),
      ba_ft2_ac_contribution = dplyr::if_else(
        is.finite(.data$condition_proportion) & .data$condition_proportion > 0,
        tree_basal_area_contribution(.data$dia, .data$tpa_unadj) / .data$condition_proportion,
        NA_real_
      )
    )
  if (anyNA(observed$ba_ft2_ac_contribution)) {
    stop("Species basal-area normalization encountered a missing or nonpositive condition proportion.", call. = FALSE)
  }

  summarized <- observed |>
    dplyr::group_by(.data$plt_cn, .data$condid) |>
    dplyr::summarise(
      ba_ft2_ac = sum(.data$ba_ft2_ac_contribution),
      sapling_ba_ft2_ac = sum(.data$ba_ft2_ac_contribution[.data$dia >= 1 & .data$dia < 5]),
      established_ba_ft2_ac = sum(.data$ba_ft2_ac_contribution[.data$dia >= 5]),
      records = dplyr::n(),
      sapling_records = sum(.data$dia >= 1 & .data$dia < 5),
      established_records = sum(.data$dia >= 5),
      .groups = "drop"
    )
  names(summarized)[-(1:2)] <- paste0(prefix, "_", names(summarized)[-(1:2)])

  conditions |>
    dplyr::select("plt_cn", "condid") |>
    dplyr::distinct() |>
    dplyr::left_join(summarized, by = c("plt_cn", "condid")) |>
    dplyr::mutate(dplyr::across(dplyr::starts_with(paste0(prefix, "_")), ~ dplyr::coalesce(.x, 0)))
}

prefix_visit_metrics <- function(data, visit, plt_column, cond_column) {
  renamed <- data
  names(renamed)[names(renamed) == "plt_cn"] <- plt_column
  names(renamed)[names(renamed) == "condid"] <- cond_column
  metric_names <- setdiff(names(renamed), c(plt_column, cond_column))
  names(renamed)[match(metric_names, names(renamed))] <- paste0(visit, "_", metric_names)
  renamed
}

classify_seedling_transition <- function(baseline_detected, followup_detected) {
  dplyr::case_when(
    is.na(baseline_detected) | is.na(followup_detected) ~ NA_character_,
    baseline_detected == 0L & followup_detected == 0L ~ "Persistent non-detection",
    baseline_detected == 0L & followup_detected == 1L ~ "Appearance",
    baseline_detected == 1L & followup_detected == 0L ~ "Loss",
    baseline_detected == 1L & followup_detected == 1L ~ "Persistence",
    TRUE ~ NA_character_
  )
}

build_longitudinal_analysis <- function(
    pairs,
    trees,
    seedlings,
    sugar_maple_spcd,
    beech_spcd,
    forest_codes,
    minimum_overlap = 0.90) {
  conditions <- longitudinal_visit_conditions(pairs)
  tree_metrics <- aggregate_tree_metrics(trees, sugar_maple_spcd, conditions)
  beech_metrics <- aggregate_species_basal_area(trees, conditions, beech_spcd, "beech")
  seedling_metrics <- aggregate_seedling_metrics(seedlings, sugar_maple_spcd, conditions)

  baseline_tree <- prefix_visit_metrics(tree_metrics, "baseline", "baseline_plt_cn", "baseline_condid")
  followup_tree <- prefix_visit_metrics(tree_metrics, "followup", "current_plt_cn", "current_condid")
  baseline_beech <- prefix_visit_metrics(beech_metrics, "baseline", "baseline_plt_cn", "baseline_condid")
  followup_beech <- prefix_visit_metrics(beech_metrics, "followup", "current_plt_cn", "current_condid")
  baseline_seedling <- prefix_visit_metrics(
    seedling_metrics |> dplyr::select(-dplyr::all_of("micrprop_unadj")),
    "baseline",
    "baseline_plt_cn",
    "baseline_condid"
  )
  followup_seedling <- prefix_visit_metrics(
    seedling_metrics |> dplyr::select(-dplyr::all_of("micrprop_unadj")),
    "followup",
    "current_plt_cn",
    "current_condid"
  )

  analysis <- pairs |>
    dplyr::left_join(baseline_tree, by = c("baseline_plt_cn", "baseline_condid")) |>
    dplyr::left_join(followup_tree, by = c("current_plt_cn", "current_condid")) |>
    dplyr::left_join(baseline_beech, by = c("baseline_plt_cn", "baseline_condid")) |>
    dplyr::left_join(followup_beech, by = c("current_plt_cn", "current_condid")) |>
    dplyr::left_join(baseline_seedling, by = c("baseline_plt_cn", "baseline_condid")) |>
    dplyr::left_join(followup_seedling, by = c("current_plt_cn", "current_condid")) |>
    dplyr::mutate(
      baseline_group_800 = .data$baseline_fortypcd %in% as.integer(.env$forest_codes),
      baseline_comparable = .data$baseline_plot_status_cd == 1L &
        .data$baseline_cond_status_cd == 1L &
        .data$baseline_group_800 &
        !is.na(.data$baseline_micrprop_unadj) & .data$baseline_micrprop_unadj > 0,
      baseline_established_maple = dplyr::coalesce(.data$baseline_established_maple_records, 0) > 0,
      followup_comparable = .data$followup_plot_status_cd == 1L &
        .data$followup_cond_status_cd == 1L &
        !is.na(.data$followup_micrprop_unadj) & .data$followup_micrprop_unadj > 0,
      overlap_adequate = .data$baseline_overlap_fraction >= .env$minimum_overlap &
        .data$followup_overlap_fraction >= .env$minimum_overlap,
      valid_interval = is.finite(.data$interval_years) & .data$interval_years > 0,
      primary_pair_eligible = .data$baseline_comparable &
        .data$baseline_established_maple &
        .data$followup_comparable &
        .data$strict_one_to_one &
        .data$overlap_adequate &
        .data$valid_interval,
      baseline_seedling_detected = as.integer(.data$baseline_maple_seedling_detected),
      followup_seedling_detected = as.integer(.data$followup_maple_seedling_detected),
      seedling_transition = factor(
        classify_seedling_transition(
          .data$baseline_seedling_detected,
          .data$followup_seedling_detected
        ),
        levels = c("Persistent non-detection", "Appearance", "Loss", "Persistence")
      ),
      seedling_detection_loss = dplyr::if_else(
        .data$baseline_seedling_detected == 1L,
        1L - .data$followup_seedling_detected,
        NA_integer_
      ),
      seedling_detection_appearance = dplyr::if_else(
        .data$baseline_seedling_detected == 0L,
        .data$followup_seedling_detected,
        NA_integer_
      ),
      baseline_other_nonmaple_ba_ft2_ac = pmax(
        0,
        dplyr::coalesce(.data$baseline_nonmaple_ba_ft2_ac, 0) -
          dplyr::coalesce(.data$baseline_beech_sapling_ba_ft2_ac, 0)
      ),
      followup_group_800 = .data$followup_fortypcd %in% as.integer(.env$forest_codes)
    )

  primary <- analysis |>
    dplyr::filter(.data$primary_pair_eligible) |>
    dplyr::arrange(.data$baseline_plt_cn, .data$baseline_condid)
  assert_unique_key(primary, c("baseline_plt_cn", "baseline_condid"), "primary longitudinal pairs")
  assert_unique_key(primary, c("current_plt_cn", "current_condid"), "primary longitudinal pairs")
  list(
    candidates = analysis,
    primary = primary,
    tree_metrics = tree_metrics,
    beech_metrics = beech_metrics,
    seedling_metrics = seedling_metrics
  )
}

longitudinal_cohort_flow <- function(candidates) {
  steps <- list(
    "Positive microplot condition links in the current evaluation" = rep(TRUE, nrow(candidates)),
    "Baseline sampled northern-hardwood conditions" = candidates$baseline_comparable,
    "Baseline conditions with established sugar maple" = candidates$baseline_comparable & candidates$baseline_established_maple,
    "Bidirectional one-to-one condition mapping" = candidates$baseline_comparable & candidates$baseline_established_maple & candidates$strict_one_to_one,
    "Comparable accessible-forest follow-up" = candidates$baseline_comparable & candidates$baseline_established_maple & candidates$strict_one_to_one & candidates$followup_comparable,
    "At least 90% shared microplot footprint and positive interval" = candidates$primary_pair_eligible
  )
  purrr::imap_dfr(steps, function(keep, step) {
    selected <- candidates[!is.na(keep) & keep, , drop = FALSE]
    tibble::tibble(
      step = step,
      pair_rows = nrow(selected),
      baseline_conditions = dplyr::n_distinct(paste(selected$baseline_plt_cn, selected$baseline_condid, sep = ":")),
      followup_conditions = dplyr::n_distinct(paste(selected$current_plt_cn, selected$current_condid, sep = ":")),
      physical_plots = dplyr::n_distinct(selected$physical_plot_key)
    )
  })
}

longitudinal_transition_summary <- function(primary) {
  primary |>
    dplyr::filter(!is.na(.data$seedling_transition)) |>
    dplyr::count(.data$seedling_transition, name = "conditions") |>
    dplyr::mutate(
      baseline_state = dplyr::if_else(
        .data$seedling_transition %in% c("Loss", "Persistence"),
        "Detected",
        "Not detected"
      )
    ) |>
    dplyr::group_by(.data$baseline_state) |>
    dplyr::mutate(
      baseline_state_total = sum(.data$conditions),
      fraction_within_baseline_state = .data$conditions / .data$baseline_state_total
    ) |>
    dplyr::ungroup()
}

longitudinal_mapping_audit <- function(candidates) {
  tibble::tibble(
    metric = c(
      "Candidate pair rows",
      "Bidirectional one-to-one pair rows",
      "Baseline split pair rows",
      "Follow-up merge pair rows",
      "Broken baseline condition references",
      "Broken follow-up condition references",
      "Plot predecessor-link mismatches",
      "Minimum baseline overlap fraction among strict pairs",
      "Median baseline overlap fraction among strict pairs",
      "Minimum follow-up overlap fraction among strict pairs",
      "Median follow-up overlap fraction among strict pairs"
    ),
    value = c(
      nrow(candidates),
      sum(candidates$strict_one_to_one, na.rm = TRUE),
      sum(candidates$baseline_pair_degree > 1L, na.rm = TRUE),
      sum(candidates$current_pair_degree > 1L, na.rm = TRUE),
      sum(is.na(candidates$baseline_cond_status_cd)),
      sum(is.na(candidates$followup_cond_status_cd)),
      sum(!candidates$plot_prev_link_matches, na.rm = TRUE),
      suppressWarnings(min(candidates$baseline_overlap_fraction[candidates$strict_one_to_one], na.rm = TRUE)),
      suppressWarnings(stats::median(candidates$baseline_overlap_fraction[candidates$strict_one_to_one], na.rm = TRUE)),
      suppressWarnings(min(candidates$followup_overlap_fraction[candidates$strict_one_to_one], na.rm = TRUE)),
      suppressWarnings(stats::median(candidates$followup_overlap_fraction[candidates$strict_one_to_one], na.rm = TRUE))
    ),
    note = c(
      "Aggregated positive SUBPTYP=2 links; one row per condition pair",
      "Both baseline and follow-up conditions have exactly one linked condition",
      "A baseline condition links to multiple follow-up conditions",
      "A follow-up condition links to multiple baseline conditions",
      "Matrix baseline keys without a matching COND record",
      "Matrix follow-up keys without a matching COND record",
      "Matrix PREV_PLT_CN differs from the predecessor declared on PLOT",
      "Relative overlap is (sum SUBPTYP_PROP_CHNG / 4) / baseline MICRPROP_UNADJ",
      "Strict-pair footprint diagnostic",
      "Relative overlap is (sum SUBPTYP_PROP_CHNG / 4) / follow-up MICRPROP_UNADJ",
      "Strict-pair footprint diagnostic"
    )
  )
}
