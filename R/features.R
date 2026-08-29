percent_rank_safe <- function(x) {
  if (sum(!is.na(x)) < 2L) return(rep(NA_real_, length(x)))
  dplyr::percent_rank(x)
}

add_regeneration_gap_metrics <- function(data, established_quantile = 2 / 3, sensitivity_quantile = 0.75) {
  assert_columns(
    data,
    c("established_maple_ba_share", "maple_seedling_tpa", "maple_seedling_detected"),
    "analysis data"
  )

  outcome_eligible <- !is.na(data$maple_seedling_detected) & !is.na(data$established_maple_ba_share)
  if (!any(outcome_eligible)) {
    stop("No seedling-sampled conditions are available to define regeneration-gap thresholds.", call. = FALSE)
  }

  established_share <- ifelse(outcome_eligible, data$established_maple_ba_share, NA_real_)
  regeneration_density <- ifelse(outcome_eligible, data$maple_seedling_tpa, NA_real_)

  established_cut <- stats::quantile(
    established_share,
    probs = established_quantile,
    na.rm = TRUE,
    names = FALSE
  )
  sensitivity_cut <- stats::quantile(
    established_share,
    probs = sensitivity_quantile,
    na.rm = TRUE,
    names = FALSE
  )

  data |>
    dplyr::mutate(
      established_percentile = percent_rank_safe(established_share),
      regeneration_percentile = percent_rank_safe(log1p(regeneration_density)),
      gap_rank_difference = .data$established_percentile - .data$regeneration_percentile,
      potential_gap = dplyr::case_when(
        is.na(.data$maple_seedling_detected) ~ NA,
        .data$established_maple_ba_share >= established_cut & .data$maple_seedling_detected == 0L ~ TRUE,
        TRUE ~ FALSE
      ),
      potential_gap_sensitivity = dplyr::case_when(
        is.na(.data$maple_seedling_detected) ~ NA,
        .data$established_maple_ba_share >= sensitivity_cut & .data$maple_seedling_detected == 0L ~ TRUE,
        TRUE ~ FALSE
      ),
      established_threshold = established_cut,
      sensitivity_threshold = sensitivity_cut
    )
}

assemble_analysis_data <- function(fia_data, climate, config) {
  fia_data <- dplyr::mutate(fia_data, geoid = as.character(.data$geoid))
  climate <- dplyr::mutate(climate, geoid = sprintf("%05d", as.integer(.data$geoid)))
  assert_unique_key(fia_data, c("plt_cn", "condid"), "FIA analytical data")
  assert_unique_key(climate, "geoid", "county climate")
  joined <- dplyr::left_join(fia_data, climate, by = "geoid", suffix = c("", "_climate"))
  audit <- join_audit(fia_data, climate, c(geoid = "geoid"), "FIA -> county climate", joined)
  if (audit$unmatched_left_keys > 0) stop("FIA observations have unmatched county climate records.")

  list(
    data = add_regeneration_gap_metrics(
      joined,
      config$analysis$gap_established_quantile,
      config$analysis$gap_sensitivity_quantile
    ),
    audit = audit
  )
}
