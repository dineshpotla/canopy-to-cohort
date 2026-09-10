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

plot_longitudinal_transitions <- function(transition_summary) {
  required <- c(
    "seedling_transition", "conditions", "baseline_state",
    "baseline_state_total", "fraction_within_baseline_state"
  )
  missing <- setdiff(required, names(transition_summary))
  if (length(missing)) {
    stop("Longitudinal transition summary is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  plotted <- transition_summary |>
    dplyr::mutate(
      baseline_state = factor(.data$baseline_state, levels = c("Not detected", "Detected")),
      followup_state = dplyr::if_else(
        .data$seedling_transition %in% c("Appearance", "Persistence"),
        "Detected at follow-up",
        "Not detected at follow-up"
      ),
      followup_state = factor(
        .data$followup_state,
        levels = c("Detected at follow-up", "Not detected at follow-up")
      ),
      count_label = paste0(
        .data$conditions,
        "\n(",
        scales::percent(.data$fraction_within_baseline_state, accuracy = 0.1),
        ")"
      )
    )

  ggplot2::ggplot(
    plotted,
    ggplot2::aes(.data$baseline_state, .data$fraction_within_baseline_state, fill = .data$followup_state)
  ) +
    ggplot2::geom_col(width = 0.68, colour = "white", linewidth = 0.5) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$count_label),
      position = ggplot2::position_stack(vjust = 0.5),
      colour = "white",
      fontface = "bold",
      size = 3.6,
      lineheight = 0.95
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Detected at follow-up" = project_palette[["forest"]],
        "Not detected at follow-up" = project_palette[["maple"]]
      ),
      name = NULL
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 1),
      limits = c(0, 1),
      expand = ggplot2::expansion(mult = c(0, 0.01))
    ) +
    ggplot2::labs(
      title = "Most seedling-detection states persist across FIA visits",
      subtitle = "Yet 75 of 677 initially detected conditions became non-detections at follow-up",
      x = "Sugar-maple seedling state at baseline",
      y = "Share within baseline state",
      caption = paste(
        "932 Michigan northern-hardwood condition pairs; visits separated by approximately 5–8 years.",
        "Pairs require established sugar maple at baseline, accessible-forest sampling at both visits,",
        "a bidirectional one-to-one condition link, and at least 90% shared microplot footprint.",
        "Transitions represent FIA tally detection, not tracked individual seedlings or verified local extinction.",
        sep = "\n"
      )
    ) +
    theme_canopy()
}

plot_longitudinal_loss_effects <- function(odds_ratios) {
  required <- c("label", "odds_ratio", "conf_low", "conf_high")
  missing <- setdiff(required, names(odds_ratios))
  if (length(missing)) {
    stop("Longitudinal odds-ratio table is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  plotted <- odds_ratios |>
    dplyr::mutate(label = stats::reorder(.data$label, .data$odds_ratio))
  ggplot2::ggplot(plotted, ggplot2::aes(.data$odds_ratio, .data$label)) +
    ggplot2::geom_vline(xintercept = 1, linetype = 2, colour = "#7A8580") +
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = .data$conf_low, xmax = .data$conf_high),
      width = 0.16,
      orientation = "y",
      linewidth = 0.8,
      colour = project_palette[["forest"]]
    ) +
    ggplot2::geom_point(size = 2.7, colour = project_palette[["maple"]]) +
    ggplot2::scale_x_log10(
      breaks = c(0.1, 0.25, 0.5, 1, 2, 4, 8),
      labels = scales::label_number(accuracy = 0.01)
    ) +
    ggplot2::labs(
      title = "Early-warning signals of seedling non-detection at the next visit",
      subtitle = "Adjusted odds ratios from the baseline-defined loss model",
      x = "Odds ratio for loss of detected seedlings (log scale)",
      y = NULL,
      caption = paste(
        "Intervals use county-cluster CR1 uncertainty. Continuous effects are per one standard deviation",
        "after the stated transformation; sapling presence compares present with absent.",
        "Associations are prognostic, not causal effects of changing stand structure.",
        sep = "\n"
      )
    ) +
    theme_canopy(base_size = 10.5) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
}

plot_longitudinal_risk_strata <- function(risk_strata) {
  required <- c(
    "risk_quartile", "conditions", "observed_loss_fraction",
    "mean_predicted_probability"
  )
  missing <- setdiff(required, names(risk_strata))
  if (length(missing)) {
    stop("Longitudinal risk-strata table is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  plotted <- risk_strata |>
    dplyr::mutate(
      risk_quartile = factor(.data$risk_quartile, levels = paste("Quartile", 1:4)),
      label = paste0(
        scales::percent(.data$observed_loss_fraction, accuracy = 0.1),
        "\n(n = ", .data$conditions, ")"
      )
    )
  ggplot2::ggplot(plotted, ggplot2::aes(.data$risk_quartile, .data$observed_loss_fraction)) +
    ggplot2::geom_col(fill = project_palette[["forest"]], width = 0.66) +
    ggplot2::geom_point(
      ggplot2::aes(y = .data$mean_predicted_probability),
      colour = project_palette[["maple"]],
      size = 3
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$label),
      vjust = -0.35,
      size = 3.3,
      colour = project_palette[["ink"]]
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 1),
      limits = c(0, max(plotted$observed_loss_fraction) * 1.25),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::labs(
      title = "Geographically held-out predictions separate low- and high-risk conditions",
      subtitle = "Bars are observed losses; burgundy points are mean predicted probabilities",
      x = "Cross-validated predicted-risk quartile",
      y = "Observed fraction losing seedling detection",
      caption = paste(
        "Each county is predicted only by models trained outside that county.",
        "Quartiles summarize internal validation and are not management intervention thresholds.",
        sep = "\n"
      )
    ) +
    theme_canopy() +
    ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
}
