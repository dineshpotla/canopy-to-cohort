source(file.path(project_root, "R", "length_study_design.R"))

testthat::test_that("paired Brier gain gives physical plots equal weight and uses a fixed sign", {
  x <- plot_balanced_brier_gain(c(1, 0, 0), c(.6, .4, .6), c(.8, .2, .3), c("a", "a", "b"), c("1", "1", "2"))
  testthat::expect_equal(x$summary$count_brier, .26)
  testthat::expect_equal(x$summary$length_brier, .065)
  testthat::expect_equal(x$summary$gain, .195)
  testthat::expect_equal(x$plots$gain, c(.12, .27))
  testthat::expect_equal(x$summary$loss_difference_sd, stats::sd(c(.12, .27)))
  testthat::expect_error(plot_balanced_brier_gain(c(0, 1), c(.2, .3), c(.2, .3), c("a", "a"), c("1", "2")), "crosses counties")
  testthat::expect_error(plot_balanced_brier_gain(1, 1.1, .5, "a", "1"), "Invalid")
})

testthat::test_that("length fraction distinguishes zero totals and mismatched definitions", {
  testthat::expect_equal(length_study_fraction(c(0, 4, 10), c(0, 1, 10), c(0, 4, 10)), c(NA_real_, .25, 1))
  testthat::expect_error(length_study_fraction(4, 2, 5), "Unresolved")
  testthat::expect_error(length_study_fraction(4, 5, 4), "Unresolved")
  testthat::expect_error(length_study_fraction(NA, 1, 4), "Unresolved")
  testthat::expect_error(length_study_fraction(4, 1.5, 4), "Unresolved")
  testthat::expect_error(length_study_fraction(1:2, 1, 1:2), "equal")
})

testthat::test_that("paired precision rounds conservatively and separates its assumptions", {
  x <- paired_loss_precision(.1, .01, 1.5, .8)
  raw <- (stats::qnorm(.975) * .1 / .01)^2
  testthat::expect_equal(x$independent_equivalent_plots, ceiling(raw))
  testthat::expect_equal(x$complete_evaluation_plots, ceiling(raw * 1.5))
  testthat::expect_equal(x$candidate_plots_at_assumed_retention, ceiling(ceiling(raw * 1.5) / .8))
  testthat::expect_gt(paired_loss_precision(.2, .01)$complete_evaluation_plots,
    paired_loss_precision(.1, .01)$complete_evaluation_plots)
  testthat::expect_gt(paired_loss_precision(.1, .005)$complete_evaluation_plots,
    paired_loss_precision(.1, .01)$complete_evaluation_plots)
  testthat::expect_match(x$limitation, "not power")
  testthat::expect_error(paired_loss_precision(.1, 0), "Invalid")
  testthat::expect_error(paired_loss_precision(.1, .01, retention = 0), "Invalid")
  testthat::expect_error(paired_loss_precision(.1, .01, variance_inflation = .5), "Invalid")
  testthat::expect_error(paired_loss_precision(c(.1, .2), .01), "Invalid")
})

testthat::test_that("Wilson planning agrees with a score interval and returns the minimal plug-in n", {
  expected <- as.numeric(stats::prop.test(80, 100, correct = FALSE)$conf.int)
  actual <- wilson_planning_interval(.8, 100)
  testthat::expect_equal(unname(actual[1:2]), expected)
  for (p in c(.5, .8)) for (h in c(.05, .1)) {
    x <- recall_precision_events(p, h)
    n <- x$independent_event_units
    testthat::expect_lte(wilson_planning_interval(p, n)[["half_total_width"]], h)
    testthat::expect_gt(wilson_planning_interval(p, n - 1)[["half_total_width"]], h)
    testthat::expect_true(x$lower >= 0 && x$upper <= 1)
  }
  testthat::expect_error(wilson_planning_interval(1.1, 10), "Invalid")
  testthat::expect_error(wilson_planning_interval(.8, 2.5), "Invalid")
  testthat::expect_error(recall_precision_events(.8, 0), "Invalid")
})

testthat::test_that("RI opportunity SQL is outcome-free and distinguishes missing or ambiguous successors", {
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  plots <- data.frame(CN = c("a", "b", "c", "a1", "a2", "b1"),
    PREV_PLT_CN = c(NA, NA, NA, "a", "a", "b"),
    MEASYEAR = c(2017, 2017, 2023, 2024, 2024, 2024), MEASMON = 6,
    PLOT_STATUS_CD = 1, DESIGNCD = 1, MANUAL = 7)
  DBI::dbWriteTable(con, "PLOT", plots)
  DBI::dbWriteTable(con, "COND", data.frame(PLT_CN = c("a", "b", "c"), CONDID = 1,
    STATECD = 26, UNITCD = 1, COUNTYCD = 1, PLOT = 1:3, COND_STATUS_CD = 1,
    MICRPROP_UNADJ = 1, FORTYPCD = 801))
  # No recruitment fields or follow-up TREE rows are present in the fixture.
  DBI::dbWriteTable(con, "TREE", data.frame(PLT_CN = c("a", "b", "c"), CONDID = 1,
    SPCD = 318, STATUSCD = 1, DIA = 10))
  DBI::dbWriteTable(con, "SEEDLING", data.frame(PLT_CN = "b", CONDID = 1, SPCD = 318, TREECOUNT = 5))
  DBI::dbWriteTable(con, "PLOT_REGEN", data.frame(PLT_CN = c("a", "b", "c")))
  x <- extract_ri_opportunity_metadata(con, 801)
  testthat::expect_false(any(grepl("outcome|new_sapling|reconcile", names(x))))
  testthat::expect_equal(unique(x$successor_count[x$baseline_plt_cn == "a"]), 2L)
  testthat::expect_false(any(x$single_successor[x$baseline_plt_cn == "a"]))
  testthat::expect_true(x$followup_plot_compatible[x$baseline_plt_cn == "b"])
  testthat::expect_true(x$date_window[x$baseline_plt_cn == "b"])
  testthat::expect_equal(x$standard_maple_record_present[x$baseline_plt_cn == "b"], 1)
  testthat::expect_equal(x$successor_count[x$baseline_plt_cn == "c"], 0L)
  testthat::expect_false(x$date_window[x$baseline_plt_cn == "c"])
  testthat::expect_error(extract_ri_opportunity_metadata(con, numeric()), "Invalid")
})

testthat::test_that("planning precision exports retain complete scenario support", {
  f <- file.path(project_root, "outputs", "tables", "recruitment-length-paired-precision.csv")
  testthat::skip_if_not(file.exists(f), "Run make length-plan first")
  x <- readr::read_csv(f, show_col_types = FALSE)
  testthat::expect_equal(nrow(x), 54)
  testthat::expect_true(all(x$candidate_plots_at_assumed_retention >= x$complete_evaluation_plots))
})

testthat::test_that("planning exports reconcile with local opportunity metadata", {
  metadata_path <- file.path(project_root, "data", "processed", "length_study_opportunity_metadata.rds")
  flow_path <- file.path(project_root, "outputs", "tables", "recruitment-length-opportunity-flow.csv")
  testthat::skip_if_not(all(file.exists(c(metadata_path, flow_path))),
    "Run make length-plan to build local opportunity metadata")
  d <- readRDS(metadata_path)
  flow <- readr::read_csv(flow_path, show_col_types = FALSE)
  testthat::expect_equal(flow$baseline_condition_visits[1], dplyr::n_distinct(d$baseline_condition_key))
  testthat::expect_equal(flow$physical_plots[1], dplyr::n_distinct(d$physical_plot_key))
  testthat::expect_false(any(grepl("outcome|new_sapling|reconcile", names(d))))
})
