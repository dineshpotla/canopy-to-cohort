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
    dplyr::mutate(share = .data$ba_ft2_ac_sum / sum(.data$ba_ft2_ac_sum)) |>
    dplyr::slice_max(.data$share, n = top_n, with_ties = FALSE) |>
    dplyr::mutate(
      species_name = stats::reorder(.data$species_name, .data$share),
      focal = .data$species_name == "sugar maple"
    )
  displayed_share <- sum(shown$share)

  ggplot2::ggplot(shown, ggplot2::aes(.data$share, .data$species_name)) +
    ggplot2::geom_col(ggplot2::aes(fill = .data$focal), width = 0.72, show.legend = FALSE) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(.data$share, accuracy = 0.1)),
      hjust = -0.12,
      size = 3.2,
      colour = project_palette[["ink"]]
    ) +
    ggplot2::scale_fill_manual(values = c(`FALSE` = project_palette[["forest"]], `TRUE` = project_palette[["maple"]])) +
    ggplot2::scale_x_continuous(labels = scales::label_percent(accuracy = 1), expand = ggplot2::expansion(mult = c(0, 0.12))) +
    ggplot2::labs(
      title = "Sugar maple anchors the sampled maple/beech/birch cohort",
      subtitle = "Share of all live-tree basal-area contribution in the analyzed sample",
      x = "Share of all-species basal-area contribution",
      y = NULL,
      caption = sprintf(
        "Top %d species shown (%.1f%% of the all-species denominator). TPA_UNADJ is not an FIA population weight; descriptive sample composition only.",
        top_n, 100 * displayed_share
      )
    ) +
    theme_canopy()
}

plot_regeneration_quadrant <- function(data) {
  threshold <- unique(stats::na.omit(data$established_threshold))[[1]]
  plotted <- data |>
    dplyr::filter(!is.na(.data$established_maple_ba_share), !is.na(.data$maple_seedling_tpa)) |>
    dplyr::arrange(.data$potential_gap)
  detected <- plotted |>
    dplyr::filter(.data$maple_seedling_tpa > 0)
  zero_bins <- plotted |>
    dplyr::filter(.data$maple_seedling_tpa == 0) |>
    dplyr::mutate(
      share_bin = pmin(0.975, floor(.data$established_maple_ba_share / 0.05) * 0.05 + 0.025)
    ) |>
    dplyr::count(.data$share_bin, .data$potential_gap)
  y_transformation <- scales::pseudo_log_trans(base = 10, sigma = 50)
  y_breaks <- c(100, 300, 1e3, 3e3, 1e4, 2e4)
  y_breaks <- y_breaks[y_breaks <= max(detected$maple_seedling_tpa, na.rm = TRUE)]

  upper <- ggplot2::ggplot(
    detected,
    ggplot2::aes(.data$established_maple_ba_share, .data$maple_seedling_tpa)
  ) +
    ggplot2::geom_point(
      colour = project_palette[["forest"]],
      alpha = 0.42,
      size = 1.6
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
    ggplot2::annotate(
      "text",
      x = threshold,
      y = max(detected$maple_seedling_tpa, na.rm = TRUE),
      label = sprintf("Upper-third cutoff\n%.1f%% established-tree share", 100 * threshold),
      hjust = 1.08,
      vjust = 1.05,
      colour = "#59645F",
      fontface = "bold",
      size = 3.2
    ) +
    ggplot2::labs(
      title = "Established trees do not always coincide with the seedling cohort",
      subtitle = "Positive seedling tallies are shown exactly; zero tallies are counted in the lower strip",
      x = NULL,
      y = "Seedlings per acre\n(pseudo-log scale)"
    ) +
    theme_canopy() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      legend.position = "none"
    )

  lower <- ggplot2::ggplot(zero_bins, ggplot2::aes(.data$share_bin, .data$n, fill = .data$potential_gap)) +
    ggplot2::geom_col(width = 0.046) +
    ggplot2::geom_vline(xintercept = threshold, linetype = 2, colour = "#6C757D") +
    ggplot2::scale_fill_manual(values = c(`FALSE` = "#A8B2AD", `TRUE` = project_palette[["maple"]]), guide = "none") +
    ggplot2::scale_y_sqrt(expand = ggplot2::expansion(mult = c(0, 0.08))) +
    ggplot2::scale_x_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.25),
      labels = scales::label_percent(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0.01, 0.01))
    ) +
    ggplot2::labs(
      x = "Sugar maple share of live established-tree basal area (DBH ≥ 5 in)",
      y = "Zero-tally\nconditions",
      caption = sprintf(
        "Bars count true zero tallies in 5-percentage-point bins; burgundy meets the %.1f%% sample cutoff.\nSquare-root count scale. Descriptive screen, not a population estimate.",
        100 * threshold
      )
    ) +
    theme_canopy() +
    ggplot2::theme(panel.grid.major.x = ggplot2::element_blank(), legend.position = "none")

  patchwork::wrap_plots(upper, lower, ncol = 1, heights = c(4.2, 1.35))
}

plot_maple_effect_curve <- function(effect_curve, rug_data = NULL) {
  required <- c("maple_ba_ft2_ac", "predicted_probability", "conf_low", "conf_high")
  missing <- setdiff(required, names(effect_curve))
  if (length(missing)) stop("Maple effect curve is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  x_upper <- max(effect_curve$maple_ba_ft2_ac, na.rm = TRUE)
  x_breaks <- c(0, 1, 5, 10, 25, 50, 100, 150)
  x_breaks <- x_breaks[x_breaks <= x_upper]

  plot <- ggplot2::ggplot(
    effect_curve,
    ggplot2::aes(
      .data$maple_ba_ft2_ac,
      .data$predicted_probability,
      colour = .data$maple_sapling_present,
      fill = .data$maple_sapling_present
    )
  ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$conf_low, ymax = .data$conf_high),
      alpha = 0.15,
      colour = NA
    ) +
    ggplot2::geom_line(linewidth = 1.15) +
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
    ggplot2::scale_colour_manual(
      values = c(`FALSE` = project_palette[["maple"]], `TRUE` = project_palette[["forest"]]),
      breaks = c("FALSE", "TRUE"),
      labels = c("Saplings absent", "Saplings present"),
      name = NULL
    ) +
    ggplot2::scale_fill_manual(
      values = c(`FALSE` = project_palette[["maple"]], `TRUE` = project_palette[["forest"]]),
      breaks = c("FALSE", "TRUE"),
      labels = c("Saplings absent", "Saplings present"),
      name = NULL
    ) +
    ggplot2::labs(
      title = "Sapling-stage continuity separates seedling outcomes",
      subtitle = "Primary established-tree cohort; adjusted county mixed model with pointwise Wald 95% intervals",
      x = expression("Established sugar maple basal area (ft"^2 * "/acre; pseudo-log scale)"),
      y = "Predicted probability of no sugar-maple seedlings tallied",
      caption = paste(
        "Established-tree basal area uses live sugar-maple TREE records with DBH ≥ 5 inches; lines differ by sugar-maple sapling presence (1–4.9 inches).",
        "Reference profile: continuous adjusters at their means, no recorded disturbance or treatment, county effect = 0.",
        "Curves span observed support through the 99th percentile. Cross-sectional association, not a transition estimate or causal effect.",
        sep = "\n"
      )
    ) +
    theme_canopy()
  if (!is.null(rug_data)) {
    plot <- plot + ggplot2::geom_rug(
      data = rug_data,
      ggplot2::aes(x = .data$focal_maple_ba_ft2_ac, colour = as.character(.data$maple_sapling_present)),
      inherit.aes = FALSE,
      sides = "b",
      alpha = 0.09,
      linewidth = 0.22
    )
  }
  plot
}

plot_model_effects <- function(primary_curve, primary_data, baseline_curve, baseline_data) {
  primary <- plot_maple_effect_curve(primary_curve, primary_data)
  x_upper <- max(baseline_curve$maple_ba_ft2_ac, na.rm = TRUE)
  x_breaks <- c(0, 1, 5, 10, 25, 50, 100, 150)
  x_breaks <- x_breaks[x_breaks <= x_upper]
  baseline <- ggplot2::ggplot(
    baseline_curve,
    ggplot2::aes(.data$maple_ba_ft2_ac, .data$predicted_probability)
  ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$conf_low, ymax = .data$conf_high),
      fill = "#75827C",
      alpha = 0.14
    ) +
    ggplot2::geom_line(colour = project_palette[["ink"]], linewidth = 0.95, linetype = 2) +
    ggplot2::geom_rug(
      data = baseline_data,
      ggplot2::aes(x = .data$focal_maple_ba_ft2_ac),
      inherit.aes = FALSE,
      sides = "b",
      alpha = 0.06,
      linewidth = 0.2,
      colour = project_palette[["ink"]]
    ) +
    ggplot2::scale_x_continuous(
      trans = scales::pseudo_log_trans(base = 10, sigma = 1),
      breaks = x_breaks,
      labels = scales::label_number(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      labels = scales::label_percent(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.01))
    ) +
    ggplot2::labs(
      title = "Context only: the full-cohort baseline mixes species absence with regeneration continuity",
      subtitle = "All-size sugar-maple basal area, including 1–4.9-inch saplings; nonlinear fixed-effect profile",
      x = expression("All-size sugar maple basal area (ft"^2 * "/acre; pseudo-log scale)"),
      y = "Predicted non-detection probability",
      caption = "This baseline is retained to show why separating FIA size classes changes the scientific interpretation; it is not the primary model."
    ) +
    theme_canopy(base_size = 10.5) +
    ggplot2::theme(legend.position = "none")
  patchwork::wrap_plots(primary, baseline, ncol = 1, heights = c(1.65, 1))
}

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
