# Fixed, exploratory condition-level recruitment models. This module makes no
# claim about individual seedlings, causal effects, or an untouched test sample.

recruitment_specifications <- function() {
  design <- c("z_coverage", "z_interval")
  count <- c(design, "z_seedling_count")
  list(
    "Prevalence" = character(),
    "Observation design" = design,
    "Seedling count and design" = count,
    "Maple stages and design" = c(count, "z_sapling_tpa", "z_established_ba")
  )
}

recruitment_scaling_specifications <- function() {
  data.frame(
    term = c("z_coverage", "z_interval", "z_seedling_count", "z_sapling_tpa", "z_established_ba"),
    source = c("baseline_micrprop_unadj", "interval_years", "baseline_seedling_count",
      "baseline_maple_sapling_tpa", "baseline_established_maple_ba_ft2_ac"),
    transformation = c("identity", "identity", "log1p", "log1p", "log1p"),
    stringsAsFactors = FALSE
  )
}

prepare_recruitment_model_data <- function(data) {
  required <- c("recruitment_eligible", "outcome_recruitment", "geoid", "physical_plot_key",
    "followup_measyear", "followup_manual", "exact_overlap",
    recruitment_scaling_specifications()$source)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Recruitment data are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  selected <- data[!is.na(data$recruitment_eligible) & data$recruitment_eligible, , drop = FALSE]
  if (any(!stats::complete.cases(selected[required]))) {
    stop("Eligible recruitment rows contain missing required fields; do not silently change matched cohorts.", call. = FALSE)
  }
  selected$outcome_recruitment <- as.integer(selected$outcome_recruitment)
  if (!all(selected$outcome_recruitment %in% 0:1)) stop("Recruitment outcome must be binary.", call. = FALSE)
  for (name in recruitment_scaling_specifications()$source) {
    if (any(!is.finite(selected[[name]])) || any(selected[[name]] < 0)) {
      stop("Invalid nonnegative recruitment predictor: ", name, call. = FALSE)
    }
  }
  if (any(selected$baseline_micrprop_unadj <= 0 | selected$baseline_micrprop_unadj > 1.01) ||
      any(selected$interval_years <= 0)) stop("Recruitment frame or measurement interval is invalid.", call. = FALSE)
  if (any(abs(selected$baseline_seedling_count - round(selected$baseline_seedling_count)) > 1e-8)) {
    stop("Baseline seedling count must be a directly verified whole-number tally.", call. = FALSE)
  }
  if ("baseline_seedling_detected" %in% names(selected) &&
      any((selected$baseline_seedling_count > 0) != as.logical(selected$baseline_seedling_detected))) {
    stop("Baseline tally and detection indicator disagree.", call. = FALSE)
  }
  # IDs are retained only in ignored model artifacts, never public summary tables.
  sort_columns <- intersect(c("physical_plot_key", "baseline_plt_cn", "baseline_condid",
    "current_plt_cn", "current_condid"), names(selected))
  ordering <- do.call(order, lapply(selected[sort_columns], as.character))
  selected <- selected[ordering, , drop = FALSE]
  selected$audit_row <- seq_len(nrow(selected))
  selected$geoid <- as.character(selected$geoid)
  selected$physical_plot_key <- as.character(selected$physical_plot_key)
  selected
}

recruitment_county_folds <- function(data, k = 5L) {
  counts <- as.data.frame(table(as.character(data$geoid)), stringsAsFactors = FALSE)
  names(counts) <- c("geoid", "observations")
  counts <- counts[order(-counts$observations, counts$geoid), , drop = FALSE]
  k <- min(as.integer(k), nrow(counts))
  if (k < 2L) stop("At least two counties are required.", call. = FALSE)
  load <- integer(k)
  counties <- integer(k)
  counts$fold <- integer(nrow(counts))
  for (i in seq_len(nrow(counts))) {
    fold <- order(load, counties, seq_len(k))[[1]]
    counts$fold[[i]] <- fold
    load[[fold]] <- load[[fold]] + counts$observations[[i]]
    counties[[fold]] <- counties[[fold]] + 1L
  }
  counts$assignment_rule <- "Greedy balance by condition count only; county ID breaks ties; outcomes never used"
  counts
}

recruitment_scale <- function(training, testing = NULL, weights = rep(1, nrow(training))) {
  if (length(weights) != nrow(training) || any(!is.finite(weights) | weights < 0) || sum(weights) <= 0) {
    stop("Invalid scaling weights.", call. = FALSE)
  }
  specification <- recruitment_scaling_specifications()
  audit <- vector("list", nrow(specification))
  for (i in seq_len(nrow(specification))) {
    transform <- if (specification$transformation[[i]] == "log1p") log1p else identity
    values <- transform(training[[specification$source[[i]]]])
    center <- sum(weights * values) / sum(weights)
    # Frequency weights reproduce standardization of an explicitly resampled cohort.
    spread <- sqrt(sum(weights * (values - center)^2) / max(1, sum(weights) - 1))
    constant <- !is.finite(spread) || spread < 1e-12
    if (constant) spread <- 1
    term <- specification$term[[i]]
    training[[term]] <- (values - center) / spread
    if (!is.null(testing)) testing[[term]] <- (transform(testing[[specification$source[[i]]]]) - center) / spread
    audit[[i]] <- data.frame(term = term, source = specification$source[[i]],
      transformation = specification$transformation[[i]], center = center, scale = spread,
      constant_in_training = constant, positive_weight_rows = sum(weights > 0),
      training_weight = sum(weights), scaling_scope = "Training observations only; frequency-weighted within bootstrap")
  }
  list(training = training, testing = testing, audit = dplyr::bind_rows(audit))
}

recruitment_design_matrix <- function(data, terms) {
  result <- cbind("(Intercept)" = rep(1, nrow(data)), as.matrix(data[terms]))
  storage.mode(result) <- "double"
  result
}

recruitment_ridge_fit <- function(x, y, lambda = 1, weights = rep(1, length(y)), max_iterations = 100L) {
  if (nrow(x) != length(y) || length(weights) != length(y) || any(!is.finite(x)) ||
      any(!is.finite(weights) | weights < 0) || lambda < 0) stop("Invalid ridge inputs.", call. = FALSE)
  keep <- weights > 0
  x <- x[keep, , drop = FALSE]
  y <- y[keep]
  weights <- weights[keep]
  if (length(unique(y)) < 2L) stop("Training sample has only one outcome class.", call. = FALSE)
  penalty <- c(0, rep(lambda, ncol(x) - 1L))
  coefficient <- c(stats::qlogis(sum(weights * y) / sum(weights)), rep(0, ncol(x) - 1L))
  objective <- function(beta) {
    eta <- as.numeric(x %*% beta)
    sum(weights * (pmax(eta, 0) + log1p(exp(-abs(eta))) - y * eta)) + sum(penalty * beta^2) / 2
  }
  converged <- FALSE
  for (iteration in seq_len(max_iterations)) {
    probability <- stats::plogis(as.numeric(x %*% coefficient))
    gradient <- as.numeric(crossprod(x, weights * (probability - y))) + penalty * coefficient
    if (max(abs(gradient)) < 1e-7) {
      converged <- TRUE
      break
    }
    hessian <- crossprod(x, x * as.numeric(weights * probability * (1 - probability))) + diag(penalty, ncol(x))
    step <- tryCatch(as.numeric(solve(hessian, gradient)), error = function(e) NULL)
    if (is.null(step) || any(!is.finite(step))) stop("Ridge information matrix is singular.", call. = FALSE)
    old_objective <- objective(coefficient)
    rate <- 1
    repeat {
      candidate <- coefficient - rate * step
      if (objective(candidate) <= old_objective + 1e-10 || rate < 2^-20) break
      rate <- rate / 2
    }
    if (rate < 2^-20) stop("Ridge line search failed.", call. = FALSE)
    coefficient <- candidate
  }
  probability <- stats::plogis(as.numeric(x %*% coefficient))
  gradient <- as.numeric(crossprod(x, weights * (probability - y))) + penalty * coefficient
  if (max(abs(gradient)) < 1e-6) converged <- TRUE
  if (!converged || any(!is.finite(coefficient)) || max(abs(coefficient)) > 30) {
    stop("Recruitment fit did not reach a stable finite solution.", call. = FALSE)
  }
  names(coefficient) <- colnames(x)
  list(coefficients = coefficient, converged = converged, iterations = iteration,
    max_gradient = max(abs(gradient)), lambda = lambda, objective = objective(coefficient),
    max_absolute_coefficient = max(abs(coefficient)), training_weight = sum(weights))
}

recruitment_rank_metrics <- function(y, probability, weights = rep(1, length(y))) {
  keep <- weights > 0
  y <- y[keep]
  probability <- probability[keep]
  weights <- weights[keep]
  positives <- sum(weights * y)
  negatives <- sum(weights * (1 - y))
  if (positives == 0 || negatives == 0) return(c(roc_auc = NA_real_, average_precision = NA_real_))
  ordering <- order(probability)
  p <- probability[ordering]
  y <- y[ordering]
  w <- weights[ordering]
  group <- cumsum(c(TRUE, diff(p) != 0))
  positive <- as.numeric(rowsum(w * y, group, reorder = FALSE))
  negative <- as.numeric(rowsum(w * (1 - y), group, reorder = FALSE))
  auc <- sum(positive * (cumsum(negative) - negative + negative / 2)) / (positives * negatives)
  positive <- rev(positive)
  negative <- rev(negative)
  ap <- sum(positive / positives * cumsum(positive) / cumsum(positive + negative))
  c(roc_auc = auc, average_precision = ap)
}

recruitment_top_capacity <- function(y, probability, weights = rep(1, length(y)), row_order = seq_along(y)) {
  ordering <- order(-probability, row_order)
  w <- weights[ordering]
  capacity <- floor(sum(w) / 4)
  if (capacity < 1) stop("Too few observations for quartile capacity.", call. = FALSE)
  selected_weight <- pmin(w, pmax(0, capacity - c(0, head(cumsum(w), -1L))))
  events <- sum(selected_weight * y[ordering])
  cutoff <- probability[ordering[which(selected_weight > 0)[length(which(selected_weight > 0))]]]
  above <- probability > cutoff
  at <- probability == cutoff
  tie_remaining <- capacity - sum(weights[above])
  expected_events <- sum(weights[above] * y[above]) + tie_remaining * sum(weights[at] * y[at]) / sum(weights[at])
  c(top_capacity = capacity, top_events = events, top_recruitment_fraction = events / capacity,
    top_no_new_tally_fraction = 1 - events / capacity,
    top_event_capture_fraction = if (sum(weights * y) > 0) events / sum(weights * y) else NA_real_,
    cutoff_tied_weight = sum(weights[at]), cutoff_tied_selected_weight = tie_remaining,
    tie_neutral_expected_top_events = expected_events)
}

recruitment_metrics <- function(y, probability, weights = rep(1, length(y)), row_order = seq_along(y),
    calibration = TRUE, prevalence_model = FALSE) {
  if (length(probability) != length(y) || any(!is.finite(probability)) ||
      any(probability < 0 | probability > 1)) stop("Invalid recruitment predictions.", call. = FALSE)
  p <- pmin(1 - 1e-12, pmax(1e-12, probability))
  rank_metrics <- recruitment_rank_metrics(y, p, weights)
  if (prevalence_model) rank_metrics[] <- NA_real_
  intercept <- slope <- NA_real_
  if (calibration && !prevalence_model && length(unique(p[weights > 0])) > 1 && length(unique(y[weights > 0])) == 2) {
    # Diagnostic calibration regression only, not coefficient inference for the ridge model.
    attempt <- tryCatch(recruitment_ridge_fit(cbind("(Intercept)" = 1, logit = stats::qlogis(p)),
      y, lambda = 0, weights = weights), error = function(e) NULL)
    if (!is.null(attempt)) {
      intercept <- attempt$coefficients[[1]]
      slope <- attempt$coefficients[[2]]
    }
  }
  c(observations = sum(weights), events = sum(weights * y),
    event_fraction = sum(weights * y) / sum(weights),
    brier_score = sum(weights * (y - p)^2) / sum(weights),
    log_loss = -sum(weights * (y * log(p) + (1 - y) * log1p(-p))) / sum(weights),
    rank_metrics, calibration_intercept = intercept, calibration_slope = slope,
    mean_predicted_probability = sum(weights * p) / sum(weights),
    observed_expected_ratio = sum(weights * y) / sum(weights * p),
    recruitment_top_capacity(y, p, weights, row_order))
}

recruitment_crossfit <- function(data, assignments = recruitment_county_folds(data), lambda = 1,
    weights = rep(1, nrow(data)), audit = TRUE, score_interval_years = NULL) {
  if (!is.null(score_interval_years) && (length(score_interval_years) != 1 ||
      !is.finite(score_interval_years) || score_interval_years <= 0)) {
    stop("Scoring interval must be a positive finite scalar.", call. = FALSE)
  }
  specifications <- recruitment_specifications()
  fold <- assignments$fold[match(data$geoid, assignments$geoid)]
  if (anyNA(fold)) stop("Missing county fold assignment.", call. = FALSE)
  prediction <- matrix(NA_real_, nrow(data), length(specifications), dimnames = list(NULL, names(specifications)))
  diagnostics <- scaling <- list()
  for (f in sort(unique(fold))) {
    train <- fold != f
    test <- !train
    if (!sum(weights[test])) next
    if (length(intersect(data$physical_plot_key[train], data$physical_plot_key[test]))) {
      stop("A physical plot crosses county folds.", call. = FALSE)
    }
    testing <- data[test, ]
    if (!is.null(score_interval_years)) testing$interval_years <- score_interval_years
    scaled <- recruitment_scale(data[train, ], testing, weights[train])
    if (audit) scaling[[length(scaling) + 1L]] <- dplyr::mutate(scaled$audit, fold = f)
    for (name in names(specifications)) {
      model <- recruitment_ridge_fit(recruitment_design_matrix(scaled$training, specifications[[name]]),
        data$outcome_recruitment[train], lambda, weights[train])
      prediction[test, name] <- stats::plogis(as.numeric(
        recruitment_design_matrix(scaled$testing, specifications[[name]]) %*% model$coefficients))
      if (audit) diagnostics[[length(diagnostics) + 1L]] <- data.frame(model = name, fold = f,
        training_n = sum(weights[train]), test_n = sum(weights[test]),
        training_events = sum(weights[train] * data$outcome_recruitment[train]),
        test_events = sum(weights[test] * data$outcome_recruitment[test]),
        training_counties = length(unique(data$geoid[train & weights > 0])),
        test_counties = length(unique(data$geoid[test & weights > 0])),
        slopes = length(specifications[[name]]), converged = model$converged,
        iterations = model$iterations, max_gradient = model$max_gradient,
        max_absolute_coefficient = model$max_absolute_coefficient,
        lambda = lambda, brier_score = weighted.mean((data$outcome_recruitment[test] - prediction[test, name])^2, weights[test]))
    }
  }
  # Unrepresented bootstrap counties have zero evaluation weight; harmless finite placeholders.
  prediction[weights == 0, ] <- 0.5
  if (anyNA(prediction)) stop("Incomplete held-out recruitment predictions.", call. = FALSE)
  summaries <- dplyr::bind_rows(lapply(names(specifications), function(name) {
    dplyr::bind_cols(data.frame(model = name), as.data.frame(as.list(recruitment_metrics(
      data$outcome_recruitment, prediction[, name], weights, data$audit_row,
      calibration = audit, prevalence_model = name == "Prevalence"))))
  }))
  list(predictions = prediction, summary = summaries, assignments = assignments,
    diagnostics = dplyr::bind_rows(diagnostics), scaling = dplyr::bind_rows(scaling), fold = fold)
}

recruitment_comparisons <- function(summary) {
  pairs <- list(c("Seedling count and design", "Observation design"),
    c("Maple stages and design", "Seedling count and design"))
  fields <- c("brier_score", "log_loss", "roc_auc", "average_precision",
    "top_recruitment_fraction", "top_no_new_tally_fraction", "top_event_capture_fraction", "top_events")
  dplyr::bind_rows(lapply(pairs, function(pair) {
    candidate <- summary[summary$model == pair[[1]], ]
    reference <- summary[summary$model == pair[[2]], ]
    if (nrow(candidate) != 1L || nrow(reference) != 1L || candidate$observations != reference$observations ||
        candidate$events != reference$events) stop("Model comparisons require exactly matched cohorts.", call. = FALSE)
    data.frame(model = pair[[1]], reference = pair[[2]], metric = fields,
      difference = as.numeric(candidate[fields] - reference[fields]),
      comparison_scope = "Same observations, outcomes, folds, capacity and penalty",
      difference_direction = "Named model minus reference; negative Brier/log loss/no-new-tally fraction favors named model")
  }))
}

recruitment_bootstrap <- function(data, crossfit, lambda = 1, resamples = 300L, seed = 20260908L) {
  counties <- unique(data$geoid)
  county_index <- match(data$geoid, counties)
  summary_rows <- comparison_rows <- failures <- list()
  set.seed(seed)
  for (b in seq_len(resamples)) {
    county_weights <- tabulate(sample.int(length(counties), length(counties), replace = TRUE), nbins = length(counties))
    weights <- county_weights[county_index]
    attempt <- tryCatch(recruitment_crossfit(data, crossfit$assignments, lambda, weights, audit = FALSE),
      error = function(e) e)
    if (inherits(attempt, "error")) {
      failures[[length(failures) + 1L]] <- data.frame(resample = b, reason = conditionMessage(attempt))
      next
    }
    summary_rows[[length(summary_rows) + 1L]] <- dplyr::mutate(attempt$summary, resample = b)
    comparison_rows[[length(comparison_rows) + 1L]] <- dplyr::mutate(recruitment_comparisons(attempt$summary), resample = b)
    if (b %% 50L == 0L) message("Recruitment full-refit county bootstrap: ", b, "/", resamples)
  }
  summaries <- dplyr::bind_rows(summary_rows)
  comparisons <- dplyr::bind_rows(comparison_rows)
  successful <- length(summary_rows)
  if (successful < 0.9 * resamples) stop("Fewer than 90% of full-refit bootstrap samples succeeded.", call. = FALSE)
  fields <- c("brier_score", "log_loss", "roc_auc", "average_precision", "top_recruitment_fraction",
    "top_no_new_tally_fraction", "top_event_capture_fraction", "top_events")
  intervals <- dplyr::bind_rows(lapply(unique(summaries$model), function(name) {
    rows <- summaries[summaries$model == name, ]
    point <- crossfit$summary[crossfit$summary$model == name, ]
    dplyr::bind_rows(lapply(fields, function(field) {
      values <- rows[[field]]
      quantiles <- if (any(is.finite(values))) stats::quantile(values, c(0.025, 0.975), na.rm = TRUE) else c(NA, NA)
      data.frame(model = name, metric = field, estimate = point[[field]],
        lower = unname(quantiles[[1]]), upper = unname(quantiles[[2]]))
    }))
  }))
  paired <- comparisons |>
    dplyr::group_by(.data$model, .data$reference, .data$metric) |>
    dplyr::summarise(lower = stats::quantile(.data$difference, 0.025, na.rm = TRUE),
      upper = stats::quantile(.data$difference, 0.975, na.rm = TRUE), .groups = "drop") |>
    dplyr::left_join(recruitment_comparisons(crossfit$summary), by = c("model", "reference", "metric"))
  note <- paste("County-cluster percentile bootstrap with training scaling and all cross-validation fits repeated;",
    "fixed original county-fold assignment, fixed model set and lambda; excludes model-choice and snapshot-selection uncertainty")
  list(intervals = dplyr::mutate(intervals, resamples_requested = resamples, resamples_succeeded = successful,
      seed = seed, uncertainty_scope = note),
    paired = dplyr::mutate(paired, resamples_requested = resamples, resamples_succeeded = successful,
      seed = seed, uncertainty_scope = note),
    failures = dplyr::bind_rows(failures),
    audit = data.frame(resamples_requested = resamples, resamples_succeeded = successful,
      resamples_failed = resamples - successful, seed = seed, uncertainty_scope = note))
}

recruitment_temporal_check <- function(data, cutoff = 2023L, lambda = 1) {
  train <- data$followup_measyear < cutoff
  test <- !train
  if (sum(train) < 50 || sum(test) < 50 || sum(data$outcome_recruitment[train]) < 20 ||
      sum(data$outcome_recruitment[test]) < 15) stop("Insufficient temporal-check support.", call. = FALSE)
  shared_plots <- intersect(data$physical_plot_key[train], data$physical_plot_key[test])
  if (length(shared_plots)) stop("Physical plots overlap the temporal split.", call. = FALSE)
  scaled <- recruitment_scale(data[train, ], data[test, ])
  specifications <- recruitment_specifications()
  rows <- models <- list()
  prediction <- matrix(NA_real_, sum(test), length(specifications), dimnames = list(NULL, names(specifications)))
  for (name in names(specifications)) {
    model <- recruitment_ridge_fit(recruitment_design_matrix(scaled$training, specifications[[name]]),
      data$outcome_recruitment[train], lambda)
    probability <- stats::plogis(as.numeric(recruitment_design_matrix(scaled$testing, specifications[[name]]) %*% model$coefficients))
    prediction[, name] <- probability
    rows[[name]] <- dplyr::bind_cols(data.frame(model = name), as.data.frame(as.list(recruitment_metrics(
      data$outcome_recruitment[test], probability, row_order = data$audit_row[test], prevalence_model = name == "Prevalence"))))
    models[[name]] <- model
  }
  support <- dplyr::bind_rows(lapply(c("Training", "Testing"), function(label) {
    x <- data[if (label == "Training") train else test, ]
    data.frame(split = label, conditions = nrow(x), events = sum(x$outcome_recruitment),
      physical_plots = length(unique(x$physical_plot_key)), counties = length(unique(x$geoid)),
      followup_year_min = min(x$followup_measyear), followup_year_max = max(x$followup_measyear),
      followup_manual_min = min(x$followup_manual), followup_manual_max = max(x$followup_manual),
      followup_manual_at_least_9 = sum(x$followup_manual >= 9),
      interval_years_min = min(x$interval_years), interval_years_median = stats::median(x$interval_years),
      interval_years_max = max(x$interval_years), physical_plots_shared = length(shared_plots),
      cutoff_year = cutoff)
  }))
  list(summary = dplyr::mutate(dplyr::bind_rows(rows),
      train_conditions = sum(train), train_events = sum(data$outcome_recruitment[train]),
      train_counties = length(unique(data$geoid[train])), test_counties = length(unique(data$geoid[test])),
      unseen_test_counties = length(setdiff(unique(data$geoid[test]), unique(data$geoid[train]))),
      physical_plots_shared = length(shared_plots), cutoff_year = cutoff,
      design = "Train follow-up years before 2023; test 2023 onward; retrospective explored-snapshot transport check"),
    support = support, scaling = scaled$audit, models = models, predictions = prediction, test_rows = which(test))
}

recruitment_final_fits <- function(data, lambda = 1) {
  scaled <- recruitment_scale(data)
  specifications <- recruitment_specifications()
  models <- rows <- list()
  for (name in names(specifications)) {
    fit <- recruitment_ridge_fit(recruitment_design_matrix(scaled$training, specifications[[name]]),
      data$outcome_recruitment, lambda)
    models[[name]] <- fit
    rows[[name]] <- data.frame(model = name, term = names(fit$coefficients),
      penalized_log_odds_coefficient = as.numeric(fit$coefficients), lambda = lambda,
      converged = fit$converged, max_gradient = fit$max_gradient,
      interpretation = "Descriptive penalized model coefficient; no causal interpretation or ordinary GLM p-value")
  }
  list(models = models, coefficients = dplyr::bind_rows(rows), scaling = scaled$audit)
}

recruitment_empirical_summaries <- function(data) {
  count_group <- cut(data$baseline_seedling_count, c(-1, 0, 1, 5, 20, Inf),
    labels = c("0", "1", "2-5", "6-20", ">20"))
  observed <- data.frame(count_group = count_group,
    saplings_present = data$baseline_maple_sapling_tpa > 0,
    outcome = data$outcome_recruitment)
  summarize <- function(data, groups) {
    data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
      dplyr::summarise(conditions = dplyr::n(), conditions_with_new_tally = sum(.data$outcome),
        recruitment_fraction = mean(.data$outcome), no_new_tally_fraction = 1 - mean(.data$outcome),
        .groups = "drop")
  }
  list(count = summarize(observed, "count_group"), sapling = summarize(observed, "saplings_present"),
    joint = summarize(observed, c("count_group", "saplings_present")))
}
