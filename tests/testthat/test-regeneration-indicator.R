source(file.path(project_root, "R", "regeneration_indicator.R"))

ri_test_input <- function() {
  pairs <- data.frame(baseline_plt_cn = "a", baseline_condid = 1, current_plt_cn = "b", current_condid = 1,
    recruitment_eligible = TRUE, baseline_micrprop_unadj = 0.25, followup_micrprop_unadj = 0.25,
    baseline_measmon = 6, followup_measmon = 7, baseline_measyear = 2018, followup_measyear = 2025,
    baseline_seedling_count = 2, physical_plot_key = "p1", geoid = "c1", outcome_recruitment = 1,
    new_maple_sapling_count = 1)
  records <- list(
    species = data.frame(spcd = c(318, 316)),
    plots = data.frame(ri_plot_cn = c("ra", "rb"), plt_cn = c("a", "b"), invyr = c(2018, 2025), browse_impact = 3),
    subplots = data.frame(ri_subp_cn = c("rsa", "rsb"), plt_cn = c("a", "b"), sbp_cn = c("sa", "sb"), subp = 1,
      regen_subp_status_cd = NA_real_, regen_micr_status_cd = 1, regen_nonsample_reasn_cd = NA_real_),
    core_subplots = data.frame(core_sbp_cn = c("sa", "sb"), plt_cn = c("a", "b"), subp = 1, subp_status_cd = 1),
    conditions = data.frame(core_cnd_cn = c("ca", "cb"), plt_cn = c("a", "b"), condid = 1, cond_status_cd = 1),
    subp_conditions = data.frame(core_scd_cn = c("sca", "scb"), plt_cn = c("a", "b"), condid = 1, subp = 1, micrcond_prop = 1),
    seedlings = data.frame(ri_seedling_cn = c("r1", "r2"), plt_cn = "a", cnd_cn = "ca", scd_cn = "sca", subp = 1,
      condid = 1, spcd = 318, seedling_source_cd = 1, length_class_cd = c(1, 5), seedlingcount = c(3, 2)),
    core_seedlings = data.frame(core_seedling_cn = "s1", plt_cn = "a", condid = 1, subp = 1, spcd = 318, treecount = 2, treecount_calc = 2)
  )
  list(pairs = pairs, records = records)
}

testthat::test_that("RI forest status does not treat retired blanks or ambiguous codes as equivalent", {
  result <- ri_valid_forest_status(c(1, 1, 2, 3, 4, 5, 9, NA, 1, 1),
    c(NA, 1, NA, NA, NA, NA, 1, 1, 2, NA), c(rep(NA, 9), 10))
  testthat::expect_identical(result, c(TRUE, TRUE, rep(FALSE, 8)))
})

testthat::test_that("RI class totals and matched core counts preserve measurement definitions", {
  input <- ri_test_input()
  result <- build_ri_audit(input$pairs, input$records)
  d <- result$pairs
  testthat::expect_true(d$baseline_ri_available)
  testthat::expect_true(d$followup_ri_available)
  testthat::expect_equal(d$ri_all_count, 5)
  testthat::expect_equal(d$ri_standard_size_count, 2)
  testthat::expect_equal(d$ri_tall_count, 2)
  testthat::expect_equal(d$ri_class_1, 3)
  testthat::expect_equal(d$ri_stump_source_count, 0)
  testthat::expect_equal(result$units$count_difference, 0)
  testthat::expect_equal(unname(rowSums(d[paste0("ri_class_", 1:6)])), d$ri_all_count)
})

testthat::test_that("a missing species tally becomes zero only after frame checks", {
  input <- ri_test_input()
  input$records$seedlings <- input$records$seedlings[FALSE, ]
  input$records$core_seedlings <- input$records$core_seedlings[FALSE, ]
  input$pairs$baseline_seedling_count <- 0
  valid <- build_ri_audit(input$pairs, input$records)
  testthat::expect_true(valid$pairs$ri_zero)
  testthat::expect_equal(valid$pairs$ri_all_count, 0)
  testthat::expect_equal(valid$units$count_difference, 0)
  for (code in c(2, 3, 9, NA_real_)) {
    changed <- input$records
    changed$subplots$regen_micr_status_cd[1] <- code
    bad <- build_ri_audit(input$pairs, changed)$pairs
    testthat::expect_false(bad$baseline_ri_available)
    testthat::expect_true(is.na(bad$ri_all_count))
    testthat::expect_false(bad$ri_zero)
  }
  missing_plot <- input$records
  missing_plot$plots <- missing_plot$plots[-1, ]
  testthat::expect_false(build_ri_audit(input$pairs, missing_plot)$pairs$baseline_ri_available)
})

testthat::test_that("RI missing counts and inconsistent foreign keys are retained as unavailable", {
  input <- ri_test_input()
  for (field in c("seedlingcount", "cnd_cn", "scd_cn", "length_class_cd", "spcd")) {
    changed <- input$records
    changed$seedlings[[field]][1] <- NA
    result <- build_ri_audit(input$pairs, changed)
    testthat::expect_false(result$pairs$baseline_ri_available)
    testthat::expect_true(is.na(result$pairs$ri_all_count))
  }
  changed <- input$records
  changed$seedlings$seedling_source_cd[1] <- 3
  testthat::expect_false(build_ri_audit(input$pairs, changed)$pairs$baseline_ri_available)
  changed <- input$records
  changed$subplots$sbp_cn[1] <- "wrong"
  testthat::expect_false(build_ri_audit(input$pairs, changed)$pairs$baseline_ri_frame_valid)
  changed <- input$records
  changed$seedlings$spcd[1] <- 999999
  testthat::expect_false(build_ri_audit(input$pairs, changed)$pairs$baseline_ri_available)
  changed <- input$records
  changed$seedlings <- rbind(changed$seedlings, changed$seedlings[1, ])
  testthat::expect_error(build_ri_audit(input$pairs, changed), "duplicated")
})

testthat::test_that("coverage and follow-up RI screens do not redefine the baseline predictor", {
  input <- ri_test_input()
  input$pairs$baseline_micrprop_unadj <- 0.5
  testthat::expect_false(build_ri_audit(input$pairs, input$records)$pairs$baseline_ri_available)
  input <- ri_test_input()
  extra <- input$records$subp_conditions[1, ]
  extra$subp <- 2
  extra$core_scd_cn <- "invalid-area"
  extra$micrcond_prop <- NA_real_
  input$records$subp_conditions <- rbind(input$records$subp_conditions, extra)
  testthat::expect_false(build_ri_audit(input$pairs, input$records)$pairs$baseline_ri_frame_valid)
  input <- ri_test_input()
  input$pairs$followup_measmon <- 12
  d <- build_ri_audit(input$pairs, input$records)$pairs
  testthat::expect_true(d$baseline_ri_available)
  testthat::expect_false(d$followup_ri_available)
  input$pairs$baseline_measmon <- 12
  testthat::expect_false(build_ri_audit(input$pairs, input$records)$pairs$baseline_ri_available)
})

testthat::test_that("RI exported aggregates reconcile with local checked records", {
  path <- file.path(project_root, "data", "processed", "recruitment_ri_audit.rds")
  testthat::skip_if_not(file.exists(path), "Run RI measurement audit first")
  result <- readRDS(path)
  d <- result$pairs
  x <- d[d$baseline_ri_available, ]
  testthat::expect_true(all(is.na(d$ri_all_count[!d$baseline_ri_available])))
  testthat::expect_equal(rowSums(x[paste0("ri_class_", 1:6)]), x$ri_all_count)
  testthat::expect_equal(x$ri_standard_size_count, rowSums(x[paste0("ri_class_", 3:6)]))
  testthat::expect_equal(x$ri_tall_count, x$ri_class_5 + x$ri_class_6)
  testthat::expect_equal(x$ri_all_count, x$ri_other_source_count + x$ri_stump_source_count)
  table <- readr::read_csv(file.path(project_root, "outputs", "tables", "recruitment-ri-height-support.csv"), show_col_types = FALSE)
  all <- table[table$population == "All RI-available intervals", ]
  testthat::expect_equal(sum(all$conditions), nrow(x))
  testthat::expect_equal(sum(all$events), sum(x$outcome_recruitment))
  testthat::expect_true(all(all$lower <= all$upper))
  testthat::expect_error(ri_group_summary(x, rep(NA_character_, nrow(x)), resamples = 3), "Invalid RI")
})
