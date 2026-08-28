aggregate_seedling_metrics <- function(seedlings, sugar_maple_spcd, conditions) {
  assert_columns(seedlings, c("plt_cn", "condid", "spcd", "tpa_unadj"), "seedling extract")
  assert_columns(conditions, c("plt_cn", "condid", "micrprop_unadj"), "eligible conditions")

  observed <- seedlings |>
    dplyr::filter(!is.na(.data$tpa_unadj), .data$tpa_unadj >= 0) |>
    dplyr::mutate(is_sugar_maple = .data$spcd == sugar_maple_spcd) |>
    dplyr::group_by(.data$plt_cn, .data$condid) |>
    dplyr::summarise(
      all_seedling_tpa_plot_basis = sum(.data$tpa_unadj, na.rm = TRUE),
      maple_seedling_tpa_plot_basis = sum(.data$tpa_unadj[.data$is_sugar_maple], na.rm = TRUE),
      maple_seedling_records = sum(.data$is_sugar_maple),
      seedling_species_records = dplyr::n(),
      .groups = "drop"
    )

  conditions |>
    dplyr::select(dplyr::all_of(c("plt_cn", "condid", "micrprop_unadj"))) |>
    dplyr::left_join(observed, by = c("plt_cn", "condid")) |>
    dplyr::mutate(
      seedling_sampled = !is.na(.data$micrprop_unadj) & .data$micrprop_unadj > 0,
      all_seedling_tpa_plot_basis = dplyr::if_else(
        .data$seedling_sampled,
        dplyr::coalesce(.data$all_seedling_tpa_plot_basis, 0),
        NA_real_
      ),
      maple_seedling_tpa_plot_basis = dplyr::if_else(
        .data$seedling_sampled,
        dplyr::coalesce(.data$maple_seedling_tpa_plot_basis, 0),
        NA_real_
      ),
      maple_seedling_tpa = dplyr::if_else(
        .data$seedling_sampled,
        .data$maple_seedling_tpa_plot_basis / .data$micrprop_unadj,
        NA_real_
      ),
      all_seedling_tpa = dplyr::if_else(
        .data$seedling_sampled,
        .data$all_seedling_tpa_plot_basis / .data$micrprop_unadj,
        NA_real_
      ),
      maple_seedling_detected = dplyr::case_when(
        !.data$seedling_sampled ~ NA_integer_,
        .data$maple_seedling_tpa_plot_basis > 0 ~ 1L,
        TRUE ~ 0L
      ),
      maple_seedling_share = dplyr::if_else(
        .data$all_seedling_tpa > 0,
        .data$maple_seedling_tpa / .data$all_seedling_tpa,
        NA_real_
      ),
      maple_seedling_records = dplyr::coalesce(.data$maple_seedling_records, 0L),
      seedling_species_records = dplyr::coalesce(.data$seedling_species_records, 0L)
    )
}
