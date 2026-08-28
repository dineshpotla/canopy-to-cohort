tree_basal_area_contribution <- function(diameter_inches, trees_per_acre_unadjusted) {
  0.005454 * diameter_inches^2 * trees_per_acre_unadjusted
}

tree_sampling_basis <- function(diameter_inches, macro_breakpoint_dia = NA_real_) {
  has_macro_breakpoint <- !is.na(macro_breakpoint_dia)
  dplyr::case_when(
    has_macro_breakpoint & diameter_inches >= macro_breakpoint_dia ~ "macroplot",
    diameter_inches < 5 ~ "microplot",
    TRUE ~ "subplot"
  )
}

tree_condition_proportion <- function(
    sampling_basis,
    micrprop_unadj,
    subpprop_unadj,
    macrprop_unadj = NA_real_) {
  dplyr::case_when(
    sampling_basis == "microplot" ~ micrprop_unadj,
    sampling_basis == "subplot" ~ subpprop_unadj,
    sampling_basis == "macroplot" ~ macrprop_unadj,
    TRUE ~ NA_real_
  )
}

aggregate_tree_metrics <- function(trees, sugar_maple_spcd, condition_proportions = NULL) {
  assert_columns(trees, c("plt_cn", "condid", "spcd", "dia", "tpa_unadj", "statuscd"), "tree extract")
  live <- trees |>
    dplyr::filter(
      .data$statuscd == 1L,
      !is.na(.data$dia),
      .data$dia >= 0,
      !is.na(.data$tpa_unadj),
      .data$tpa_unadj >= 0
    ) |>
    dplyr::mutate(
      ba_plot_basis = tree_basal_area_contribution(.data$dia, .data$tpa_unadj),
      is_sugar_maple = .data$spcd == sugar_maple_spcd
    )

  if (!is.null(condition_proportions)) {
    assert_columns(
      condition_proportions,
      c("plt_cn", "condid", "micrprop_unadj", "subpprop_unadj"),
      "tree condition proportions"
    )
    if (!"macrprop_unadj" %in% names(condition_proportions)) {
      condition_proportions$macrprop_unadj <- NA_real_
    }
    if (!"macro_breakpoint_dia" %in% names(live)) {
      live$macro_breakpoint_dia <- NA_real_
    }
    live <- live |>
      dplyr::left_join(
        condition_proportions |>
          dplyr::select(dplyr::all_of(c(
            "plt_cn", "condid", "micrprop_unadj", "subpprop_unadj", "macrprop_unadj"
          ))),
        by = c("plt_cn", "condid")
      ) |>
      dplyr::mutate(
        sampling_basis = tree_sampling_basis(.data$dia, .data$macro_breakpoint_dia),
        tree_condprop_unadj = tree_condition_proportion(
          .data$sampling_basis,
          .data$micrprop_unadj,
          .data$subpprop_unadj,
          .data$macrprop_unadj
        ),
        ba_ft2_ac_contribution = dplyr::if_else(
          !is.na(.data$tree_condprop_unadj) & .data$tree_condprop_unadj > 0,
          .data$ba_plot_basis / .data$tree_condprop_unadj,
          NA_real_
        )
      )

    invalid_normalization <- live |>
      dplyr::filter(is.na(.data$ba_ft2_ac_contribution))
    if (nrow(invalid_normalization)) {
      invalid_bases <- paste(sort(unique(invalid_normalization$sampling_basis)), collapse = ", ")
      stop(
        "Cannot normalize ", nrow(invalid_normalization),
        " live-tree records because their FIA condition proportion is missing or nonpositive (",
        invalid_bases, ").",
        call. = FALSE
      )
    }
  } else {
    live <- live |>
      dplyr::mutate(
        sampling_basis = tree_sampling_basis(.data$dia),
        ba_ft2_ac_contribution = .data$ba_plot_basis
      )
  }

  live |>
    dplyr::group_by(.data$plt_cn, .data$condid) |>
    dplyr::summarise(
      total_ba_plot_basis = sum(.data$ba_plot_basis, na.rm = TRUE),
      maple_ba_plot_basis = sum(.data$ba_plot_basis[.data$is_sugar_maple], na.rm = TRUE),
      total_ba_ft2_ac = sum(.data$ba_ft2_ac_contribution, na.rm = TRUE),
      maple_ba_ft2_ac = sum(.data$ba_ft2_ac_contribution[.data$is_sugar_maple], na.rm = TRUE),
      live_tree_records = dplyr::n(),
      microplot_tree_records = sum(.data$sampling_basis == "microplot"),
      subplot_tree_records = sum(.data$sampling_basis == "subplot"),
      macroplot_tree_records = sum(.data$sampling_basis == "macroplot"),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      nonmaple_ba_ft2_ac = pmax(0, .data$total_ba_ft2_ac - .data$maple_ba_ft2_ac),
      maple_ba_share = dplyr::if_else(
        .data$total_ba_ft2_ac > 0,
        .data$maple_ba_ft2_ac / .data$total_ba_ft2_ac,
        0
      )
    )
}
