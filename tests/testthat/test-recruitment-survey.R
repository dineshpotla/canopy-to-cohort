source(file.path(project_root, "R", "recruitment_models.R"))
source(file.path(project_root, "R", "recruitment_survey.R"))

testthat::test_that("capacity comparisons integrate cutoff ties without choosing a favorable order", {
  target <- c(1, 0, 1, 0)
  first <- recruitment_survey_selection(target, rep(1, 4), 0.5)
  reversed <- recruitment_survey_selection(target, rep(1, 4), 0.5, row_order = c(1, 3, 2, 4))
  testthat::expect_equal(first$capacity, 2)
  testthat::expect_equal(first$expected_targets, 1)
  testthat::expect_equal(first$expected_targets, reversed$expected_targets)
  testthat::expect_equal(c(first$minimum_targets_over_cutoff_ties, first$maximum_targets_over_cutoff_ties), c(0, 2))
  testthat::expect_equal(first$deterministic_targets, 1)
  testthat::expect_equal(reversed$deterministic_targets, 2)
  testthat::expect_equal(first$extra_targets_vs_random, 0)
  full <- recruitment_survey_selection(target, 1:4, 1)
  testthat::expect_equal(full$expected_targets, sum(target))
  testthat::expect_error(recruitment_survey_selection(target, 1:4, 0), "Invalid")
  testthat::expect_error(recruitment_survey_selection(target, 1:4, 0.01), "at least one")
})

testthat::test_that("integer county multiplicities reproduce explicit repeated observations", {
  y <- c(1, 0, 1, 0)
  score <- c(3, 2, 2, 1)
  weights <- c(2, 3, 0, 1)
  index <- rep(seq_along(y), weights)
  weighted <- recruitment_survey_selection(y, score, 0.5, weights)
  expanded <- recruitment_survey_selection(y[index], score[index], 0.5)
  fields <- c("capacity", "expected_targets", "minimum_targets_over_cutoff_ties", "maximum_targets_over_cutoff_ties",
    "selected_target_fraction", "target_capture_fraction", "deterministic_targets")
  testthat::expect_equal(weighted[fields], expanded[fields])
  testthat::expect_error(recruitment_survey_selection(y, score, 0.5, c(1, 1, 0.5, 1)), "Invalid")
})

testthat::test_that("objectives reverse priority explicitly and random expectation is analytic", {
  d <- data.frame(outcome_recruitment = c(0, 0, 1, 1), baseline_seedling_count = 1:4,
    baseline_micrprop_unadj = 1, baseline_maple_sapling_tpa = c(0, 0, 1, 1),
    audit_row = 1:4, physical_plot_key = c("a", "a", "b", "c"))
  p <- cbind("Seedling count and design" = c(0.1, 0.2, 0.8, 0.9), "Maple stages and design" = c(0.1, 0.2, 0.8, 0.9))
  result <- recruitment_survey_evaluate(d, p, capacities = 0.5)
  model <- result[result$policy == "Count model", ]
  testthat::expect_equal(model$expected_targets, c(2, 2))
  testthat::expect_equal(model$deterministic_selected_physical_plots, c(1, 2))
  random <- result[result$policy == "Random expectation", ]
  testthat::expect_equal(random$expected_targets, c(1, 1))
  testthat::expect_true(all(is.na(random$deterministic_targets)))
  testthat::expect_true(all(recruitment_survey_comparisons(result)$target_fraction_difference == 0))
})

testthat::test_that("common scoring horizon changes test inputs but not training scaling", {
  path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  testthat::skip_if_not(file.exists(path), "Run recruitment models first")
  entry <- readRDS(path)[["Baseline seedlings detected"]]
  common <- recruitment_crossfit(entry$data, entry$crossfit$assignments, score_interval_years = 7)
  testthat::expect_equal(common$scaling, entry$crossfit$scaling)
  testthat::expect_equal(common$fold, entry$crossfit$fold)
  testthat::expect_true(all(is.finite(common$predictions)))
  testthat::expect_error(recruitment_crossfit(entry$data, score_interval_years = 0), "Scoring interval")
  p <- recruitment_survey_temporal_horizon(entry$data, entry$temporal)
  testthat::expect_equal(dim(p), dim(entry$temporal$predictions))
  testthat::expect_true(all(p >= 0 & p <= 1))
})

testthat::test_that("exported survey results reconcile without favoring any policy", {
  path <- file.path(project_root, "outputs", "tables", "recruitment-survey-summary.csv")
  testthat::skip_if_not(file.exists(path), "Run survey audit first")
  result <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(result$capacity, floor(result$observations * result$requested_fraction))
  testthat::expect_equal(result$expected_targets + result$expected_non_targets, result$capacity)
  testthat::expect_equal(result$selected_target_fraction, result$expected_targets / result$capacity)
  testthat::expect_true(all(result$expected_targets >= result$minimum_targets_over_cutoff_ties - 1e-8))
  testthat::expect_true(all(result$expected_targets <= result$maximum_targets_over_cutoff_ties + 1e-8))
  testthat::expect_true(all(result$lower <= result$upper))
  random <- result[result$policy == "Random expectation", ]
  testthat::expect_equal(random$expected_targets, random$random_expected_targets)
})

testthat::test_that("survey exports reproduce local held-out predictions", {
  model_path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  summary_path <- file.path(project_root, "outputs", "tables", "recruitment-survey-summary.csv")
  paired_path <- file.path(project_root, "outputs", "tables", "recruitment-survey-paired-differences.csv")
  testthat::skip_if_not(all(file.exists(c(model_path, summary_path, paired_path))),
    "Run recruitment models and survey audit for local prediction checks")
  result <- readr::read_csv(summary_path, show_col_types = FALSE)
  paired <- readr::read_csv(paired_path, show_col_types = FALSE)
  bundle <- readRDS(model_path)
  for (population in names(bundle)) {
    entry <- bundle[[population]]
    actual <- recruitment_survey_evaluate(entry$data, entry$crossfit$predictions)
    exported <- result[result$population == population, ]
    testthat::expect_equal(exported$expected_targets, actual$expected_targets)
    selected <- paired[paired$population == population, ]
    calculated <- recruitment_survey_comparisons(actual)
    testthat::expect_equal(selected$target_fraction_difference, calculated$target_fraction_difference)
  }
})
