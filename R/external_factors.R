# Feasibility helpers only. No external-factor model or causal estimand.

external_harvest_window <- function(year, month, lookback = 3L) {
  if (!length(year) || length(year) != length(month) ||
      any(!is.finite(c(year, month))) || any(year != as.integer(year)) ||
      any(month != as.integer(month)) || any(month < 1 | month > 12) ||
      length(lookback) != 1L || !is.finite(lookback) ||
      lookback != as.integer(lookback) || lookback < 1) {
    stop("Invalid baseline calendar or harvest lookback.", call. = FALSE)
  }
  # Hunting seasons can extend into January of the following calendar year.
  # Conservatively exclude that season for ALL January visits. This avoids
  # using the unobserved visit day or assuming a particular DMU's season dates.
  end <- as.integer(year) - 1L - as.integer(month == 1L)
  data.frame(first_season = end - lookback + 1L, last_season = end,
    january_shift = month == 1L,
    required_seasons = vapply(end, function(y) paste(seq.int(y - lookback + 1L, y), collapse = ";"), character(1)))
}

external_browse_join <- function(pairs, browse) {
  required <- c("PLT_CN", "BROWSE_IMPACT")
  if (!all(required %in% names(browse)) ||
      !all(c("baseline_plt_cn", "current_plt_cn") %in% names(pairs))) {
    stop("Missing browse-join columns.", call. = FALSE)
  }
  if (anyNA(browse$PLT_CN) || anyDuplicated(as.character(browse$PLT_CN))) {
    stop("Browse table must have unique nonmissing plot-visit keys.", call. = FALSE)
  }
  if (any(!is.na(browse$BROWSE_IMPACT) & !browse$BROWSE_IMPACT %in% 1:5)) {
    stop("Unexpected BROWSE_IMPACT code; inspect protocol before recoding.", call. = FALSE)
  }
  pairs$baseline_browse_impact <- browse$BROWSE_IMPACT[match(as.character(pairs$baseline_plt_cn), as.character(browse$PLT_CN))]
  pairs$followup_browse_impact <- browse$BROWSE_IMPACT[match(as.character(pairs$current_plt_cn), as.character(browse$PLT_CN))]
  pairs
}
