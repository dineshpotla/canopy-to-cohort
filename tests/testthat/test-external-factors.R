source(file.path(project_root, "R", "external_factors.R"))

testthat::test_that("harvest windows precede the baseline visit, including January", {
  x <- external_harvest_window(c(2011, 2012, 2018), c(2, 1, 12))
  testthat::expect_equal(x$first_season, c(2008, 2008, 2015))
  testthat::expect_equal(x$last_season, c(2010, 2010, 2017))
  testthat::expect_equal(x$january_shift, c(FALSE, TRUE, FALSE))
  testthat::expect_equal(x$required_seasons, c("2008;2009;2010", "2008;2009;2010", "2015;2016;2017"))
  testthat::expect_equal(external_harvest_window(2018, 6, 1)$first_season, 2017)
})

testthat::test_that("invalid or missing measurement calendars are not filled", {
  testthat::expect_error(external_harvest_window(2018, NA), "Invalid")
  testthat::expect_error(external_harvest_window(2018, 0), "Invalid")
  testthat::expect_error(external_harvest_window(2018, 13), "Invalid")
  testthat::expect_error(external_harvest_window(c(2017, 2018), 6), "Invalid")
  testthat::expect_error(external_harvest_window(2018, 6, 1.5), "Invalid")
})

testthat::test_that("browse join preserves conditions and missingness", {
  p <- data.frame(baseline_plt_cn = c("10", "10", "11", "12"), current_plt_cn = c("20", "20", "21", "22"))
  b <- data.frame(PLT_CN = c("10", "11", "20"), BROWSE_IMPACT = c(2, NA, 3))
  x <- external_browse_join(p, b)
  testthat::expect_equal(nrow(x), nrow(p))
  testthat::expect_equal(x$baseline_browse_impact, c(2, 2, NA, NA))
  testthat::expect_equal(x$followup_browse_impact, c(3, 3, NA, NA))
  testthat::expect_error(external_browse_join(p, rbind(b, b[1, ])), "unique")
  b$BROWSE_IMPACT[1] <- 0
  testthat::expect_error(external_browse_join(p, b), "Unexpected")
})
