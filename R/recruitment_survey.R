# Fixed-capacity retrospective selection diagnostics. The target is a recorded
# inventory state, not independently measured survey need or treatment benefit.

recruitment_survey_selection <- function(target, score, fraction, weights = rep(1, length(target)),
    row_order = seq_along(target), physical_plot = seq_along(target)) {
  n <- length(target)
  if (!n || length(score) != n || length(weights) != n || length(row_order) != n || length(physical_plot) != n ||
      anyNA(target) || any(!target %in% 0:1) || any(!is.finite(score)) ||
      any(!is.finite(weights) | weights < 0 | abs(weights - round(weights)) > 1e-8) ||
      length(fraction) != 1 || !is.finite(fraction) || fraction <= 0 || fraction > 1) {
    stop("Invalid survey selection inputs.", call. = FALSE)
  }
  total <- sum(weights)
  capacity <- floor(total * fraction)
  if (capacity < 1) stop("Survey capacity must select at least one condition.", call. = FALSE)
  ordering <- order(-score, row_order)
  w <- weights[ordering]
  taken <- pmin(w, pmax(0, capacity - c(0, head(cumsum(w), -1L))))
  selected <- numeric(n)
  selected[ordering] <- taken
  cutoff <- score[ordering[max(which(taken > 0))]]
  above <- score > cutoff
  tied <- score == cutoff
  remaining <- capacity - sum(weights[above])
  tied_total <- sum(weights[tied])
  tied_targets <- sum(weights[tied] * target[tied])
  above_targets <- sum(weights[above] * target[above])
  expected <- above_targets + remaining * tied_targets / tied_total
  target_total <- sum(weights * target)
  random <- capacity * target_total / total
  data.frame(observations = total, target_total = target_total, target_prevalence = target_total / total,
    requested_fraction = fraction, capacity = capacity, realized_fraction = capacity / total,
    expected_targets = expected, expected_non_targets = capacity - expected,
    selected_target_fraction = expected / capacity,
    target_capture_fraction = if (target_total > 0) expected / target_total else NA_real_,
    random_expected_targets = random, extra_targets_vs_random = expected - random,
    deterministic_targets = sum(selected * target),
    deterministic_selected_physical_plots = length(unique(physical_plot[selected > 0])),
    minimum_targets_over_cutoff_ties = above_targets + max(0, remaining - (tied_total - tied_targets)),
    maximum_targets_over_cutoff_ties = above_targets + min(remaining, tied_targets),
    cutoff_score = cutoff, cutoff_tied_mass = tied_total, cutoff_tied_selected = remaining,
    tie_rule = "Expected uniform allocation within cutoff ties; deterministic source-key ordering also retained")
}

recruitment_survey_scores <- function(data, predictions) {
  required <- c("Seedling count and design", "Maple stages and design")
  if (nrow(predictions) != nrow(data) || !all(required %in% colnames(predictions)) ||
      any(!is.finite(predictions)) || any(predictions < 0 | predictions > 1)) {
    stop("Survey scores require aligned finite held-out predictions.", call. = FALSE)
  }
  cbind("Raw seedling count" = data$baseline_seedling_count,
    "Count per sampled coverage" = data$baseline_seedling_count / data$baseline_micrprop_unadj,
    "Sapling presence" = as.numeric(data$baseline_maple_sapling_tpa > 0),
    "Count model" = predictions[, "Seedling count and design"],
    "Maple-stage model" = predictions[, "Maple stages and design"])
}

recruitment_survey_evaluate <- function(data, predictions, weights = rep(1, nrow(data)),
    capacities = c(0.1, 0.25, 0.5)) {
  scores <- recruitment_survey_scores(data, predictions)
  rows <- list()
  for (objective in c("No recorded entry", "Recorded entry")) {
    target <- if (objective == "No recorded entry") 1 - data$outcome_recruitment else data$outcome_recruitment
    direction <- if (objective == "No recorded entry") -1 else 1
    for (fraction in capacities) {
      for (policy in c("Random expectation", colnames(scores))) {
        score <- if (policy == "Random expectation") rep(0, nrow(data)) else direction * scores[, policy]
        row <- recruitment_survey_selection(target, score, fraction, weights, data$audit_row, data$physical_plot_key)
        # Random selection is an analytic expectation, not an arbitrary key-order policy.
        if (policy == "Random expectation") {
          row$deterministic_targets <- NA_real_
          row$deterministic_selected_physical_plots <- NA_real_
        }
        rows[[length(rows) + 1L]] <- dplyr::mutate(row, objective = objective, policy = policy)
      }
    }
  }
  dplyr::bind_rows(rows)
}

recruitment_survey_comparisons <- function(summary) {
  references <- list(c("Count model", "Raw seedling count"),
    c("Maple-stage model", "Raw seedling count"), c("Maple-stage model", "Count model"))
  keys <- c("objective", "requested_fraction")
  dplyr::bind_rows(lapply(references, function(pair) {
    a <- summary[summary$policy == pair[[1]], ]
    b <- summary[summary$policy == pair[[2]], ]
    key <- function(x) paste(x$objective, x$requested_fraction)
    at <- match(key(a), key(b))
    if (anyNA(at) || anyDuplicated(key(a)) || anyDuplicated(key(b)) ||
        any(a$observations != b$observations[at]) || any(a$capacity != b$capacity[at]) || any(a$target_total != b$target_total[at])) {
      stop("Survey comparisons must use the same target and capacity.", call. = FALSE)
    }
    data.frame(a[keys], policy = pair[[1]], reference = pair[[2]], capacity = a$capacity,
      target_fraction_difference = a$selected_target_fraction - b$selected_target_fraction[at],
      expected_target_difference = a$expected_targets - b$expected_targets[at],
      direction = "Named policy minus reference; positive means greater capture of the stated proxy")
  }))
}

recruitment_survey_bootstrap <- function(data, crossfit, resamples = 300L, seed = 20260908L) {
  counties <- unique(data$geoid)
  county_index <- match(data$geoid, counties)
  summaries <- differences <- failures <- list()
  set.seed(seed)
  for (b in seq_len(resamples)) {
    w <- tabulate(sample.int(length(counties), length(counties), replace = TRUE), nbins = length(counties))[county_index]
    attempt <- tryCatch({
      fitted <- recruitment_crossfit(data, crossfit$assignments, weights = w, audit = FALSE)
      metrics <- recruitment_survey_evaluate(data, fitted$predictions, weights = w)
      list(summary = metrics, difference = recruitment_survey_comparisons(metrics))
    }, error = function(e) e)
    if (inherits(attempt, "error")) {
      failures[[length(failures) + 1L]] <- data.frame(resample = b, reason = conditionMessage(attempt))
    } else {
      summaries[[length(summaries) + 1L]] <- dplyr::mutate(attempt$summary, resample = b)
      differences[[length(differences) + 1L]] <- dplyr::mutate(attempt$difference, resample = b)
    }
    if (b %% 50L == 0L) message("Survey comparison full-refit county bootstrap: ", b, "/", resamples)
  }
  success <- length(summaries)
  if (success < 0.9 * resamples) stop("Fewer than 90% of survey bootstrap draws succeeded.", call. = FALSE)
  interval <- dplyr::bind_rows(summaries) |>
    dplyr::group_by(.data$objective, .data$policy, .data$requested_fraction) |>
    dplyr::summarise(lower = stats::quantile(.data$selected_target_fraction, 0.025),
      upper = stats::quantile(.data$selected_target_fraction, 0.975), .groups = "drop")
  paired <- dplyr::bind_rows(differences) |>
    dplyr::group_by(.data$objective, .data$policy, .data$reference, .data$requested_fraction) |>
    dplyr::summarise(lower = stats::quantile(.data$target_fraction_difference, 0.025),
      upper = stats::quantile(.data$target_fraction_difference, 0.975), .groups = "drop")
  scope <- paste(resamples, "whole-county resamples with all training scaling and county-held-out model fits repeated;",
    "fixed original folds, policies and model set; tie expectations recomputed;",
    "not survey-design uncertainty or external validation")
  list(intervals = dplyr::mutate(interval, uncertainty_scope = scope),
    paired = dplyr::mutate(paired, uncertainty_scope = scope),
    audit = data.frame(resamples_requested = resamples, resamples_succeeded = success,
      resamples_failed = resamples - success, seed = seed, uncertainty_scope = scope),
    failures = if (length(failures)) dplyr::bind_rows(failures) else data.frame(resample = integer(), reason = character()))
}

recruitment_survey_temporal_horizon <- function(data, temporal, horizon = 7) {
  if (length(horizon) != 1 || !is.finite(horizon) || horizon <= 0) stop("Invalid scoring horizon.", call. = FALSE)
  test <- data[temporal$test_rows, ]
  test$interval_years <- horizon
  for (i in seq_len(nrow(temporal$scaling))) {
    a <- temporal$scaling[i, ]
    value <- test[[a$source]]
    if (a$transformation == "log1p") value <- log1p(value)
    test[[a$term]] <- (value - a$center) / a$scale
  }
  specs <- recruitment_specifications()
  result <- vapply(names(specs), function(name) {
    stats::plogis(as.numeric(recruitment_design_matrix(test, specs[[name]]) %*% temporal$models[[name]]$coefficients))
  }, numeric(nrow(test)))
  colnames(result) <- names(specs)
  result
}
