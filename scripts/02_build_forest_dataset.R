source("R/utils.R")
source("R/validation.R")
source("R/fia_schema.R")
source("R/fia_extract.R")
source("R/basal_area.R")

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
evalid <- evaluation$evalid[[1]]
forest_codes <- forest_types$value
maple_spcd <- maple_ref$spcd[[1]]

write_csv_atomic(evaluation, project_path("outputs", "audits", "selected-evaluation.csv"))
write_csv_atomic(forest_types, project_path("data", "interim", "retained-forest-types.csv"))
write_csv_atomic(maple_ref, project_path("data", "interim", "sugar-maple-reference.csv"))

log_step(paste("Extracting conditions for EVALID", evalid))
conditions <- extract_eligible_conditions(con, evalid, forest_codes)
assert_unique_key(conditions, c("plt_cn", "condid"), "eligible conditions")
assert_range(conditions$condprop_unadj, 0, 1, allow_na = FALSE, label = "condition proportion")
assert_range(conditions$micrprop_unadj, 0, 1, allow_na = FALSE, label = "microplot condition proportion")
assert_range(conditions$subpprop_unadj, 0, 1, allow_na = FALSE, label = "subplot condition proportion")
assert_range(conditions$macrprop_unadj, 0, 1, label = "macroplot condition proportion")
save_rds_atomic(conditions, project_path("data", "interim", "eligible_conditions.rds"))

log_step("Extracting and aggregating live trees")
trees <- extract_eligible_trees(con, evalid, forest_codes)
assert_range(trees$dia, 0, Inf, label = "tree diameter")
assert_range(trees$tpa_unadj, 0, Inf, label = "tree expansion")

tree_metrics <- aggregate_tree_metrics(
  trees,
  maple_spcd,
  conditions |>
    dplyr::select(dplyr::all_of(c(
      "plt_cn", "condid", "micrprop_unadj", "subpprop_unadj", "macrprop_unadj"
    )))
)
assert_unique_key(tree_metrics, c("plt_cn", "condid"), "tree metrics")
assert_range(tree_metrics$maple_ba_share, 0, 1, label = "maple basal-area share")
save_rds_atomic(tree_metrics, project_path("data", "interim", "tree_metrics.rds"))

composition <- extract_species_composition(con, evalid, forest_codes)
write_csv_atomic(composition, project_path("data", "processed", "species_composition.csv"))

cohort <- build_cohort_flow(con, evalid, forest_codes, conditions)
write_csv_atomic(cohort, project_path("data", "interim", "cohort-flow-base.csv"))
write_csv_atomic(
  tibble::tibble(
    metric = c("tree rows", "tree conditions", "eligible conditions without live tree rows"),
    value = c(nrow(trees), nrow(tree_metrics), nrow(dplyr::anti_join(conditions, tree_metrics, by = c("plt_cn", "condid"))))
  ),
  project_path("outputs", "audits", "tree-extraction-summary.csv")
)

set.seed(20260826)
tree_checks <- tree_metrics |>
  dplyr::slice_sample(n = min(20L, nrow(tree_metrics))) |>
  dplyr::arrange(.data$plt_cn, .data$condid)
write_csv_atomic(tree_checks, project_path("outputs", "audits", "tree-metric-hand-check-sample.csv"))

log_step(paste("Forest dataset complete:", nrow(conditions), "eligible conditions"))
