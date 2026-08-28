source("R/utils.R")
source("R/validation.R")
source("R/models.R")
source("R/plotting.R")

config <- read_config()
analysis_data <- read_required_rds(project_path(config$files$analysis_data))
model_data <- prepare_model_data(analysis_data)
save_rds_atomic(model_data, project_path(config$files$model_data))

fit <- fit_regeneration_model(model_data, config)
save_rds_atomic(fit$model, project_path("outputs", "models", "regeneration-occurrence-model.rds"))
write_csv_atomic(fit$support, project_path("outputs", "tables", "model-support.csv"))

odds_ratios <- tidy_odds_ratios(fit$model)
write_csv_atomic(odds_ratios, project_path("outputs", "tables", "model-odds-ratios.csv"))
save_figure(plot_model_effects(odds_ratios), "04_model_effects.png", width = 8, height = 5.4)

diagnostic_path <- project_path("outputs", "figures", "model_diagnostics.png")
grDevices::png(diagnostic_path, width = 2200, height = 1600, res = 240)
if (inherits(fit$model, "merMod") && requireNamespace("DHARMa", quietly = TRUE)) {
  set.seed(20260826)
  residuals <- DHARMa::simulateResiduals(fit$model, n = 500, plot = FALSE)
  plot(residuals)
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
