source("R/utils.R")
source("R/validation.R")
source("R/models.R")
source("R/plotting.R")

config <- read_config()
analysis_data <- read_required_rds(project_path(config$files$analysis_data))
primary_model_data <- prepare_model_data(analysis_data, established_only = TRUE)
baseline_model_data <- prepare_model_data(analysis_data, established_only = FALSE)

fit <- fit_regeneration_model(
  primary_model_data,
  config,
  spline_df = config$analysis$primary_spline_comparison_df,
  nonlinear_maple = FALSE,
  include_sapling = TRUE,
  include_treatment = TRUE,
  cohort_label = "Primary established-tree cohort"
)
baseline_fit <- fit_regeneration_model(
  baseline_model_data,
  config,
  spline_df = config$analysis$maple_spline_df,
  nonlinear_maple = TRUE,
  include_sapling = FALSE,
  include_treatment = FALSE,
  cohort_label = "Full-cohort baseline"
)
save_rds_atomic(fit$data, project_path(config$files$model_data))
save_rds_atomic(fit$model, project_path("outputs", "models", "regeneration-occurrence-model.rds"))
save_rds_atomic(baseline_fit$model, project_path("outputs", "models", "baseline-regeneration-occurrence-model.rds"))
write_csv_atomic(fit$support, project_path("outputs", "tables", "model-support.csv"))
write_csv_atomic(baseline_fit$support, project_path("outputs", "tables", "baseline-model-support.csv"))
write_csv_atomic(fit$diagnostics, project_path("outputs", "tables", "model-diagnostics-summary.csv"))
write_csv_atomic(baseline_fit$diagnostics, project_path("outputs", "tables", "baseline-model-diagnostics-summary.csv"))
write_csv_atomic(
  fit$functional_form_comparison,
  project_path("outputs", "tables", "model-functional-form-comparison.csv")
)
write_csv_atomic(
  baseline_fit$functional_form_comparison,
  project_path("outputs", "tables", "baseline-model-functional-form-comparison.csv")
)
write_csv_atomic(
  fit$random_structure_comparison,
  project_path("outputs", "tables", "model-random-structure-comparison.csv")
)
write_csv_atomic(
  fit$scaling_audit,
  project_path("outputs", "tables", "model-scaling-audit.csv")
)
write_csv_atomic(
  baseline_fit$scaling_audit,
  project_path("outputs", "tables", "baseline-model-scaling-audit.csv")
)

odds_ratios <- tidy_odds_ratios(fit$model, maple_label = "Established sugar-maple basal area")
write_csv_atomic(odds_ratios, project_path("outputs", "tables", "model-odds-ratios.csv"))
write_csv_atomic(
  tidy_odds_ratios(baseline_fit$model, maple_label = "All-size sugar-maple basal area"),
  project_path("outputs", "tables", "baseline-model-odds-ratios.csv")
)
inference_sensitivity <- fixed_effect_inference_sensitivity(fit, odds_ratios)
write_csv_atomic(
  inference_sensitivity,
  project_path("outputs", "tables", "model-inference-sensitivity.csv")
)
effect_curve <- maple_effect_curve(fit)
baseline_effect_curve <- maple_effect_curve(baseline_fit, vary_sapling = FALSE)
write_csv_atomic(effect_curve, project_path("outputs", "tables", "model-maple-effect-curve.csv"))
write_csv_atomic(
  baseline_effect_curve,
  project_path("outputs", "tables", "baseline-model-maple-effect-curve.csv")
)
save_figure(
  plot_model_effects(effect_curve, fit$data, baseline_effect_curve, baseline_fit$data),
  "04_model_effects.png",
  width = 9.2,
  height = 10.4
)

write_csv_atomic(
  cohort_continuity_summary(fit$data),
  project_path("outputs", "tables", "model-cohort-continuity.csv")
)
write_csv_atomic(
  sapling_form_comparison(fit),
  project_path("outputs", "tables", "model-sapling-form-comparison.csv")
)
write_csv_atomic(
  forest_type_sensitivity(fit),
  project_path("outputs", "tables", "model-forest-type-sensitivity.csv")
)
treatment_summary <- fit$data |>
  dplyr::group_by(.data$treated) |>
  dplyr::summarise(
    observations = dplyr::n(),
    no_seedlings = sum(.data$outcome_no_seedlings == 1L),
    seedlings_detected = sum(.data$outcome_no_seedlings == 0L),
    no_seedling_fraction = mean(.data$outcome_no_seedlings == 1L),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    treated = as.character(.data$treated),
    interpretation = "Observed FIA treatment indicator; descriptive association without an untreated counterfactual or before-after design"
  )
write_csv_atomic(treatment_summary, project_path("outputs", "tables", "model-treatment-summary.csv"))

treatment_code_summary <- analysis_data |>
  dplyr::semi_join(fit$data, by = c("plt_cn", "condid")) |>
  dplyr::select(dplyr::all_of(c("plt_cn", "condid", "trtcd1", "trtcd2", "trtcd3"))) |>
  tidyr::pivot_longer(
    dplyr::starts_with("trtcd"),
    names_to = "treatment_field",
    values_to = "treatment_code"
  ) |>
  dplyr::filter(!is.na(.data$treatment_code), .data$treatment_code > 0) |>
  dplyr::mutate(
    treatment_label = dplyr::recode(
      as.character(.data$treatment_code),
      `10` = "Cutting",
      `20` = "Site preparation",
      `30` = "Artificial regeneration",
      `40` = "Natural regeneration",
      `50` = "Other treatment",
      .default = "Other documented FIA treatment code"
    ),
    condition_key = paste(.data$plt_cn, .data$condid, sep = ":")
  ) |>
  dplyr::group_by(.data$treatment_code, .data$treatment_label) |>
  dplyr::summarise(
    condition_count = dplyr::n_distinct(.data$condition_key),
    recorded_slots = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(.data$condition_count), .data$treatment_code)
write_csv_atomic(
  treatment_code_summary,
  project_path("outputs", "tables", "model-treatment-code-summary.csv")
)

cohort_audit <- tibble::tibble(
  cohort_step = c(
    "All northern-hardwood conditions",
    "Seedling-sampled conditions",
    "Primary established-tree cohort",
    "Primary cohort with maple saplings",
    "Primary cohort without maple saplings"
  ),
  observations = c(
    nrow(analysis_data),
    nrow(baseline_model_data),
    nrow(primary_model_data),
    sum(primary_model_data$maple_sapling_present == "TRUE"),
    sum(primary_model_data$maple_sapling_present == "FALSE")
  ),
  rule = c(
    "FIA maple/beech/birch forest-type group",
    "demonstrated microplot sampling opportunity",
    "at least one live sugar-maple TREE record with DBH at least 5 inches",
    "at least one live sugar-maple TREE record with DBH 1 to 4.9 inches",
    "no live sugar-maple TREE record with DBH 1 to 4.9 inches"
  )
)
write_csv_atomic(cohort_audit, project_path("outputs", "tables", "model-cohort-audit.csv"))

cross_validation <- county_grouped_cross_validation(fit, k = config$analysis$grouped_cv_folds)
write_csv_atomic(
  cross_validation$summary,
  project_path("outputs", "tables", "model-cross-validation-summary.csv")
)
write_csv_atomic(
  cross_validation$folds,
  project_path("outputs", "tables", "model-cross-validation-folds.csv")
)
write_csv_atomic(
  cross_validation$predictions,
  project_path("outputs", "tables", "model-cross-validation-predictions.csv")
)
write_csv_atomic(
  cross_validation$assignments,
  project_path("outputs", "tables", "model-cross-validation-county-folds.csv")
)

diagnostic_path <- project_path("outputs", "figures", "model_diagnostics.png")
grDevices::png(diagnostic_path, width = 2800, height = 1400, res = 240)
if (inherits(fit$model, "merMod") && requireNamespace("DHARMa", quietly = TRUE)) {
  set.seed(20260826)
  residuals <- DHARMa::simulateResiduals(fit$model, n = 500, plot = FALSE)
  fitted_probability <- stats::predict(fit$model, type = "response")
  diagnostic_tests <- list(
    uniformity = DHARMa::testUniformity(residuals),
    dispersion = DHARMa::testDispersion(residuals),
    outliers = DHARMa::testOutliers(residuals),
    residual_quantiles = DHARMa::testQuantiles(
      residuals,
      predictor = fitted_probability,
      plot = FALSE
    )
  )
  old_par <- graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2) + 0.1)
  ordered_residuals <- sort(residuals$scaledResiduals)
  expected_uniform <- stats::ppoints(length(ordered_residuals))
  graphics::plot(
    expected_uniform,
    ordered_residuals,
    pch = 16,
    cex = 0.55,
    col = grDevices::adjustcolor("#285943", alpha.f = 0.55),
    xlim = c(0, 1),
    ylim = c(0, 1),
    xlab = "Expected uniform quantile",
    ylab = "Observed DHARMa residual quantile",
    main = sprintf(
      "Residual uniformity\nKS p = %.3f; dispersion p = %.3f; outlier p = %.3f",
      diagnostic_tests$uniformity$p.value,
      diagnostic_tests$dispersion$p.value,
      diagnostic_tests$outliers$p.value
    )
  )
  graphics::abline(0, 1, col = "#8B1E3F", lwd = 2)
  graphics::plot(
    fitted_probability,
    residuals$scaledResiduals,
    pch = 16,
    cex = 0.55,
    col = grDevices::adjustcolor("#285943", alpha.f = 0.35),
    xlim = c(0, 1),
    ylim = c(0, 1),
    xlab = "Fitted conditional probability",
    ylab = "Scaled DHARMa residual",
    main = sprintf(
      "Residuals versus fitted probability\ncombined quantile-test p = %.3f",
      diagnostic_tests$residual_quantiles$p.value
    )
  )
  graphics::abline(h = 0.5, col = "#8B1E3F", lty = 2, lwd = 1.5)
  smooth <- stats::loess(residuals$scaledResiduals ~ fitted_probability, span = 0.8)
  ordered_fitted <- order(fitted_probability)
  graphics::lines(
    fitted_probability[ordered_fitted],
    stats::predict(smooth)[ordered_fitted],
    col = "#263238",
    lwd = 2
  )
  graphics::par(old_par)
  diagnostic_table <- dplyr::bind_rows(lapply(names(diagnostic_tests), function(name) {
    result <- diagnostic_tests[[name]]
    tibble::tibble(
      diagnostic = name,
      statistic = as.numeric(result$statistic %||% NA_real_)[[1]],
      p_value = as.numeric(result$p.value %||% NA_real_)[[1]],
      method = result$method %||% NA_character_,
      interpretation = "Small p-values indicate evidence of model-data mismatch"
    )
  }))
  write_csv_atomic(
    diagnostic_table,
    project_path("outputs", "tables", "model-dharma-tests.csv")
  )
} else {
  graphics::par(mfrow = c(2, 2))
  plot(fit$model)
}
grDevices::dev.off()

if (requireNamespace("performance", quietly = TRUE)) {
  collinearity <- try(performance::check_collinearity(fit$model), silent = TRUE)
  if (!inherits(collinearity, "try-error")) {
    write_csv_atomic(as.data.frame(collinearity), project_path("outputs", "tables", "model-collinearity.csv"))
  }
}

log_step(paste("Model complete:", fit$support$model_type))
