scale_predictor <- function(x) {
  x <- as.numeric(x)
  spread <- stats::sd(x, na.rm = TRUE)
  if (!is.finite(spread) || spread == 0) return(rep(NA_real_, length(x)))
  as.numeric((x - mean(x, na.rm = TRUE)) / spread)
}

prepare_model_data <- function(data, established_only = FALSE) {
  source_cohort_n <- nrow(data)
  prepared <- data |>
    dplyr::transmute(
      plt_cn = .data$plt_cn,
      condid = .data$condid,
      geoid = factor(.data$geoid),
      county_name = .data$county_name,
      outcome_no_seedlings = ifelse(is.na(.data$maple_seedling_detected), NA_integer_, 1L - .data$maple_seedling_detected),
      focal_maple_ba_ft2_ac = if (established_only) .data$established_maple_ba_ft2_ac else .data$maple_ba_ft2_ac,
      all_size_maple_ba_ft2_ac = .data$maple_ba_ft2_ac,
      established_maple_ba_ft2_ac = .data$established_maple_ba_ft2_ac,
      established_maple_records = .data$established_maple_records,
      maple_sapling_ba_ft2_ac = .data$maple_sapling_ba_ft2_ac,
      maple_sapling_present = factor(.data$maple_sapling_present, levels = c(FALSE, TRUE)),
      nonmaple_ba_ft2_ac = .data$nonmaple_ba_ft2_ac,
      stand_age = .data$stand_age,
      disturbed = factor(.data$disturbed, levels = c(FALSE, TRUE)),
      treated = factor(.data$treated, levels = c(FALSE, TRUE)),
      forest_type_code = factor(.data$fortypcd),
      forest_type = .data$forest_type,
      mean_annual_temp_c = .data$mean_annual_temp_c,
      mean_annual_precip_mm = .data$mean_annual_precip_mm,
      measyear = .data$measyear,
      microplot_coverage = .data$micrprop_unadj
    ) |>
    dplyr::filter(
      !is.na(.data$outcome_no_seedlings), !is.na(.data$focal_maple_ba_ft2_ac),
      !is.na(.data$nonmaple_ba_ft2_ac), !is.na(.data$microplot_coverage),
      .data$microplot_coverage > 0,
      !.env$established_only | .data$established_maple_records > 0
    ) |>
    dplyr::mutate(
      log_maple_ba = log1p(.data$focal_maple_ba_ft2_ac),
      z_maple_ba = scale_predictor(.data$log_maple_ba),
      z_nonmaple_ba = scale_predictor(log1p(.data$nonmaple_ba_ft2_ac)),
      z_stand_age = scale_predictor(.data$stand_age),
      z_mean_temp = scale_predictor(.data$mean_annual_temp_c),
      z_precip = scale_predictor(.data$mean_annual_precip_mm),
      z_year = scale_predictor(.data$measyear),
      z_microplot_coverage = scale_predictor(.data$microplot_coverage)
    ) |>
    droplevels()
  attr(prepared, "source_cohort_n") <- source_cohort_n
  attr(prepared, "analytical_cohort_n") <- nrow(prepared)
  attr(prepared, "outcome_eligible_n") <- nrow(prepared)
  attr(prepared, "cohort_definition") <- if (established_only) {
    "seedling-sampled conditions with at least one live sugar-maple TREE record at least 5 inches DBH"
  } else {
    "all seedling-sampled northern-hardwood conditions"
  }
  attr(prepared, "maple_exposure_definition") <- if (established_only) {
    "frame-corrected basal area of live sugar-maple TREE records at least 5 inches DBH"
  } else {
    "frame-corrected basal area of all live sugar-maple TREE records at least 1 inch DBH"
  }
  prepared
}

model_scaling_specifications <- function() {
  list(
    z_maple_ba = list(raw = "focal_maple_ba_ft2_ac", transformation = "log1p", transform = log1p),
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

choose_model_terms <- function(data, config, include_sapling = FALSE, include_treatment = FALSE) {
  candidate_terms <- c("z_maple_ba", "z_nonmaple_ba", "z_microplot_coverage")
  if (include_sapling) candidate_terms <- append(candidate_terms, "maple_sapling_present", after = 1L)
  if (include_treatment) candidate_terms <- c(candidate_terms, "treated")
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

summarize_model_diagnostics <- function(model, nonlinear_maple = TRUE, spline_df = 3L) {
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
    maple_function = if (nonlinear_maple) {
      sprintf("natural spline of standardized log1p basal area (df = %d)", as.integer(spline_df))
    } else {
      "linear standardized log1p basal area"
    }
  )
}

fit_regeneration_model <- function(
    data,
    config,
    spline_df = 3L,
    nonlinear_maple = TRUE,
    include_sapling = FALSE,
    include_treatment = FALSE,
    cohort_label = "Full seedling-sampled cohort") {
  analytical_cohort_n <- attr(data, "analytical_cohort_n") %||% nrow(data)
  outcome_eligible_n <- attr(data, "outcome_eligible_n") %||% nrow(data)
  source_cohort_n <- attr(data, "source_cohort_n") %||% analytical_cohort_n
  cohort_definition <- attr(data, "cohort_definition") %||% cohort_label
  maple_exposure_definition <- attr(data, "maple_exposure_definition") %||% "frame-corrected sugar-maple basal area"
  terms <- choose_model_terms(data, config, include_sapling, include_treatment)
  repeat {
    parameter_count <- length(terms) + if (nonlinear_maple) spline_df - 1L else 0L
    complete_unscaled <- data[
      stats::complete.cases(data[c("outcome_no_seedlings", terms, "geoid")]),
      , drop = FALSE
    ]
    scaled <- scale_model_predictors(complete_unscaled, terms, cohort_definition)
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
  if (is.null(spline_attempt) || !isTRUE(spline_attempt$converged)) stop("The nonlinear functional-form comparison model did not converge.", call. = FALSE)
  if (is.null(linear_attempt) || !isTRUE(linear_attempt$converged)) stop("The linear functional-form comparison model did not converge.", call. = FALSE)

  selected_attempt <- if (nonlinear_maple) spline_attempt else linear_attempt
  if (isTRUE(selected_attempt$singular)) stop("The prespecified county random intercept was singular.", call. = FALSE)
  fit <- selected_attempt$model
  selected_formula <- if (nonlinear_maple) spline_formula else linear_formula
  plot_candidate_supported <- support$multi_condition_plot_visits >= config$analysis$minimum_groups_for_random_effect
  county_plot_attempt <- if (plot_candidate_supported) {
    fit_mixed_logistic(selected_formula, complete, c("(1 | geoid)", "(1 | plt_cn)"))
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
  diagnostics <- summarize_model_diagnostics(fit, nonlinear_maple, spline_df)
  comparison <- model_functional_form_comparison(linear_attempt$model, spline_attempt$model, spline_df) |>
    dplyr::mutate(selected = if (nonlinear_maple) grepl("Natural spline", .data$model) else .data$model == "Linear maple term")
  support$model_type <- "mixed-effects logistic regression"
  support$source_cohort_n <- source_cohort_n
  support$cohort_label <- cohort_label
  support$cohort_definition <- cohort_definition
  support$maple_exposure_definition <- maple_exposure_definition
  support$random_effect_used <- TRUE
  support$county_random_effect_used <- TRUE
  support$plot_random_effect_used <- FALSE
  support$random_effect_structure <- "county random intercept"
  support$model_formula <- paste(selected_formula, "+ (1 | geoid)")
  support$maple_function <- if (nonlinear_maple) {
    sprintf("natural spline of standardized log1p basal area (df = %d)", spline_df)
  } else {
    "linear standardized log1p basal area"
  }
  support$maple_spline_df <- if (nonlinear_maple) spline_df else NA_integer_
  support$converged <- selected_attempt$converged
  support$singular <- selected_attempt$singular
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
    terms = terms, spline_df = spline_df, nonlinear_maple = nonlinear_maple,
    include_sapling = include_sapling, include_treatment = include_treatment,
    cohort_label = cohort_label, cohort_definition = cohort_definition,
    maple_exposure_definition = maple_exposure_definition
  )
}

tidy_odds_ratios <- function(model, level = 0.95, maple_label = "Sugar-maple basal area") {
  coefficients <- as.data.frame(stats::coef(summary(model)))
  coefficients$term <- rownames(coefficients)
  rownames(coefficients) <- NULL
  statistic_name <- intersect(c("z value", "t value"), names(coefficients))[[1]]
  p_value_name <- intersect(c("Pr(>|z|)", "Pr(>|t|)"), names(coefficients))[[1]]
  critical <- stats::qnorm(1 - (1 - level) / 2)
  labels <- c(
    z_maple_ba = maple_label,
    maple_sapling_presentTRUE = "Sugar-maple saplings present",
    z_nonmaple_ba = "Non-maple basal area",
    z_microplot_coverage = "Microplot condition coverage",
    z_stand_age = "Stand age",
    disturbedTRUE = "Recorded disturbance",
    treatedTRUE = "Recorded treatment",
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
      maple_effect_note = ifelse(
        grepl("ns\\(z_maple_ba", .data$term),
        "The nonlinear sugar-maple association is reported as a prediction curve, not a single odds ratio",
        NA_character_
      )
    )
}

fixed_effect_inference_sensitivity <- function(fit, odds_ratios, level = 0.95) {
  formula <- stats::as.formula(
    paste("outcome_no_seedlings ~", fixed_effect_rhs(fit$terms, fit$nonlinear_maple, fit$spline_df))
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

maple_effect_curve <- function(fit, points = 160L, level = 0.95, vary_sapling = fit$include_sapling) {
  model <- fit$model
  data <- fit$data
  observed <- data$focal_maple_ba_ft2_ac[is.finite(data$focal_maple_ba_ft2_ac)]
  lower <- if (min(observed, na.rm = TRUE) > 0) min(observed, na.rm = TRUE) else 0
  upper <- as.numeric(stats::quantile(observed, 0.99, names = FALSE, type = 8))
  grid <- expm1(seq(log1p(lower), log1p(upper), length.out = points))
  log_center <- mean(data$log_maple_ba, na.rm = TRUE)
  log_scale <- stats::sd(data$log_maple_ba, na.rm = TRUE)

  sapling_values <- if (isTRUE(vary_sapling) && "maple_sapling_present" %in% fit$terms) c(FALSE, TRUE) else FALSE
  newdata <- data[rep(1L, length(grid) * length(sapling_values)), , drop = FALSE]
  newdata$focal_maple_ba_ft2_ac <- rep(grid, times = length(sapling_values))
  newdata$maple_sapling_present <- factor(
    rep(sapling_values, each = length(grid)),
    levels = levels(data$maple_sapling_present)
  )
  numeric_adjusters <- intersect(
    c("z_nonmaple_ba", "z_microplot_coverage", "z_stand_age", "z_mean_temp", "z_precip", "z_year"),
    fit$terms
  )
  for (term in numeric_adjusters) newdata[[term]] <- 0
  if ("disturbed" %in% fit$terms) newdata$disturbed <- factor(FALSE, levels = levels(data$disturbed))
  if ("treated" %in% fit$terms) newdata$treated <- factor(FALSE, levels = levels(data$treated))
  newdata$log_maple_ba <- log1p(newdata$focal_maple_ba_ft2_ac)
  newdata$z_maple_ba <- (newdata$log_maple_ba - log_center) / log_scale

  design <- stats::model.matrix(stats::delete.response(stats::terms(model)), newdata)
  beta <- lme4::fixef(model)
  design <- design[, names(beta), drop = FALSE]
  covariance <- as.matrix(stats::vcov(model))[names(beta), names(beta), drop = FALSE]
  linear_predictor <- as.numeric(design %*% beta)
  standard_error <- sqrt(rowSums((design %*% covariance) * design))
  critical <- stats::qnorm(1 - (1 - level) / 2)
  tibble::tibble(
    focal_maple_ba_ft2_ac = newdata$focal_maple_ba_ft2_ac,
    maple_ba_ft2_ac = newdata$focal_maple_ba_ft2_ac,
    log1p_maple_ba = newdata$log_maple_ba,
    z_maple_ba = newdata$z_maple_ba,
    maple_sapling_present = as.character(newdata$maple_sapling_present),
    spline_df = if (fit$nonlinear_maple) fit$spline_df else NA_integer_,
    nonlinear_maple = fit$nonlinear_maple,
    cohort_label = fit$cohort_label,
    maple_exposure_definition = fit$maple_exposure_definition,
    predicted_probability = stats::plogis(linear_predictor),
    conf_low = stats::plogis(linear_predictor - critical * standard_error),
    conf_high = stats::plogis(linear_predictor + critical * standard_error),
    prediction_scale = "probability of no sugar-maple seedlings tallied",
    covariate_profile = "continuous adjusters at their means; no recorded disturbance or treatment; county random effect set to zero",
    inference_method = "pointwise Wald 95% confidence interval",
    observed_range_note = "curve restricted to the observed minimum through the observed 99th percentile of the cohort-specific sugar-maple exposure"
  )
}

sapling_form_comparison <- function(fit) {
  data <- fit$data
  base_terms <- setdiff(fit$terms, "maple_sapling_present")
  positive <- data$maple_sapling_ba_ft2_ac > 0
  log_amount <- log1p(data$maple_sapling_ba_ft2_ac)
  positive_center <- mean(log_amount[positive])
  positive_scale <- stats::sd(log_amount[positive])
  data$z_maple_sapling_ba <- scale_predictor(log_amount)
  data$z_positive_sapling_ba <- ifelse(
    positive,
    (log_amount - positive_center) / positive_scale,
    0
  )
  specifications <- list(
    "No sapling-stage term" = base_terms,
    "Continuous sapling basal area" = append(base_terms, "z_maple_sapling_ba", after = 1L),
    "Binary sapling presence" = append(base_terms, "maple_sapling_present", after = 1L),
    "Presence plus positive amount" = append(
      append(base_terms, "maple_sapling_present", after = 1L),
      "z_positive_sapling_ba",
      after = 2L
    )
  )
  attempts <- lapply(specifications, function(terms) {
    fixed <- paste("outcome_no_seedlings ~", fixed_effect_rhs(terms, fit$nonlinear_maple, fit$spline_df))
    fit_mixed_logistic(fixed, data)
  })
  if (any(vapply(attempts, is.null, logical(1)))) {
    stop("At least one sapling-stage candidate model failed.", call. = FALSE)
  }
  no_sapling <- attempts[["No sapling-stage term"]]$model
  binary <- attempts[["Binary sapling presence"]]$model
  binary_lrt <- stats::anova(no_sapling, binary, test = "Chisq")
  binary_lrt_row <- binary_lrt[nrow(binary_lrt), , drop = FALSE]
  dplyr::bind_rows(lapply(names(attempts), function(name) {
    candidate_model <- attempts[[name]]$model
    coefficients <- as.data.frame(stats::coef(summary(candidate_model)))
    reported_term <- if (name == "Continuous sapling basal area") {
      "z_maple_sapling_ba"
    } else if (name %in% c("Binary sapling presence", "Presence plus positive amount")) {
      "maple_sapling_presentTRUE"
    } else {
      NA_character_
    }
    estimate <- if (!is.na(reported_term) && reported_term %in% rownames(coefficients)) coefficients[reported_term, "Estimate"] else NA_real_
    standard_error <- if (!is.na(reported_term) && reported_term %in% rownames(coefficients)) coefficients[reported_term, "Std. Error"] else NA_real_
    p_column <- intersect(c("Pr(>|z|)", "Pr(>|t|)"), names(coefficients))[[1]]
    p_value <- if (!is.na(reported_term) && reported_term %in% rownames(coefficients)) coefficients[reported_term, p_column] else NA_real_
    tibble::tibble(
      model = name,
      observations = stats::nobs(candidate_model),
      aic = stats::AIC(candidate_model),
      delta_aic = stats::AIC(candidate_model) - min(vapply(attempts, function(x) stats::AIC(x$model), numeric(1))),
      reported_term = reported_term,
      odds_ratio = exp(estimate),
      conf_low = exp(estimate - 1.96 * standard_error),
      conf_high = exp(estimate + 1.96 * standard_error),
      wald_p_value = p_value,
      binary_vs_none_lrt_p_value = if (name == "Binary sapling presence") {
        as.numeric(binary_lrt_row[["Pr(>Chisq)"]])
      } else {
        NA_real_
      },
      selected = name == "Binary sapling presence",
      selection_note = if (name == "Binary sapling presence") {
        "Selected: best AIC and direct ecological interpretation; positive amount adds no useful fit"
      } else {
        "Comparison candidate"
      }
    )
  }))
}

forest_type_sensitivity <- function(fit, core_type = "801", level = 0.95) {
  fixed_rhs <- fixed_effect_rhs(fit$terms, fit$nonlinear_maple, fit$spline_df)
  type_attempt <- fit_mixed_logistic(
    paste("outcome_no_seedlings ~", fixed_rhs, "+ forest_type_code"),
    fit$data
  )
  if (is.null(type_attempt) || !isTRUE(type_attempt$converged)) {
    stop("The forest-type sensitivity model did not converge.", call. = FALSE)
  }
  type_lrt <- stats::anova(fit$model, type_attempt$model, test = "Chisq")
  type_lrt_row <- type_lrt[nrow(type_lrt), , drop = FALSE]

  core_data <- droplevels(fit$data[as.character(fit$data$forest_type_code) == core_type, , drop = FALSE])
  core_attempt <- fit_mixed_logistic(paste("outcome_no_seedlings ~", fixed_rhs), core_data)
  if (is.null(core_attempt) || !isTRUE(core_attempt$converged)) {
    stop("The core forest-type sensitivity model did not converge.", call. = FALSE)
  }
  extract_maple <- function(model) {
    coefficients <- as.data.frame(stats::coef(summary(model)))
    if (!"z_maple_ba" %in% rownames(coefficients)) return(c(NA_real_, NA_real_, NA_real_, NA_real_))
    estimate <- coefficients["z_maple_ba", "Estimate"]
    standard_error <- coefficients["z_maple_ba", "Std. Error"]
    p_column <- intersect(c("Pr(>|z|)", "Pr(>|t|)"), names(coefficients))[[1]]
    c(
      odds_ratio = exp(estimate),
      conf_low = exp(estimate - stats::qnorm(1 - (1 - level) / 2) * standard_error),
      conf_high = exp(estimate + stats::qnorm(1 - (1 - level) / 2) * standard_error),
      p_value = coefficients["z_maple_ba", p_column]
    )
  }
  main_maple <- extract_maple(fit$model)
  core_maple <- extract_maple(core_attempt$model)
  tibble::tibble(
    analysis = c("Primary established-tree cohort", "Add forest-type indicators", paste("Restrict to forest type", core_type)),
    observations = c(stats::nobs(fit$model), stats::nobs(type_attempt$model), stats::nobs(core_attempt$model)),
    events_no_seedlings = c(
      sum(fit$data$outcome_no_seedlings == 1L),
      sum(fit$data$outcome_no_seedlings == 1L),
      sum(core_data$outcome_no_seedlings == 1L)
    ),
    aic = c(stats::AIC(fit$model), stats::AIC(type_attempt$model), stats::AIC(core_attempt$model)),
    omnibus_lrt_p_value = c(NA_real_, as.numeric(type_lrt_row[["Pr(>Chisq)"]]), NA_real_),
    maple_odds_ratio = c(main_maple[["odds_ratio"]], NA_real_, core_maple[["odds_ratio"]]),
    maple_conf_low = c(main_maple[["conf_low"]], NA_real_, core_maple[["conf_low"]]),
    maple_conf_high = c(main_maple[["conf_high"]], NA_real_, core_maple[["conf_high"]]),
    maple_wald_p_value = c(main_maple[["p_value"]], NA_real_, core_maple[["p_value"]]),
    interpretation = c(
      "Primary specification",
      "Omnibus adjustment sensitivity; sparse forest-type cells limit coefficient interpretation",
      "Direction and precision check in the dominant sugar maple/beech/yellow birch type"
    )
  )
}

cohort_continuity_summary <- function(primary_data) {
  primary_data |>
    dplyr::group_by(.data$maple_sapling_present) |>
    dplyr::summarise(
      observations = dplyr::n(),
      no_seedlings = sum(.data$outcome_no_seedlings == 1L),
      seedlings_detected = sum(.data$outcome_no_seedlings == 0L),
      no_seedling_fraction = mean(.data$outcome_no_seedlings == 1L),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      maple_sapling_present = as.character(.data$maple_sapling_present),
      denominator_note = "conditions with demonstrated seedling sampling and at least one live sugar-maple tree at least 5 inches DBH"
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
  fixed_formula <- paste("outcome_no_seedlings ~", fixed_effect_rhs(fit$terms, fit$nonlinear_maple, fit$spline_df))

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
      prediction_method = "held-out county; training-fold transformations; fixed effects only (county random effect set to zero)"
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
