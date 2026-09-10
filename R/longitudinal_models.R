longitudinal_loss_scaling_specifications <- function() {
  list(
    z_baseline_seedling_tpa = list(
      raw = "baseline_seedling_tpa",
      transformation = "log1p",
      transform = log1p
    ),
    z_established_maple_ba = list(
      raw = "established_maple_ba_ft2_ac",
      transformation = "log1p",
      transform = log1p
    ),
    z_beech_sapling_ba = list(
      raw = "beech_sapling_ba_ft2_ac",
      transformation = "log1p",
      transform = log1p
    ),
    z_other_nonmaple_ba = list(
      raw = "other_nonmaple_ba_ft2_ac",
      transformation = "log1p",
      transform = log1p
    ),
    z_microplot_coverage = list(
      raw = "baseline_microplot_coverage",
      transformation = "identity",
      transform = identity
    ),
    z_interval_years = list(
      raw = "interval_years",
      transformation = "identity",
      transform = identity
    )
  )
}

longitudinal_loss_terms <- function() {
  c(
    "z_baseline_seedling_tpa",
    "maple_sapling_present",
    "z_established_maple_ba",
    "z_beech_sapling_ba",
    "z_other_nonmaple_ba",
    "z_microplot_coverage",
    "z_interval_years"
  )
}

longitudinal_loss_model_specifications <- function() {
  list(
    "Prevalence benchmark" = character(),
    "Starting abundance and observation" = c(
      "z_baseline_seedling_tpa",
      "z_microplot_coverage",
      "z_interval_years"
    ),
    "Stage structure" = c(
      "z_baseline_seedling_tpa",
      "maple_sapling_present",
      "z_established_maple_ba",
      "z_other_nonmaple_ba",
      "z_microplot_coverage",
      "z_interval_years"
    ),
    "Beech hypothesis" = longitudinal_loss_terms()
  )
}

longitudinal_formula <- function(terms = longitudinal_loss_terms()) {
  rhs <- if (length(terms)) paste(terms, collapse = " + ") else "1"
  stats::as.formula(paste("outcome_loss ~", rhs))
}

raw_longitudinal_loss_data <- function(longitudinal) {
  assert_columns(
    longitudinal,
    c(
      "primary_pair_eligible", "baseline_seedling_detected", "seedling_detection_loss",
      "baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid",
      "physical_plot_key", "geoid", "county_name", "baseline_maple_seedling_tpa",
      "baseline_maple_sapling_present", "baseline_established_maple_ba_ft2_ac",
      "baseline_beech_sapling_ba_ft2_ac", "baseline_other_nonmaple_ba_ft2_ac",
      "baseline_micrprop_unadj", "interval_years", "followup_group_800"
    ),
    "longitudinal analytical data"
  )
  longitudinal |>
    dplyr::filter(.data$primary_pair_eligible, .data$baseline_seedling_detected == 1L) |>
    dplyr::transmute(
      baseline_plt_cn = .data$baseline_plt_cn,
      baseline_condid = .data$baseline_condid,
      current_plt_cn = .data$current_plt_cn,
      current_condid = .data$current_condid,
      physical_plot_key = factor(.data$physical_plot_key),
      geoid = factor(.data$geoid),
      county_name = .data$county_name,
      outcome_loss = as.integer(.data$seedling_detection_loss),
      baseline_seedling_tpa = as.numeric(.data$baseline_maple_seedling_tpa),
      maple_sapling_present = factor(.data$baseline_maple_sapling_present, levels = c(FALSE, TRUE)),
      established_maple_ba_ft2_ac = as.numeric(.data$baseline_established_maple_ba_ft2_ac),
      beech_sapling_ba_ft2_ac = as.numeric(.data$baseline_beech_sapling_ba_ft2_ac),
      other_nonmaple_ba_ft2_ac = as.numeric(.data$baseline_other_nonmaple_ba_ft2_ac),
      baseline_microplot_coverage = as.numeric(.data$baseline_micrprop_unadj),
      interval_years = as.numeric(.data$interval_years),
      followup_group_800 = .data$followup_group_800
    ) |>
    droplevels()
}

scale_longitudinal_loss_predictors <- function(training, testing = NULL) {
  specifications <- longitudinal_loss_scaling_specifications()
  audit <- vector("list", length(specifications))
  names(audit) <- names(specifications)
  for (term in names(specifications)) {
    specification <- specifications[[term]]
    training_values <- specification$transform(training[[specification$raw]])
    center <- mean(training_values, na.rm = TRUE)
    spread <- stats::sd(training_values, na.rm = TRUE)
    if (!is.finite(center) || !is.finite(spread) || spread == 0) {
      stop("Longitudinal scaling failed for ", term, ".", call. = FALSE)
    }
    training[[term]] <- (training_values - center) / spread
    if (!is.null(testing)) {
      testing_values <- specification$transform(testing[[specification$raw]])
      testing[[term]] <- (testing_values - center) / spread
    }
    audit[[term]] <- tibble::tibble(
      model_variable = term,
      source_variable = specification$raw,
      transformation = specification$transformation,
      center = center,
      scale = spread,
      observations = sum(is.finite(training_values)),
      scaling_population = "training data only"
    )
  }
  list(training = training, testing = testing, audit = dplyr::bind_rows(audit))
}

prepare_longitudinal_loss_data <- function(longitudinal) {
  raw <- raw_longitudinal_loss_data(longitudinal)
  required <- c("outcome_loss", longitudinal_loss_terms(), "geoid")
  complete_raw_fields <- c(
    "outcome_loss",
    vapply(
      longitudinal_loss_scaling_specifications(),
      function(x) x$raw,
      character(1)
    ),
    "maple_sapling_present",
    "geoid"
  )
  raw <- raw[stats::complete.cases(raw[complete_raw_fields]), , drop = FALSE]
  scaled <- scale_longitudinal_loss_predictors(raw)
  data <- scaled$training
  if (!all(stats::complete.cases(data[required]))) {
    stop("Longitudinal loss model contains incomplete declared fields after scaling.", call. = FALSE)
  }
  list(raw = raw, data = data, scaling_audit = scaled$audit)
}

validate_longitudinal_loss_glm <- function(model, label = "longitudinal loss model") {
  if (!isTRUE(model$converged)) {
    stop(label, " failed to converge.", call. = FALSE)
  }
  coefficient <- stats::coef(model)
  coefficient_table <- stats::coef(summary(model))
  separation_flag <- any(!is.finite(coefficient)) ||
    any(abs(coefficient) > 10) ||
    any(!is.finite(coefficient_table[, "Std. Error"])) ||
    any(coefficient_table[, "Std. Error"] > 5)
  if (separation_flag) {
    stop(label, " shows separation or severe coefficient instability.", call. = FALSE)
  }
  invisible(model)
}

fit_longitudinal_loss_models <- function(data) {
  specifications <- longitudinal_loss_model_specifications()
  models <- lapply(specifications, function(terms) {
    stats::glm(longitudinal_formula(terms), family = stats::binomial(), data = data)
  })
  for (model_name in names(models)) {
    validate_longitudinal_loss_glm(
      models[[model_name]],
      paste0("Longitudinal loss model '", model_name, "'")
    )
  }
  full <- models[["Beech hypothesis"]]
  list(models = models, model = full, terms = specifications[["Beech hypothesis"]])
}

cluster_robust_glm_covariance <- function(model, cluster) {
  design <- stats::model.matrix(model)
  response <- stats::model.response(stats::model.frame(model))
  fitted <- stats::fitted(model)
  if (length(cluster) != nrow(design)) stop("Cluster vector does not match the fitted model rows.", call. = FALSE)
  cluster <- as.character(cluster)
  if (anyNA(cluster)) stop("Cluster identifiers contain missing values.", call. = FALSE)
  score_rows <- design * as.numeric(response - fitted)
  cluster_scores <- rowsum(score_rows, cluster, reorder = FALSE)
  weights <- as.numeric(fitted * (1 - fitted))
  information <- crossprod(design, design * weights)
  bread <- tryCatch(solve(information), error = function(e) NULL)
  if (is.null(bread)) stop("Could not invert the longitudinal model information matrix.", call. = FALSE)
  clusters <- nrow(cluster_scores)
  observations <- nrow(design)
  parameters <- ncol(design)
  if (clusters <= 1L || observations <= parameters) {
    stop("Insufficient clusters or residual degrees of freedom for CR1 covariance.", call. = FALSE)
  }
  correction <- (clusters / (clusters - 1)) * ((observations - 1) / (observations - parameters))
  correction * bread %*% crossprod(cluster_scores) %*% bread
}

tidy_longitudinal_loss_odds_ratios <- function(model, data, level = 0.95) {
  coefficient <- stats::coef(model)
  model_standard_error <- sqrt(diag(stats::vcov(model)))
  robust_covariance <- cluster_robust_glm_covariance(model, data$geoid)
  robust_standard_error <- sqrt(diag(robust_covariance))
  critical <- stats::qnorm(1 - (1 - level) / 2)
  labels <- c(
    z_baseline_seedling_tpa = "Baseline sugar-maple seedling density",
    maple_sapling_presentTRUE = "Sugar-maple saplings present at baseline",
    z_established_maple_ba = "Established sugar-maple basal area",
    z_beech_sapling_ba = "American beech sapling basal area",
    z_other_nonmaple_ba = "Non-maple basal area excluding beech saplings",
    z_microplot_coverage = "Baseline microplot condition coverage",
    z_interval_years = "Measurement interval"
  )
  tibble::tibble(
    term = names(coefficient),
    log_odds = unname(coefficient),
    model_standard_error = unname(model_standard_error),
    county_cluster_robust_standard_error = unname(robust_standard_error),
    odds_ratio = exp(.data$log_odds),
    conf_low = exp(.data$log_odds - critical * .data$county_cluster_robust_standard_error),
    conf_high = exp(.data$log_odds + critical * .data$county_cluster_robust_standard_error),
    robust_z = .data$log_odds / .data$county_cluster_robust_standard_error,
    robust_p_value = 2 * stats::pnorm(abs(.data$robust_z), lower.tail = FALSE),
    label = dplyr::coalesce(unname(labels[.data$term]), .data$term),
    interpretation = dplyr::if_else(
      .data$term == "maple_sapling_presentTRUE",
      "Adjusted odds ratio for loss when saplings are present versus absent",
      "Adjusted odds ratio for loss per one training-cohort SD on the stated transformed scale"
    ),
    interval_method = "County-cluster CR1 sandwich 95% confidence interval"
  ) |>
    dplyr::filter(.data$term != "(Intercept)")
}

longitudinal_model_support <- function(fit, data, source_cohort_n) {
  terms <- fit$terms
  model <- fit$model
  events <- sum(data$outcome_loss == 1L)
  nonevents <- sum(data$outcome_loss == 0L)
  coefficients <- stats::coef(summary(model))
  tibble::tibble(
    source_transition_cohort_n = source_cohort_n,
    baseline_detected_cohort_n = nrow(data),
    model_complete_n = stats::nobs(model),
    losses = events,
    persistence = nonevents,
    loss_fraction = events / nrow(data),
    fixed_effect_slopes = length(terms),
    losses_per_slope = events / length(terms),
    counties = dplyr::n_distinct(data$geoid),
    physical_plots = dplyr::n_distinct(data$physical_plot_key),
    converged = isTRUE(model$converged),
    separation_flag = any(!is.finite(stats::coef(model))) ||
      any(abs(stats::coef(model)) > 10) ||
      any(coefficients[, "Std. Error"] > 5),
    model_formula = paste(deparse(stats::formula(model)), collapse = " "),
    estimand = "Probability that sugar-maple seedlings detected at baseline are not detected at the next FIA visit",
    interpretation = "Prognostic association under a strict repeated-condition design; not a causal treatment effect or verified local extinction"
  )
}

longitudinal_model_comparison <- function(fit) {
  models <- fit$models
  names_in_order <- names(models)
  rows <- lapply(seq_along(models), function(index) {
    candidate_model <- models[[index]]
    comparison <- if (index > 1L) {
      stats::anova(models[[index - 1L]], candidate_model, test = "Chisq")
    } else {
      NULL
    }
    tibble::tibble(
      model = names_in_order[[index]],
      added_after = if (index > 1L) names_in_order[[index - 1L]] else NA_character_,
      observations = stats::nobs(candidate_model),
      slopes = length(stats::coef(candidate_model)) - 1L,
      log_likelihood = as.numeric(stats::logLik(candidate_model)),
      aic = stats::AIC(candidate_model),
      brier_score = mean((stats::model.response(stats::model.frame(candidate_model)) - stats::fitted(candidate_model))^2),
      roc_auc = binary_auc(stats::model.response(stats::model.frame(candidate_model)), stats::fitted(candidate_model)),
      likelihood_ratio_chisq = if (is.null(comparison)) NA_real_ else as.numeric(comparison$Deviance[[2]]),
      likelihood_ratio_df = if (is.null(comparison)) NA_real_ else as.numeric(comparison$Df[[2]]),
      likelihood_ratio_p_value = if (is.null(comparison)) NA_real_ else as.numeric(comparison$`Pr(>Chi)`[[2]]),
      role = dplyr::case_when(
        names_in_order[[index]] == "Prevalence benchmark" ~ "Reference prediction",
        names_in_order[[index]] == "Starting abundance and observation" ~ "Starting abundance, sampling opportunity, and elapsed time",
        names_in_order[[index]] == "Stage structure" ~ "Adds baseline saplings and stand basal-area structure",
        TRUE ~ "Primary model; adds the v2 American beech hypothesis specified before final fitting"
      )
    )
  })
  result <- dplyr::bind_rows(rows)
  dplyr::mutate(result, delta_aic = .data$aic - min(.data$aic))
}

longitudinal_model_diagnostics <- function(model, data) {
  observed <- data$outcome_loss
  predicted <- stats::fitted(model)
  calibration <- calibration_statistics(observed, predicted)
  influence <- stats::influence.measures(model)
  cooks <- stats::cooks.distance(model)
  leverage <- stats::hatvalues(model)
  tibble::tibble(
    metric = c(
      "Residual deviance / residual df",
      "In-sample Brier score",
      "In-sample ROC AUC",
      "Calibration intercept",
      "Calibration slope",
      "Maximum Cook distance",
      "Maximum leverage",
      "Influential rows by any influence.measures flag"
    ),
    value = c(
      stats::deviance(model) / stats::df.residual(model),
      mean((observed - predicted)^2),
      binary_auc(observed, predicted),
      calibration[["calibration_intercept"]],
      calibration[["calibration_slope"]],
      max(cooks),
      max(leverage),
      sum(apply(influence$is.inf, 1, any))
    ),
    interpretation = c(
      "Descriptive dispersion check for the fitted logistic model",
      "Apparent performance; geographically held-out performance is primary",
      "Apparent discrimination; geographically held-out performance is primary",
      "Apparent calibration; ideal value is zero",
      "Apparent calibration; ideal value is one",
      "Case-influence diagnostic",
      "Design-matrix influence diagnostic",
      "Rows crossing at least one conventional influence.measures threshold"
    )
  )
}

valid_longitudinal_county_folds <- function(raw_data, requested_folds = 5L) {
  fold_data <- raw_data
  fold_data$outcome_no_seedlings <- fold_data$outcome_loss
  maximum <- min(as.integer(requested_folds), dplyr::n_distinct(fold_data$geoid))
  for (k in seq(maximum, 2L, by = -1L)) {
    assignments <- balanced_county_folds(fold_data, k)
    lookup <- stats::setNames(assignments$fold, assignments$geoid)
    fold <- unname(lookup[as.character(raw_data$geoid)])
    support <- tibble::tibble(fold = fold, outcome = raw_data$outcome_loss) |>
      dplyr::group_by(.data$fold) |>
      dplyr::summarise(classes = dplyr::n_distinct(.data$outcome), .groups = "drop")
    if (all(support$classes == 2L)) return(assignments)
  }
  stop("Could not construct geographically grouped folds with both outcome classes.", call. = FALSE)
}

longitudinal_county_cross_validation <- function(raw_data, requested_folds = 5L) {
  specifications <- longitudinal_loss_model_specifications()
  assignments <- valid_longitudinal_county_folds(raw_data, requested_folds)
  fold_lookup <- stats::setNames(assignments$fold, assignments$geoid)
  record_fold <- unname(fold_lookup[as.character(raw_data$geoid)])
  predictions <- list()
  folds <- list()
  counter <- 0L

  for (fold in sort(unique(record_fold))) {
    training_raw <- raw_data[record_fold != fold, , drop = FALSE]
    testing_raw <- raw_data[record_fold == fold, , drop = FALSE]
    scaled <- scale_longitudinal_loss_predictors(training_raw, testing_raw)
    training <- scaled$training
    testing <- scaled$testing
    for (model_name in names(specifications)) {
      counter <- counter + 1L
      fold_model <- stats::glm(
        longitudinal_formula(specifications[[model_name]]),
        family = stats::binomial(),
        data = training
      )
      validate_longitudinal_loss_glm(
        fold_model,
        paste0("Longitudinal loss cross-validation model '", model_name, "' in fold ", fold)
      )
      predicted <- stats::predict(fold_model, newdata = testing, type = "response")
      predictions[[counter]] <- tibble::tibble(
        baseline_plt_cn = testing$baseline_plt_cn,
        baseline_condid = testing$baseline_condid,
        current_plt_cn = testing$current_plt_cn,
        current_condid = testing$current_condid,
        geoid = as.character(testing$geoid),
        fold = fold,
        model = model_name,
        observed = testing$outcome_loss,
        predicted_probability = as.numeric(predicted),
        prediction_method = "Held-out county; transformations learned on training counties only"
      )
      folds[[counter]] <- tibble::tibble(
        fold = fold,
        model = model_name,
        observations = nrow(testing),
        losses = sum(testing$outcome_loss == 1L),
        persistence = sum(testing$outcome_loss == 0L),
        counties = dplyr::n_distinct(testing$geoid),
        brier_score = mean((testing$outcome_loss - predicted)^2),
        roc_auc = binary_auc(testing$outcome_loss, predicted),
        converged = fold_model$converged
      )
    }
  }

  predictions <- dplyr::bind_rows(predictions)
  folds <- dplyr::bind_rows(folds)
  summary <- predictions |>
    dplyr::group_by(.data$model) |>
    dplyr::summarise(
      observations = dplyr::n(),
      losses = sum(.data$observed == 1L),
      counties = dplyr::n_distinct(.data$geoid),
      folds = dplyr::n_distinct(.data$fold),
      brier_score = mean((.data$observed - .data$predicted_probability)^2),
      roc_auc = binary_auc(.data$observed, .data$predicted_probability),
      calibration_intercept = calibration_statistics(.data$observed, .data$predicted_probability)[["calibration_intercept"]],
      calibration_slope = calibration_statistics(.data$observed, .data$predicted_probability)[["calibration_slope"]],
      .groups = "drop"
    )
  benchmark_brier <- summary$brier_score[summary$model == "Prevalence benchmark"]
  summary <- summary |>
    dplyr::mutate(
      roc_auc = dplyr::if_else(.data$model == "Prevalence benchmark", NA_real_, .data$roc_auc),
      calibration_intercept = dplyr::if_else(
        .data$model == "Prevalence benchmark",
        NA_real_,
        .data$calibration_intercept
      ),
      calibration_slope = dplyr::if_else(
        .data$model == "Prevalence benchmark",
        NA_real_,
        .data$calibration_slope
      ),
      brier_skill_vs_prevalence = 1 - .data$brier_score / benchmark_brier,
      validation_design = paste0(max(.data$folds), "-fold cross-validation grouped by county"),
      interpretation = "Internal geographic validation; county effects are not transferred to held-out counties"
    )
  list(
    summary = summary,
    folds = folds,
    predictions = predictions,
    assignments = assignments
  )
}

longitudinal_risk_strata <- function(predictions, model_name = "Beech hypothesis") {
  selected <- predictions |>
    dplyr::filter(.data$model == .env$model_name) |>
    dplyr::mutate(risk_quartile = dplyr::ntile(.data$predicted_probability, 4L))
  selected |>
    dplyr::group_by(.data$risk_quartile) |>
    dplyr::summarise(
      conditions = dplyr::n(),
      losses = sum(.data$observed == 1L),
      observed_loss_fraction = mean(.data$observed == 1L),
      mean_predicted_probability = mean(.data$predicted_probability),
      minimum_predicted_probability = min(.data$predicted_probability),
      maximum_predicted_probability = max(.data$predicted_probability),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      risk_quartile = paste("Quartile", .data$risk_quartile),
      model = model_name,
      note = "Quartiles use geographically held-out predicted probabilities; descriptive risk stratification, not an intervention threshold"
    )
}

longitudinal_random_effect_sensitivity <- function(data, fixed_model) {
  fixed_formula <- paste(deparse(stats::formula(fixed_model)), collapse = " ")
  formula <- stats::as.formula(paste(fixed_formula, "+ (1 | geoid)"))
  attempt <- tryCatch(
    lme4::glmer(
      formula,
      family = stats::binomial(),
      data = data,
      control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
    ),
    error = function(e) e
  )
  if (inherits(attempt, "error")) {
    return(tibble::tibble(
      model = c("Fixed-effect logistic", "County random-intercept sensitivity"),
      converged = c(fixed_model$converged, FALSE),
      singular = c(NA, NA),
      aic = c(stats::AIC(fixed_model), NA_real_),
      county_variance = c(NA_real_, NA_real_),
      note = c("Primary prognostic model", paste("Sensitivity fit failed:", conditionMessage(attempt)))
    ))
  }
  convergence_messages <- attempt@optinfo$conv$lme4$messages %||% character()
  variance <- as.data.frame(lme4::VarCorr(attempt))$vcov[[1]]
  tibble::tibble(
    model = c("Fixed-effect logistic", "County random-intercept sensitivity"),
    converged = c(fixed_model$converged, length(convergence_messages) == 0L),
    singular = c(NA, lme4::isSingular(attempt, tol = 1e-4)),
    aic = c(stats::AIC(fixed_model), stats::AIC(attempt)),
    county_variance = c(NA_real_, variance),
    note = c(
      "Primary prognostic model with county-cluster robust uncertainty",
      "Sensitivity only; singularity does not invalidate the declared fixed-effect model"
    )
  )
}
