testthat::test_that("missing seedling rows become zero only for sampled conditions", {
  seedlings <- tibble::tibble(
    plt_cn = "a", condid = 1L, spcd = 10L, tpa_unadj = 100
  )
  conditions <- tibble::tibble(
    plt_cn = c("a", "b", "c"), condid = 1L, micrprop_unadj = c(1, 0.5, 0)
  )
  result <- aggregate_seedling_metrics(seedlings, sugar_maple_spcd = 20L, conditions)
  testthat::expect_equal(result$maple_seedling_detected[result$plt_cn == "a"], 0L)
  testthat::expect_equal(result$maple_seedling_detected[result$plt_cn == "b"], 0L)
  testthat::expect_true(is.na(result$maple_seedling_detected[result$plt_cn == "c"]))
})

testthat::test_that("gap thresholds are derived only from seedling-sampled conditions", {
  data <- tibble::tibble(
    maple_ba_share = c(0.10, 0.20, 0.30, 0.99),
    maple_seedling_tpa = c(50, 0, 0, NA_real_),
    maple_seedling_detected = c(1L, 0L, 0L, NA_integer_)
  )

  result <- add_regeneration_gap_metrics(data, established_quantile = 0.5, sensitivity_quantile = 0.75)

  testthat::expect_equal(
    unique(result$established_threshold),
    stats::quantile(c(0.10, 0.20, 0.30), 0.5, names = FALSE)
  )
  testthat::expect_equal(
    unique(result$sensitivity_threshold),
    stats::quantile(c(0.10, 0.20, 0.30), 0.75, names = FALSE)
  )
  testthat::expect_true(result$potential_gap[[3]])
  testthat::expect_true(is.na(result$potential_gap[[4]]))
})
