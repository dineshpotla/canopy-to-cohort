# Planning tools only: no outcome extraction, height model, or validation claim.
plot_balanced_brier_gain <- function(outcome, count_probability, length_probability, plot, county) {
  args <- list(outcome, count_probability, length_probability, plot, county)
  if (!length(outcome) || any(lengths(args) != length(outcome)) || anyNA(outcome) ||
      any(!outcome %in% 0:1) || anyNA(plot) || anyNA(county) ||
      any(!is.finite(c(count_probability, length_probability))) ||
      any(c(count_probability, length_probability) < 0 | c(count_probability, length_probability) > 1)) {
    stop("Invalid paired plot-level score inputs.", call. = FALSE)
  }
  x <- data.frame(plot, county, count_loss = (outcome - count_probability)^2,
    length_loss = (outcome - length_probability)^2)
  plot_scores <- x |> dplyr::group_by(.data$plot) |>
    dplyr::summarise(counties = dplyr::n_distinct(.data$county), county = dplyr::first(.data$county),
      conditions = dplyr::n(), count_brier = mean(.data$count_loss),
      length_brier = mean(.data$length_loss), .groups = "drop")
  if (any(plot_scores$counties != 1L)) stop("A physical plot crosses counties.", call. = FALSE)
  plot_scores$gain <- plot_scores$count_brier - plot_scores$length_brier
  list(plots = plot_scores, summary = data.frame(physical_plots = nrow(plot_scores),
    count_brier = mean(plot_scores$count_brier), length_brier = mean(plot_scores$length_brier),
    gain = mean(plot_scores$gain), loss_difference_sd = stats::sd(plot_scores$gain)))
}

length_study_fraction <- function(ordinary_count, tall_count, ri_standard_count) {
  if (!length(ordinary_count) || length(tall_count) != length(ordinary_count) ||
      length(ri_standard_count) != length(ordinary_count)) {
    stop("Length-study counts must have equal nonzero lengths.", call. = FALSE)
  }
  counts <- c(ordinary_count, tall_count, ri_standard_count)
  if (any(!is.finite(counts)) || any(counts < 0) || any(abs(counts - round(counts)) > 1e-8) ||
      any(ordinary_count != ri_standard_count) || any(tall_count > ri_standard_count)) {
    stop("Unresolved length-study count definitions or invalid counts.", call. = FALSE)
  }
  result <- rep(NA_real_, length(ordinary_count))
  positive <- ordinary_count > 0
  result[positive] <- tall_count[positive] / ordinary_count[positive]
  result
}

paired_loss_precision <- function(loss_difference_sd, half_width, variance_inflation = 1,
                                  retention = 1, confidence = 0.95) {
  args <- list(loss_difference_sd, half_width, variance_inflation, retention, confidence)
  if (any(lengths(args) != 1L) || any(!is.finite(unlist(args))) ||
      loss_difference_sd <= 0 || loss_difference_sd > 1 || half_width <= 0 || half_width >= 1 ||
      variance_inflation < 1 || retention <= 0 || retention > 1 || confidence <= 0 || confidence >= 1) {
    stop("Invalid paired-loss planning inputs.", call. = FALSE)
  }
  z <- stats::qnorm((1 + confidence) / 2)
  unrounded <- (z * loss_difference_sd / half_width)^2
  complete <- max(2, ceiling(variance_inflation * unrounded))
  data.frame(loss_difference_sd, half_width, variance_inflation, retention, confidence,
    independent_equivalent_plots = max(2, ceiling(unrounded)), complete_evaluation_plots = complete,
    candidate_plots_at_assumed_retention = ceiling(complete / retention),
    limitation = "Normal-approximation precision for frozen paired plot-level losses; hypothetical inputs; not power, training size, calibration adequacy, or guaranteed recruitment yield")
}

wilson_planning_interval <- function(proportion, n, confidence = 0.95) {
  if (length(proportion) != 1L || length(n) != 1L || length(confidence) != 1L ||
      any(!is.finite(c(proportion, n, confidence))) || proportion < 0 || proportion > 1 ||
      n < 1 || n != round(n) || confidence <= 0 || confidence >= 1) {
    stop("Invalid Wilson planning inputs.", call. = FALSE)
  }
  z2 <- stats::qnorm((1 + confidence) / 2)^2
  center <- (proportion + z2 / (2 * n)) / (1 + z2 / n)
  half <- sqrt(z2) * sqrt(proportion * (1 - proportion) / n + z2 / (4 * n^2)) / (1 + z2 / n)
  c(lower = center - half, upper = center + half, half_total_width = half)
}

recall_precision_events <- function(proportion, half_width, confidence = 0.95) {
  if (length(half_width) != 1L || !is.finite(half_width) || half_width <= 0 || half_width >= 0.5) {
    stop("Invalid recall precision target.", call. = FALSE)
  }
  wilson_planning_interval(proportion, 1, confidence)
  lower <- 0L
  upper <- 1L
  while (wilson_planning_interval(proportion, upper, confidence)[["half_total_width"]] > half_width) {
    if (upper > 1e7) stop("Recall precision target is outside the planning range.", call. = FALSE)
    upper <- upper * 2L
  }
  while (upper - lower > 1L) {
    middle <- floor((lower + upper) / 2)
    if (wilson_planning_interval(proportion, middle, confidence)[["half_total_width"]] <= half_width) {
      upper <- middle
    } else lower <- middle
  }
  interval <- wilson_planning_interval(proportion, upper, confidence)
  data.frame(assumed_recall = proportion, target_half_total_width = half_width,
    independent_event_units = upper, confidence, lower = unname(interval[["lower"]]),
    upper = unname(interval[["upper"]]),
    limitation = "Wilson width evaluated at an assumed proportion, not expected interval width or guaranteed precision; fixed-rule independent-event illustration, not paired-policy, calibration, or training sample size")
}

extract_ri_opportunity_metadata <- function(con, forest_codes) {
  if (!length(forest_codes) || any(!is.finite(forest_codes)) || any(forest_codes != round(forest_codes))) {
    stop("Invalid forest codes for the RI opportunity census.", call. = FALSE)
  }
  code_sql <- paste(as.integer(forest_codes), collapse = ",")
  # TREE is consulted only for baseline established-maple membership. No
  # follow-up TREE counts, reconciliation codes, or recruitment outcomes enter.
  sql <- paste0(
    "SELECT bp.CN AS BASELINE_PLT_CN, bc.CONDID AS BASELINE_CONDID,",
    " bc.STATECD, bc.UNITCD, bc.COUNTYCD, bc.PLOT,",
    " bp.MEASYEAR AS BASELINE_MEASYEAR, bp.MEASMON AS BASELINE_MEASMON,",
    " np.CN AS CURRENT_PLT_CN, np.MEASYEAR AS FOLLOWUP_MEASYEAR, np.MEASMON AS FOLLOWUP_MEASMON,",
    " np.PLOT_STATUS_CD AS FOLLOWUP_PLOT_STATUS_CD, np.DESIGNCD AS FOLLOWUP_DESIGNCD,",
    " EXISTS (SELECT 1 FROM SEEDLING s WHERE s.PLT_CN=bp.CN AND s.CONDID=bc.CONDID",
    " AND s.SPCD=318 AND s.TREECOUNT>0) AS STANDARD_MAPLE_RECORD_PRESENT",
    " FROM PLOT bp JOIN COND bc ON bc.PLT_CN=bp.CN",
    " LEFT JOIN PLOT np ON np.PREV_PLT_CN=bp.CN",
    " WHERE EXISTS (SELECT 1 FROM PLOT_REGEN r WHERE r.PLT_CN=bp.CN)",
    " AND EXISTS (SELECT 1 FROM TREE t WHERE t.PLT_CN=bp.CN AND t.CONDID=bc.CONDID",
    " AND t.SPCD=318 AND t.STATUSCD=1 AND t.DIA>=5)",
    " AND bp.PLOT_STATUS_CD=1 AND bp.DESIGNCD=1 AND bp.MANUAL>=1",
    " AND bc.COND_STATUS_CD=1 AND bc.MICRPROP_UNADJ>0 AND bc.FORTYPCD IN (", code_sql, ")"
  )
  d <- standardize_names(DBI::dbGetQuery(con, sql))
  assert_unique_key(d, c("baseline_plt_cn", "baseline_condid", "current_plt_cn"), "RI opportunity metadata")
  d$baseline_plt_cn <- as.character(d$baseline_plt_cn)
  d$current_plt_cn <- as.character(d$current_plt_cn)
  d$physical_plot_key <- with(d, paste(statecd, unitcd, countycd, plot, sep = "-"))
  d$geoid <- with(d, sprintf("%02d%03d", statecd, countycd))
  d$baseline_condition_key <- paste(d$baseline_plt_cn, d$baseline_condid, sep = ":")
  successors <- d |> dplyr::group_by(.data$baseline_condition_key) |>
    dplyr::summarise(successor_count = dplyr::n_distinct(.data$current_plt_cn, na.rm = TRUE), .groups = "drop")
  d <- dplyr::left_join(d, successors, by = "baseline_condition_key")
  d$interval_years <- with(d, followup_measyear - baseline_measyear + (followup_measmon - baseline_measmon) / 12)
  d$single_successor <- d$successor_count == 1
  d$followup_plot_compatible <- with(d, single_successor & !is.na(followup_plot_status_cd) &
    followup_plot_status_cd == 1 & !is.na(followup_designcd) & followup_designcd == 1)
  d$date_window <- with(d, is.finite(interval_years) & interval_years >= 4.5 & interval_years <= 8.5)
  d
}
