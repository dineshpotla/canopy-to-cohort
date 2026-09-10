# Manuscript reconciliation only; no new predictive models or outcome selection.
recruitment_paper_support <- function(data) {
  eligible <- data[data$recruitment_eligible, , drop = FALSE]
  populations <- list("All eligible pairs" = eligible,
    "Baseline seedlings detected" = eligible[eligible$baseline_seedling_count > 0, , drop = FALSE])
  dplyr::bind_rows(lapply(names(populations), function(population) {
    x <- populations[[population]]
    if (!nrow(x) || anyNA(x$outcome_recruitment)) stop("Incomplete paper population.", call. = FALSE)
    data.frame(population = population, conditions = nrow(x),
      physical_plots = length(unique(x$physical_plot_key)), counties = length(unique(x$geoid)),
      events = sum(x$outcome_recruitment), new_saplings = sum(x$new_maple_sapling_count),
      baseline_year_min = min(x$baseline_measyear), baseline_year_max = max(x$baseline_measyear),
      followup_year_min = min(x$followup_measyear), followup_year_max = max(x$followup_measyear),
      interval_years_min = min(x$interval_years), interval_years_median = stats::median(x$interval_years),
      interval_years_max = max(x$interval_years),
      coverage_min = min(x$baseline_micrprop_unadj), coverage_median = stats::median(x$baseline_micrprop_unadj),
      coverage_max = max(x$baseline_micrprop_unadj),
      scoring_unit = "Condition interval; equal condition weight; not a survey-weighted population estimate")
  }))
}

recruitment_paper_audit <- function(data, bundle, validation, paired, temporal,
    bootstrap, survey_bootstrap, fates, fate_summary, growth) {
  checks <- list()
  check <- function(name, passed, detail) {
    checks[[length(checks) + 1L]] <<- data.frame(check = name, passed = isTRUE(passed), detail = detail)
  }
  same <- function(x, y) isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = 1e-10))
  key <- function(x) paste(x$current_plt_cn, x$current_condid, sep = "/")
  selected <- data[data$recruitment_eligible, , drop = FALSE]
  check("Uncertain outcomes remain missing", all(is.na(data$outcome_recruitment[!data$recruitment_eligible])),
    "Excluded intervals are not biological zeros")
  check("Entrant outcome reconciles", all(selected$outcome_recruitment == as.integer(selected$new_maple_sapling_count > 0)),
    "Condition outcomes agree with qualifying entrant counts")
  for (population in names(bundle)) {
    m <- bundle[[population]]
    expected <- if (population == "All eligible pairs") selected else selected[selected$baseline_seedling_count > 0, ]
    check(paste(population, "matched rows"), setequal(key(m$data), key(expected)) &&
      !anyDuplicated(key(m$data)) && nrow(m$data) == nrow(expected), "Model rows equal the audited population")
    ordered <- expected[match(key(m$data), key(expected)), ]
    check(paste(population, "matched outcomes"), same(m$data$outcome_recruitment, ordered$outcome_recruitment),
      "Stored model outcomes agree in row order with rebuilt records")
    check(paste(population, "prediction matrix"), nrow(m$crossfit$predictions) == nrow(m$data) &&
      identical(colnames(m$crossfit$predictions), names(recruitment_specifications())) &&
      all(is.finite(m$crossfit$predictions)), "All four models predict every identical case")
    for (group in c("physical_plot_key", "geoid")) {
      check(paste(population, group, "folds"), all(vapply(split(m$crossfit$fold, m$data[[group]]),
        function(x) length(unique(x)) == 1L, logical(1))), "No plot or county crosses evaluation folds")
    }
    check(paste(population, "convergence"), all(m$crossfit$diagnostics$converged), "Every original held-out fit converged")
    fields <- c("observations", "events", "brier_score", "log_loss", "roc_auc", "average_precision",
      "calibration_intercept", "calibration_slope", "mean_predicted_probability", "observed_expected_ratio",
      "top_capacity", "top_events")
    for (model in names(recruitment_specifications())) {
      measured <- recruitment_metrics(m$data$outcome_recruitment, m$crossfit$predictions[, model],
        row_order = m$data$audit_row, prevalence_model = model == "Prevalence")
      exported <- validation[validation$population == population & validation$model == model, ]
      check(paste(population, model, "metrics"), nrow(exported) == 1L &&
        same(measured[fields], unlist(exported[fields])), "Recomputed from local held-out predictions with equal condition weights")
      test_rows <- m$temporal$test_rows
      measured_test <- recruitment_metrics(m$data$outcome_recruitment[test_rows], m$temporal$predictions[, model],
        row_order = m$data$audit_row[test_rows], prevalence_model = model == "Prevalence")
      exported_test <- temporal[temporal$population == population & temporal$model == model, ]
      check(paste(population, model, "temporal metrics"), nrow(exported_test) == 1L &&
        same(measured_test[fields], unlist(exported_test[fields])), "Recomputed from stored later-year predictions")
    }
    check(paste(population, "temporal separation"), !length(intersect(
      m$data$physical_plot_key[m$temporal$test_rows], m$data$physical_plot_key[-m$temporal$test_rows])),
      "Training and testing share no physical plot")
    differences <- recruitment_comparisons(validation[validation$population == population, ])
    comparison_key <- function(x) paste(x$model, x$reference, x$metric)
    exported <- paired[paired$population == population, ]
    expected_differences <- differences$difference[match(comparison_key(exported), comparison_key(differences))]
    check(paste(population, "paired differences"), nrow(exported) == nrow(differences) &&
      !anyNA(expected_differences) && same(exported$difference, expected_differences) &&
      all(exported$lower <= exported$upper), "Contrasts use named model minus matched reference")
  }
  for (label in c("Models", "Survey diagnostics")) {
    b <- if (label == "Models") bootstrap else survey_bootstrap
    check(paste(label, "bootstrap completion"), nrow(b) == 2L &&
      all(b$resamples_requested == 300L & b$resamples_succeeded == 300L & b$resamples_failed == 0L),
      "300 full-refit county resamples per population; 600 successful draws in this analysis")
  }
  check("Fate accounting", sum(fate_summary$trees) == nrow(fates) &&
    sum(fate_summary$trees[fate_summary$fate_eligible]) == sum(fates$fate_eligible),
    "Source stems and comparable-fate denominator reconcile")
  for (fate in unique(fates$fate)) {
    check(paste("Fate", fate), sum(fate_summary$trees[fate_summary$fate == fate]) == sum(fates$fate == fate),
      "Published fate category matches source-linked stems")
  }
  survivors <- fates[fates$fate_eligible & fates$followup_statuscd == 1, ]
  check("Surviving growth summary", growth$survivors == nrow(survivors) &&
    growth$zero_increment == sum(survivors$annual_diameter_increment == 0) &&
    growth$negative_increment == sum(survivors$annual_diameter_increment < 0) &&
    same(growth$median_increment_inches_year, stats::median(survivors$annual_diameter_increment)) &&
    same(c(growth$p10, growth$p90), stats::quantile(survivors$annual_diameter_increment, c(0.1, 0.9))),
    "Survivor denominator, zero and negative differences, median, and tail quantiles reconcile")
  dplyr::bind_rows(checks)
}

# Reconcile the tables newly made visible in the analytical appendix.
# This checks saved computations without fitting or changing a research model.
recruitment_paper_detail_audit <- function(bundle, coefficients, diagnostics, joint, intervals) {
  checks <- list()
  check <- function(name, passed, detail) {
    checks[[length(checks) + 1L]] <<- data.frame(check = name, passed = isTRUE(passed), detail = detail)
  }
  same_rows <- function(actual, expected, keys, fields) {
    if (!all(c(keys, fields) %in% names(actual)) || !all(c(keys, fields) %in% names(expected))) return(FALSE)
    key <- function(x) do.call(paste, c(x[keys], sep = "\r"))
    a <- key(actual)
    e <- key(expected)
    if (anyDuplicated(a) || anyDuplicated(e) || !setequal(a, e)) return(FALSE)
    actual <- actual[match(e, a), , drop = FALSE]
    all(vapply(fields, function(field) isTRUE(all.equal(actual[[field]], expected[[field]],
      tolerance = 1e-10, check.attributes = FALSE)), logical(1)))
  }
  for (population in names(bundle)) {
    m <- bundle[[population]]
    c <- coefficients[coefficients$population == population, , drop = FALSE]
    check(paste(population, "appendix coefficients"),
      same_rows(c, m$final$coefficients, c("model", "term"),
        c("penalized_log_odds_coefficient", "lambda", "converged")),
      "All full-population coefficients match the saved model bundle")
    d <- diagnostics[diagnostics$population == population, , drop = FALSE]
    fields <- c("training_n", "test_n", "training_events", "test_events", "training_counties", "test_counties",
      "converged", "iterations", "max_gradient", "max_absolute_coefficient")
    check(paste(population, "appendix fold diagnostics"),
      same_rows(d, m$crossfit$diagnostics, c("model", "fold"), fields),
      "Fold denominators and optimization diagnostics match saved held-out fits")
    x <- intervals[intervals$population == population, , drop = FALSE]
    metrics <- c("brier_score", "log_loss", "roc_auc", "average_precision", "top_recruitment_fraction",
      "top_no_new_tally_fraction", "top_event_capture_fraction", "top_events")
    expected <- tidyr::pivot_longer(m$crossfit$summary[, c("model", metrics)],
      cols = dplyr::all_of(metrics), names_to = "metric", values_to = "estimate")
    valid_bounds <- (is.na(x$estimate) & is.na(x$lower) & is.na(x$upper)) |
      (is.finite(x$estimate) & is.finite(x$lower) & is.finite(x$upper) & x$lower <= x$upper)
    check(paste(population, "appendix interval point estimates"),
      same_rows(x, expected, c("model", "metric"), "estimate") && all(valid_bounds) &&
        all(x$resamples_requested == 300 & x$resamples_succeeded == 300),
      "Interval-table points match saved predictions; bounds and recorded bootstrap counts checked, not replayed")
  }
  expected_joint <- recruitment_empirical_summaries(bundle[["All eligible pairs"]]$data)$joint
  check("Appendix joint strata", same_rows(joint, expected_joint, c("count_group", "saplings_present"),
    c("conditions", "conditions_with_new_tally", "recruitment_fraction", "no_new_tally_fraction")),
    "Joint count and sapling cells recomputed from saved analysis rows")
  dplyr::bind_rows(checks)
}
