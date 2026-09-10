read_direction_audit <- function(name) {
  path <- project_path("outputs", "audits", paste0(name, ".csv"))
  testthat::skip_if_not(file.exists(path), "Direction audit has not been built")
  readr::read_csv(path, show_col_types = FALSE)
}

audit_metric <- function(data, name) {
  value <- data$value[data$metric == name]
  stopifnot(length(value) == 1L)
  value
}

testthat::test_that("direction comparisons use equal cohorts and reproduce differences", {
  models <- read_direction_audit("research-direction-model-summary")
  intervals <- read_direction_audit("research-direction-conditional-bootstrap")
  counts <- read_direction_audit("research-direction-count-strata")
  strong <- models[models$model == "Starting abundance and observation", ]
  testthat::expect_equal(nrow(strong), 1L)
  for (field in c("observations", "losses", "counties", "folds", "top_quartile_n")) {
    testthat::expect_equal(length(unique(models[[field]])), 1L)
  }
  testthat::expect_equal(models$brier_difference_vs_strong,
    models$brier_score - strong$brier_score, tolerance = 1e-12)
  testthat::expect_equal(models$extra_top_quartile_losses_vs_strong,
    models$top_quartile_losses - strong$top_quartile_losses)
  testthat::expect_true(all(models$top_quartile_n == floor(models$observations / 4)))
  testthat::expect_true(all(models$top_quartile_losses <= models$losses))
  testthat::expect_equal(sum(counts$conditions), strong$observations)
  testthat::expect_equal(sum(counts$losses), strong$losses)
  testthat::expect_equal(counts$observed_loss_fraction, counts$losses / counts$conditions)
  testthat::expect_true(all(intervals$brier_difference_lower <= intervals$brier_difference_upper))
  testthat::expect_true(all(intervals$auc_difference_lower <= intervals$auc_difference_upper))
  expected_difference <- models$brier_score[match(intervals$model, models$model)] -
    models$brier_score[match(intervals$reference, models$model)]
  testthat::expect_equal(intervals$brier_difference, expected_difference, tolerance = 1e-12)
  testthat::expect_true(all(grepl("conditional", intervals$uncertainty_scope)))
})

testthat::test_that("recruitment feasibility reconciles stage and fate denominators", {
  current <- read_direction_audit("recruitment-feasibility-current-summary")
  fates <- read_direction_audit("recruitment-feasibility-tagged-sapling-fates")
  transitions <- read_direction_audit("recruitment-feasibility-sapling-transitions")
  overlap <- read_direction_audit("recruitment-feasibility-seedling-ingrowth-overlap")
  get <- function(name) audit_metric(current, name)
  testthat::expect_equal(sum(fates$tree_records), get("Tagged baseline maple saplings"))
  testthat::expect_equal(sum(fates$tree_records[fates$followup_statuscd == 1], na.rm = TRUE),
    get("Tagged saplings recorded alive at follow-up"))
  testthat::expect_equal(sum(fates$tree_records[fates$followup_statuscd == 2], na.rm = TRUE),
    get("Tagged saplings recorded dead at follow-up"))
  testthat::expect_equal(sum(transitions$conditions), get("Current condition intervals"))
  testthat::expect_equal(sum(overlap$conditions), get("Current condition intervals"))
  testthat::expect_equal(sum(overlap$new_sapling_records), get("New live maple saplings"))
  testthat::expect_equal(sum(overlap$conditions_with_new_saplings),
    get("Conditions with new live maple saplings"))
  testthat::expect_lte(get("Conditions with new live maple saplings"), get("New live maple saplings"))
  testthat::expect_lte(get("Tagged survivors reaching at least 5 inches"),
    get("Tagged saplings recorded alive at follow-up"))
})

testthat::test_that("historical feasibility counts repeated intervals without inflating plots", {
  historical <- read_direction_audit("recruitment-feasibility-historical-summary")
  periods <- read_direction_audit("recruitment-feasibility-historical-periods")
  repeats <- read_direction_audit("recruitment-feasibility-historical-repeat-support")
  get <- function(name) audit_metric(historical, name)
  testthat::expect_equal(sum(periods$condition_intervals), get("Provisional historical condition intervals"))
  testthat::expect_equal(sum(periods$intervals_with_new_saplings), get("Intervals with new saplings"))
  testthat::expect_equal(sum(periods$new_sapling_records), get("New sapling records"))
  testthat::expect_equal(sum(repeats$physical_plots), get("Physical plots"))
  testthat::expect_equal(sum(repeats$physical_plots * repeats$condition_intervals),
    get("Provisional historical condition intervals"))
  testthat::expect_lte(get("Physical plots with new saplings"), get("Intervals with new saplings"))
  testthat::expect_lte(get("Intervals with new saplings"), get("New sapling records"))
})
