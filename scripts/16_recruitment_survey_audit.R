source("R/utils.R")
source("R/recruitment_models.R")
source("R/recruitment_survey.R")

run_recruitment_survey_audit <- function() {
  fits <- read_required_rds(project_path("outputs", "models", "recruitment-analysis.rds"))
  current <- prepare_recruitment_model_data(read_required_rds(project_path("data", "processed", "recruitment_condition_pairs.rds")))
  fields <- c("audit_row", "geoid", "physical_plot_key", "outcome_recruitment", recruitment_scaling_specifications()$source)
  if (!isTRUE(all.equal(current[fields], fits[["All eligible pairs"]]$data[fields], check.attributes = FALSE))) {
    stop("The model bundle does not match the current endpoint data; rerun recruitment models first.", call. = FALSE)
  }
  summary <- paired <- audits <- temporal <- horizon <- temporal_horizon <- failures <- list()
  write <- function(x, suffix) write_csv_atomic(x, project_path("outputs", "tables", paste0("recruitment-survey-", suffix, ".csv")))
  for (population in names(fits)) {
    entry <- fits[[population]]
    d <- entry$data
    log_step(paste("Fixed survey-priority comparisons:", population))
    point <- recruitment_survey_evaluate(d, entry$crossfit$predictions)
    boot <- recruitment_survey_bootstrap(d, entry$crossfit)
    summary[[population]] <- dplyr::left_join(point, boot$intervals,
      by = c("objective", "policy", "requested_fraction")) |>
      dplyr::mutate(population = population, assessment = "County held out; realized interval")
    paired[[population]] <- dplyr::left_join(recruitment_survey_comparisons(point), boot$paired,
      by = c("objective", "policy", "reference", "requested_fraction")) |>
      dplyr::mutate(population = population)
    audits[[population]] <- dplyr::mutate(boot$audit, population = population)
    if (nrow(boot$failures)) failures[[population]] <- dplyr::mutate(boot$failures, population = population)
    test <- d[entry$temporal$test_rows, ]
    temporal[[population]] <- recruitment_survey_evaluate(test, entry$temporal$predictions) |>
      dplyr::mutate(population = population, assessment = "2023 onward temporal test; realized interval")
    common <- recruitment_crossfit(d, entry$crossfit$assignments, audit = FALSE, score_interval_years = 7)
    horizon[[population]] <- recruitment_survey_evaluate(d, common$predictions) |>
      dplyr::mutate(population = population, assessment = "County held out; common seven-year scoring interval",
        limitation = "Observed outcomes retain their actual variable intervals; no seven-year probability validation")
    temporal_horizon[[population]] <- recruitment_survey_evaluate(test, recruitment_survey_temporal_horizon(d, entry$temporal)) |>
      dplyr::mutate(population = population, assessment = "Temporal test; common seven-year scoring interval",
        limitation = "Observed outcomes retain their actual variable intervals; no seven-year probability validation")
  }
  write(dplyr::bind_rows(summary), "summary")
  write(dplyr::bind_rows(paired), "paired-differences")
  write(dplyr::bind_rows(audits), "bootstrap-audit")
  write(dplyr::bind_rows(temporal), "temporal")
  write(dplyr::bind_rows(horizon), "common-horizon")
  write(dplyr::bind_rows(temporal_horizon), "temporal-common-horizon")
  failure <- if (length(failures)) dplyr::bind_rows(failures) else data.frame(resample = integer(), reason = character(), population = character())
  write(failure, "failures")
  print(dplyr::bind_rows(summary) |>
    dplyr::filter(.data$population == "Baseline seedlings detected", .data$objective == "No recorded entry", .data$requested_fraction == 0.25) |>
    dplyr::select("policy", "capacity", "expected_targets", "selected_target_fraction",
      "extra_targets_vs_random", "lower", "upper"))
  print(dplyr::bind_rows(paired) |>
    dplyr::filter(.data$population == "Baseline seedlings detected", .data$objective == "No recorded entry", .data$requested_fraction == 0.25))
  log_step("Saved aggregate survey-priority comparisons; no fieldwork or publication performed")
}

run_recruitment_survey_audit()
