testthat::test_that("every retained code has a reference record", {
  path <- project_path("data", "processed", "analysis_plot_condition.rds")
  species_path <- project_path("data", "interim", "sugar-maple-reference.csv")
  forest_path <- project_path("data", "interim", "retained-forest-types.csv")
  testthat::skip_if_not(all(file.exists(c(path, species_path, forest_path))), "Derived codebooks not built")
  data <- readRDS(path)
  forest <- readr::read_csv(forest_path, show_col_types = FALSE)
  species <- readr::read_csv(species_path, show_col_types = FALSE)
  code_col <- intersect(c("value", "fortypcd", "code"), names(forest))[[1]]
  testthat::expect_true(all(unique(data$fortypcd) %in% forest[[code_col]]))
  testthat::expect_equal(species$spcd, 318)
  testthat::expect_equal(tolower(species$scientific_name), "acer saccharum")
})
