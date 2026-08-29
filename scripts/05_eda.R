source("R/utils.R")
source("R/validation.R")
source("R/features.R")
source("R/plotting.R")

config <- read_config()
fia_data <- read_required_rds(project_path("data", "processed", "fia_plot_condition.rds"))
climate <- readr::read_csv(project_path(config$files$county_climate), show_col_types = FALSE)
assembled <- assemble_analysis_data(fia_data, climate, config)
analysis_data <- assembled$data

assert_unique_key(analysis_data, c("plt_cn", "condid"), "analysis data")
assert_range(analysis_data$maple_ba_share, 0, 1, label = "sugar maple basal-area share")
assert_range(analysis_data$established_maple_ba_share, 0, 1, label = "established sugar-maple basal-area share")
assert_range(analysis_data$maple_seedling_tpa, 0, Inf, label = "sugar maple seedling density")
save_rds_atomic(analysis_data, project_path(config$files$analysis_data))
write_csv_atomic(assembled$audit, project_path("outputs", "audits", "climate-join-audit.csv"))
write_csv_atomic(missingness_summary(analysis_data), project_path("outputs", "tables", "analysis-missingness.csv"))

key_summary <- analysis_data |>
  dplyr::summarise(
    plot_conditions = dplyr::n(),
    plot_visits = dplyr::n_distinct(.data$plt_cn),
    counties = dplyr::n_distinct(.data$geoid),
    years_min = min(.data$measyear, na.rm = TRUE),
    years_max = max(.data$measyear, na.rm = TRUE),
    seedling_sampled = sum(.data$seedling_sampled, na.rm = TRUE),
    zero_maple_seedlings = sum(.data$maple_seedling_detected == 0L, na.rm = TRUE),
    maple_seedling_detected = sum(.data$maple_seedling_detected == 1L, na.rm = TRUE),
    potential_gaps = sum(.data$potential_gap, na.rm = TRUE),
    potential_gap_fraction = mean(.data$potential_gap, na.rm = TRUE)
  )
write_csv_atomic(key_summary, project_path("outputs", "tables", "analysis-summary.csv"))

threshold_summary <- analysis_data |>
  dplyr::summarise(
    primary_established_threshold = dplyr::first(.data$established_threshold),
    primary_gap_n = sum(.data$potential_gap, na.rm = TRUE),
    primary_gap_fraction = mean(.data$potential_gap, na.rm = TRUE),
    sensitivity_established_threshold = dplyr::first(.data$sensitivity_threshold),
    sensitivity_gap_n = sum(.data$potential_gap_sensitivity, na.rm = TRUE),
    sensitivity_gap_fraction = mean(.data$potential_gap_sensitivity, na.rm = TRUE)
  )
write_csv_atomic(threshold_summary, project_path("outputs", "tables", "gap-threshold-sensitivity.csv"))

composition <- readr::read_csv(project_path("data", "processed", "species_composition.csv"), show_col_types = FALSE)
composition_plot <- plot_species_composition(composition)
gap_plot <- plot_regeneration_quadrant(analysis_data)
save_figure(composition_plot, "02_species_composition.png", width = 8, height = 5.8)
save_figure(gap_plot, "03_regeneration_quadrant.png", width = 8.5, height = 6.2)

log_step("Exploratory analysis complete")
