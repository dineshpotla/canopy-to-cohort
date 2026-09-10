source(file.path(project_root, "R", "recruitment_submission.R"))

testthat::test_that("second implementation scales only from training rows", {
  d <- data.frame(baseline_micrprop_unadj = c(.5, 1, .75), interval_years = c(5, 6, 7),
    baseline_seedling_count = c(0, 2, 10), baseline_maple_sapling_tpa = c(0, 1, 2),
    baseline_established_maple_ba_ft2_ac = c(1, 3, 5))
  a <- submission_design(d, d)
  altered <- d
  altered$baseline_seedling_count <- 100000
  b <- submission_design(d, altered)
  testthat::expect_equal(a$training, b$training)
  testthat::expect_equal(colMeans(a$training)[-1], rep(0, 5), ignore_attr = TRUE, tolerance = 1e-10)
  testthat::expect_equal(apply(a$training[, -1], 2, sd), rep(1, 5), ignore_attr = TRUE)
})

testthat::test_that("second optimizer agrees with a reference unpenalized GLM", {
  x <- cbind(1, seq(-2, 2, length.out = 20))
  y <- c(0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1)
  fit <- submission_fit(x, y, lambda = 0)
  reference <- stats::glm.fit(x, y, family = stats::binomial())
  testthat::expect_true(fit$converged)
  testthat::expect_lt(fit$max_gradient, 1e-3)
  testthat::expect_equal(drop(plogis(x %*% fit$coefficients)), reference$fitted.values, tolerance = 1e-6)
  prevalence <- submission_fit(x[, 1, drop = FALSE], y)
  testthat::expect_equal(plogis(prevalence$coefficients), mean(y), tolerance = 1e-8)
})

testthat::test_that("rank-based audit gives half credit to ties", {
  testthat::expect_equal(unname(submission_metrics(c(0, 1), c(.5, .5))["roc_auc"]), .5)
  testthat::expect_equal(unname(submission_metrics(c(0, 1), c(.1, .9))["roc_auc"]), 1)
  testthat::expect_true(is.na(submission_metrics(c(0, 1), c(.1, .9), TRUE)["roc_auc"]))
})

testthat::test_that("second implementation verifies predictions and detects corruption", {
  path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  testthat::skip_if_not(file.exists(path), "Local model bundle required")
  bundle <- readRDS(path)
  result <- submission_verify_bundle(bundle)
  testthat::expect_true(result$passed)
  testthat::expect_equal(nrow(result$fits), 48L)
  testthat::expect_equal(nrow(result$metrics), 16L)
  bundle[[1]]$crossfit$predictions[1, 3] <- .99
  testthat::expect_false(submission_verify_bundle(bundle)$passed)
})
