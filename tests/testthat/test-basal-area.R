testthat::test_that("basal area uses FIA inch-to-square-foot constant and expansion", {
  testthat::expect_equal(tree_basal_area_contribution(10, 1), 0.5454, tolerance = 1e-10)
  testthat::expect_equal(tree_basal_area_contribution(10, 6), 3.2724, tolerance = 1e-10)
})

testthat::test_that("aggregated maple basal area never exceeds total basal area", {
  trees <- tibble::tibble(
    plt_cn = c("a", "a"), condid = c(1L, 1L), spcd = c(1L, 2L),
    dia = c(10, 8), tpa_unadj = c(6, 6), statuscd = c(1L, 1L)
  )
  result <- aggregate_tree_metrics(trees, sugar_maple_spcd = 1L)
  testthat::expect_lte(result$maple_ba_ft2_ac, result$total_ba_ft2_ac)
  testthat::expect_true(result$maple_ba_share >= 0 && result$maple_ba_share <= 1)
})

testthat::test_that("design-1 trees use the FIA sampling-unit condition proportion", {
  trees <- tibble::tibble(
    plt_cn = c("a", "a", "a"),
    condid = 1L,
    spcd = c(1L, 1L, 2L),
    dia = c(4.9, 5, 10),
    tpa_unadj = c(10, 6, 6),
    statuscd = 1L,
    designcd = 1L,
    macro_breakpoint_dia = NA_real_
  )
  proportions <- tibble::tibble(
    plt_cn = "a",
    condid = 1L,
    micrprop_unadj = 0.25,
    subpprop_unadj = 0.5,
    macrprop_unadj = NA_real_
  )

  result <- aggregate_tree_metrics(trees, sugar_maple_spcd = 1L, proportions)
  expected_micro <- tree_basal_area_contribution(4.9, 10) / 0.25
  expected_subplots <- (
    tree_basal_area_contribution(5, 6) + tree_basal_area_contribution(10, 6)
  ) / 0.5

  testthat::expect_equal(result$total_ba_ft2_ac, expected_micro + expected_subplots)
  testthat::expect_equal(
    result$maple_ba_ft2_ac,
    expected_micro + tree_basal_area_contribution(5, 6) / 0.5
  )
  testthat::expect_equal(result$maple_sapling_ba_ft2_ac, expected_micro)
  testthat::expect_true(result$maple_sapling_present)
  testthat::expect_equal(result$established_maple_records, 1L)
  testthat::expect_equal(
    result$established_maple_ba_ft2_ac,
    tree_basal_area_contribution(5, 6) / 0.5
  )
  testthat::expect_equal(
    result$maple_ba_share,
    result$maple_ba_ft2_ac / result$total_ba_ft2_ac
  )
  testthat::expect_false(isTRUE(all.equal(
    result$maple_ba_share,
    result$maple_ba_plot_basis / result$total_ba_plot_basis
  )))
  testthat::expect_equal(result$microplot_tree_records, 1L)
  testthat::expect_equal(result$subplot_tree_records, 2L)
  testthat::expect_equal(result$macroplot_tree_records, 0L)
  testthat::expect_equal(
    result$total_ba_plot_basis,
    sum(tree_basal_area_contribution(trees$dia, trees$tpa_unadj))
  )
})

testthat::test_that("macroplot breakpoints use macroplot condition proportion when supplied", {
  trees <- tibble::tibble(
    plt_cn = c("a", "a", "a"),
    condid = 1L,
    spcd = 1L,
    dia = c(4, 10, 20),
    tpa_unadj = 1,
    statuscd = 1L,
    macro_breakpoint_dia = 20
  )
  proportions <- tibble::tibble(
    plt_cn = "a",
    condid = 1L,
    micrprop_unadj = 0.25,
    subpprop_unadj = 0.5,
    macrprop_unadj = 0.75
  )

  result <- aggregate_tree_metrics(trees, sugar_maple_spcd = 1L, proportions)
  expected <- tree_basal_area_contribution(4, 1) / 0.25 +
    tree_basal_area_contribution(10, 1) / 0.5 +
    tree_basal_area_contribution(20, 1) / 0.75

  testthat::expect_equal(result$total_ba_ft2_ac, expected)
  testthat::expect_equal(result$macroplot_tree_records, 1L)
})

testthat::test_that("missing sampling-unit coverage cannot silently normalize trees", {
  trees <- tibble::tibble(
    plt_cn = "a", condid = 1L, spcd = 1L, dia = 4,
    tpa_unadj = 1, statuscd = 1L
  )
  proportions <- tibble::tibble(
    plt_cn = "a", condid = 1L,
    micrprop_unadj = 0, subpprop_unadj = 1
  )

  testthat::expect_error(
    aggregate_tree_metrics(trees, sugar_maple_spcd = 1L, proportions),
    "condition proportion is missing or nonpositive"
  )
})
