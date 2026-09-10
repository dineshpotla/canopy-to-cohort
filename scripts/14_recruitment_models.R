source("R/utils.R")
source("R/recruitment_models.R")

run_recruitment_models <- function() {
  raw <- prepare_recruitment_model_data(read_required_rds(project_path("data", "processed", "recruitment_condition_pairs.rds")))
  populations <- list("All eligible pairs" = raw, "Baseline seedlings detected" = raw[raw$baseline_seedling_count > 0, ])
  summaries <- diagnostics <- scaling <- assignments <- empirical <- fits <- list()
  intervals <- paired <- bootstrap_audit <- sensitivities <- temporal <- temporal_support <- coefficients <- failures <- list()
  write <- function(x, suffix) write_csv_atomic(x, project_path("outputs", "tables", paste0("recruitment-model-", suffix, ".csv")))
  for (population in names(populations)) {
    d <- populations[[population]]
    log_step(paste("Recruitment comparisons:", population, nrow(d), "conditions", sum(d$outcome_recruitment), "events"))
    cv <- recruitment_crossfit(d)
    summaries[[population]] <- dplyr::mutate(cv$summary, population = population)
    diagnostics[[population]] <- dplyr::mutate(cv$diagnostics, population = population)
    scaling[[population]] <- dplyr::mutate(cv$scaling, population = population)
    assignments[[population]] <- dplyr::mutate(cv$assignments, population = population)
    final <- recruitment_final_fits(d)
    coefficients[[population]] <- dplyr::mutate(final$coefficients, population = population)
    # Save ignored row-level predictions, not public identifiers or coordinates.
    fits[[population]] <- list(data = d, crossfit = cv, final = final)
    boot <- recruitment_bootstrap(d, cv, resamples = 300L)
    intervals[[population]] <- dplyr::mutate(boot$intervals, population = population)
    paired[[population]] <- dplyr::mutate(boot$paired, population = population)
    bootstrap_audit[[population]] <- dplyr::mutate(boot$audit, population = population)
    if (nrow(boot$failures)) failures[[population]] <- dplyr::mutate(boot$failures, population = population)
    time <- recruitment_temporal_check(d)
    temporal[[population]] <- dplyr::mutate(time$summary, population = population)
    temporal_support[[population]] <- dplyr::mutate(time$support, population = population)
    fits[[population]]$temporal <- time
    for (label in c("Exact mapped overlap", "Follow-up manual >=9", "Ridge lambda 4", "Unpenalized")) {
      subset <- d
      lambda <- 1
      if (label == "Exact mapped overlap") subset <- d[d$exact_overlap, ]
      if (label == "Follow-up manual >=9") subset <- d[d$followup_manual >= 9, ]
      if (label == "Ridge lambda 4") lambda <- 4
      if (label == "Unpenalized") lambda <- 0
      # Retain existing county assignment for these subsets, not re-balance by outcomes.
      result <- tryCatch(recruitment_crossfit(subset, cv$assignments, lambda), error = function(e) e)
      if (inherits(result, "error")) {
        failures[[paste(population, label)]] <- data.frame(population = population, analysis = label, reason = conditionMessage(result))
      } else sensitivities[[paste(population, label)]] <- dplyr::mutate(result$summary, population = population, sensitivity = label, lambda = lambda)
    }
  }
  counts <- recruitment_empirical_summaries(raw)
  write(dplyr::bind_rows(summaries), "validation")
  write(dplyr::bind_rows(diagnostics), "fold-diagnostics")
  write(dplyr::bind_rows(scaling), "fold-scaling")
  write(dplyr::bind_rows(assignments), "county-folds")
  write(dplyr::bind_rows(intervals), "intervals")
  write(dplyr::bind_rows(paired), "paired-differences")
  write(dplyr::bind_rows(bootstrap_audit), "bootstrap-audit")
  write(dplyr::bind_rows(sensitivities), "sensitivities")
  write(dplyr::bind_rows(temporal), "temporal")
  write(dplyr::bind_rows(temporal_support), "temporal-support")
  write(dplyr::bind_rows(coefficients), "coefficients")
  write(counts$count, "count-strata")
  write(counts$sapling, "sapling-strata")
  write(counts$joint, "joint-strata")
  failure_table <- dplyr::bind_rows(failures)
  if (!nrow(failure_table)) failure_table <- data.frame(population = character(), analysis = character(), reason = character())
  write(failure_table, "failures")
  save_rds_atomic(fits, project_path("outputs", "models", "recruitment-analysis.rds"))
  print(dplyr::bind_rows(summaries)[, c("population", "model", "observations", "events", "brier_score", "roc_auc", "top_recruitment_fraction")])
  log_step("Recruitment modeling complete; full-refit bootstrap and aggregate exports saved")
}

run_recruitment_models()
