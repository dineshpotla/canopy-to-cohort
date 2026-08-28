source("R/utils.R")
source("R/validation.R")
source("R/models.R")
source("R/plotting.R")

config <- read_config()
analysis_data <- read_required_rds(project_path(config$files$analysis_data))
model_data <- prepare_model_data(analysis_data)

fit <- fit_regeneration_model(
  model_data,
  config,
  spline_df = config$analysis$maple_spline_df
)
save_rds_atomic(fit$data, project_path(config$files$model_data))
save_rds_atomic(fit$model, project_path("outputs", "models", "regeneration-occurrence-model.rds"))
write_csv_atomic(fit$support, project_path("outputs", "tables", "model-support.csv"))
write_csv_atomic(fit$diagnostics, project_path("outputs", "tables", "model-diagnostics-summary.csv"))
write_csv_atomic(
  fit$functional_form_comparison,
  project_path("outputs", "tables", "model-functional-form-comparison.csv")
)
write_csv_atomic(
  fit$random_structure_comparison,
  project_path("outputs", "tables", "model-random-structure-comparison.csv")
)
write_csv_atomic(
  fit$scaling_audit,
  project_path("outputs", "tables", "model-scaling-audit.csv")
)

odds_ratios <- tidy_odds_ratios(fit$model)
write_csv_atomic(odds_ratios, project_path("outputs", "tables", "model-odds-ratios.csv"))
inference_sensitivity <- fixed_effect_inference_sensitivity(fit, odds_ratios)
write_csv_atomic(
  inference_sensitivity,
  project_path("outputs", "tables", "model-inference-sensitivity.csv")
)
effect_curve <- maple_effect_curve(fit)
write_csv_atomic(effect_curve, project_path("outputs", "tables", "model-maple-effect-curve.csv"))
save_figure(plot_maple_effect_curve(effect_curve), "04_model_effects.png", width = 8.4, height = 5.8)

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
