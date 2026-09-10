source(file.path(project_root, "R", "recruitment.R"))

testthat::test_that("new sapling tally requires explicit reconciliation and no predecessor", {
  x <- recruitment_tree_class(c(1, 1, 1, 1, 1, 2), rep(318, 6), c(1.1, 1.1, 1.1, 5, 1.1, 1.1),
    c(1, 3, 1, 1, NA, 1), c(NA, NA, "old", NA, NA, NA))
  testthat::expect_equal(x, c("New live sapling tally", "Ambiguous new sapling tally", "Previously tagged sapling",
    "Not a live maple sapling", "Ambiguous new sapling tally", "Not a live maple sapling"))
})

testthat::test_that("sapling fate distinguishes growth, death, errors, and taxonomy", {
  x <- recruitment_sapling_fate(c("a", "b", "c", "d", "e", NA), c(1, 2, 0, 1, 3, NA),
    c(318, 318, 318, 316, 318, NA), c(5, NA, 1.1, 1.2, NA, NA), c(NA, NA, 7, NA, NA, NA))
  testthat::expect_equal(x, c("Alive; reached 5 inches", "Recorded dead", "No longer sampled", "Species reidentified", "Recorded removed", "Unlinked"))
})

testthat::test_that("missing tree attributes do not establish biological recruitment or fate", {
  recruits <- recruitment_tree_class(c(NA, 1, 1), c(318, NA, 318), c(1.2, 1.2, NA), rep(1, 3), rep(NA_character_, 3))
  testthat::expect_equal(recruits, rep("Ambiguous new sapling tally", 3))
  fates <- recruitment_sapling_fate(c("a", "b"), c(NA, 1), c(318, NA), c(1.2, 1.2), c(NA, NA))
  testthat::expect_equal(fates, c("Unresolved", "Unresolved"))
})

testthat::test_that("built recruitment cohort retains source rows and masks uncertain outcomes", {
  path <- file.path(project_root, "data", "processed", "recruitment_condition_pairs.rds")
  testthat::skip_if_not(file.exists(path), "Run scripts/13_build_recruitment_dataset.R for integration assertions")
  d <- readRDS(path)
  source <- readRDS(file.path(project_root, "data", "processed", "longitudinal_plot_condition.rds"))
  testthat::expect_equal(nrow(d), nrow(source))
  testthat::expect_false(anyDuplicated(paste(d$current_plt_cn, d$current_condid)) > 0)
  testthat::expect_true(all(is.na(d$outcome_recruitment[!d$recruitment_eligible])))
  testthat::expect_equal(d$outcome_recruitment[d$recruitment_eligible], as.integer(d$new_maple_sapling_count[d$recruitment_eligible] > 0))
  testthat::expect_true(all(d$ambiguous_new_maple_sapling_count[d$recruitment_eligible] == 0))
  testthat::expect_true(all(d$recruits_outside_shared_subplots[d$recruitment_eligible] == 0))
  testthat::expect_true(all(d$baseline_seedling_count >= 0, na.rm = TRUE))
  testthat::expect_equal(d$baseline_maple_sapling_tpa, d$baseline_maple_sapling_tpa_plot_basis / d$baseline_micrprop_unadj)
  testthat::expect_true(all(d$followup_total_ba_ft2_ac[d$followup_zero_tree_corrected] == 0))
  testthat::expect_true(all(d$followup_maple_sapling_count[d$followup_zero_tree_corrected] == 0))
})

testthat::test_that("tagged sapling ambiguous fates do not become mortality", {
  path <- file.path(project_root, "data", "processed", "recruitment_sapling_fates.rds")
  testthat::skip_if_not(file.exists(path), "Run recruitment builder for integration assertions")
  f <- readRDS(path)
  testthat::expect_false(anyDuplicated(f$tree_cn) > 0)
  testthat::expect_true(all(is.na(f$outcome_death[f$fate %in% c("Species reidentified", "No longer sampled", "Unlinked")])) )
  testthat::expect_true(all(f$outcome_survival[f$reached_five_inches & f$fate_eligible] == 1))
  testthat::expect_true(all(is.na(f$outcome_survival[!f$fate_eligible])))
  testthat::expect_true(all(f$protocol_design_comparable[f$fate_eligible]))
  testthat::expect_true(all(f$primary_pair_eligible[f$fate_eligible]))
  testthat::expect_true(all(is.na(f$annual_diameter_increment[f$followup_statuscd != 1])))
})
