source(file.path(project_root, "R", "recruitment_models.R"))
source(file.path(project_root, "R", "recruitment_paper.R"))

testthat::test_that("paper support keeps distinct conditions, plots, and events", {
  d <- data.frame(recruitment_eligible = c(TRUE, TRUE, TRUE, FALSE),
    baseline_seedling_count = c(0, 2, 4, 5), physical_plot_key = c("a", "a", "b", "c"),
    geoid = c("x", "x", "y", "z"), outcome_recruitment = c(0, 1, 0, NA),
    new_maple_sapling_count = c(0, 3, 0, 2), baseline_measyear = c(2011, 2011, 2012, 2013),
    followup_measyear = c(2018, 2018, 2019, 2020), interval_years = 7,
    baseline_micrprop_unadj = c(0.5, 0.5, 1, 1))
  x <- recruitment_paper_support(d)
  testthat::expect_equal(x$conditions, c(3L, 2L))
  testthat::expect_equal(x$physical_plots, c(2L, 2L))
  testthat::expect_equal(x$events, c(1, 1))
  testthat::expect_equal(x$new_saplings, c(3, 3))
  testthat::expect_equal(x$baseline_year_min, c(2011, 2011))
  testthat::expect_equal(x$coverage_min, c(0.5, 0.5))
  d$outcome_recruitment[[2]] <- NA
  testthat::expect_error(recruitment_paper_support(d), "Incomplete paper population")
})

testthat::test_that("paper reconciliation detects stale metrics", {
  path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  testthat::skip_if_not(file.exists(path), "Run recruitment models for integration checks")
  read_output <- function(name, folder = "tables") readr::read_csv(
    file.path(project_root, "outputs", folder, paste0(name, ".csv")), show_col_types = FALSE)
  d <- readRDS(file.path(project_root, "data", "processed", "recruitment_condition_pairs.rds"))
  args <- list(data = d, bundle = readRDS(path), validation = read_output("recruitment-model-validation"),
    paired = read_output("recruitment-model-paired-differences"), temporal = read_output("recruitment-model-temporal"),
    bootstrap = read_output("recruitment-model-bootstrap-audit"), survey_bootstrap = read_output("recruitment-survey-bootstrap-audit"),
    fates = readRDS(file.path(project_root, "data", "processed", "recruitment_sapling_fates.rds")),
    fate_summary = read_output("recruitment-sapling-fates", "audits"), growth = read_output("recruitment-sapling-growth", "audits"))
  audit <- do.call(recruitment_paper_audit, args)
  testthat::expect_true(all(audit$passed), info = paste(audit$check[!audit$passed], collapse = "; "))
  testthat::expect_false(anyDuplicated(audit$check) > 0)
  testthat::expect_equal(recruitment_paper_support(d)$conditions, c(922L, 672L))
  args$validation$brier_score[[1]] <- args$validation$brier_score[[1]] + 0.01
  testthat::expect_false(all(do.call(recruitment_paper_audit, args)$passed))
})

testthat::test_that("analytical appendix checks reject changed exports", {
  path <- file.path(project_root, "outputs", "models", "recruitment-analysis.rds")
  testthat::skip_if_not(file.exists(path), "Run recruitment models for integration checks")
  read_output <- function(name) readr::read_csv(
    file.path(project_root, "outputs", "tables", paste0("recruitment-model-", name, ".csv")),
    show_col_types = FALSE)
  args <- list(bundle = readRDS(path), coefficients = read_output("coefficients"),
    diagnostics = read_output("fold-diagnostics"), joint = read_output("joint-strata"),
    intervals = read_output("intervals"))
  audit <- do.call(recruitment_paper_detail_audit, args)
  testthat::expect_equal(nrow(audit), 7L)
  testthat::expect_true(all(audit$passed), info = paste(audit$check[!audit$passed], collapse = "; "))
  for (change in list(c("coefficients", "penalized_log_odds_coefficient"),
                      c("diagnostics", "test_events"), c("joint", "conditions"),
                      c("intervals", "estimate"))) {
    altered <- args
    altered[[change[[1]]]][[change[[2]]]][[1]] <- altered[[change[[1]]]][[change[[2]]]][[1]] + 1
    testthat::expect_false(all(do.call(recruitment_paper_detail_audit, altered)$passed))
  }
})
