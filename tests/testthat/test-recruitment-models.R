source(file.path(project_root, "R", "recruitment_models.R"))

testthat::test_that("rank metrics and capacity handle ties honestly", {
  y <- c(0, 0, 1, 1)
  testthat::expect_equal(unname(recruitment_rank_metrics(y, rep(0.5, 4))), c(0.5, 0.5))
  testthat::expect_equal(unname(recruitment_rank_metrics(y, c(0.1, 0.2, 0.8, 0.9))), c(1, 1))
  top <- recruitment_top_capacity(y, rep(0.5, 4))
  testthat::expect_equal(unname(top["top_capacity"]), 1)
  testthat::expect_equal(unname(top["tie_neutral_expected_top_events"]), 0.5)
})

testthat::test_that("ridge intercept is unpenalized and zero penalty reproduces glm", {
  x <- cbind("(Intercept)" = 1, predictor = seq(-2, 2, length.out = 20))
  y <- rep(c(0, 1, 0, 0, 1), 4)
  fit <- recruitment_ridge_fit(x, y, lambda = 0)
  reference <- stats::glm.fit(x, y, family = stats::binomial())
  testthat::expect_equal(unname(fit$coefficients), unname(reference$coefficients), tolerance = 1e-6)
  intercept <- recruitment_ridge_fit(matrix(1, length(y), 1), y, lambda = 100)
  testthat::expect_equal(stats::plogis(intercept$coefficients[[1]]), mean(y), tolerance = 1e-9)
  testthat::expect_error(recruitment_ridge_fit(x, rep(0, 20)), "one outcome class")
})

testthat::test_that("county assignment never inspects outcomes", {
  d <- data.frame(geoid = rep(letters[1:8], 1:8), outcome_recruitment = rep(0:1, 18))
  first <- recruitment_county_folds(d)
  d$outcome_recruitment <- 1 - d$outcome_recruitment
  testthat::expect_identical(first, recruitment_county_folds(d))
  testthat::expect_equal(nrow(first), length(unique(d$geoid)))
})

testthat::test_that("scaling derives only from training observations", {
  fields <- recruitment_scaling_specifications()$source
  d <- as.data.frame(setNames(rep(list(1:8), length(fields)), fields))
  test <- d * 1000
  first <- recruitment_scale(d, test)
  second <- recruitment_scale(d, test * 2)
  testthat::expect_identical(first$audit, second$audit)
  testthat::expect_identical(first$training, second$training)
  testthat::expect_equal(mean(first$training$z_seedling_count), 0, tolerance = 1e-12)
  testthat::expect_equal(stats::sd(first$training$z_seedling_count), 1, tolerance = 1e-12)
})

testthat::test_that("saved comparisons and predictions reconcile without outcome-direction gates", {
  path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  testthat::skip_if_not(file.exists(path), "Run recruitment models first")
  fits <- readRDS(path)
  for (entry in fits) {
    cv <- entry$crossfit
    d <- entry$data
    testthat::expect_false(anyNA(cv$predictions))
    testthat::expect_equal(unique(cv$summary$observations), nrow(d))
    testthat::expect_equal(unique(cv$summary$events), sum(d$outcome_recruitment))
    testthat::expect_true(all(cv$diagnostics$converged))
    for (model in colnames(cv$predictions)) {
      summary <- cv$summary[cv$summary$model == model, ]
      testthat::expect_equal(summary$brier_score, mean((d$outcome_recruitment - cv$predictions[, model])^2))
      testthat::expect_equal(summary$top_no_new_tally_fraction, 1 - summary$top_recruitment_fraction)
    }
    for (fold in unique(cv$fold)) {
      testthat::expect_length(intersect(d$physical_plot_key[cv$fold == fold], d$physical_plot_key[cv$fold != fold]), 0)
    }
    testthat::expect_equal(sum(entry$temporal$support$conditions), nrow(d))
    testthat::expect_equal(sum(entry$temporal$support$events), sum(d$outcome_recruitment))
    testthat::expect_true(all(entry$temporal$support$physical_plots_shared == 0))
  }
})

testthat::test_that("aggregate recruitment tables reconcile with their local analytical records", {
  path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  testthat::skip_if_not(file.exists(path), "Run recruitment models first")
  fits <- readRDS(path)
  read <- function(name) readr::read_csv(file.path(project_root, "outputs", "tables", paste0("recruitment-model-", name, ".csv")), show_col_types = FALSE)
  paired <- read("paired-differences")
  bootstrap <- read("bootstrap-audit")
  testthat::expect_equal(bootstrap$resamples_requested, bootstrap$resamples_succeeded + bootstrap$resamples_failed)
  for (population in names(fits)) {
    calculated <- recruitment_comparisons(fits[[population]]$crossfit$summary)
    rows <- paired[paired$population == population, ]
    key <- function(x) paste(x$model, x$reference, x$metric)
    testthat::expect_equal(rows$difference, calculated$difference[match(key(rows), key(calculated))])
    testthat::expect_true(all(rows$lower <= rows$upper))
  }
  d <- fits[["All eligible pairs"]]$data
  count <- read("count-strata")
  testthat::expect_equal(sum(count$conditions), nrow(d))
  testthat::expect_equal(sum(count$conditions_with_new_tally), sum(d$outcome_recruitment))
  testthat::expect_equal(count$recruitment_fraction, count$conditions_with_new_tally / count$conditions)
  testthat::expect_equal(count$no_new_tally_fraction, 1 - count$recruitment_fraction)
  fate <- readRDS(file.path(project_root, "data", "processed", "recruitment_sapling_fates.rds"))
  exported <- readr::read_csv(file.path(project_root, "outputs", "audits", "recruitment-sapling-fates.csv"), show_col_types = FALSE)
  testthat::expect_equal(sum(exported$trees), nrow(fate))
  testthat::expect_equal(sum(exported$trees[exported$fate_eligible]), sum(fate$fate_eligible))
})
