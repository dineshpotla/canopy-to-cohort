longitudinal_appearance_scaling_specifications <- function() {
  list(
    z_established_maple_ba = list(
      raw = "established_maple_ba_ft2_ac",
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

longitudinal_appearance_terms <- function() {
  c(
    "maple_sapling_present",
    "z_established_maple_ba",
    "z_microplot_coverage",
    "z_interval_years"
  )
}

longitudinal_appearance_model_specifications <- function() {
  list(
    "Prevalence benchmark" = character(),
    "Observation design" = c(
      "z_microplot_coverage",
      "z_interval_years"
    ),
    "Maple stage and observation" = longitudinal_appearance_terms()
  )
}

longitudinal_appearance_formula <- function(terms = longitudinal_appearance_terms()) {
  rhs <- if (length(terms)) paste(terms, collapse = " + ") else "1"
  stats::as.formula(paste("outcome_appearance ~", rhs))
}

raw_longitudinal_appearance_data <- function(longitudinal) {
  assert_columns(
    longitudinal,
    c(
      "primary_pair_eligible", "baseline_seedling_detected",
      "seedling_detection_appearance", "baseline_plt_cn", "baseline_condid",
      "current_plt_cn", "current_condid", "physical_plot_key", "geoid",
      "county_name", "baseline_maple_sapling_present",
      "baseline_established_maple_ba_ft2_ac", "baseline_micrprop_unadj",
      "interval_years"
    ),
    "longitudinal analytical data"
  )
  longitudinal |>
    dplyr::filter(
      .data$primary_pair_eligible,
      .data$baseline_seedling_detected == 0L
    ) |>
    dplyr::transmute(
      baseline_plt_cn = .data$baseline_plt_cn,
      baseline_condid = .data$baseline_condid,
      current_plt_cn = .data$current_plt_cn,
      current_condid = .data$current_condid,
      physical_plot_key = factor(.data$physical_plot_key),
      geoid = factor(.data$geoid),
      county_name = .data$county_name,
      outcome_appearance = as.integer(.data$seedling_detection_appearance),
      maple_sapling_present = factor(
        .data$baseline_maple_sapling_present,
        levels = c(FALSE, TRUE)
      ),
      established_maple_ba_ft2_ac = as.numeric(
        .data$baseline_established_maple_ba_ft2_ac
      ),
      baseline_microplot_coverage = as.numeric(.data$baseline_micrprop_unadj),
      interval_years = as.numeric(.data$interval_years)
    ) |>
    droplevels()
}

scale_longitudinal_appearance_predictors <- function(training, testing = NULL) {
  specifications <- longitudinal_appearance_scaling_specifications()
  audit <- vector("list", length(specifications))
  names(audit) <- names(specifications)

  for (term in names(specifications)) {
    specification <- specifications[[term]]
    training_values <- specification$transform(training[[specification$raw]])
    if (any(!is.finite(training_values))) {
      stop("Appearance-model scaling received non-finite training values for ", term, ".", call. = FALSE)
    }
    center <- mean(training_values)
    spread <- stats::sd(training_values)
    if (!is.finite(center) || !is.finite(spread) || spread == 0) {
      stop("Appearance-model scaling failed for ", term, ".", call. = FALSE)
    }
    training[[term]] <- (training_values - center) / spread

    if (!is.null(testing)) {
      testing_values <- specification$transform(testing[[specification$raw]])
      if (any(!is.finite(testing_values))) {
        stop("Appearance-model scaling received non-finite testing values for ", term, ".", call. = FALSE)
      }
      testing[[term]] <- (testing_values - center) / spread
    }

    audit[[term]] <- tibble::tibble(
      model_variable = term,
      source_variable = specification$raw,
      transformation = specification$transformation,
      center = center,
      scale = spread,
      observations = length(training_values),
      scaling_population = "training data only"
    )
  }

  list(
    training = training,
    testing = testing,
    audit = dplyr::bind_rows(audit)
  )
}

prepare_longitudinal_appearance_data <- function(longitudinal) {
  raw <- raw_longitudinal_appearance_data(longitudinal)
  complete_raw_fields <- c(
    "outcome_appearance",
    vapply(
      longitudinal_appearance_scaling_specifications(),
      function(x) x$raw,
      character(1)
    ),
    "maple_sapling_present",
    "geoid"
  )
  raw <- raw[stats::complete.cases(raw[complete_raw_fields]), , drop = FALSE]
  raw <- droplevels(raw)

  if (!nrow(raw)) {
    stop("No complete baseline non-detection records are available for the appearance model.", call. = FALSE)
  }
  if (!all(raw$outcome_appearance %in% c(0L, 1L))) {
    stop("The appearance outcome must contain only zero and one.", call. = FALSE)
  }
  if (dplyr::n_distinct(raw$outcome_appearance) != 2L) {
    stop("The appearance cohort must contain both outcome classes.", call. = FALSE)
  }
  if (nlevels(raw$maple_sapling_present) != 2L) {
    stop("The appearance cohort must contain both maple-sapling states.", call. = FALSE)
  }

  scaled <- scale_longitudinal_appearance_predictors(raw)
  data <- scaled$training
  required <- c("outcome_appearance", longitudinal_appearance_terms(), "geoid")
  if (!all(stats::complete.cases(data[required]))) {
    stop("The appearance model contains incomplete declared fields after scaling.", call. = FALSE)
  }

  list(raw = raw, data = data, scaling_audit = scaled$audit)
}

validate_longitudinal_appearance_glm <- function(model, label = "appearance model") {
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

fit_longitudinal_appearance_models <- function(data) {
  specifications <- longitudinal_appearance_model_specifications()
  models <- lapply(specifications, function(terms) {
    stats::glm(
      longitudinal_appearance_formula(terms),
      family = stats::binomial(),
      data = data
    )
  })
  for (model_name in names(models)) {
    validate_longitudinal_appearance_glm(
      models[[model_name]],
      paste0("Longitudinal appearance model '", model_name, "'")
    )
  }

  full_name <- "Maple stage and observation"
  list(
    models = models,
    model = models[[full_name]],
    terms = specifications[[full_name]],
    primary_model_name = full_name
  )
}

tidy_longitudinal_appearance_odds_ratios <- function(model, data, level = 0.95) {
  coefficient <- stats::coef(model)
  model_standard_error <- sqrt(diag(stats::vcov(model)))
  robust_covariance <- cluster_robust_glm_covariance(model, data$geoid)
  robust_standard_error <- sqrt(diag(robust_covariance))
  critical <- stats::qnorm(1 - (1 - level) / 2)
  labels <- c(
    maple_sapling_presentTRUE = "Sugar-maple saplings present at baseline",
    z_established_maple_ba = "Established sugar-maple basal area",
    z_microplot_coverage = "Baseline microplot condition coverage",
    z_interval_years = "Measurement interval"
  )

  tibble::tibble(
    term = names(coefficient),
    log_odds = unname(coefficient),
    model_standard_error = unname(model_standard_error),
    county_cluster_robust_standard_error = unname(robust_standard_error),
    odds_ratio = exp(.data$log_odds),
    conf_low = exp(
      .data$log_odds - critical * .data$county_cluster_robust_standard_error
    ),
    conf_high = exp(
      .data$log_odds + critical * .data$county_cluster_robust_standard_error
    ),
    robust_z = .data$log_odds / .data$county_cluster_robust_standard_error,
    robust_p_value = 2 * stats::pnorm(abs(.data$robust_z), lower.tail = FALSE),
    label = dplyr::coalesce(unname(labels[.data$term]), .data$term),
    interpretation = dplyr::if_else(
      .data$term == "maple_sapling_presentTRUE",
      "Adjusted odds ratio for appearance when saplings are present versus absent",
      "Adjusted odds ratio for appearance per one training-cohort SD on the stated transformed scale"
    ),
    outcome = "Sugar-maple seedling detection appearance at the next FIA visit",
    interval_method = "County-cluster CR1 sandwich 95% confidence interval"
  ) |>
    dplyr::filter(.data$term != "(Intercept)")
}

longitudinal_appearance_model_support <- function(
    fit,
    data,
    source_cohort_n,
    cross_validation_folds = NULL) {
  model <- fit$model
  appearances <- sum(data$outcome_appearance == 1L)
  persistent_non_detections <- sum(data$outcome_appearance == 0L)
  coefficients <- stats::coef(summary(model))
  slopes <- length(fit$terms)
  minimum_training_appearances <- NA_integer_
  if (!is.null(cross_validation_folds)) {
    full_folds <- cross_validation_folds |>
      dplyr::filter(.data$model == fit$primary_model_name)
    if (!nrow(full_folds)) {
      stop("Appearance-model support could not find full-model validation folds.", call. = FALSE)
    }
    minimum_training_appearances <- appearances - max(full_folds$appearances)
  }

  tibble::tibble(
    source_transition_cohort_n = source_cohort_n,
    baseline_nondetected_cohort_n = nrow(data),
    model_complete_n = stats::nobs(model),
    appearances = appearances,
    persistent_non_detections = persistent_non_detections,
    appearance_fraction = appearances / nrow(data),
    fixed_effect_slopes = slopes,
    appearances_per_slope = appearances / slopes,
    minimum_training_appearances = minimum_training_appearances,
    minimum_training_appearances_per_slope = minimum_training_appearances / slopes,
    minority_outcomes_per_slope = min(appearances, persistent_non_detections) / slopes,
    counties = dplyr::n_distinct(data$geoid),
    physical_plots = dplyr::n_distinct(data$physical_plot_key),
    converged = isTRUE(model$converged),
    separation_flag = any(!is.finite(stats::coef(model))) ||
      any(abs(stats::coef(model)) > 10) ||
      any(!is.finite(coefficients[, "Std. Error"])) ||
      any(coefficients[, "Std. Error"] > 5),
    model_formula = paste(deparse(stats::formula(model)), collapse = " "),
    estimand = paste(
      "Probability that sugar-maple seedlings not detected at baseline are",
      "detected at the next FIA visit"
    ),
    interpretation = paste(
      "Secondary prognostic association under the strict repeated-condition design;",
      "not a causal establishment effect or proof of local colonization"
    )
  )
}

longitudinal_appearance_model_comparison <- function(fit) {
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
      brier_score = mean(
        (stats::model.response(stats::model.frame(candidate_model)) -
          stats::fitted(candidate_model))^2
      ),
      roc_auc = binary_auc(
        stats::model.response(stats::model.frame(candidate_model)),
        stats::fitted(candidate_model)
      ),
      likelihood_ratio_chisq = if (is.null(comparison)) {
        NA_real_
      } else {
        as.numeric(comparison$Deviance[[2]])
      },
      likelihood_ratio_df = if (is.null(comparison)) {
        NA_real_
      } else {
        as.numeric(comparison$Df[[2]])
      },
      likelihood_ratio_p_value = if (is.null(comparison)) {
        NA_real_
      } else {
        as.numeric(comparison$`Pr(>Chi)`[[2]])
      },
      role = dplyr::case_when(
        names_in_order[[index]] == "Prevalence benchmark" ~
          "Reference prediction from the overall appearance prevalence",
        names_in_order[[index]] == "Observation design" ~
          "Adds baseline sampling opportunity and elapsed time",
        TRUE ~
          "Secondary appearance model; adds baseline sugar-maple stage structure"
      ),
      prediction_target = paste(
        "Follow-up seedling detection among conditions with no baseline",
        "sugar-maple seedling detection"
      )
    )
  })
  result <- dplyr::bind_rows(rows)
  dplyr::mutate(result, delta_aic = .data$aic - min(.data$aic))
}

longitudinal_appearance_model_diagnostics <- function(model, data) {
  observed <- data$outcome_appearance
  predicted <- stats::fitted(model)
  calibration <- calibration_statistics(observed, predicted)
  influence <- stats::influence.measures(model)

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
      max(stats::cooks.distance(model)),
      max(stats::hatvalues(model)),
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

longitudinal_appearance_county_cross_validation <- function(
    raw_data,
    requested_folds = 5L) {
  specifications <- longitudinal_appearance_model_specifications()
  fold_input <- raw_data
  fold_input$outcome_loss <- fold_input$outcome_appearance
  assignments <- valid_longitudinal_county_folds(fold_input, requested_folds)
  fold_lookup <- stats::setNames(assignments$fold, assignments$geoid)
  record_fold <- unname(fold_lookup[as.character(raw_data$geoid)])
  predictions <- list()
  folds <- list()
  counter <- 0L

  for (fold in sort(unique(record_fold))) {
    training_raw <- raw_data[record_fold != fold, , drop = FALSE]
    testing_raw <- raw_data[record_fold == fold, , drop = FALSE]
    scaled <- scale_longitudinal_appearance_predictors(training_raw, testing_raw)
    training <- scaled$training
    testing <- scaled$testing

    for (model_name in names(specifications)) {
      counter <- counter + 1L
      fold_model <- stats::glm(
        longitudinal_appearance_formula(specifications[[model_name]]),
        family = stats::binomial(),
        data = training
      )
      validate_longitudinal_appearance_glm(
        fold_model,
        paste0("Appearance cross-validation model '", model_name, "' in fold ", fold)
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
        observed = testing$outcome_appearance,
        predicted_probability = as.numeric(predicted),
        outcome_name = "seedling_detection_appearance",
        prediction_target = paste(
          "Follow-up sugar-maple seedling detection among baseline",
          "non-detections"
        ),
        prediction_method = paste(
          "Held-out county; transformations learned on training counties only;",
          "fixed-effect logistic prediction"
        )
      )
      folds[[counter]] <- tibble::tibble(
        fold = fold,
        model = model_name,
        observations = nrow(testing),
        appearances = sum(testing$outcome_appearance == 1L),
        persistent_non_detections = sum(testing$outcome_appearance == 0L),
        counties = dplyr::n_distinct(testing$geoid),
        brier_score = mean((testing$outcome_appearance - predicted)^2),
        roc_auc = binary_auc(testing$outcome_appearance, predicted),
        converged = fold_model$converged
      )
    }
  }

  predictions <- dplyr::bind_rows(predictions) |>
    dplyr::arrange(.data$fold, .data$model, .data$geoid, .data$baseline_plt_cn, .data$baseline_condid)
  folds <- dplyr::bind_rows(folds)
  summary <- predictions |>
    dplyr::group_by(.data$model) |>
    dplyr::summarise(
      observations = dplyr::n(),
      appearances = sum(.data$observed == 1L),
      persistent_non_detections = sum(.data$observed == 0L),
      counties = dplyr::n_distinct(.data$geoid),
      folds = dplyr::n_distinct(.data$fold),
      brier_score = mean((.data$observed - .data$predicted_probability)^2),
      roc_auc = binary_auc(.data$observed, .data$predicted_probability),
      calibration_intercept = calibration_statistics(
        .data$observed,
        .data$predicted_probability
      )[["calibration_intercept"]],
      calibration_slope = calibration_statistics(
        .data$observed,
        .data$predicted_probability
      )[["calibration_slope"]],
      .groups = "drop"
    )
  benchmark_brier <- summary$brier_score[summary$model == "Prevalence benchmark"]
  if (length(benchmark_brier) != 1L || !is.finite(benchmark_brier)) {
    stop("Appearance cross-validation did not produce a valid prevalence benchmark.", call. = FALSE)
  }
  summary <- summary |>
    dplyr::mutate(
      roc_auc = dplyr::if_else(
        .data$model == "Prevalence benchmark",
        NA_real_,
        .data$roc_auc
      ),
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
      outcome_name = "seedling_detection_appearance",
      validation_design = paste0(max(.data$folds), "-fold cross-validation grouped by county"),
      interpretation = paste(
        "Internal geographic validation of appearance among baseline non-detections;",
        "no county-specific effect is transferred to held-out counties"
      )
    )

  list(
    summary = summary,
    folds = folds,
    predictions = predictions,
    assignments = assignments
  )
}

longitudinal_appearance_risk_strata <- function(
    predictions,
    model_name = "Maple stage and observation") {
  selected <- predictions |>
    dplyr::filter(.data$model == .env$model_name)
  if (!nrow(selected)) {
    stop("No appearance predictions were found for model '", model_name, "'.", call. = FALSE)
  }

  selected |>
    dplyr::mutate(risk_quartile = dplyr::ntile(.data$predicted_probability, 4L)) |>
    dplyr::group_by(.data$risk_quartile) |>
    dplyr::summarise(
      conditions = dplyr::n(),
      appearances = sum(.data$observed == 1L),
      persistent_non_detections = sum(.data$observed == 0L),
      observed_appearance_fraction = mean(.data$observed == 1L),
      mean_predicted_probability = mean(.data$predicted_probability),
      minimum_predicted_probability = min(.data$predicted_probability),
      maximum_predicted_probability = max(.data$predicted_probability),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      risk_quartile = paste("Quartile", .data$risk_quartile),
      model = model_name,
      outcome_name = "seedling_detection_appearance",
      note = paste(
        "Quartiles use geographically held-out appearance probabilities;",
        "descriptive opportunity stratification, not an intervention threshold"
      )
    )
}
