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
