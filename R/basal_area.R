tree_basal_area_contribution <- function(diameter_inches, trees_per_acre_unadjusted) {
  0.005454 * diameter_inches^2 * trees_per_acre_unadjusted
}

aggregate_tree_metrics <- function(trees, sugar_maple_spcd, condition_proportions = NULL) {
  assert_columns(trees, c("plt_cn", "condid", "spcd", "dia", "tpa_unadj", "statuscd"), "tree extract")
  live <- trees |>
    dplyr::filter(.data$statuscd == 1L, !is.na(.data$dia), .data$dia >= 0, !is.na(.data$tpa_unadj), .data$tpa_unadj >= 0) |>
    dplyr::mutate(
      ba_plot_basis = tree_basal_area_contribution(.data$dia, .data$tpa_unadj),
      is_sugar_maple = .data$spcd == sugar_maple_spcd
    ) |>
    dplyr::group_by(.data$plt_cn, .data$condid) |>
    dplyr::summarise(
      total_ba_plot_basis = sum(.data$ba_plot_basis, na.rm = TRUE),
      maple_ba_plot_basis = sum(.data$ba_plot_basis[.data$is_sugar_maple], na.rm = TRUE),
      live_tree_records = dplyr::n(),
      .groups = "drop"
    )

  if (!is.null(condition_proportions)) {
    live <- live |>
      dplyr::left_join(condition_proportions, by = c("plt_cn", "condid")) |>
      dplyr::mutate(
        total_ba_ft2_ac = dplyr::if_else(
          !is.na(.data$condprop_unadj) & .data$condprop_unadj > 0,
          .data$total_ba_plot_basis / .data$condprop_unadj,
          NA_real_
        ),
        maple_ba_ft2_ac = dplyr::if_else(
          !is.na(.data$condprop_unadj) & .data$condprop_unadj > 0,
          .data$maple_ba_plot_basis / .data$condprop_unadj,
          NA_real_
        )
      )
  } else {
    live <- live |>
      dplyr::mutate(
        total_ba_ft2_ac = .data$total_ba_plot_basis,
        maple_ba_ft2_ac = .data$maple_ba_plot_basis
      )
  }

  live |>
    dplyr::mutate(
      nonmaple_ba_ft2_ac = pmax(0, .data$total_ba_ft2_ac - .data$maple_ba_ft2_ac),
      maple_ba_share = dplyr::if_else(
        .data$total_ba_plot_basis > 0,
        .data$maple_ba_plot_basis / .data$total_ba_plot_basis,
        0
      )
    )
}
