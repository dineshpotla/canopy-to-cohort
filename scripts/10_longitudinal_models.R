source("R/utils.R")
source("R/validation.R")
source("R/models.R")
source("R/longitudinal.R")
source("R/longitudinal_models.R")
source("R/longitudinal_appearance_models.R")
source("R/plotting.R")

config <- read_config()
longitudinal <- read_required_rds(project_path(config$files$longitudinal_data))
prepared <- prepare_longitudinal_loss_data(longitudinal)

log_step(paste(
  "Fitting longitudinal seedling-loss model to",
  nrow(prepared$data),
  "baseline-detected conditions"
))
fit <- fit_longitudinal_loss_models(prepared$data)
odds_ratios <- tidy_longitudinal_loss_odds_ratios(fit$model, prepared$data)
support <- longitudinal_model_support(fit, prepared$data, nrow(longitudinal))
comparison <- longitudinal_model_comparison(fit)
diagnostics <- longitudinal_model_diagnostics(fit$model, prepared$data)
random_sensitivity <- longitudinal_random_effect_sensitivity(prepared$data, fit$model)

save_rds_atomic(prepared$data, project_path(config$files$longitudinal_model_data))
save_rds_atomic(fit$model, project_path("outputs", "models", "longitudinal-seedling-loss-model.rds"))
write_csv_atomic(
  prepared$scaling_audit |>
    dplyr::mutate(scaling_population = "final complete baseline-detected model cohort"),
  project_path("outputs", "tables", "longitudinal-loss-scaling-audit.csv")
)
write_csv_atomic(support, project_path("outputs", "tables", "longitudinal-loss-model-support.csv"))
write_csv_atomic(odds_ratios, project_path("outputs", "tables", "longitudinal-loss-odds-ratios.csv"))
write_csv_atomic(comparison, project_path("outputs", "tables", "longitudinal-loss-model-comparison.csv"))
write_csv_atomic(diagnostics, project_path("outputs", "tables", "longitudinal-loss-diagnostics.csv"))
write_csv_atomic(
  random_sensitivity,
  project_path("outputs", "tables", "longitudinal-loss-random-effect-sensitivity.csv")
)

log_step("Running geographically grouped longitudinal cross-validation")
cross_validation <- longitudinal_county_cross_validation(
  prepared$raw,
  requested_folds = config$analysis$longitudinal_grouped_cv_folds
)
risk_strata <- longitudinal_risk_strata(cross_validation$predictions)
write_csv_atomic(
  cross_validation$summary,
  project_path("outputs", "tables", "longitudinal-loss-cross-validation-summary.csv")
)
write_csv_atomic(
  cross_validation$folds,
  project_path("outputs", "tables", "longitudinal-loss-cross-validation-folds.csv")
)
write_csv_atomic(
  cross_validation$predictions,
  project_path("outputs", "tables", "longitudinal-loss-cross-validation-predictions.csv")
)
write_csv_atomic(
  cross_validation$assignments,
  project_path("outputs", "tables", "longitudinal-loss-cross-validation-county-folds.csv")
)
write_csv_atomic(
  risk_strata,
  project_path("outputs", "tables", "longitudinal-loss-risk-strata.csv")
)

transition_summary <- longitudinal_transition_summary(longitudinal)
save_figure(
  plot_longitudinal_transitions(transition_summary),
  "08_longitudinal_transitions.png",
  width = 8.4,
  height = 6.2
)
early_warning_plot <- patchwork::wrap_plots(
  plot_longitudinal_loss_effects(odds_ratios),
  plot_longitudinal_risk_strata(risk_strata),
  ncol = 1,
  heights = c(1.35, 1)
)
save_figure(
  early_warning_plot,
  "09_longitudinal_early_warning.png",
  width = 9,
  height = 10.5
)

log_step(paste(
  "Longitudinal loss model complete; held-out AUC =",
  sprintf(
    "%.3f",
    cross_validation$summary$roc_auc[cross_validation$summary$model == "Beech hypothesis"]
  )
))

log_step("Fitting secondary seedling-detection appearance model")
appearance_prepared <- prepare_longitudinal_appearance_data(longitudinal)
appearance_fit <- fit_longitudinal_appearance_models(appearance_prepared$data)
appearance_odds_ratios <- tidy_longitudinal_appearance_odds_ratios(
  appearance_fit$model,
  appearance_prepared$data
)
appearance_comparison <- longitudinal_appearance_model_comparison(appearance_fit)
appearance_diagnostics <- longitudinal_appearance_model_diagnostics(
  appearance_fit$model,
  appearance_prepared$data
)

log_step("Running geographically grouped appearance cross-validation")
appearance_cross_validation <- longitudinal_appearance_county_cross_validation(
  appearance_prepared$raw,
  requested_folds = config$analysis$longitudinal_grouped_cv_folds
)
appearance_support <- longitudinal_appearance_model_support(
  appearance_fit,
  appearance_prepared$data,
  nrow(longitudinal),
  appearance_cross_validation$folds
)
appearance_risk_strata <- longitudinal_appearance_risk_strata(
  appearance_cross_validation$predictions,
  appearance_fit$primary_model_name
)

save_rds_atomic(
  appearance_prepared$data,
  project_path(config$files$longitudinal_appearance_model_data)
)
save_rds_atomic(
  appearance_fit$model,
  project_path("outputs", "models", "longitudinal-seedling-appearance-model.rds")
)
write_csv_atomic(
  appearance_prepared$scaling_audit |>
    dplyr::mutate(scaling_population = "final complete baseline-nondetected appearance cohort"),
  project_path("outputs", "tables", "longitudinal-appearance-scaling-audit.csv")
)
write_csv_atomic(
  appearance_support,
  project_path("outputs", "tables", "longitudinal-appearance-model-support.csv")
)
write_csv_atomic(
  appearance_odds_ratios,
  project_path("outputs", "tables", "longitudinal-appearance-odds-ratios.csv")
)
write_csv_atomic(
  appearance_comparison,
  project_path("outputs", "tables", "longitudinal-appearance-model-comparison.csv")
)
write_csv_atomic(
  appearance_diagnostics,
  project_path("outputs", "tables", "longitudinal-appearance-diagnostics.csv")
)
write_csv_atomic(
  appearance_cross_validation$summary,
  project_path("outputs", "tables", "longitudinal-appearance-cross-validation-summary.csv")
)
write_csv_atomic(
  appearance_cross_validation$folds,
  project_path("outputs", "tables", "longitudinal-appearance-cross-validation-folds.csv")
)
write_csv_atomic(
  appearance_cross_validation$predictions,
  project_path("outputs", "tables", "longitudinal-appearance-cross-validation-predictions.csv")
)
write_csv_atomic(
  appearance_cross_validation$assignments,
  project_path("outputs", "tables", "longitudinal-appearance-cross-validation-county-folds.csv")
)
write_csv_atomic(
  appearance_risk_strata,
  project_path("outputs", "tables", "longitudinal-appearance-risk-strata.csv")
)

log_step(paste(
  "Appearance model complete; held-out AUC =",
  sprintf(
    "%.3f",
    appearance_cross_validation$summary$roc_auc[
      appearance_cross_validation$summary$model == appearance_fit$primary_model_name
    ]
  )
))
