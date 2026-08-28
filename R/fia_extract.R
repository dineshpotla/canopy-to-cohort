latest_current_evaluation <- function(con, statecd = 26L) {
  sql <- sprintf(
    paste(
      "SELECT DISTINCT e.CN AS eval_cn, e.EVALID, e.EVAL_DESCR,",
      "e.START_INVYR, e.END_INVYR, e.ESTN_METHOD",
      "FROM POP_EVAL e",
      "JOIN POP_EVAL_TYP t ON t.EVAL_CN = e.CN",
      "WHERE e.STATECD = %d AND t.EVAL_TYP = 'EXPCURR'",
      "ORDER BY e.END_INVYR DESC, e.EVALID DESC LIMIT 1"
    ),
    statecd
  )
  result <- standardize_names(DBI::dbGetQuery(con, sql))
  if (nrow(result) != 1L) stop("Could not resolve one current FIA evaluation.", call. = FALSE)
  tibble::as_tibble(result)
}

current_evaluation_by_id <- function(con, evalid, statecd = 26L) {
  evalid <- as.integer(evalid)
  if (length(evalid) != 1L || is.na(evalid)) {
    stop("A single integer EVALID is required.", call. = FALSE)
  }
  sql <- sprintf(
    paste(
      "SELECT DISTINCT e.CN AS eval_cn, e.EVALID, e.EVAL_DESCR,",
      "e.START_INVYR, e.END_INVYR, e.ESTN_METHOD",
      "FROM POP_EVAL e",
      "JOIN POP_EVAL_TYP t ON t.EVAL_CN = e.CN",
      "WHERE e.STATECD = %d AND t.EVAL_TYP = 'EXPCURR' AND e.EVALID = %d"
    ),
    as.integer(statecd),
    evalid
  )
  result <- standardize_names(DBI::dbGetQuery(con, sql))
  if (nrow(result) != 1L) {
    stop("Configured FIA EVALID ", evalid, " is not available as one current evaluation.", call. = FALSE)
  }
  tibble::as_tibble(result)
}

resolve_current_evaluation <- function(con, statecd = 26L, evalid = NULL) {
  if (is.null(evalid)) {
    return(latest_current_evaluation(con, statecd))
  }
  current_evaluation_by_id(con, evalid, statecd)
}

current_northern_hardwood_types <- function(con) {
  result <- standardize_names(DBI::dbGetQuery(
    con,
    paste(
      "SELECT VALUE, MEANING, TYPGRPCD, MANUAL_START, MANUAL_END, ALLOWED_IN_FIELD",
      "FROM REF_FOREST_TYPE",
      "WHERE TYPGRPCD = 800",
      "AND ALLOWED_IN_FIELD = 'Y'",
      "AND MANUAL_END IS NULL",
      "ORDER BY VALUE"
    )
  ))
  if (!nrow(result)) stop("No active field types in FIA forest-type group 800.", call. = FALSE)
  tibble::as_tibble(result)
}

sugar_maple_reference <- function(con) {
  result <- standardize_names(DBI::dbGetQuery(
    con,
    paste(
      "SELECT SPCD, COMMON_NAME, SCIENTIFIC_NAME, SPECIES_SYMBOL",
      "FROM REF_SPECIES",
      "WHERE lower(COMMON_NAME) = 'sugar maple'",
      "OR lower(SCIENTIFIC_NAME) = 'acer saccharum'"
    )
  ))
  if (nrow(result) != 1L) stop("Expected one sugar maple reference row; found ", nrow(result), call. = FALSE)
  tibble::as_tibble(result)
}

eligible_condition_cte <- function(evalid, forest_codes) {
  code_sql <- paste(as.integer(forest_codes), collapse = ",")
  paste0(
    "WITH eval_plots AS (",
    " SELECT DISTINCT PLT_CN FROM POP_PLOT_STRATUM_ASSGN WHERE EVALID = ", as.integer(evalid),
    "), eligible AS (",
    " SELECT c.PLT_CN, c.CONDID FROM COND c",
    " JOIN eval_plots ep ON ep.PLT_CN = c.PLT_CN",
    " JOIN PLOT p ON p.CN = c.PLT_CN",
    " WHERE p.PLOT_STATUS_CD = 1",
    " AND c.COND_STATUS_CD = 1",
    " AND c.FORTYPCD IN (", code_sql, ")",
    ") "
  )
}

extract_eligible_conditions <- function(con, evalid, forest_codes) {
  code_sql <- paste(as.integer(forest_codes), collapse = ",")
  sql <- paste0(
    "WITH eval_plots AS (",
    " SELECT DISTINCT PLT_CN FROM POP_PLOT_STRATUM_ASSGN WHERE EVALID = ", as.integer(evalid),
    "), county_names AS (",
    " SELECT STATECD, COUNTYCD, MIN(COUNTYNM) AS COUNTYNM",
    " FROM COUNTY GROUP BY STATECD, COUNTYCD",
    ") ",
    "SELECT CAST(c.PLT_CN AS TEXT) AS PLT_CN, c.CONDID, c.INVYR,",
    " p.MEASYEAR, p.MEASMON, p.MEASDAY, p.MANUAL, p.DESIGNCD, p.KINDCD,",
    " c.STATECD, c.UNITCD, c.COUNTYCD, cn.COUNTYNM, c.PLOT,",
    " c.COND_STATUS_CD, c.FORTYPCD, r.MEANING AS FOREST_TYPE,",
    " c.CONDPROP_UNADJ, c.MICRPROP_UNADJ, c.SUBPPROP_UNADJ,",
    " c.STDAGE, c.STDSZCD, c.BALIVE,",
    " c.DSTRBCD1, c.DSTRBYR1, c.DSTRBCD2, c.DSTRBYR2, c.DSTRBCD3, c.DSTRBYR3,",
    " c.TRTCD1, c.TRTYR1, c.TRTCD2, c.TRTYR2, c.TRTCD3, c.TRTYR3",
    " FROM COND c",
    " JOIN eval_plots ep ON ep.PLT_CN = c.PLT_CN",
    " JOIN PLOT p ON p.CN = c.PLT_CN",
    " JOIN REF_FOREST_TYPE r ON r.VALUE = c.FORTYPCD",
    " LEFT JOIN county_names cn ON cn.STATECD = c.STATECD AND cn.COUNTYCD = c.COUNTYCD",
    " WHERE p.PLOT_STATUS_CD = 1",
    " AND c.COND_STATUS_CD = 1",
    " AND c.FORTYPCD IN (", code_sql, ")",
    " ORDER BY c.PLT_CN, c.CONDID"
  )
  standardize_names(DBI::dbGetQuery(con, sql)) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      plt_cn = as.character(.data$plt_cn),
      geoid = sprintf("%02d%03d", .data$statecd, .data$countycd),
      county_name = as.character(.data$countynm),
      stand_age = as.numeric(.data$stdage),
      disturbed = dplyr::if_else(
        dplyr::coalesce(.data$dstrbcd1, 0L) > 0L |
          dplyr::coalesce(.data$dstrbcd2, 0L) > 0L |
          dplyr::coalesce(.data$dstrbcd3, 0L) > 0L,
        TRUE,
        FALSE
      ),
      treated = dplyr::if_else(
        dplyr::coalesce(.data$trtcd1, 0L) > 0L |
          dplyr::coalesce(.data$trtcd2, 0L) > 0L |
          dplyr::coalesce(.data$trtcd3, 0L) > 0L,
        TRUE,
        FALSE
      )
    ) |>
    dplyr::select(-dplyr::all_of("countynm"))
}

extract_eligible_trees <- function(con, evalid, forest_codes) {
  sql <- paste0(
    eligible_condition_cte(evalid, forest_codes),
    "SELECT CAST(t.PLT_CN AS TEXT) AS PLT_CN, t.CONDID, CAST(t.CN AS TEXT) AS TREE_CN,",
    " CAST(t.SPCD AS INTEGER) AS SPCD, t.DIA, t.TPA_UNADJ, t.STATUSCD",
    " FROM TREE t JOIN eligible e ON e.PLT_CN = t.PLT_CN AND e.CONDID = t.CONDID",
    " WHERE t.STATUSCD = 1 AND t.SPCD IS NOT NULL"
  )
  standardize_names(DBI::dbGetQuery(con, sql)) |>
    tibble::as_tibble() |>
    dplyr::mutate(plt_cn = as.character(.data$plt_cn), tree_cn = as.character(.data$tree_cn))
}

extract_eligible_seedlings <- function(con, evalid, forest_codes) {
  sql <- paste0(
    eligible_condition_cte(evalid, forest_codes),
    "SELECT CAST(s.PLT_CN AS TEXT) AS PLT_CN, s.CONDID, CAST(s.CN AS TEXT) AS SEEDLING_CN,",
    " CAST(s.SPCD AS INTEGER) AS SPCD, s.SUBP, s.TREECOUNT, s.TREECOUNT_CALC, s.TPA_UNADJ",
    " FROM SEEDLING s JOIN eligible e ON e.PLT_CN = s.PLT_CN AND e.CONDID = s.CONDID"
  )
  standardize_names(DBI::dbGetQuery(con, sql)) |>
    tibble::as_tibble() |>
    dplyr::mutate(plt_cn = as.character(.data$plt_cn), seedling_cn = as.character(.data$seedling_cn))
}

extract_species_composition <- function(con, evalid, forest_codes) {
  sql <- paste0(
    eligible_condition_cte(evalid, forest_codes),
    "SELECT CAST(t.SPCD AS INTEGER) AS SPCD,",
    " COALESCE(rs.COMMON_NAME, 'Unknown species') AS SPECIES_NAME,",
    " COUNT(*) AS TREE_RECORDS,",
    " SUM(0.005454 * t.DIA * t.DIA * t.TPA_UNADJ) AS BA_FT2_AC_SUM",
    " FROM TREE t",
    " JOIN eligible e ON e.PLT_CN = t.PLT_CN AND e.CONDID = t.CONDID",
    " LEFT JOIN REF_SPECIES rs ON rs.SPCD = CAST(t.SPCD AS INTEGER)",
    " WHERE t.STATUSCD = 1 AND t.DIA >= 0 AND t.TPA_UNADJ >= 0",
    " GROUP BY CAST(t.SPCD AS INTEGER), rs.COMMON_NAME",
    " ORDER BY BA_FT2_AC_SUM DESC"
  )
  standardize_names(DBI::dbGetQuery(con, sql)) |> tibble::as_tibble()
}

build_cohort_flow <- function(con, evalid, forest_codes, eligible_conditions) {
  code_sql <- paste(as.integer(forest_codes), collapse = ",")
  queries <- c(
    "Plot visits assigned to current evaluation" = sprintf(
      "SELECT COUNT(DISTINCT PLT_CN) AS n FROM POP_PLOT_STRATUM_ASSGN WHERE EVALID = %d", evalid
    ),
    "Sampled plot visits" = sprintf(
      paste(
        "SELECT COUNT(DISTINCT p.CN) AS n FROM PLOT p",
        "JOIN POP_PLOT_STRATUM_ASSGN a ON a.PLT_CN=p.CN AND a.EVALID=%d",
        "WHERE p.PLOT_STATUS_CD=1"
      ), evalid
    ),
    "Accessible forest conditions" = sprintf(
      paste(
        "SELECT COUNT(*) AS n FROM COND c",
        "JOIN POP_PLOT_STRATUM_ASSGN a ON a.PLT_CN=c.PLT_CN AND a.EVALID=%d",
        "JOIN PLOT p ON p.CN=c.PLT_CN",
        "WHERE p.PLOT_STATUS_CD=1 AND c.COND_STATUS_CD=1"
      ), evalid
    ),
    "Northern hardwood forest-type-group conditions" = sprintf(
      paste(
        "SELECT COUNT(*) AS n FROM COND c",
        "JOIN POP_PLOT_STRATUM_ASSGN a ON a.PLT_CN=c.PLT_CN AND a.EVALID=%d",
        "JOIN PLOT p ON p.CN=c.PLT_CN",
        "WHERE p.PLOT_STATUS_CD=1 AND c.COND_STATUS_CD=1 AND c.FORTYPCD IN (%s)"
      ), evalid, code_sql
    )
  )
  purrr::imap_dfr(queries, function(sql, step) {
    tibble::tibble(step = step, observations = as.numeric(DBI::dbGetQuery(con, sql)$n[[1]]))
  }) |>
    dplyr::bind_rows(tibble::tibble(
      step = "Conditions with demonstrated microplot sampling",
      observations = sum(eligible_conditions$micrprop_unadj > 0, na.rm = TRUE)
    ))
}
