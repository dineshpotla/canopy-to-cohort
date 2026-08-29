source(project_path("R", "models.R"))

testthat::test_that("model formulas support selected linear and contextual nonlinear maple terms", {
  terms <- c("z_maple_ba", "maple_sapling_present", "z_nonmaple_ba")
  nonlinear <- fixed_effect_rhs(terms, nonlinear_maple = TRUE, spline_df = 3L)
  linear <- fixed_effect_rhs(terms, nonlinear_maple = FALSE, spline_df = 2L)
  testthat::expect_match(nonlinear, "splines::ns\\(z_maple_ba, df = 3\\)")
  testthat::expect_false(grepl("splines::ns", linear, fixed = TRUE))
  testthat::expect_match(linear, "z_maple_ba")
  testthat::expect_match(linear, "maple_sapling_present")
})

testthat::test_that("county fold allocation is deterministic and prevents county leakage", {
  synthetic <- tibble::tibble(
    geoid = rep(sprintf("%05d", 1:23), times = rep(3:25, length.out = 23)),
    outcome_no_seedlings = rep(c(0L, 1L), length.out = sum(rep(3:25, length.out = 23)))
  )
  first <- balanced_county_folds(synthetic, k = 10L)
  second <- balanced_county_folds(synthetic[sample(nrow(synthetic)), ], k = 10L)
  testthat::expect_equal(
    dplyr::arrange(first, .data$geoid)[c("geoid", "fold")],
    dplyr::arrange(second, .data$geoid)[c("geoid", "fold")]
  )
  testthat::expect_equal(nrow(first), dplyr::n_distinct(synthetic$geoid))
  testthat::expect_equal(sort(unique(first$fold)), 1:10)
  testthat::expect_true(all(table(first$geoid) == 1L))
})

testthat::test_that("binary AUC handles exact separation and tied rankings", {
  testthat::expect_equal(binary_auc(c(0L, 0L, 1L, 1L), c(0.1, 0.2, 0.8, 0.9)), 1)
  testthat::expect_equal(binary_auc(c(0L, 1L), c(0.5, 0.5)), 0.5)
  testthat::expect_true(is.na(binary_auc(c(1L, 1L), c(0.2, 0.8))))
})

testthat::test_that("held-out records use training-fold transformations", {
  training <- tibble::tibble(
    focal_maple_ba_ft2_ac = c(1, 3, 7, 15),
    nonmaple_ba_ft2_ac = c(1, 2, 4, 8),
    z_maple_ba = NA_real_, z_nonmaple_ba = NA_real_,
    log_maple_ba = NA_real_
  )
  testing <- tibble::tibble(
    focal_maple_ba_ft2_ac = 31, nonmaple_ba_ft2_ac = 16,
    z_maple_ba = NA_real_, z_nonmaple_ba = NA_real_, log_maple_ba = NA_real_
  )
  scaled <- apply_training_fold_scaling(training, testing, c("z_maple_ba", "z_nonmaple_ba"))
  testthat::expect_equal(mean(scaled$training$z_maple_ba), 0, tolerance = 1e-12)
  testthat::expect_equal(stats::sd(scaled$training$z_maple_ba), 1, tolerance = 1e-12)
  expected <- (log1p(31) - mean(log1p(training$focal_maple_ba_ft2_ac))) /
    stats::sd(log1p(training$focal_maple_ba_ft2_ac))
  testthat::expect_equal(scaled$testing$z_maple_ba, expected)
})

testthat::test_that("calibration statistics return intercept and slope", {
  values <- calibration_statistics(
    observed = rep(c(0L, 1L), 50),
    predicted = rep(c(0.2, 0.8), 50)
  )
  testthat::expect_named(values, c("calibration_intercept", "calibration_slope"))
  testthat::expect_true(all(is.finite(values)))
})
