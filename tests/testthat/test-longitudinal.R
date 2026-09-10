testthat::test_that("seedling transitions are classified without reversing time", {
  observed <- classify_seedling_transition(
    baseline_detected = c(0L, 0L, 1L, 1L, NA_integer_),
    followup_detected = c(0L, 1L, 0L, 1L, 1L)
  )
  testthat::expect_equal(
    observed,
    c("Persistent non-detection", "Appearance", "Loss", "Persistence", NA_character_)
  )
})

testthat::test_that("microplot linkage averages four subplots before relative-overlap checks", {
  sql <- longitudinal_pair_cte(262501)
  testthat::expect_match(sql, "SUM(COALESCE(m.SUBPTYP_PROP_CHNG, 0.0)) / 4.0", fixed = TRUE)
  testthat::expect_match(sql, "WHERE m.SUBPTYP = 2", fixed = TRUE)
  testthat::expect_match(sql, "COUNT(*) AS BASELINE_PAIR_DEGREE", fixed = TRUE)
  testthat::expect_match(sql, "COUNT(*) AS CURRENT_PAIR_DEGREE", fixed = TRUE)
})

testthat::test_that("species basal area respects microplot and subplot condition proportions", {
  trees <- tibble::tibble(
    plt_cn = c("p1", "p1"),
    condid = c(1L, 1L),
    spcd = c(531L, 531L),
    dia = c(4, 10),
    tpa_unadj = c(1, 1),
    statuscd = c(1L, 1L),
    macro_breakpoint_dia = c(NA_real_, NA_real_)
  )
  conditions <- tibble::tibble(
    plt_cn = "p1",
    condid = 1L,
    micrprop_unadj = 0.5,
    subpprop_unadj = 0.25,
    macrprop_unadj = NA_real_
  )
  result <- aggregate_species_basal_area(trees, conditions, 531L, "beech")
  expected_sapling <- tree_basal_area_contribution(4, 1) / 0.5
  expected_established <- tree_basal_area_contribution(10, 1) / 0.25
  testthat::expect_equal(result$beech_sapling_ba_ft2_ac, expected_sapling)
  testthat::expect_equal(result$beech_established_ba_ft2_ac, expected_established)
  testthat::expect_equal(result$beech_ba_ft2_ac, expected_sapling + expected_established)
  testthat::expect_equal(result$beech_records, 2)
})

testthat::test_that("longitudinal cohort follows strict baseline-defined pairs", {
  path <- project_path("data", "processed", "longitudinal_plot_condition.rds")
  testthat::skip_if_not(file.exists(path), "Longitudinal data have not been built")
  data <- readRDS(path)
  testthat::expect_silent(
    assert_unique_key(data, c("baseline_plt_cn", "baseline_condid"), "baseline pairs")
  )
  testthat::expect_silent(
    assert_unique_key(data, c("current_plt_cn", "current_condid"), "follow-up pairs")
  )
  testthat::expect_true(all(data$primary_pair_eligible))
  testthat::expect_true(all(data$strict_one_to_one))
  testthat::expect_true(all(data$baseline_overlap_fraction >= 0.90))
  testthat::expect_true(all(data$followup_overlap_fraction >= 0.90))
  testthat::expect_true(all(data$plot_prev_link_matches))
  testthat::expect_false(any(data$baseline_plt_cn == data$current_plt_cn))
  testthat::expect_true(all(data$baseline_established_maple))
  testthat::expect_true(all(data$followup_comparable))
  testthat::expect_equal(nrow(data), 932)
  testthat::expect_equal(sum(data$baseline_seedling_detected == 1L), 677)
  testthat::expect_equal(sum(data$seedling_transition == "Loss"), 75)
  testthat::expect_equal(
    data$baseline_other_nonmaple_ba_ft2_ac,
    pmax(
      0,
      data$baseline_nonmaple_ba_ft2_ac - data$baseline_beech_sapling_ba_ft2_ac
    ),
    tolerance = 1e-12
  )
  testthat::expect_equal(
    data$seedling_detection_loss[data$baseline_seedling_detected == 1L],
    1L - data$followup_seedling_detected[data$baseline_seedling_detected == 1L]
  )
})

testthat::test_that("longitudinal model uses only the declared ecological signals and design covariates", {
  support_path <- project_path("outputs", "tables", "longitudinal-loss-model-support.csv")
  scale_path <- project_path("outputs", "tables", "longitudinal-loss-scaling-audit.csv")
  testthat::skip_if_not(
    all(file.exists(c(support_path, scale_path))),
    "Longitudinal model has not been fit"
  )
  support <- readr::read_csv(support_path, show_col_types = FALSE)
  scaling <- readr::read_csv(scale_path, show_col_types = FALSE)
  testthat::expect_true(support$converged)
  testthat::expect_false(support$separation_flag)
  testthat::expect_equal(support$fixed_effect_slopes, 7)
  testthat::expect_equal(support$losses_per_slope, support$losses / support$fixed_effect_slopes)
  testthat::expect_equal(support$model_complete_n, 677)
  testthat::expect_equal(support$losses, 75)
  testthat::expect_false(grepl("followup|spline|treatment|climate", support$model_formula))
  testthat::expect_setequal(
    scaling$model_variable,
    setdiff(longitudinal_loss_terms(), "maple_sapling_present")
  )
})

testthat::test_that("county-grouped validation is complete and leakage-free", {
  prediction_path <- project_path(
    "outputs", "tables", "longitudinal-loss-cross-validation-predictions.csv"
  )
  assignment_path <- project_path(
    "outputs", "tables", "longitudinal-loss-cross-validation-county-folds.csv"
  )
  risk_path <- project_path("outputs", "tables", "longitudinal-loss-risk-strata.csv")
  testthat::skip_if_not(
    all(file.exists(c(prediction_path, assignment_path, risk_path))),
    "Longitudinal validation has not been run"
  )
  predictions <- readr::read_csv(prediction_path, show_col_types = FALSE)
  assignments <- readr::read_csv(assignment_path, show_col_types = FALSE)
  risk <- readr::read_csv(risk_path, show_col_types = FALSE)
  testthat::expect_equal(dplyr::n_distinct(assignments$geoid), nrow(assignments))
  joined <- predictions |>
    dplyr::left_join(assignments |> dplyr::select("geoid", assigned_fold = "fold"), by = "geoid")
  testthat::expect_equal(joined$fold, joined$assigned_fold)
  full <- predictions |>
    dplyr::filter(.data$model == "Beech hypothesis")
  testthat::expect_equal(nrow(full), 677)
  testthat::expect_equal(sum(full$observed), 75)
  testthat::expect_equal(dplyr::n_distinct(full$fold), 5)
  fold_classes <- full |>
    dplyr::group_by(.data$fold) |>
    dplyr::summarise(classes = dplyr::n_distinct(.data$observed), .groups = "drop")
  testthat::expect_true(all(fold_classes$classes == 2L))
  testthat::expect_equal(sum(risk$conditions), 677)
  testthat::expect_equal(sum(risk$losses), 75)
})

testthat::test_that("appearance specification is conditional, lean, and baseline focused", {
  testthat::expect_equal(length(longitudinal_appearance_terms()), 4L)
  testthat::expect_setequal(
    longitudinal_appearance_terms(),
    c(
      "maple_sapling_present",
      "z_established_maple_ba",
      "z_microplot_coverage",
      "z_interval_years"
    )
  )
  testthat::expect_false(any(grepl("beech|nonmaple", longitudinal_appearance_terms())))

  path <- project_path("data", "processed", "longitudinal_plot_condition.rds")
  testthat::skip_if_not(file.exists(path), "Longitudinal data have not been built")
  data <- readRDS(path)
  raw <- raw_longitudinal_appearance_data(data)
  testthat::expect_equal(nrow(raw), 255L)
  testthat::expect_equal(sum(raw$outcome_appearance), 59L)
  expected <- data |>
    dplyr::filter(.data$primary_pair_eligible, .data$baseline_seedling_detected == 0L) |>
    dplyr::arrange(.data$baseline_plt_cn, .data$baseline_condid)
  observed <- raw |>
    dplyr::arrange(.data$baseline_plt_cn, .data$baseline_condid)
  testthat::expect_equal(
    observed$outcome_appearance,
    expected$followup_seedling_detected
  )
})

testthat::test_that("appearance scaling learns from training records only", {
  training <- tibble::tibble(
    established_maple_ba_ft2_ac = c(0, exp(2) - 1, exp(4) - 1),
    baseline_microplot_coverage = c(0.25, 0.50, 0.75),
    interval_years = c(5, 6, 7)
  )
  testing <- tibble::tibble(
    established_maple_ba_ft2_ac = exp(8) - 1,
    baseline_microplot_coverage = 1,
    interval_years = 9
  )
  scaled <- scale_longitudinal_appearance_predictors(training, testing)
  testthat::expect_equal(scaled$audit$center, c(2, 0.5, 6))
  testthat::expect_equal(scaled$audit$scale, c(2, 0.25, 1))
  testthat::expect_equal(scaled$testing$z_established_maple_ba, 3)
  testthat::expect_equal(scaled$testing$z_microplot_coverage, 2)
  testthat::expect_equal(scaled$testing$z_interval_years, 3)
})

testthat::test_that("appearance validation is complete and its metrics reproduce predictions", {
  support_path <- project_path("outputs", "tables", "longitudinal-appearance-model-support.csv")
  prediction_path <- project_path(
    "outputs", "tables", "longitudinal-appearance-cross-validation-predictions.csv"
  )
  assignment_path <- project_path(
    "outputs", "tables", "longitudinal-appearance-cross-validation-county-folds.csv"
  )
  summary_path <- project_path(
    "outputs", "tables", "longitudinal-appearance-cross-validation-summary.csv"
  )
  risk_path <- project_path("outputs", "tables", "longitudinal-appearance-risk-strata.csv")
  paths <- c(support_path, prediction_path, assignment_path, summary_path, risk_path)
  testthat::skip_if_not(all(file.exists(paths)), "Appearance validation has not been run")

  support <- readr::read_csv(support_path, show_col_types = FALSE)
  predictions <- readr::read_csv(prediction_path, show_col_types = FALSE)
  assignments <- readr::read_csv(assignment_path, show_col_types = FALSE)
  summary <- readr::read_csv(summary_path, show_col_types = FALSE)
  risk <- readr::read_csv(risk_path, show_col_types = FALSE)
  full_name <- "Maple stage and observation"
  full <- predictions |>
    dplyr::filter(.data$model == .env$full_name)
  full_summary <- summary |>
    dplyr::filter(.data$model == .env$full_name)

  testthat::expect_equal(support$model_complete_n, 255L)
  testthat::expect_equal(support$appearances, 59L)
  testthat::expect_equal(support$fixed_effect_slopes, 4L)
  testthat::expect_equal(
    support$minimum_training_appearances_per_slope,
    support$minimum_training_appearances / support$fixed_effect_slopes
  )
  testthat::expect_false(support$separation_flag)
  testthat::expect_equal(dplyr::n_distinct(assignments$geoid), nrow(assignments))
  joined <- full |>
    dplyr::left_join(
      assignments |> dplyr::select("geoid", assigned_fold = "fold"),
      by = "geoid"
    )
  testthat::expect_equal(joined$fold, joined$assigned_fold)
  testthat::expect_equal(nrow(full), 255L)
  testthat::expect_equal(sum(full$observed), 59L)
  testthat::expect_equal(dplyr::n_distinct(full$fold), 5L)
  fold_classes <- full |>
    dplyr::group_by(.data$fold) |>
    dplyr::summarise(classes = dplyr::n_distinct(.data$observed), .groups = "drop")
  testthat::expect_true(all(fold_classes$classes == 2L))
  testthat::expect_equal(sum(risk$conditions), 255L)
  testthat::expect_equal(sum(risk$appearances), 59L)
  testthat::expect_equal(
    full_summary$roc_auc,
    binary_auc(full$observed, full$predicted_probability)
  )
  benchmark <- predictions |>
    dplyr::filter(.data$model == "Prevalence benchmark")
  testthat::expect_equal(
    full_summary$brier_skill_vs_prevalence,
    1 - mean((full$observed - full$predicted_probability)^2) /
      mean((benchmark$observed - benchmark$predicted_probability)^2)
  )
})
