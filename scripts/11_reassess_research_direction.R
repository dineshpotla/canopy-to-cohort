# Exploratory direction audit, not a replacement primary analysis. All models
# reuse the existing county folds; comparisons therefore are internal validation.
# Only aggregate outputs are written. No prediction or record-level files are saved.
source("R/utils.R")
source("R/validation.R")
source("R/models.R")
source("R/longitudinal.R")
source("R/longitudinal_models.R")

config <- read_config()
longitudinal <- read_required_rds(project_path(config$files$longitudinal_data))
prepared <- prepare_longitudinal_loss_data(longitudinal)
raw <- prepared$raw
key <- c("baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid")
raw <- raw |>
  dplyr::left_join(
    longitudinal |>
      dplyr::select(dplyr::all_of(c(key, "baseline_nonmaple_ba_ft2_ac"))),
    by = key
  ) |>
  dplyr::mutate(audit_row = dplyr::row_number())
stopifnot(nrow(raw) == nrow(prepared$raw), all(is.finite(raw$baseline_nonmaple_ba_ft2_ac)))
stopifnot(max(abs(raw$baseline_nonmaple_ba_ft2_ac -
  raw$beech_sapling_ba_ft2_ac - raw$other_nonmaple_ba_ft2_ac)) < 1e-8)

fold_file <- project_path("outputs", "tables", "longitudinal-loss-cross-validation-county-folds.csv")
assignments <- readr::read_csv(fold_file, show_col_types = FALSE,
  col_types = readr::cols(geoid = readr::col_character()))
stopifnot(!anyDuplicated(assignments$geoid))
record_fold <- assignments$fold[match(as.character(raw$geoid), assignments$geoid)]
stopifnot(!anyNA(record_fold))
for (i in seq_len(nrow(assignments))) {
  county_rows <- as.character(raw$geoid) == assignments$geoid[[i]]
  stopifnot(sum(county_rows) == assignments$observations[[i]],
    sum(raw$outcome_loss[county_rows]) == assignments$events[[i]])
}

strong <- "Starting abundance and observation"
current <- "Beech hypothesis"
total_only <- "Maple structure and total nonmaple"
total_beech <- "Maple structure and total nonmaple plus beech"
base_terms <- c("z_baseline_seedling_tpa", "z_microplot_coverage", "z_interval_years")
total_terms <- c(base_terms, "maple_sapling_present", "z_established_maple_ba", "z_total_nonmaple_ba")
specifications <- list(
  "Prevalence benchmark" = character(),
  "Starting density only" = "z_baseline_seedling_tpa",
  "Starting abundance and observation" = base_terms,
  "Beech hypothesis" = longitudinal_loss_terms(),
  "Maple structure and total nonmaple" = total_terms,
  "Maple structure and total nonmaple plus beech" = c(total_terms, "z_beech_sapling_ba")
)

log_step("Auditing incremental predictive value on the existing fixed county folds")
predictions <- matrix(NA_real_, nrow(raw), length(specifications),
  dimnames = list(NULL, names(specifications)))
fold_results <- list()
scaling_results <- list()
for (fold in sort(unique(record_fold))) {
  train <- record_fold != fold
  test <- !train
  scaled <- scale_longitudinal_loss_predictors(raw[train, ], raw[test, ])
  total_values <- log1p(scaled$training$baseline_nonmaple_ba_ft2_ac)
  center <- mean(total_values)
  spread <- stats::sd(total_values)
  stopifnot(is.finite(center), is.finite(spread), spread > 0)
  scaled$training$z_total_nonmaple_ba <- (total_values - center) / spread
  scaled$testing$z_total_nonmaple_ba <-
    (log1p(scaled$testing$baseline_nonmaple_ba_ft2_ac) - center) / spread
  scaling_results[[length(scaling_results) + 1L]] <- dplyr::bind_rows(
    scaled$audit,
    tibble::tibble(model_variable = "z_total_nonmaple_ba",
      source_variable = "baseline_nonmaple_ba_ft2_ac", transformation = "log1p",
      center = center, scale = spread, observations = sum(train),
      scaling_population = "training data only")
  ) |>
    dplyr::mutate(fold = fold)
  for (model_name in names(specifications)) {
    fold_model <- stats::glm(longitudinal_formula(specifications[[model_name]]),
      family = stats::binomial(), data = scaled$training)
    validate_longitudinal_loss_glm(fold_model, paste("Direction audit", model_name, "fold", fold))
    probability <- as.numeric(stats::predict(fold_model, newdata = scaled$testing, type = "response"))
    stopifnot(all(is.finite(probability)), all(probability > 0 & probability < 1))
    predictions[test, model_name] <- probability
    fold_results[[length(fold_results) + 1L]] <- tibble::tibble(
      model = model_name, fold = fold, training_n = sum(train), testing_n = sum(test),
      training_losses = sum(raw$outcome_loss[train]), testing_losses = sum(raw$outcome_loss[test]),
      slopes = length(specifications[[model_name]]),
      brier_score = mean((raw$outcome_loss[test] - probability)^2),
      roc_auc = binary_auc(raw$outcome_loss[test], probability),
      converged = isTRUE(fold_model$converged), maximum_absolute_coefficient = max(abs(stats::coef(fold_model))),
      maximum_standard_error = max(stats::coef(summary(fold_model))[, "Std. Error"])
    )
  }
}
stopifnot(all(is.finite(predictions)))

# Check exact reproduction of existing out-of-fold scores before interpreting new comparisons.
prior <- readr::read_csv(project_path("outputs", "tables", "longitudinal-loss-cross-validation-summary.csv"),
  show_col_types = FALSE)
for (model_name in c("Prevalence benchmark", strong, current)) {
  stopifnot(abs(mean((raw$outcome_loss - predictions[, model_name])^2) -
    prior$brier_score[prior$model == model_name]) < 1e-10)
}

# Exactly 169 of 677 conditions are selected for every model. The stable source
# row order breaks ties, and the tie-neutral expected capture is also reported.
top_n <- floor(nrow(raw) / 4L)
top_summary <- function(probability) {
  ordered <- order(-probability, raw$audit_row)
  cutoff <- probability[ordered[[top_n]]]
  above <- probability > cutoff
  at <- probability == cutoff
  remaining <- top_n - sum(above)
  tibble::tibble(
    top_quartile_n = top_n,
    top_quartile_losses = sum(raw$outcome_loss[ordered[seq_len(top_n)]]),
    top_quartile_capture_fraction = sum(raw$outcome_loss[ordered[seq_len(top_n)]]) / sum(raw$outcome_loss),
    cutoff_tied_n = sum(at), cutoff_tied_selected_n = remaining,
    tie_neutral_expected_losses = sum(raw$outcome_loss[above]) + remaining * mean(raw$outcome_loss[at])
  )
}
summary <- dplyr::bind_rows(lapply(names(specifications), function(model_name) {
  probability <- predictions[, model_name]
  calibration <- if (model_name == "Prevalence benchmark") {
    c(calibration_intercept = NA_real_, calibration_slope = NA_real_)
  } else calibration_statistics(raw$outcome_loss, probability)
  dplyr::bind_cols(tibble::tibble(
    model = model_name, observations = nrow(raw), losses = sum(raw$outcome_loss),
    counties = dplyr::n_distinct(raw$geoid), folds = length(unique(record_fold)),
    slopes = length(specifications[[model_name]]),
    brier_score = mean((raw$outcome_loss - probability)^2),
    roc_auc = if (model_name == "Prevalence benchmark") NA_real_ else binary_auc(raw$outcome_loss, probability),
    calibration_intercept = unname(calibration[["calibration_intercept"]]),
    calibration_slope = unname(calibration[["calibration_slope"]])
  ), top_summary(probability))
}))
strong_row <- summary[summary$model == strong, ]
summary <- summary |>
  dplyr::mutate(
    brier_difference_vs_strong = .data$brier_score - strong_row$brier_score,
    auc_difference_vs_strong = .data$roc_auc - strong_row$roc_auc,
    extra_top_quartile_losses_vs_strong = .data$top_quartile_losses - strong_row$top_quartile_losses,
    interpretation = "Exploratory reuse of existing county folds; not independent validation or model selection",
    brier_difference_direction = "Negative favors the named model over the strong benchmark",
    top_quartile_note = "Matched floor(n/4) capacity; ties broken by fixed source row order; not a treatment threshold"
  )

prevalence_brier <- summary$brier_score[summary$model == "Prevalence benchmark"]
full_brier <- summary$brier_score[summary$model == current]
decomposition <- tibble::tibble(
  metric = c("Prevalence Brier", "Strong benchmark Brier", "Current full model Brier",
    "Full improvement over prevalence", "Strong benchmark improvement over prevalence",
    "Additional full-model improvement over strong benchmark",
    "Fraction of full improvement already obtained by strong benchmark"),
  value = c(prevalence_brier, strong_row$brier_score, full_brier,
    prevalence_brier - full_brier, prevalence_brier - strong_row$brier_score,
    strong_row$brier_score - full_brier,
    (prevalence_brier - strong_row$brier_score) / (prevalence_brier - full_brier)),
  interpretation = "Descriptive decomposition of pooled held-out Brier differences, not causal attribution"
)

# Paired county-cluster resampling of already fitted out-of-fold predictions.
# Models and folds are NOT refit. Intervals condition on this fitted analysis and
# omit fitting, fold construction, model search, and direction-selection uncertainty.
comparisons <- tibble::tibble(
  model = c("Starting density only", current, total_only, total_beech, total_beech),
  reference = c(rep(strong, 4L), total_only)
)
county_rows <- split(seq_len(nrow(raw)), as.character(raw$geoid))
bootstrap_n <- 2000L
set.seed(20260907)
bootstrap_brier <- matrix(NA_real_, bootstrap_n, nrow(comparisons))
bootstrap_auc <- matrix(NA_real_, bootstrap_n, nrow(comparisons))
for (b in seq_len(bootstrap_n)) {
  sampled <- sample(seq_along(county_rows), length(county_rows), replace = TRUE)
  rows <- unlist(county_rows[sampled], use.names = FALSE)
  outcome <- raw$outcome_loss[rows]
  for (j in seq_len(nrow(comparisons))) {
    candidate <- predictions[rows, comparisons$model[[j]]]
    reference <- predictions[rows, comparisons$reference[[j]]]
    bootstrap_brier[b, j] <- mean((outcome - candidate)^2 - (outcome - reference)^2)
    bootstrap_auc[b, j] <- binary_auc(outcome, candidate) - binary_auc(outcome, reference)
  }
}
uncertainty <- dplyr::bind_rows(lapply(seq_len(nrow(comparisons)), function(j) {
  candidate <- predictions[, comparisons$model[[j]]]
  reference_probability <- predictions[, comparisons$reference[[j]]]
  tibble::tibble(
    model = comparisons$model[[j]], reference = comparisons$reference[[j]],
    brier_difference = mean((raw$outcome_loss - candidate)^2 - (raw$outcome_loss - reference_probability)^2),
    brier_difference_lower = unname(stats::quantile(bootstrap_brier[, j], 0.025)),
    brier_difference_upper = unname(stats::quantile(bootstrap_brier[, j], 0.975)),
    auc_difference = binary_auc(raw$outcome_loss, candidate) - binary_auc(raw$outcome_loss, reference_probability),
    auc_difference_lower = unname(stats::quantile(bootstrap_auc[, j], 0.025)),
    auc_difference_upper = unname(stats::quantile(bootstrap_auc[, j], 0.975)),
    resamples = bootstrap_n, cluster = "county", seed = 20260907L,
    uncertainty_scope = "Percentile intervals conditional on existing fitted folds; no refitting or selection uncertainty",
    difference_direction = "Negative Brier or positive AUC favors the named model over reference"
  )
}))

log_step("Auditing direct baseline SEEDLING TREECOUNT and sampling footprint")
con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(config), flags = RSQLite::SQLITE_RO)
seedlings <- tryCatch(extract_longitudinal_seedlings(con, config$release$evalid),
  finally = DBI::dbDisconnect(con))
counts <- seedlings |>
  dplyr::filter(.data$spcd == 318L) |>
  dplyr::group_by(.data$plt_cn, .data$condid) |>
  dplyr::summarise(raw_count = sum(.data$treecount),
    calculated_count = sum(.data$treecount_calc),
    tpa_plot_basis = sum(.data$tpa_unadj), records = dplyr::n(),
    missing_raw_count = sum(is.na(.data$treecount)), .groups = "drop")
count_data <- raw |>
  dplyr::left_join(counts, by = c("baseline_plt_cn" = "plt_cn", "baseline_condid" = "condid"))
stopifnot(nrow(count_data) == nrow(raw), !anyNA(count_data$raw_count),
  all(count_data$missing_raw_count == 0), all(count_data$raw_count >= 1),
  all(count_data$raw_count == round(count_data$raw_count)),
  max(abs(count_data$baseline_seedling_tpa * count_data$baseline_microplot_coverage -
    count_data$tpa_plot_basis)) < 1e-8)
count_data <- count_data |>
  dplyr::mutate(
    count_group = cut(.data$raw_count, breaks = c(0, 1, 5, 20, Inf),
      labels = c("1 tallied seedling", "2-5 tallied seedlings", "6-20 tallied seedlings", ">20 tallied seedlings")),
    coverage_group = dplyr::if_else(.data$baseline_microplot_coverage < 0.99,
      "Below 99% microplot condition coverage", "At least 99% microplot condition coverage")
  )
count_summary <- function(data, groups) {
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
    dplyr::summarise(conditions = dplyr::n(), losses = sum(.data$outcome_loss),
      observed_loss_fraction = mean(.data$outcome_loss),
      fraction_of_all_losses = sum(.data$outcome_loss) / sum(raw$outcome_loss),
      median_raw_count = stats::median(.data$raw_count),
      median_microplot_coverage = stats::median(.data$baseline_microplot_coverage),
      minimum_microplot_coverage = min(.data$baseline_microplot_coverage),
      maximum_microplot_coverage = max(.data$baseline_microplot_coverage), .groups = "drop")
}
count_strata <- count_summary(count_data, "count_group")
count_coverage <- count_summary(count_data, c("count_group", "coverage_group"))
count_audit <- tibble::tibble(
  metric = c("Loss-cohort conditions with raw count verified", "Raw/calculated count disagreements",
    "Maximum density-times-coverage versus TPA discrepancy", "Minimum TPA per calculated seedling",
    "Maximum TPA per calculated seedling", "Total raw count equal to one",
    "Losses among conditions with one raw seedling"),
  value = c(nrow(count_data), sum(count_data$raw_count != count_data$calculated_count),
    max(abs(count_data$baseline_seedling_tpa * count_data$baseline_microplot_coverage - count_data$tpa_plot_basis)),
    min(count_data$tpa_plot_basis / count_data$calculated_count),
    max(count_data$tpa_plot_basis / count_data$calculated_count),
    sum(count_data$raw_count == 1), sum(count_data$outcome_loss[count_data$raw_count == 1])),
  count_source = "Sum of direct FIA SEEDLING.TREECOUNT records for baseline sugar maple SPCD 318",
  interpretation = "Counts and coverage can explain fragile detection; these summaries do not identify mortality, recruitment, or imperfect detection separately"
)

outputs <- list(
  "model-summary" = summary,
  "fold-diagnostics" = dplyr::bind_rows(fold_results),
  "fold-scaling" = dplyr::bind_rows(scaling_results),
  "brier-decomposition" = decomposition,
  "conditional-bootstrap" = uncertainty,
  "count-strata" = count_strata,
  "count-coverage-strata" = count_coverage,
  "count-audit" = count_audit
)
for (name in names(outputs)) {
  write_csv_atomic(outputs[[name]], project_path("outputs", "audits", paste0("research-direction-", name, ".csv")))
}
print(summary |>
  dplyr::select(dplyr::all_of(c("model", "brier_score", "roc_auc",
    "top_quartile_losses", "brier_difference_vs_strong"))), n = Inf, width = Inf)
print(decomposition, n = Inf, width = Inf)
print(uncertainty, n = Inf, width = Inf)
print(count_strata, n = Inf, width = Inf)
log_step("Exploratory research-direction audit complete; aggregate outputs only")
