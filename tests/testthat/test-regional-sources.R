source(file.path(project_root, "R", "regional_sources.R"))

testthat::test_that("regional acquisition has a fixed authorized scope and safe dates", {
  x <- regional_fia_sources()
  testthat::expect_identical(x$state, c("WI", "MN"))
  testthat::expect_identical(x$statecd, c(55L, 27L))
  testthat::expect_true(all(startsWith(x$source_url, "https://apps.fs.usda.gov/fia/datamart/Databases/")))
  testthat::expect_error(regional_fia_sources("../../outside"), "Invalid")
  testthat::expect_error(regional_fia_sources("2026-13-99"), "Invalid")
  testthat::expect_error(regional_fia_sources(c("2026-09-09", "2026-09-10")), "Invalid")
  bad <- x[1, ]
  bad$statecd <- 27L
  testthat::expect_error(regional_acquire_one(bad), "Unapproved")
  bad <- x[1, ]
  bad$source_url <- "https://example.com/other.zip"
  testthat::expect_error(regional_acquire_one(bad), "Unapproved")
  testthat::expect_error(regional_acquire_one(data.frame()), "Unapproved")
})

testthat::test_that("regional archives cannot extract unexpected or escaping database paths", {
  listing <- data.frame(Name = c("SQLite_FIADB_WI.db", "readme.txt"), Length = c(4096, 100))
  testthat::expect_equal(regional_archive_member(listing, "WI")$Name, "SQLite_FIADB_WI.db")
  testthat::expect_error(regional_archive_member(listing, "MN"), "Unexpected")
  for (bad in c("../SQLite_FIADB_WI.db", "/SQLite_FIADB_WI.db", "C:\\SQLite_FIADB_WI.db")) {
    testthat::expect_error(regional_archive_member(data.frame(Name = bad, Length = 4096), "WI"), "unsafe")
  }
  testthat::expect_error(regional_archive_member(rbind(listing, listing[1, ]), "WI"), "Unexpected")
  testthat::expect_error(regional_archive_member(data.frame(Name = "SQLite_FIADB_WI.db", Length = 0), "WI"), "Unexpected")
  testthat::expect_error(regional_archive_member(listing, "MI"), "Invalid")
})

testthat::test_that("regional extraction preserves a free-space reserve", {
  testthat::expect_true(regional_space_guard(10, 6, 4))
  testthat::expect_error(regional_space_guard(9, 6, 4), "Insufficient")
  testthat::expect_error(regional_space_guard(NA_real_, 6, 4), "Invalid")
  testthat::expect_error(regional_space_guard(10, -1, 4), "Invalid")
})

testthat::test_that("regional source checks are read-only and reject a wrong state", {
  database <- tempfile(fileext = ".db")
  on.exit(unlink(database), add = TRUE)
  con <- DBI::dbConnect(RSQLite::SQLite(), database)
  DBI::dbWriteTable(con, "PLOT", data.frame(STATECD = 55L))
  for (table in c("COND", "TREE", "SEEDLING", "PLOT_REGEN", "SUBPLOT_REGEN", "SEEDLING_REGEN",
      "SUBPLOT", "SUBP_COND", "SUBP_COND_CHNG_MTRX", "REF_SPECIES", "REF_FOREST_TYPE")) {
    DBI::dbWriteTable(con, table, data.frame(CN = character()))
  }
  DBI::dbDisconnect(con)
  before <- sha256_file(database)
  testthat::expect_true(regional_validate_sqlite(database, 55L))
  testthat::expect_identical(sha256_file(database), before)
  testthat::expect_error(regional_validate_sqlite(database, 27L), "state does not match")
  con <- DBI::dbConnect(RSQLite::SQLite(), database)
  DBI::dbRemoveTable(con, "PLOT_REGEN")
  DBI::dbDisconnect(con)
  testthat::expect_error(regional_validate_sqlite(database, 55L), "missing tables")
})
