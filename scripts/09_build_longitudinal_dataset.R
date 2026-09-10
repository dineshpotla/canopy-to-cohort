source("R/utils.R")
source("R/validation.R")
source("R/fia_schema.R")
source("R/fia_extract.R")
source("R/basal_area.R")
source("R/regeneration.R")
source("R/longitudinal.R")

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
beech_ref <- american_beech_reference(con)
evalid <- evaluation$evalid[[1]]

log_step(paste("Extracting longitudinal microplot condition links for EVALID", evalid))
pairs <- extract_longitudinal_pair_candidates(con, evalid)
assert_unique_key(
  pairs,
  c("baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid"),
  "longitudinal pair candidates"
)
assert_range(pairs$overlap_prop, 0, 1, allow_na = FALSE, label = "linked microplot overlap")

log_step("Extracting tree and seedling records for linked visits")
trees <- extract_longitudinal_trees(con, evalid)
seedlings <- extract_longitudinal_seedlings(con, evalid)
assert_range(trees$dia, 0, Inf, label = "longitudinal tree diameter")
assert_range(trees$tpa_unadj, 0, Inf, label = "longitudinal tree expansion")
assert_range(seedlings$tpa_unadj, 0, Inf, label = "longitudinal seedling expansion")

log_step("Constructing baseline-defined longitudinal cohort")
built <- build_longitudinal_analysis(
  pairs = pairs,
  trees = trees,
  seedlings = seedlings,
  sugar_maple_spcd = maple_ref$spcd[[1]],
  beech_spcd = beech_ref$spcd[[1]],
  forest_codes = forest_types$value,
  minimum_overlap = config$analysis$longitudinal_minimum_overlap
)
candidates <- built$candidates
longitudinal <- built$primary

assert_unique_key(
  longitudinal,
  c("baseline_plt_cn", "baseline_condid"),
  "longitudinal analytical cohort"
)
assert_unique_key(
  longitudinal,
  c("current_plt_cn", "current_condid"),
  "longitudinal analytical cohort"
)
assert_range(longitudinal$baseline_overlap_fraction, 0.90, 1.01, allow_na = FALSE, label = "baseline overlap fraction")
assert_range(longitudinal$followup_overlap_fraction, 0.90, 1.01, allow_na = FALSE, label = "follow-up overlap fraction")
assert_range(longitudinal$baseline_maple_seedling_tpa, 0, Inf, allow_na = FALSE, label = "baseline maple seedling density")
assert_range(longitudinal$followup_maple_seedling_tpa, 0, Inf, allow_na = FALSE, label = "follow-up maple seedling density")
if (!all(longitudinal$interval_years >= 4.5 & longitudinal$interval_years <= 8.5)) {
  stop("Longitudinal intervals fall outside the expected approximately 5- to 8-year range.", call. = FALSE)
}

save_rds_atomic(candidates, project_path("data", "interim", "longitudinal_pair_candidates.rds"))
save_rds_atomic(longitudinal, project_path(config$files$longitudinal_data))
write_csv_atomic(
  longitudinal_cohort_flow(candidates),
  project_path("outputs", "tables", "longitudinal-cohort-flow.csv")
)
write_csv_atomic(
  longitudinal_transition_summary(longitudinal),
  project_path("outputs", "tables", "longitudinal-transition-summary.csv")
)
write_csv_atomic(
  tibble::tibble(
    cohort = c("Primary strict-pair cohort", "Still classified in forest-type group 800 at follow-up"),
    conditions = c(nrow(longitudinal), sum(longitudinal$followup_group_800)),
    fraction = c(1, mean(longitudinal$followup_group_800)),
    role = c(
      "Primary transition cohort; follow-up forest type is not an eligibility condition",
      "Post-baseline classification sensitivity, not a primary eligibility filter"
    )
  ),
  project_path("outputs", "tables", "longitudinal-followup-forest-type-sensitivity.csv")
)
write_csv_atomic(
  longitudinal_mapping_audit(candidates),
  project_path("outputs", "audits", "longitudinal-mapping-audit.csv")
)
write_csv_atomic(
  tibble::tibble(
    metric = c(
      "Analytical condition pairs",
      "Physical plots",
      "Counties",
      "Minimum interval years",
      "Mean interval years",
      "Maximum interval years",
      "Baseline seedling detections",
      "Follow-up seedling detections"
    ),
    value = c(
      nrow(longitudinal),
      dplyr::n_distinct(longitudinal$physical_plot_key),
      dplyr::n_distinct(longitudinal$geoid),
      min(longitudinal$interval_years),
      mean(longitudinal$interval_years),
      max(longitudinal$interval_years),
      sum(longitudinal$baseline_seedling_detected),
      sum(longitudinal$followup_seedling_detected)
    ),
    interpretation = c(
      "Strict bidirectional one-to-one pairs with at least 90% shared microplot footprint",
      "Stable FIA plot identities represented in the condition-pair cohort",
      "County identifiers used for geographically grouped validation",
      "Elapsed time based on measurement year and month",
      "Elapsed time based on measurement year and month",
      "Elapsed time based on measurement year and month",
      "Presence of a positive sugar-maple SEEDLING tally at baseline",
      "Presence of a positive sugar-maple SEEDLING tally at follow-up"
    )
  ),
  project_path("outputs", "audits", "longitudinal-extraction-summary.csv")
)

set.seed(20260906)
hand_check <- longitudinal |>
  dplyr::slice_sample(n = min(20L, nrow(longitudinal))) |>
  dplyr::select(dplyr::all_of(c(
    "baseline_plt_cn", "baseline_condid", "current_plt_cn", "current_condid",
    "county_name", "interval_years", "baseline_overlap_fraction", "followup_overlap_fraction",
    "baseline_established_maple_ba_ft2_ac", "baseline_maple_sapling_present",
    "baseline_beech_ba_ft2_ac", "baseline_maple_seedling_tpa",
    "followup_maple_seedling_tpa", "seedling_transition"
  ))) |>
  dplyr::arrange(.data$baseline_plt_cn, .data$baseline_condid)
write_csv_atomic(
  hand_check,
  project_path("outputs", "audits", "longitudinal-record-hand-check-sample.csv")
)

log_step(paste(
  "Longitudinal cohort complete:",
  nrow(longitudinal),
  "condition pairs and",
  sum(longitudinal$seedling_transition == "Loss"),
  "losses"
))
