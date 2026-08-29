source("R/utils.R")
source("R/validation.R")
source("R/fia_schema.R")
source("R/fia_extract.R")
source("R/regeneration.R")

config <- read_config()
con <- connect_fia()
on.exit(disconnect_fia(con), add = TRUE)

evaluation <- resolve_current_evaluation(
  con,
  config$project$state_fips,
  config$release$evalid %||% NULL
)
forest_types <- current_northern_hardwood_types(con)
maple_ref <- sugar_maple_reference(con)
conditions <- read_required_rds(project_path("data", "interim", "eligible_conditions.rds"))
tree_metrics <- read_required_rds(project_path("data", "interim", "tree_metrics.rds"))

log_step("Extracting FIA seedling tallies")
seedlings <- extract_eligible_seedlings(con, evaluation$evalid[[1]], forest_types$value)
assert_range(seedlings$tpa_unadj, 0, Inf, label = "seedling expansion")

regen <- aggregate_seedling_metrics(seedlings, maple_ref$spcd[[1]], conditions)
assert_unique_key(regen, c("plt_cn", "condid"), "regeneration metrics")
assert_range(regen$maple_seedling_tpa, 0, Inf, label = "maple seedling density")
assert_range(regen$maple_seedling_share, 0, 1, label = "maple seedling share")

analysis <- conditions |>
  dplyr::left_join(tree_metrics, by = c("plt_cn", "condid")) |>
  dplyr::left_join(
    regen |>
      dplyr::select(-dplyr::all_of("micrprop_unadj")),
    by = c("plt_cn", "condid")
  ) |>
  dplyr::mutate(
    dplyr::across(
      dplyr::any_of(c(
        "total_ba_plot_basis", "maple_ba_plot_basis", "total_ba_ft2_ac",
        "maple_ba_ft2_ac", "nonmaple_ba_ft2_ac", "maple_ba_share", "live_tree_records",
        "maple_sapling_ba_plot_basis", "maple_sapling_ba_ft2_ac", "maple_sapling_records",
        "overstory_total_ba_plot_basis", "established_maple_ba_plot_basis",
        "overstory_total_ba_ft2_ac", "established_maple_ba_ft2_ac",
        "other_live_ba_ft2_ac", "established_maple_ba_share",
        "overstory_tree_records", "established_maple_records"
      )),
      ~ dplyr::coalesce(.x, 0)
    ),
    maple_sapling_present = .data$maple_sapling_records > 0
  )

assert_unique_key(analysis, c("plt_cn", "condid"), "FIA analytical data")
assert_range(analysis$maple_ba_share, 0, 1, label = "maple basal-area share")
assert_range(analysis$established_maple_ba_share, 0, 1, label = "established maple basal-area share")
assert_range(analysis$maple_seedling_tpa, 0, Inf, label = "maple seedling density")
save_rds_atomic(analysis, project_path("data", "processed", "fia_plot_condition.rds"))

tree_audit <- join_audit(conditions, tree_metrics, c(plt_cn = "plt_cn", condid = "condid"), "conditions -> tree metrics", analysis)
regen_audit <- join_audit(conditions, regen, c(plt_cn = "plt_cn", condid = "condid"), "conditions -> regeneration metrics", analysis)
write_csv_atomic(dplyr::bind_rows(tree_audit, regen_audit), project_path("outputs", "audits", "fia-join-audit.csv"))

ba_validation <- analysis |>
  dplyr::filter(!is.na(.data$balive), is.finite(.data$total_ba_ft2_ac)) |>
  dplyr::summarise(
    observations = dplyr::n(),
    pearson_correlation = stats::cor(.data$total_ba_ft2_ac, .data$balive),
    mean_absolute_error_ft2_ac = mean(abs(.data$total_ba_ft2_ac - .data$balive)),
    root_mean_squared_error_ft2_ac = sqrt(mean((.data$total_ba_ft2_ac - .data$balive)^2)),
    median_signed_error_ft2_ac = stats::median(.data$total_ba_ft2_ac - .data$balive),
    max_absolute_error_ft2_ac = max(abs(.data$total_ba_ft2_ac - .data$balive))
  )
if (
  ba_validation$pearson_correlation < 0.9999 ||
    ba_validation$mean_absolute_error_ft2_ac > 0.01 ||
    ba_validation$max_absolute_error_ft2_ac > 0.05
) {
  stop("Computed live-tree basal area does not agree with FIA COND.BALIVE.", call. = FALSE)
}
write_csv_atomic(ba_validation, project_path("outputs", "audits", "basal-area-validation.csv"))

protocol <- conditions |>
  dplyr::select(dplyr::all_of(c("plt_cn", "manual"))) |>
  dplyr::distinct() |>
  dplyr::left_join(seedlings, by = "plt_cn") |>
  dplyr::group_by(.data$manual) |>
  dplyr::summarise(
    plot_visits = dplyr::n_distinct(.data$plt_cn),
    seedling_rows = sum(!is.na(.data$seedling_cn)),
    treecount_missing = sum(is.na(.data$treecount) & !is.na(.data$seedling_cn)),
    treecount_calc_missing = sum(is.na(.data$treecount_calc) & !is.na(.data$seedling_cn)),
    tpa_missing = sum(is.na(.data$tpa_unadj) & !is.na(.data$seedling_cn)),
    treecount_max = suppressWarnings(max(.data$treecount, na.rm = TRUE)),
    .groups = "drop"
  )
write_csv_atomic(protocol, project_path("outputs", "audits", "seedling-protocol-summary.csv"))

cohort <- readr::read_csv(project_path("data", "interim", "cohort-flow-base.csv"), show_col_types = FALSE) |>
  dplyr::bind_rows(
    tibble::tibble(step = "Conditions with modeled seedling detection outcome", observations = sum(!is.na(analysis$maple_seedling_detected)))
  )
write_csv_atomic(cohort, project_path("outputs", "tables", "cohort-flow.csv"))

set.seed(20260826)
check_sample <- analysis |>
  dplyr::filter(.data$seedling_sampled) |>
  dplyr::slice_sample(n = min(20L, sum(analysis$seedling_sampled, na.rm = TRUE))) |>
  dplyr::select(dplyr::all_of(c(
    "plt_cn", "condid", "forest_type", "condprop_unadj", "micrprop_unadj",
    "total_ba_ft2_ac", "maple_ba_ft2_ac", "maple_ba_share",
    "maple_sapling_ba_ft2_ac", "maple_sapling_present",
    "overstory_total_ba_ft2_ac", "established_maple_ba_ft2_ac", "established_maple_ba_share",
    "maple_seedling_tpa", "maple_seedling_detected"
  ))) |>
  dplyr::arrange(.data$plt_cn, .data$condid)
write_csv_atomic(check_sample, project_path("outputs", "audits", "analytical-record-hand-check-sample.csv"))

log_step(paste("Regeneration metrics complete:", sum(analysis$seedling_sampled), "sampled conditions"))
