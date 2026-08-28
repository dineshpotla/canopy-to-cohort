scale_predictor <- function(x) {
  x <- as.numeric(x)
  spread <- stats::sd(x, na.rm = TRUE)
  if (!is.finite(spread) || spread == 0) return(rep(NA_real_, length(x)))
  as.numeric((x - mean(x, na.rm = TRUE)) / spread)
}

prepare_model_data <- function(data) {
  analytical_cohort_n <- nrow(data)
  prepared <- data |>
    dplyr::transmute(
      plt_cn = .data$plt_cn,
      condid = .data$condid,
      geoid = factor(.data$geoid),
      county_name = .data$county_name,
      outcome_no_seedlings = ifelse(is.na(.data$maple_seedling_detected), NA_integer_, 1L - .data$maple_seedling_detected),
      maple_ba_ft2_ac = .data$maple_ba_ft2_ac,
      log_maple_ba = log1p(.data$maple_ba_ft2_ac),
      nonmaple_ba_ft2_ac = .data$nonmaple_ba_ft2_ac,
      stand_age = .data$stand_age,
      disturbed = factor(.data$disturbed, levels = c(FALSE, TRUE)),
      mean_annual_temp_c = .data$mean_annual_temp_c,
      mean_annual_precip_mm = .data$mean_annual_precip_mm,
      measyear = .data$measyear,
      microplot_coverage = .data$micrprop_unadj
    ) |>
    dplyr::filter(
      !is.na(.data$outcome_no_seedlings), !is.na(.data$maple_ba_ft2_ac),
      !is.na(.data$nonmaple_ba_ft2_ac), !is.na(.data$microplot_coverage),
      .data$microplot_coverage > 0
    ) |>
    dplyr::mutate(
      z_maple_ba = scale_predictor(.data$log_maple_ba),
      z_nonmaple_ba = scale_predictor(log1p(.data$nonmaple_ba_ft2_ac)),
      z_stand_age = scale_predictor(.data$stand_age),
      z_mean_temp = scale_predictor(.data$mean_annual_temp_c),
      z_precip = scale_predictor(.data$mean_annual_precip_mm),
      z_year = scale_predictor(.data$measyear),
      z_microplot_coverage = scale_predictor(.data$microplot_coverage)
    ) |>
    droplevels()
  attr(prepared, "analytical_cohort_n") <- analytical_cohort_n
  attr(prepared, "outcome_eligible_n") <- nrow(prepared)
  prepared
}

model_scaling_specifications <- function() {
  list(
    z_maple_ba = list(raw = "maple_ba_ft2_ac", transformation = "log1p", transform = log1p),
    z_nonmaple_ba = list(raw = "nonmaple_ba_ft2_ac", transformation = "log1p", transform = log1p),
    z_microplot_coverage = list(raw = "microplot_coverage", transformation = "identity", transform = identity),
    z_stand_age = list(raw = "stand_age", transformation = "identity", transform = identity),
    z_mean_temp = list(raw = "mean_annual_temp_c", transformation = "identity", transform = identity),
    z_precip = list(raw = "mean_annual_precip_mm", transformation = "identity", transform = identity),
    z_year = list(raw = "measyear", transformation = "identity", transform = identity)
  )
}

scale_model_predictors <- function(data, terms, cohort_definition = "final model-complete cohort") {
  specifications <- model_scaling_specifications()
  audit <- list()
  for (term in intersect(terms, names(specifications))) {
    specification <- specifications[[term]]
    values <- specification$transform(data[[specification$raw]])
    center <- mean(values, na.rm = TRUE)
    spread <- stats::sd(values, na.rm = TRUE)
    if (!is.finite(center) || !is.finite(spread) || spread == 0) {
      stop("Model scaling failed for ", term, ".", call. = FALSE)
    }
    data[[term]] <- (values - center) / spread
    if (term == "z_maple_ba") data$log_maple_ba <- values
    audit[[term]] <- tibble::tibble(
      model_variable = term,
      source_variable = specification$raw,
      transformation = specification$transformation,
      center = center,
      scale = spread,
      observations = sum(is.finite(values)),
      cohort_definition = cohort_definition
    )
  }
  list(data = data, audit = dplyr::bind_rows(audit))
}

choose_model_terms <- function(data, config) {
  candidate_terms <- c("z_maple_ba", "z_nonmaple_ba", "z_microplot_coverage")
  optional <- c("z_stand_age", "disturbed", "z_mean_temp", "z_precip", "z_year")
  for (term in optional) {
    x <- data[[term]]
    complete <- mean(!is.na(x))
    variation <- if (is.factor(x)) nlevels(droplevels(x[!is.na(x)])) > 1L else stats::sd(x, na.rm = TRUE) > 0
    if (complete >= 0.75 && isTRUE(variation)) candidate_terms <- c(candidate_terms, term)
  }
  if (all(c("z_mean_temp", "z_precip") %in% candidate_terms)) {
    climate_correlation <- stats::cor(data$z_mean_temp, data$z_precip, use = "complete.obs")
    if (is.finite(climate_correlation) && abs(climate_correlation) > config$analysis$maximum_correlation) {
      candidate_terms <- setdiff(candidate_terms, "z_precip")
    }
  }
  candidate_terms
}

fixed_effect_rhs <- function(terms, nonlinear_maple = TRUE, spline_df = 3L) {
  model_terms <- terms
  if (nonlinear_maple) {
    model_terms[model_terms == "z_maple_ba"] <- sprintf("splines::ns(z_maple_ba, df = %d)", as.integer(spline_df))
  }
  paste(model_terms, collapse = " + ")
}

model_support_summary <- function(
    data,
    terms,
    fixed_effect_parameters = length(terms),
    analytical_cohort_n = nrow(data),
    outcome_eligible_n = nrow(data)) {
  complete <- data[stats::complete.cases(data[c("outcome_no_seedlings", terms, "geoid")]), , drop = FALSE]
  events <- sum(complete$outcome_no_seedlings == 1L)
  nonevents <- sum(complete$outcome_no_seedlings == 0L)
  plot_counts <- table(complete$plt_cn)
  tibble::tibble(
    analytical_cohort_n = analytical_cohort_n,
    outcome_eligible_n = outcome_eligible_n,
    model_complete_n = nrow(complete),
    model_complete_fraction_of_cohort = nrow(complete) / analytical_cohort_n,
    outcome_eligible_fraction_of_cohort = outcome_eligible_n / analytical_cohort_n,
    observations = nrow(complete), events_no_seedlings = events,
    events_seedlings = nonevents, event_fraction = events / nrow(complete),
    fixed_effect_parameters = fixed_effect_parameters,
    events_per_parameter = min(events, nonevents) / max(fixed_effect_parameters, 1L),
    fixed_effect_terms = fixed_effect_parameters,
    events_per_term = min(events, nonevents) / max(fixed_effect_parameters, 1L),
    counties = dplyr::n_distinct(complete$geoid),
    median_county_n = stats::median(table(complete$geoid)),
    plot_visits = dplyr::n_distinct(complete$plt_cn),
    multi_condition_plot_visits = sum(plot_counts > 1L),
    max_conditions_per_plot_visit = if (length(plot_counts)) max(plot_counts) else 0L,
    complete_case_fraction = nrow(complete) / analytical_cohort_n
  )
}

fit_mixed_logistic <- function(fixed_formula, data, random_terms = "(1 | geoid)") {
  formula <- stats::as.formula(paste(fixed_formula, "+", paste(random_terms, collapse = " + ")))
  fit <- tryCatch(
    lme4::glmer(
      formula, family = stats::binomial(link = "logit"), data = data,
      control = lme4::glmerControl(
        optimizer = "bobyqa", optCtrl = list(maxfun = 2e5),
        check.conv.singular = "ignore"
      )
    ),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)
  messages <- fit@optinfo$conv$lme4$messages %||% character()
  optimizer_code <- fit@optinfo$conv$opt %||% 0L
  list(
    model = fit,
    converged = length(messages) == 0L && all(optimizer_code == 0L),
    singular = lme4::isSingular(fit, tol = 1e-4),
    random_terms = random_terms
  )
}

random_effect_variance <- function(model, group) {
  variance_table <- as.data.frame(lme4::VarCorr(model))
  value <- variance_table$vcov[variance_table$grp == group & variance_table$var1 == "(Intercept)"]
  if (length(value)) value[[1]] else NA_real_
}

model_random_structure_comparison <- function(county_model, county_plot_attempt = NULL) {
  county_log_likelihood <- as.numeric(stats::logLik(county_model))
  county_row <- tibble::tibble(
    model = "County only",
    random_effect_structure = "county random intercept",
    converged = TRUE,
    singular = lme4::isSingular(county_model, tol = 1e-4),
    log_likelihood = county_log_likelihood,
    aic = stats::AIC(county_model),
    bic = stats::BIC(county_model),
    county_variance = random_effect_variance(county_model, "geoid"),
    plot_visit_variance = NA_real_,
    likelihood_ratio_chisq = NA_real_,
    boundary_mixture_p_value = NA_real_,
    selected = TRUE,
    selection_note = "Selected as the parsimonious supported structure"
  )
  if (is.null(county_plot_attempt)) {
    return(dplyr::mutate(
      county_row,
      selection_note = "Selected; the plot-visit candidate could not be fit reliably"
    ))
  }

  extended_model <- county_plot_attempt$model
  statistic <- max(0, 2 * (as.numeric(stats::logLik(extended_model)) - county_log_likelihood))
  boundary_p <- 0.5 * stats::pchisq(statistic, df = 1, lower.tail = FALSE)
  extended_row <- tibble::tibble(
    model = "County plus plot visit",
    random_effect_structure = "county and plot-visit random intercepts",
    converged = county_plot_attempt$converged,
    singular = county_plot_attempt$singular,
    log_likelihood = as.numeric(stats::logLik(extended_model)),
    aic = stats::AIC(extended_model),
    bic = stats::BIC(extended_model),
    county_variance = random_effect_variance(extended_model, "geoid"),
    plot_visit_variance = random_effect_variance(extended_model, "plt_cn"),
    likelihood_ratio_chisq = statistic,
    boundary_mixture_p_value = boundary_p,
    selected = FALSE,
    selection_note = "Not selected: the added variance component lacks support and does not improve AIC"
  )
  dplyr::bind_rows(county_row, extended_row)
}

model_functional_form_comparison <- function(linear_model, spline_model, spline_df = 3L) {
  comparison <- stats::anova(linear_model, spline_model, test = "Chisq")
  likelihood_row <- comparison[nrow(comparison), , drop = FALSE]
  tibble::tibble(
    model = c("Linear maple term", sprintf("Natural spline maple term (df = %d)", spline_df)),
    maple_function = c("linear standardized log1p basal area", "natural spline of standardized log1p basal area"),
    fixed_effect_parameters = c(length(lme4::fixef(linear_model)) - 1L, length(lme4::fixef(spline_model)) - 1L),
    estimated_fixed_coefficients_including_intercept = c(
      length(lme4::fixef(linear_model)),
      length(lme4::fixef(spline_model))
    ),
    log_likelihood = c(as.numeric(stats::logLik(linear_model)), as.numeric(stats::logLik(spline_model))),
    aic = c(stats::AIC(linear_model), stats::AIC(spline_model)),
    bic = c(stats::BIC(linear_model), stats::BIC(spline_model)),
    likelihood_ratio_chisq = c(NA_real_, as.numeric(likelihood_row[["Chisq"]])),
    likelihood_ratio_df = c(NA_real_, as.numeric(likelihood_row[["Df"]])),
    likelihood_ratio_p_value = c(NA_real_, as.numeric(likelihood_row[["Pr(>Chisq)"]])),
    comparison_note = c("Reference model", "Likelihood-ratio test against the nested linear maple specification")
  )
}

summarize_model_diagnostics <- function(model, spline_df = 3L) {
  variance_table <- as.data.frame(lme4::VarCorr(model))
  county_variance <- variance_table$vcov[variance_table$grp == "geoid"][[1]]
  gradient <- model@optinfo$derivs$gradient %||% NA_real_
  tibble::tibble(
    model_class = class(model)[[1]],
    converged = length(model@optinfo$conv$lme4$messages %||% character()) == 0L && all((model@optinfo$conv$opt %||% 0L) == 0L),
    singular = lme4::isSingular(model, tol = 1e-4),
    log_likelihood = as.numeric(stats::logLik(model)), aic = stats::AIC(model), bic = stats::BIC(model),
    county_random_intercept_variance = county_variance,
    county_latent_scale_icc = county_variance / (county_variance + pi^2 / 3),
    max_absolute_optimizer_gradient = max(abs(gradient), na.rm = TRUE),
    random_effect_structure = "county random intercept",
    maple_function = sprintf(
      "natural spline of standardized log1p basal area (df = %d)",
      as.integer(spline_df)
    )
  )
}

fit_regeneration_model <- function(data, config, spline_df = 3L) {
  analytical_cohort_n <- attr(data, "analytical_cohort_n") %||% nrow(data)
  outcome_eligible_n <- attr(data, "outcome_eligible_n") %||% nrow(data)
  terms <- choose_model_terms(data, config)
  repeat {
    parameter_count <- length(terms) + spline_df - 1L
    complete_unscaled <- data[
      stats::complete.cases(data[c("outcome_no_seedlings", terms, "geoid")]),
      , drop = FALSE
    ]
    scaled <- scale_model_predictors(complete_unscaled, terms)
    complete <- scaled$data
    support <- model_support_summary(
      complete,
      terms,
      parameter_count,
      analytical_cohort_n = analytical_cohort_n,
      outcome_eligible_n = outcome_eligible_n
    )
    if (support$events_per_parameter >= config$analysis$minimum_events_per_parameter || length(terms) <= 3L) break
    terms <- terms[-length(terms)]
  }
  county_supported <- support$counties >= config$analysis$minimum_groups_for_random_effect &&
    sum(table(complete$geoid) >= 5L) >= config$analysis$minimum_groups_for_random_effect
  if (!county_supported) stop("The prespecified county random intercept lacks the configured group support.", call. = FALSE)

  spline_formula <- paste("outcome_no_seedlings ~", fixed_effect_rhs(terms, TRUE, spline_df))
  linear_formula <- paste("outcome_no_seedlings ~", fixed_effect_rhs(terms, FALSE, spline_df))
  spline_attempt <- fit_mixed_logistic(spline_formula, complete)
  linear_attempt <- fit_mixed_logistic(linear_formula, complete)
  if (is.null(spline_attempt) || !isTRUE(spline_attempt$converged)) stop("The prespecified county-level nonlinear mixed model did not converge.", call. = FALSE)
  if (isTRUE(spline_attempt$singular)) stop("The prespecified county random intercept was singular.", call. = FALSE)
  if (is.null(linear_attempt) || !isTRUE(linear_attempt$converged)) stop("The linear functional-form comparison model did not converge.", call. = FALSE)

  fit <- spline_attempt$model
  plot_candidate_supported <- support$multi_condition_plot_visits >= config$analysis$minimum_groups_for_random_effect
  county_plot_attempt <- if (plot_candidate_supported) {
    fit_mixed_logistic(spline_formula, complete, c("(1 | geoid)", "(1 | plt_cn)"))
  } else {
    NULL
  }
  if (!is.null(county_plot_attempt) && !isTRUE(county_plot_attempt$converged)) county_plot_attempt <- NULL
  random_comparison <- model_random_structure_comparison(fit, county_plot_attempt)
  if (nrow(random_comparison) > 1L && random_comparison$aic[[2]] + 2 < random_comparison$aic[[1]]) {
    stop("The county-plus-plot candidate materially improves AIC; county-only selection must be reconsidered.", call. = FALSE)
  }
  conditional_predictions <- stats::predict(fit, type = "response")
  population_predictions <- stats::predict(fit, type = "response", re.form = NA)
  diagnostics <- summarize_model_diagnostics(fit, spline_df)
  comparison <- model_functional_form_comparison(linear_attempt$model, fit, spline_df)
  support$model_type <- "mixed-effects logistic regression"
  support$random_effect_used <- TRUE
  support$county_random_effect_used <- TRUE
  support$plot_random_effect_used <- FALSE
  support$random_effect_structure <- "county random intercept"
  support$model_formula <- paste(spline_formula, "+ (1 | geoid)")
  support$maple_function <- sprintf("natural spline of standardized log1p basal area (df = %d)", spline_df)
  support$maple_spline_df <- spline_df
  support$converged <- spline_attempt$converged
  support$singular <- spline_attempt$singular
  support$in_sample_brier_conditional <- mean((complete$outcome_no_seedlings - conditional_predictions)^2)
  support$in_sample_brier_fixed_effects_only <- mean((complete$outcome_no_seedlings - population_predictions)^2)
  support$brier_score <- support$in_sample_brier_conditional
  support$coefficient_interval_method <- "model-based Wald 95% confidence intervals"
  support$random_structure_selection_rule <- "county-only retained unless the plot-visit candidate improves AIC by more than 2"
  support$county_plus_plot_delta_aic <- if (nrow(random_comparison) > 1L) {
    random_comparison$aic[[2]] - random_comparison$aic[[1]]
  } else {
    NA_real_
  }
  support$county_plus_plot_boundary_p_value <- if (nrow(random_comparison) > 1L) {
    random_comparison$boundary_mixture_p_value[[2]]
  } else {
    NA_real_
  }
  list(
    model = fit, linear_comparison_model = linear_attempt$model, data = complete,
    support = support, diagnostics = diagnostics,
    functional_form_comparison = comparison,
    random_structure_comparison = random_comparison,
    scaling_audit = scaled$audit,
    terms = terms, spline_df = spline_df
  )
}

tidy_odds_ratios <- function(model, level = 0.95) {
  coefficients <- as.data.frame(stats::coef(summary(model)))
  coefficients$term <- rownames(coefficients)
  rownames(coefficients) <- NULL
  statistic_name <- intersect(c("z value", "t value"), names(coefficients))[[1]]
  p_value_name <- intersect(c("Pr(>|z|)", "Pr(>|t|)"), names(coefficients))[[1]]
  critical <- stats::qnorm(1 - (1 - level) / 2)
  labels <- c(
    z_nonmaple_ba = "Non-maple basal area",
    z_microplot_coverage = "Microplot condition coverage",
    z_stand_age = "Stand age",
    disturbedTRUE = "Recorded disturbance",
    z_mean_temp = "Mean annual temperature",
    z_precip = "Annual precipitation",
    z_year = "Measurement year"
  )
  coefficients |>
    dplyr::filter(.data$term != "(Intercept)", !grepl("ns\\(z_maple_ba", .data$term)) |>
    dplyr::transmute(
      term = .data$term,
      estimate = exp(.data[["Estimate"]]),
      std.error = .data[["Std. Error"]],
      statistic = .data[[statistic_name]],
      p.value = .data[[p_value_name]],
      conf.low = exp(.data[["Estimate"]] - critical * .data[["Std. Error"]]),
      conf.high = exp(.data[["Estimate"]] + critical * .data[["Std. Error"]]),
      label = dplyr::coalesce(unname(labels[.data$term]), .data$term),
      interpretation = "Adjusted odds ratio for no sugar-maple seedlings tallied; continuous effects are per 1 SD",
      inference_method = "Wald 95% confidence interval",
      maple_effect_note = "The nonlinear sugar-maple association is reported as a prediction curve, not a single odds ratio"
    )
}

fixed_effect_inference_sensitivity <- function(fit, odds_ratios, level = 0.95) {
  formula <- stats::as.formula(
    paste("outcome_no_seedlings ~", fixed_effect_rhs(fit$terms, TRUE, fit$spline_df))
  )
  sensitivity_model <- stats::glm(formula, family = stats::binomial(), data = fit$data)
  design <- stats::model.matrix(sensitivity_model)
  response <- stats::model.response(stats::model.frame(sensitivity_model))
  fitted <- stats::fitted(sensitivity_model)
  score_rows <- design * as.numeric(response - fitted)
  cluster <- as.character(fit$data$geoid)
  cluster_scores <- rowsum(score_rows, cluster, reorder = FALSE)
  weights <- as.numeric(fitted * (1 - fitted))
  bread <- solve(crossprod(design, design * weights))
  clusters <- nrow(cluster_scores)
  observations <- nrow(design)
  parameters <- ncol(design)
  correction <- (clusters / (clusters - 1)) * ((observations - 1) / (observations - parameters))
  covariance <- correction * bread %*% crossprod(cluster_scores) %*% bread
  robust_standard_error <- sqrt(diag(covariance))
  coefficient <- stats::coef(sensitivity_model)
  critical <- stats::qnorm(1 - (1 - level) / 2)
  robust <- tibble::tibble(
    term = names(coefficient),
    cluster_robust_log_odds = unname(coefficient),
    cluster_robust_standard_error = unname(robust_standard_error),
    cluster_robust_p_value = 2 * stats::pnorm(abs(cluster_robust_log_odds / cluster_robust_standard_error), lower.tail = FALSE),
    cluster_robust_odds_ratio = exp(cluster_robust_log_odds),
    cluster_robust_conf_low = exp(cluster_robust_log_odds - critical * cluster_robust_standard_error),
    cluster_robust_conf_high = exp(cluster_robust_log_odds + critical * cluster_robust_standard_error)
  ) |>
    dplyr::filter(.data$term != "(Intercept)", !grepl("ns\\(z_maple_ba", .data$term))

  odds_ratios |>
    dplyr::select(
      "term", "label",
      mixed_model_odds_ratio = "estimate",
      mixed_model_conf_low = "conf.low",
      mixed_model_conf_high = "conf.high",
      mixed_model_wald_p_value = "p.value"
    ) |>
    dplyr::mutate(
      mixed_model_bh_p_value = stats::p.adjust(.data$mixed_model_wald_p_value, method = "BH")
    ) |>
    dplyr::left_join(robust, by = "term") |>
    dplyr::mutate(
      sensitivity_model = "fixed-effect logistic regression with county-cluster CR1 sandwich covariance",
      interpretation = "Cluster-robust estimates are a sensitivity analysis, not replacements for the county mixed model"
    )
}

maple_effect_curve <- function(fit, points = 160L, level = 0.95) {
  model <- fit$model
  data <- fit$data
  observed <- data$maple_ba_ft2_ac[is.finite(data$maple_ba_ft2_ac)]
  upper <- as.numeric(stats::quantile(observed, 0.99, names = FALSE, type = 8))
  grid <- expm1(seq(0, log1p(upper), length.out = points))
  log_center <- mean(data$log_maple_ba, na.rm = TRUE)
  log_scale <- stats::sd(data$log_maple_ba, na.rm = TRUE)

  newdata <- data[rep(1L, length(grid)), , drop = FALSE]
  numeric_adjusters <- intersect(
    c("z_nonmaple_ba", "z_microplot_coverage", "z_stand_age", "z_mean_temp", "z_precip", "z_year"),
    fit$terms
  )
  for (term in numeric_adjusters) newdata[[term]] <- 0
  if ("disturbed" %in% fit$terms) newdata$disturbed <- factor(FALSE, levels = levels(data$disturbed))
  newdata$maple_ba_ft2_ac <- grid
  newdata$log_maple_ba <- log1p(grid)
  newdata$z_maple_ba <- (newdata$log_maple_ba - log_center) / log_scale

  design <- stats::model.matrix(stats::delete.response(stats::terms(model)), newdata)
  beta <- lme4::fixef(model)
  design <- design[, names(beta), drop = FALSE]
  covariance <- as.matrix(stats::vcov(model))[names(beta), names(beta), drop = FALSE]
  linear_predictor <- as.numeric(design %*% beta)
  standard_error <- sqrt(rowSums((design %*% covariance) * design))
  critical <- stats::qnorm(1 - (1 - level) / 2)
  tibble::tibble(
    maple_ba_ft2_ac = grid, log1p_maple_ba = log1p(grid), z_maple_ba = newdata$z_maple_ba,
    spline_df = fit$spline_df,
    predicted_probability = stats::plogis(linear_predictor),
    conf_low = stats::plogis(linear_predictor - critical * standard_error),
    conf_high = stats::plogis(linear_predictor + critical * standard_error),
    prediction_scale = "probability of no sugar-maple seedlings tallied",
    covariate_profile = "continuous adjusters at their means; no recorded disturbance; county random effect set to zero",
    inference_method = "pointwise Wald 95% confidence interval",
    observed_range_note = "curve restricted to zero through the observed 99th percentile of sugar-maple basal area"
  )
}

binary_auc <- function(observed, predicted) {
  keep <- is.finite(observed) & is.finite(predicted)
  observed <- observed[keep]
  predicted <- predicted[keep]
  positives <- sum(observed == 1L)
  negatives <- sum(observed == 0L)
  if (positives == 0L || negatives == 0L) return(NA_real_)
  ranks <- rank(predicted, ties.method = "average")
  (sum(ranks[observed == 1L]) - positives * (positives + 1) / 2) / (positives * negatives)
}

balanced_county_folds <- function(data, k = 10L) {
  county <- data |>
    dplyr::mutate(geoid = as.character(.data$geoid)) |>
    dplyr::group_by(.data$geoid) |>
    dplyr::summarise(observations = dplyr::n(), events = sum(.data$outcome_no_seedlings == 1L), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(.data$observations), dplyr::desc(.data$events), .data$geoid)
  k <- min(as.integer(k), nrow(county))
  if (k < 2L) stop("Grouped validation requires at least two counties.", call. = FALSE)
  fold_observations <- numeric(k)
  fold_events <- numeric(k)
  fold_counties <- integer(k)
  assigned <- integer(nrow(county))
  for (index in seq_len(nrow(county))) {
    fold <- order(fold_observations, fold_events, fold_counties, seq_len(k))[[1]]
    assigned[[index]] <- fold
    fold_observations[[fold]] <- fold_observations[[fold]] + county$observations[[index]]
    fold_events[[fold]] <- fold_events[[fold]] + county$events[[index]]
    fold_counties[[fold]] <- fold_counties[[fold]] + 1L
  }
  dplyr::mutate(county, fold = assigned)
}

calibration_statistics <- function(observed, predicted) {
  clipped <- pmin(pmax(predicted, 1e-6), 1 - 1e-6)
  linear_predictor <- stats::qlogis(clipped)
  intercept_fit <- suppressWarnings(stats::glm(observed ~ 1, offset = linear_predictor, family = stats::binomial()))
  slope_fit <- suppressWarnings(stats::glm(observed ~ linear_predictor, family = stats::binomial()))
  c(
    calibration_intercept = unname(stats::coef(intercept_fit)[[1]]),
    calibration_slope = unname(stats::coef(slope_fit)[[2]])
  )
}

apply_training_fold_scaling <- function(training, testing, terms) {
  specifications <- model_scaling_specifications()
  for (term in intersect(terms, names(specifications))) {
    specification <- specifications[[term]]
    training_values <- specification$transform(training[[specification$raw]])
    testing_values <- specification$transform(testing[[specification$raw]])
    center <- mean(training_values, na.rm = TRUE)
    spread <- stats::sd(training_values, na.rm = TRUE)
    if (!is.finite(spread) || spread == 0) stop("Fold-specific scaling failed for ", term, ".", call. = FALSE)
    training[[term]] <- (training_values - center) / spread
    testing[[term]] <- (testing_values - center) / spread
    if (term == "z_maple_ba") {
      training$log_maple_ba <- training_values
      testing$log_maple_ba <- testing_values
    }
  }
  list(training = training, testing = testing)
}

county_grouped_cross_validation <- function(fit, k = 10L) {
  data <- fit$data
  assignments <- balanced_county_folds(data, k = k)
  fold_lookup <- stats::setNames(assignments$fold, assignments$geoid)
  record_fold <- unname(fold_lookup[as.character(data$geoid)])
  predictions <- vector("list", max(assignments$fold))
  fold_metrics <- vector("list", max(assignments$fold))
  fixed_formula <- paste("outcome_no_seedlings ~", fixed_effect_rhs(fit$terms, TRUE, fit$spline_df))

  for (fold in seq_len(max(assignments$fold))) {
    training <- data[record_fold != fold, , drop = FALSE]
    testing <- data[record_fold == fold, , drop = FALSE]
    scaled <- apply_training_fold_scaling(training, testing, fit$terms)
    training <- scaled$training
    testing <- scaled$testing
    attempt <- fit_mixed_logistic(fixed_formula, training)
    if (is.null(attempt) || !isTRUE(attempt$converged)) stop("Grouped cross-validation model failed in fold ", fold, ".", call. = FALSE)
    predicted <- stats::predict(
      attempt$model, newdata = testing, type = "response",
      re.form = NA, allow.new.levels = TRUE
    )
    predictions[[fold]] <- tibble::tibble(
      plt_cn = testing$plt_cn, condid = testing$condid, geoid = as.character(testing$geoid),
      fold = fold, observed = testing$outcome_no_seedlings,
      predicted_probability = as.numeric(predicted),
      prediction_method = "held-out county; training-fold scaling and spline; fixed effects only (county random effect set to zero)"
    )
    fold_metrics[[fold]] <- tibble::tibble(
      fold = fold, observations = nrow(testing), events = sum(testing$outcome_no_seedlings == 1L),
      counties = dplyr::n_distinct(testing$geoid),
      brier_score = mean((testing$outcome_no_seedlings - predicted)^2),
      roc_auc = binary_auc(testing$outcome_no_seedlings, predicted),
      training_model_singular = attempt$singular
    )
  }
  predictions <- dplyr::bind_rows(predictions) |>
    dplyr::arrange(.data$fold, .data$geoid, .data$plt_cn, .data$condid)
  fold_metrics <- dplyr::bind_rows(fold_metrics)
  calibration <- calibration_statistics(predictions$observed, predictions$predicted_probability)
  summary <- tibble::tibble(
    metric = c("Brier score", "ROC AUC", "Calibration intercept", "Calibration slope"),
    value = c(
      mean((predictions$observed - predictions$predicted_probability)^2),
      binary_auc(predictions$observed, predictions$predicted_probability),
      calibration[["calibration_intercept"]], calibration[["calibration_slope"]]
    ),
    ideal_value = c(0, 1, 0, 1),
    validation_design = sprintf("deterministic %d-fold cross-validation grouped by county", max(predictions$fold)),
    prediction_method = "transformations learned in each training fold; held-out counties predicted with fixed effects only; no county effect transferred",
    observations = nrow(predictions), counties = dplyr::n_distinct(predictions$geoid),
    folds = max(predictions$fold)
  )
  list(summary = summary, folds = fold_metrics, predictions = predictions, assignments = assignments)
}
