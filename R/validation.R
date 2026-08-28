assert_columns <- function(data, columns, label = deparse(substitute(data))) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(label, " is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(data)
}

assert_unique_key <- function(data, keys, label = deparse(substitute(data))) {
  assert_columns(data, keys, label)
  duplicates <- data |>
    dplyr::count(dplyr::across(dplyr::all_of(keys)), name = "n") |>
    dplyr::filter(.data$n > 1L)
  if (nrow(duplicates)) {
    stop(label, " has ", nrow(duplicates), " duplicated key combinations.", call. = FALSE)
  }
  invisible(data)
}

assert_range <- function(x, lower = -Inf, upper = Inf, allow_na = TRUE, label = deparse(substitute(x))) {
  if (!allow_na && anyNA(x)) stop(label, " contains missing values.", call. = FALSE)
  bad <- !is.na(x) & (x < lower | x > upper)
  if (any(bad)) {
    stop(label, " contains ", sum(bad), " values outside [", lower, ", ", upper, "].", call. = FALSE)
  }
  invisible(x)
}

join_audit <- function(left, right, by, label, result = NULL) {
  left_keys <- dplyr::distinct(left, dplyr::across(dplyr::all_of(names(by) %||% by)))
  right_key_names <- unname(by)
  right_keys <- dplyr::distinct(right, dplyr::across(dplyr::all_of(right_key_names)))
  names(right_keys) <- names(by) %||% right_key_names
  unmatched <- dplyr::anti_join(left_keys, right_keys, by = names(by) %||% by)

  tibble::tibble(
    join = label,
    left_rows = nrow(left),
    right_rows = nrow(right),
    result_rows = if (is.null(result)) NA_integer_ else nrow(result),
    left_unique_keys = nrow(left_keys),
    right_unique_keys = nrow(right_keys),
    unmatched_left_keys = nrow(unmatched)
  )
}

missingness_summary <- function(data) {
  result <- tibble::tibble(
    variable = names(data),
    missing_n = vapply(data, function(x) sum(is.na(x)), integer(1))
  )
  result$missing_pct <- 100 * result$missing_n / nrow(data)
  result
}

cohort_step <- function(step, data, id_columns = character()) {
  tibble::tibble(
    step = step,
    rows = nrow(data),
    unique_plots = if ("plt_cn" %in% names(data)) dplyr::n_distinct(data$plt_cn) else NA_integer_,
    unique_plot_conditions = if (all(c("plt_cn", "condid") %in% names(data))) {
      dplyr::n_distinct(paste(data$plt_cn, data$condid, sep = "::"))
    } else {
      NA_integer_
    }
  )
}
