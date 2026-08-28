scale_predictor <- function(x) {
  values <- as.numeric(scale(x))
  if (all(is.na(values))) rep(NA_real_, length(x)) else values
}

prepare_model_data <- function(data) {
  data |>
    dplyr::transmute(
      plt_cn = .data$plt_cn,
      condid = .data$condid,
      geoid = factor(.data$geoid),
      county_name = .data$county_name,
      outcome_no_seedlings = ifelse(is.na(.data$maple_seedling_detected), NA_integer_, 1L - .data$maple_seedling_detected),
      z_maple_ba = scale_predictor(log1p(.data$maple_ba_ft2_ac)),
      z_nonmaple_ba = scale_predictor(log1p(.data$nonmaple_ba_ft2_ac)),
      z_stand_age = scale_predictor(.data$stand_age),
      disturbed = factor(.data$disturbed, levels = c(FALSE, TRUE)),
      z_mean_temp = scale_predictor(.data$mean_annual_temp_c),
      z_precip = scale_predictor(.data$mean_annual_precip_mm),
      z_year = scale_predictor(.data$measyear),
      microplot_coverage = .data$micrprop_unadj,
      z_microplot_coverage = scale_predictor(.data$micrprop_unadj)
    ) |>
    dplyr::filter(
      !is.na(.data$outcome_no_seedlings),
      !is.na(.data$z_maple_ba),
      !is.na(.data$z_nonmaple_ba),
      !is.na(.data$microplot_coverage),
      .data$microplot_coverage > 0
    ) |>
    droplevels()
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

model_support_summary <- function(data, terms) {
  complete <- data[stats::complete.cases(data[c("outcome_no_seedlings", terms, "geoid", "plt_cn")]), , drop = FALSE]
  events <- sum(complete$outcome_no_seedlings == 1L)
  nonevents <- sum(complete$outcome_no_seedlings == 0L)
  plot_counts <- table(complete$plt_cn)
  tibble::tibble(
    observations = nrow(complete),
    events_no_seedlings = events,
    events_seedlings = nonevents,
    event_fraction = events / nrow(complete),
    fixed_effect_terms = length(terms),
    events_per_term = min(events, nonevents) / max(length(terms), 1L),
    counties = dplyr::n_distinct(complete$geoid),
    median_county_n = stats::median(table(complete$geoid)),
    plot_visits = dplyr::n_distinct(complete$plt_cn),
    multi_condition_plot_visits = sum(plot_counts > 1L),
    max_conditions_per_plot_visit = if (length(plot_counts)) max(plot_counts) else 0L,
    complete_case_fraction = nrow(complete) / nrow(data)
  )
}

fit_mixed_logistic <- function(fixed_formula, random_terms, data) {
  formula <- stats::as.formula(paste(fixed_formula, "+", paste(random_terms, collapse = " + ")))
  fit <- tryCatch(
    lme4::glmer(
      formula,
      family = stats::binomial(link = "logit"),
      data = data,
      control = lme4::glmerControl(
        optimizer = "bobyqa",
        optCtrl = list(maxfun = 2e5),
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

fit_regeneration_model <- function(data, config) {
  terms <- choose_model_terms(data, config)
  support <- model_support_summary(data, terms)

  while (support$events_per_term < config$analysis$minimum_events_per_parameter && length(terms) > 2L) {
    terms <- terms[-length(terms)]
    support <- model_support_summary(data, terms)
  }

  complete <- data[stats::complete.cases(data[c("outcome_no_seedlings", terms, "geoid", "plt_cn")]), , drop = FALSE]
  fixed_formula <- paste("outcome_no_seedlings ~", paste(terms, collapse = " + "))

  county_supported <- support$counties >= config$analysis$minimum_groups_for_random_effect &&
    sum(table(complete$geoid) >= 5L) >= config$analysis$minimum_groups_for_random_effect
  plot_supported <- support$multi_condition_plot_visits >= config$analysis$minimum_groups_for_random_effect

  candidate_structures <- list()
  if (county_supported && plot_supported) {
    candidate_structures[["county and plot visit"]] <- c("(1 | geoid)", "(1 | plt_cn)")
  }
  if (county_supported) candidate_structures[["county"]] <- "(1 | geoid)"
  if (plot_supported) candidate_structures[["plot visit"]] <- "(1 | plt_cn)"

  accepted <- NULL
  for (random_terms in candidate_structures) {
    attempt <- fit_mixed_logistic(fixed_formula, random_terms, complete)
    if (!is.null(attempt) && isTRUE(attempt$converged) && !isTRUE(attempt$singular)) {
      accepted <- attempt
      break
    }
  }

  if (is.null(accepted)) {
    fit <- stats::glm(stats::as.formula(fixed_formula), family = stats::binomial(), data = complete)
    converged <- isTRUE(fit$converged)
    singular <- FALSE
    random_terms <- character()
  } else {
    fit <- accepted$model
    converged <- accepted$converged
    singular <- accepted$singular
    random_terms <- accepted$random_terms
  }

  predictions <- stats::predict(fit, type = "response")
  support$model_type <- if (inherits(fit, "merMod")) "mixed-effects logistic regression" else "logistic regression"
  support$random_effect_used <- inherits(fit, "merMod")
  support$county_random_effect_used <- "(1 | geoid)" %in% random_terms
  support$plot_random_effect_used <- "(1 | plt_cn)" %in% random_terms
  support$random_effect_structure <- dplyr::case_when(
    support$county_random_effect_used && support$plot_random_effect_used ~ "county and plot-visit random intercepts",
    support$county_random_effect_used ~ "county random intercept",
    support$plot_random_effect_used ~ "plot-visit random intercept",
    TRUE ~ "no random intercept"
  )
  support$model_formula <- paste(c(fixed_formula, random_terms), collapse = " + ")
  support$converged <- converged
  support$singular <- singular
  support$brier_score <- mean((complete$outcome_no_seedlings - predictions)^2)

  list(model = fit, data = complete, support = support, terms = terms)
}

tidy_odds_ratios <- function(model) {
  if (inherits(model, "merMod")) {
    result <- broom.mixed::tidy(model, effects = "fixed", conf.int = TRUE, exponentiate = TRUE)
  } else {
    result <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  }
  labels <- c(
    z_maple_ba = "Sugar maple basal area",
    z_nonmaple_ba = "Non-maple basal area",
    z_microplot_coverage = "Microplot condition coverage",
    z_stand_age = "Stand age",
    disturbedTRUE = "Recorded disturbance",
    z_mean_temp = "Mean annual temperature",
    z_precip = "Annual precipitation",
    z_year = "Measurement year"
  )
  result |>
    dplyr::filter(.data$term != "(Intercept)") |>
    dplyr::mutate(
      label = unname(labels[.data$term]),
      label = dplyr::coalesce(.data$label, .data$term),
      interpretation = "Odds ratio for no sugar-maple seedlings tallied"
    )
}
