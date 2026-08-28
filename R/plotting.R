project_palette <- c(
  maple = "#8B1E3F",
  forest = "#285943",
  moss = "#6B8E5B",
  sand = "#D8C3A5",
  ink = "#263238",
  pale = "#EDF1EC"
)

theme_canopy <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", colour = project_palette[["ink"]]),
      plot.subtitle = ggplot2::element_text(colour = "#50605A"),
      plot.caption = ggplot2::element_text(hjust = 0, lineheight = 1.05),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )
}

save_figure <- function(plot, filename, width = 8, height = 5.5) {
  path <- project_path("outputs", "figures", filename)
  ggplot2::ggsave(path, plot, width = width, height = height, dpi = 320, bg = "white")
  invisible(path)
}

plot_species_composition <- function(composition, top_n = 12L) {
  shown <- composition |>
    dplyr::slice_max(.data$ba_ft2_ac_sum, n = top_n, with_ties = FALSE) |>
    dplyr::mutate(species_name = stats::reorder(.data$species_name, .data$ba_ft2_ac_sum))

  ggplot2::ggplot(shown, ggplot2::aes(.data$ba_ft2_ac_sum, .data$species_name)) +
    ggplot2::geom_col(fill = project_palette[["forest"]], width = 0.72) +
    ggplot2::scale_x_continuous(labels = scales::label_number(big.mark = ","), expand = ggplot2::expansion(mult = c(0, 0.06))) +
    ggplot2::labs(
      title = "Sugar maple anchors the sampled maple/beech/birch cohort",
      subtitle = "FIA unadjusted plot-basis live-tree basal-area contribution across analyzed conditions",
      x = expression("Summed basal-area contribution (ft"^2 * "/acre on FIA plot basis)"),
      y = NULL,
      caption = "TPA_UNADJ expands sampled trees to a plot-acre basis; it is not an FIA population weight. Descriptive sample totals only."
    ) +
    theme_canopy()
}

plot_regeneration_quadrant <- function(data) {
  threshold <- unique(stats::na.omit(data$established_threshold))[[1]]
  plotted <- data |>
    dplyr::filter(!is.na(.data$maple_ba_share), !is.na(.data$maple_seedling_tpa)) |>
    dplyr::arrange(.data$potential_gap)
  y_transformation <- scales::pseudo_log_trans(base = 10, sigma = 50)
  y_breaks <- c(0, 100, 300, 1e3, 3e3, 1e4, 2e4)
  y_breaks <- y_breaks[y_breaks <= max(plotted$maple_seedling_tpa, na.rm = TRUE)]

  ggplot2::ggplot(
    plotted,
    ggplot2::aes(.data$maple_ba_share, .data$maple_seedling_tpa)
  ) +
    ggplot2::geom_point(
      ggplot2::aes(colour = .data$potential_gap),
      alpha = 0.55,
      size = 1.7
    ) +
    ggplot2::geom_vline(xintercept = threshold, linetype = 2, colour = "#6C757D") +
    ggplot2::scale_y_continuous(
      trans = y_transformation,
      breaks = y_breaks,
      labels = scales::label_number(big.mark = ",")
    ) +
    ggplot2::scale_x_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.25),
      labels = scales::label_percent(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0.01, 0.01))
    ) +
    ggplot2::scale_colour_manual(
      values = c(`FALSE` = "#A8B2AD", `TRUE` = project_palette[["maple"]]),
      breaks = c(FALSE, TRUE),
      labels = c("Other observation", "Potential gap"),
      na.value = "#E0E0E0",
      name = NULL
    ) +
    ggplot2::annotate(
      "text",
      x = threshold,
      y = max(plotted$maple_seedling_tpa, na.rm = TRUE),
      label = sprintf("Upper-third cutoff\n%.1f%% maple share", 100 * threshold),
      hjust = 1.08,
      vjust = 1.05,
      colour = "#59645F",
      fontface = "bold",
      size = 3.2
    ) +
    ggplot2::annotate(
      "text",
      x = 0.98,
      y = 0,
      label = "High established maple\nNo seedlings tallied",
      hjust = 1,
      vjust = -0.8,
      colour = project_palette[["maple"]],
      fontface = "bold",
      size = 3.5
    ) +
    ggplot2::labs(
      title = "Where canopy presence does not coincide with observed seedlings",
      subtitle = "Potential gaps combine upper-third sugar-maple basal-area share with zero seedlings tallied",
      x = "Sugar maple share of live-tree basal area",
      y = "Sugar maple seedlings per acre (pseudo-log scale; exact values)",
      caption = sprintf(
        "Dashed line = %.1f%% sample cutoff. Points are not jittered; zero means no seedlings tallied on sampled microplots.",
        100 * threshold
      )
    ) +
    theme_canopy()
}

plot_maple_effect_curve <- function(effect_curve) {
  required <- c("maple_ba_ft2_ac", "predicted_probability", "conf_low", "conf_high")
  missing <- setdiff(required, names(effect_curve))
  if (length(missing)) stop("Maple effect curve is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  spline_df <- if ("spline_df" %in% names(effect_curve)) unique(effect_curve$spline_df) else 3L
  if (length(spline_df) != 1L || !is.finite(spline_df)) {
    stop("Maple effect curve must contain one finite spline_df value.", call. = FALSE)
  }
  x_upper <- max(effect_curve$maple_ba_ft2_ac, na.rm = TRUE)
  x_breaks <- c(0, 1, 5, 10, 25, 50, 100, 150)
  x_breaks <- x_breaks[x_breaks <= x_upper]

  ggplot2::ggplot(
    effect_curve,
    ggplot2::aes(.data$maple_ba_ft2_ac, .data$predicted_probability)
  ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$conf_low, ymax = .data$conf_high),
      fill = project_palette[["maple"]], alpha = 0.18
    ) +
    ggplot2::geom_line(linewidth = 1.15, colour = project_palette[["maple"]]) +
    ggplot2::scale_x_continuous(
      trans = scales::pseudo_log_trans(base = 10, sigma = 1),
      breaks = x_breaks,
      labels = scales::label_number(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1), labels = scales::label_percent(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.01))
    ) +
    ggplot2::labs(
      title = "Seedling non-detection changes nonlinearly with maple basal area",
      subtitle = "Adjusted county-level mixed model; ribbon is a pointwise Wald 95% confidence interval",
      x = expression("Sugar maple basal area (ft"^2 * "/acre; pseudo-log scale)"),
      y = "Predicted probability of no sugar-maple seedlings tallied",
      caption = paste(
        sprintf("Natural spline (%d df) of standardized log(x + 1) maple basal area.", as.integer(spline_df)),
        "Reference profile: other continuous variables at their means, no recorded disturbance, county effect = 0.",
        "Curve ends at the observed 99th percentile. Observational association, not a causal effect.",
        sep = "\n"
      )
    ) +
    theme_canopy()
}

# Backward-compatible name; v1.2 expects prediction-curve data rather than odds ratios.
plot_model_effects <- plot_maple_effect_curve

wilson_interval <- function(successes, total, z = 1.96) {
  if (is.na(total) || total <= 0) {
    return(tibble::tibble(estimate = NA_real_, conf_low = NA_real_, conf_high = NA_real_))
  }
  p <- successes / total
  denominator <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / denominator
  half <- z * sqrt((p * (1 - p) + z^2 / (4 * total)) / total) / denominator
  tibble::tibble(estimate = p, conf_low = pmax(0, center - half), conf_high = pmin(1, center + half))
}

plot_county_gap_uncertainty <- function(county_summary, minimum_n = 20L) {
  required <- c(
    "county_name", "gap_denominator", "estimate", "conf_low", "conf_high", "map_supported"
  )
  missing <- setdiff(required, names(county_summary))
  if (length(missing)) {
    stop("County summary is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  shown <- county_summary |>
    dplyr::filter(.data$map_supported, !is.na(.data$estimate)) |>
    dplyr::mutate(
      county_label = paste0(.data$county_name, "  (n = ", .data$gap_denominator, ")"),
      county_label = stats::reorder(.data$county_label, .data$estimate)
    )
  if (!nrow(shown)) stop("No counties meet the mapping support threshold.", call. = FALSE)

  ggplot2::ggplot(shown, ggplot2::aes(.data$estimate, .data$county_label)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = .data$conf_low, xend = .data$conf_high, yend = .data$county_label),
      linewidth = 1.05,
      colour = project_palette[["forest"]]
    ) +
    ggplot2::geom_point(size = 2.8, colour = project_palette[["maple"]]) +
    ggplot2::scale_x_continuous(
      labels = scales::label_percent(accuracy = 1),
      limits = c(0, max(shown$conf_high, na.rm = TRUE)),
      expand = ggplot2::expansion(mult = c(0, 0.04))
    ) +
    ggplot2::labs(
      title = "County fractions remain uncertain even after support screening",
      subtitle = "Exploratory gap fraction with unweighted Wilson 95% reference intervals; denominator shown in labels",
      x = "Flagged fraction among seedling-sampled conditions",
      y = NULL,
      caption = paste0(
        "Counties shown only when n ≥ ", minimum_n,
        ". Descriptive, unweighted binomial intervals; they ignore FIA survey design and within-county clustering."
      )
    ) +
    theme_canopy(base_size = 10.5) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 8.3),
      legend.position = "none"
    )
}
