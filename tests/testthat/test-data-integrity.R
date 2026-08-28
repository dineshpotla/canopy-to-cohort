testthat::test_that("processed analytical data satisfy core invariants", {
  path <- project_path("data", "processed", "analysis_plot_condition.rds")
  testthat::skip_if_not(file.exists(path), "Analytical data have not been built")
  data <- readRDS(path)
  testthat::expect_silent(assert_unique_key(data, c("plt_cn", "condid"), "analysis data"))
  testthat::expect_true(all(data$maple_ba_share >= 0 & data$maple_ba_share <= 1, na.rm = TRUE))
  testthat::expect_true(all(data$maple_ba_ft2_ac <= data$total_ba_ft2_ac + 1e-8, na.rm = TRUE))
  testthat::expect_true(all(data$maple_seedling_tpa >= 0, na.rm = TRUE))
  testthat::expect_false(anyDuplicated(data[c("plt_cn", "condid")]) > 0)
})

testthat::test_that("computed basal area agrees with FIA condition basal area", {
  path <- project_path("outputs", "audits", "basal-area-validation.csv")
  testthat::skip_if_not(file.exists(path), "Basal-area validation has not been built")
  validation <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_gte(validation$observations, 1000)
  testthat::expect_gte(validation$pearson_correlation, 0.9999)
  testthat::expect_lt(validation$mean_absolute_error_ft2_ac, 0.01)
  testthat::expect_lt(validation$root_mean_squared_error_ft2_ac, 0.01)
  testthat::expect_lt(validation$max_absolute_error_ft2_ac, 0.05)
})

testthat::test_that("county climate is complete and plausible", {
  path <- project_path("data", "processed", "county_climate_1991_2020.csv")
  testthat::skip_if_not(file.exists(path), "County climate has not been built")
  climate <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_equal(nrow(climate), 83)
  testthat::expect_equal(dplyr::n_distinct(climate$geoid), 83)
  testthat::expect_true(all(climate$climate_years == 30))
  testthat::expect_true(all(dplyr::between(climate$mean_annual_temp_c, -5, 15)))
  testthat::expect_true(all(dplyr::between(climate$mean_annual_precip_mm, 300, 2000)))
})

testthat::test_that("model support gates passed", {
  path <- project_path("outputs", "tables", "model-support.csv")
  testthat::skip_if_not(file.exists(path), "Model has not been fit")
  support <- readr::read_csv(path, show_col_types = FALSE)
  testthat::expect_true(support$converged)
  testthat::expect_false(support$singular)
  testthat::expect_gte(support$events_per_parameter, 10)
  testthat::expect_true(support$county_random_effect_used)
  testthat::expect_false(support$plot_random_effect_used)
  testthat::expect_equal(support$analytical_cohort_n, 1457)
  testthat::expect_equal(support$model_complete_n, 1424)
  testthat::expect_equal(
    support$model_complete_fraction_of_cohort,
    support$model_complete_n / support$analytical_cohort_n,
    tolerance = 1e-12
  )
  testthat::expect_gte(support$multi_condition_plot_visits, 30)
})

testthat::test_that("v1.2 model evidence artifacts are internally consistent", {
  curve_path <- project_path("outputs", "tables", "model-maple-effect-curve.csv")
  cv_path <- project_path("outputs", "tables", "model-cross-validation-summary.csv")
  random_path <- project_path("outputs", "tables", "model-random-structure-comparison.csv")
  scaling_path <- project_path("outputs", "tables", "model-scaling-audit.csv")
  testthat::skip_if_not(
    all(file.exists(c(curve_path, cv_path, random_path, scaling_path))),
    "v1.2 model evidence has not been built"
  )
  curve <- readr::read_csv(curve_path, show_col_types = FALSE)
  validation <- readr::read_csv(cv_path, show_col_types = FALSE)
  random <- readr::read_csv(random_path, show_col_types = FALSE)
  scaling <- readr::read_csv(scaling_path, show_col_types = FALSE)
  testthat::expect_true(all(dplyr::between(curve$predicted_probability, 0, 1)))
  testthat::expect_true(all(curve$conf_low <= curve$predicted_probability))
  testthat::expect_true(all(curve$conf_high >= curve$predicted_probability))
  testthat::expect_setequal(validation$metric, c("Brier score", "ROC AUC", "Calibration intercept", "Calibration slope"))
  testthat::expect_equal(sum(random$selected), 1)
  testthat::expect_equal(random$random_effect_structure[random$selected], "county random intercept")
  testthat::expect_true(all(scaling$cohort_definition == "final model-complete cohort"))
  testthat::expect_true(all(scaling$observations == 1424))
})
