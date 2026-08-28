connect_fia <- function(path = find_fia_sqlite()) {
  DBI::dbConnect(RSQLite::SQLite(), path)
}

disconnect_fia <- function(con) {
  if (DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  invisible(NULL)
}

schema_inventory <- function(con) {
  tables <- DBI::dbListTables(con)
  purrr::map_dfr(tables, function(table) {
    info <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", DBI::dbQuoteIdentifier(con, table), ")"))
    tibble::as_tibble(info) |>
      dplyr::transmute(
        table = table,
        column_position = .data$cid + 1L,
        column = .data$name,
        sqlite_type = .data$type,
        not_null = as.logical(.data$notnull),
        default_value = .data$dflt_value,
        primary_key_position = .data$pk
      )
  })
}

table_row_counts <- function(con, tables) {
  purrr::map_dfr(tables, function(table) {
    if (!table %in% DBI::dbListTables(con)) {
      return(tibble::tibble(table = table, rows = NA_real_, present = FALSE))
    }
    count <- DBI::dbGetQuery(
      con,
      paste0("SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, table))
    )$n[[1]]
    tibble::tibble(table = table, rows = as.numeric(count), present = TRUE)
  })
}

read_table_safe <- function(con, table, columns = NULL, where = NULL) {
  if (!table %in% DBI::dbListTables(con)) stop("Missing FIA table: ", table, call. = FALSE)
  available <- DBI::dbListFields(con, table)
  if (is.null(columns)) columns <- available
  missing <- setdiff(columns, available)
  if (length(missing)) {
    stop(table, " is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  quoted <- paste(DBI::dbQuoteIdentifier(con, columns), collapse = ", ")
  sql <- paste0("SELECT ", quoted, " FROM ", DBI::dbQuoteIdentifier(con, table))
  if (!is.null(where)) sql <- paste(sql, "WHERE", where)
  standardize_names(DBI::dbGetQuery(con, sql))
}

find_reference_matches <- function(con, table, patterns) {
  data <- standardize_names(DBI::dbReadTable(con, table))
  text_columns <- names(data)[vapply(data, is.character, logical(1))]
  if (!length(text_columns)) return(data[0, , drop = FALSE])
  combined <- do.call(paste, c(data[text_columns], sep = " | "))
  keep <- Reduce(`|`, lapply(patterns, function(pattern) grepl(pattern, combined, ignore.case = TRUE)))
  tibble::as_tibble(data[keep, , drop = FALSE])
}
