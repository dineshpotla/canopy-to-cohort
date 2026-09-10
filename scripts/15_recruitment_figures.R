source("R/utils.R")
source("R/recruitment_models.R")

d <- prepare_recruitment_model_data(read_required_rds(project_path("data", "processed", "recruitment_condition_pairs.rds")))
counts <- recruitment_empirical_summaries(d)$count
set.seed(20260908)
counties <- unique(d$geoid)
group <- cut(d$baseline_seedling_count, c(-1, 0, 1, 5, 20, Inf), labels = c("0", "1", "2-5", "6-20", ">20"))
draws <- replicate(2000, {
  w <- tabulate(sample.int(length(counties), length(counties), replace = TRUE), nbins = length(counties))[match(d$geoid, counties)]
  vapply(levels(group), function(g) {
    keep <- group == g
    if (sum(w[keep]) == 0) return(NA_real_)
    weighted.mean(d$outcome_recruitment[keep], w[keep])
  }, numeric(1))
})
counts$lower <- apply(draws, 1, stats::quantile, 0.025, na.rm = TRUE)
counts$upper <- apply(draws, 1, stats::quantile, 0.975, na.rm = TRUE)
counts$uncertainty <- "2000 county-cluster percentile resamples; zero observed events yields degenerate empirical interval, not proof of zero probability"
write_csv_atomic(counts, project_path("outputs", "tables", "recruitment-model-count-strata-intervals.csv"))
theme <- ggplot2::theme_minimal(base_size = 12) + ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
  plot.title.position = "plot", plot.caption = ggplot2::element_text(hjust = 0, size = 9),
  plot.margin = ggplot2::margin(10, 25, 10, 10))
plot <- ggplot2::ggplot(counts, ggplot2::aes(.data$count_group, .data$recruitment_fraction)) +
  ggplot2::geom_col(fill = "#345f50", width = 0.62) +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = .data$lower, ymax = .data$upper), width = 0.13) +
  ggplot2::geom_text(ggplot2::aes(y = .data$upper + 0.018, label = paste0(.data$conditions_with_new_tally, "/", .data$conditions)), vjust = 0, size = 3.5) +
  ggplot2::scale_y_continuous(labels = scales::percent, limits = c(0, max(counts$upper) + 0.07)) +
  ggplot2::labs(x = "Recorded baseline maple seedlings across sampled microplots", y = "Conditions with a new live sapling tally",
    title = "Seedling counts and recorded sapling entry",
    subtitle = "922 audited Michigan condition pairs; labels show recruit-bearing conditions / total",
    caption = "County-resampled intervals. No events in the zero-count group does not establish zero probability.\nCounts above five can be field estimates; bins are descriptive, not stocking thresholds.") + theme
ggplot2::ggsave(project_path("outputs", "figures", "10_recruitment_counts.png"), plot, width = 9, height = 5.4, dpi = 180, bg = "white")

comparison <- readr::read_csv(project_path("outputs", "tables", "recruitment-model-paired-differences.csv"), show_col_types = FALSE) |>
  dplyr::filter(.data$metric == "brier_score") |>
  dplyr::mutate(contrast = dplyr::if_else(.data$model == "Seedling count and design", "Add seedling count\nto observation design", "Add maple stages\nto count + design"))
plot <- ggplot2::ggplot(comparison, ggplot2::aes(.data$difference, .data$contrast)) +
  ggplot2::geom_vline(xintercept = 0, linetype = 2, color = "gray55") +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = .data$lower, xmax = .data$upper), orientation = "y", width = 0.15) +
  ggplot2::geom_point(size = 2.8, color = "#345f50") +
  ggplot2::facet_wrap(~population, ncol = 1) +
  ggplot2::labs(x = "Brier difference (negative favors added information)", y = NULL,
    title = "Incremental prediction from seedling counts and maple stages",
    caption = "95% percentile intervals from 300 county resamples per population, with all training scaling and fits repeated.\nModel set, penalty and original county folds remain fixed; exploratory snapshot, not external validation.") + theme
ggplot2::ggsave(project_path("outputs", "figures", "11_recruitment_incremental_value.png"), plot, width = 9, height = 6.2, dpi = 180, bg = "white")
log_step("Recruitment figures and their aggregate supporting data saved")
