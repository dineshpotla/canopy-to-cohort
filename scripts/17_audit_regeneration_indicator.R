source("R/utils.R")

# Availability only: RI records do not by themselves prove a comparable sampled
# height-class opportunity. No absent RI row is interpreted as zero regeneration.
run_regeneration_indicator_inventory <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), find_fia_sqlite(read_config()), flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  pairs <- read_required_rds(project_path("data", "processed", "recruitment_condition_pairs.rds"))
  pairs <- pairs[pairs$recruitment_eligible, ]
  plot <- DBI::dbGetQuery(con, "SELECT PLT_CN, INVYR, STATECD, UNITCD, COUNTYCD, PLOT FROM PLOT_REGEN")
  seedling <- DBI::dbGetQuery(con, "SELECT PLT_CN, CONDID, SPCD, LENGTH_CLASS_CD, SEEDLINGCOUNT FROM SEEDLING_REGEN")
  write <- function(x, name) write_csv_atomic(x, project_path("outputs", "tables", paste0("recruitment-survey-ri-", name, ".csv")))
  has <- function(visit, maple_only = FALSE) {
    x <- seedling
    if (maple_only) x <- x[!is.na(x$SPCD) & x$SPCD == 318, ]
    paste(pairs[[paste0(visit, "_plt_cn")]], pairs[[paste0(visit, "_condid")]]) %in% paste(x$PLT_CN, x$CONDID)
  }
  baseline_plot <- pairs$baseline_plt_cn %in% plot$PLT_CN
  followup_plot <- pairs$current_plt_cn %in% plot$PLT_CN
  groups <- list("All recruitment-eligible pairs" = rep(TRUE, nrow(pairs)),
    "Baseline RI plot record" = baseline_plot,
    "RI plot records at both visits" = baseline_plot & followup_plot,
    "Baseline any-species RI seedling condition record" = has("baseline"),
    "Baseline maple RI seedling condition record" = has("baseline", TRUE))
  coverage <- dplyr::bind_rows(lapply(names(groups), function(name) {
    x <- pairs[groups[[name]], ]
    data.frame(screen = name, conditions = nrow(x), physical_plots = dplyr::n_distinct(x$physical_plot_key),
      counties = dplyr::n_distinct(x$geoid), baseline_standard_seedling_detections = sum(x$baseline_seedling_count > 0),
      conditions_with_recorded_entry = sum(x$outcome_recruitment), new_saplings = sum(x$new_maple_sapling_count),
      interpretation = "Record-presence screen only; RI frame, protocol, measurement timing, and valid zeros not audited")
  }))
  write(coverage, "coverage")
  write(DBI::dbGetQuery(con, "SELECT INVYR AS inventory_year, COUNT(*) AS plot_regen_records, COUNT(DISTINCT PLT_CN) AS plot_visits FROM PLOT_REGEN GROUP BY INVYR ORDER BY INVYR"), "calendar")
  write(DBI::dbGetQuery(con, "SELECT REGEN_SUBP_STATUS_CD, REGEN_MICR_STATUS_CD, COUNT(*) AS subplot_records FROM SUBPLOT_REGEN GROUP BY REGEN_SUBP_STATUS_CD, REGEN_MICR_STATUS_CD"), "sampling-status")
  write(DBI::dbGetQuery(con, "SELECT LENGTH_CLASS_CD, SEEDLING_SOURCE_CD, COUNT(*) AS maple_records, SUM(SEEDLINGCOUNT) AS recorded_maple_count FROM SEEDLING_REGEN WHERE SPCD=318 GROUP BY LENGTH_CLASS_CD, SEEDLING_SOURCE_CD"), "maple-classes")
  print(coverage[, c("screen", "conditions", "physical_plots", "conditions_with_recorded_entry")])
  log_step("RI availability inventory saved; no height-class model or external-validation claim")
}

run_regeneration_indicator_inventory()
