source("R/utils.R")
source("R/plotting.R")

config <- read_config()
analysis_data <- read_required_rds(project_path(config$files$analysis_data))
counties <- read_required_rds(project_path("data", "processed", "michigan_counties.rds"))

normalize_county <- function(x) {
  normalized <- tolower(x)
  normalized <- gsub("[^a-z ]", "", normalized)
  trimws(normalized)
}

county_summary <- analysis_data |>
  dplyr::group_by(.data$geoid, .data$county_name) |>
  dplyr::summarise(
    sample_n = dplyr::n(),
    gap_n = sum(.data$potential_gap, na.rm = TRUE),
    gap_denominator = sum(!is.na(.data$potential_gap)),
    .groups = "drop"
  ) |>
  dplyr::rowwise() |>
  dplyr::mutate(interval = list(wilson_interval(.data$gap_n, .data$gap_denominator))) |>
  tidyr::unnest_wider(interval) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    map_supported = .data$gap_denominator >= config$analysis$minimum_map_n,
    mapped_gap_fraction = ifelse(.data$map_supported, .data$estimate, NA_real_)
  )

write_csv_atomic(county_summary, project_path("outputs", "tables", "county-sample-summary.csv"))
county_attributes <- counties |>
  dplyr::left_join(county_summary, by = c("geoid", "county_name")) |>
  dplyr::mutate(county_key = normalize_county(.data$county_name))
map_data <- ggplot2::map_data("county", region = "michigan") |>
  dplyr::mutate(county_key = normalize_county(.data$subregion)) |>
  dplyr::left_join(county_attributes, by = "county_key")
if (dplyr::n_distinct(map_data$county_key[!is.na(map_data$geoid)]) != 83L) {
  stop("County polygon join did not match all 83 Michigan counties.", call. = FALSE)
}

sample_map <- ggplot2::ggplot(map_data) +
  ggplot2::geom_polygon(
    ggplot2::aes(.data$long, .data$lat, group = .data$group, fill = .data$sample_n),
    colour = "white", linewidth = 0.15
  ) +
  ggplot2::scale_fill_viridis_c(option = "C", trans = "sqrt", na.value = "#E8E8E8") +
  ggplot2::labs(
    title = "Maple/beech/birch observations concentrate in northern Michigan",
    subtitle = "Analyzed FIA plot-condition count by county; square-root color scale",
    fill = "Conditions\n(sqrt scale)",
    caption = paste(
      "Gray = no analyzed conditions.",
      "County aggregation uses FIA county IDs only; no plot coordinates are used or inferred.",
      sep = "\n"
    )
  ) +
  ggplot2::coord_quickmap() +
  theme_canopy() +
  ggplot2::theme(axis.text = ggplot2::element_blank(), axis.title = ggplot2::element_blank(), panel.grid = ggplot2::element_blank())

gap_map <- ggplot2::ggplot(map_data) +
  ggplot2::geom_polygon(
    ggplot2::aes(.data$long, .data$lat, group = .data$group, fill = .data$mapped_gap_fraction),
    colour = "white", linewidth = 0.15
  ) +
  ggplot2::scale_fill_gradientn(
    colours = c("#F1EEE7", "#D7A45B", project_palette[["maple"]]),
    labels = scales::label_percent(accuracy = 1),
    limits = c(0, max(county_summary$mapped_gap_fraction, na.rm = TRUE)),
    na.value = "#D7D9D8"
  ) +
  ggplot2::labs(
    title = "Potential regeneration gaps vary across the analyzed sample",
    subtitle = paste0(
      "Flagged fraction among seedling-sampled conditions; gray = n < ",
      config$analysis$minimum_map_n,
      " or no data"
    ),
    fill = "Flagged\nfraction",
    caption = paste(
      "Exploratory sample summary; not a design-based county estimate.",
      "Gray counties have fewer than 20 seedling-sampled conditions or no data.",
      sep = "\n"
    )
  ) +
  ggplot2::coord_quickmap() +
  theme_canopy() +
  ggplot2::theme(axis.text = ggplot2::element_blank(), axis.title = ggplot2::element_blank(), panel.grid = ggplot2::element_blank())

save_figure(sample_map, "01_study_area_sample_map.png", width = 7, height = 6.8)
save_figure(gap_map, "05_county_gap_map.png", width = 7, height = 6.8)
save_figure(
  plot_county_gap_uncertainty(county_summary, config$analysis$minimum_map_n),
  "06_county_gap_uncertainty.png",
  width = 7.2,
  height = 6.8
)

log_step("Spatial summaries complete")
