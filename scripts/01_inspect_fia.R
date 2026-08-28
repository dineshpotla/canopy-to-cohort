source("R/utils.R")
source("R/fia_schema.R")

ensure_dirs(project_path("outputs", "audits"), project_path("data", "interim"))
db_path <- find_fia_sqlite()
log_step(paste("Inspecting", db_path))
con <- connect_fia(db_path)
on.exit(disconnect_fia(con), add = TRUE)

schema <- schema_inventory(con)
write_csv_atomic(schema, project_path("outputs", "audits", "fia-schema.csv"))

priority_tables <- c(
  "PLOT", "COND", "TREE", "SEEDLING", "SUBP_COND", "SURVEY",
  "REF_SPECIES", "REF_FOREST_TYPE", "POP_EVAL", "POP_EVAL_TYP",
  "POP_PLOT_STRATUM_ASSGN", "POP_STRATUM"
)
counts <- table_row_counts(con, priority_tables)
write_csv_atomic(counts, project_path("outputs", "audits", "fia-table-counts.csv"))

required_tables <- c("PLOT", "COND", "TREE", "SEEDLING", "REF_SPECIES", "REF_FOREST_TYPE")
missing_tables <- setdiff(required_tables, DBI::dbListTables(con))
if (length(missing_tables)) {
  stop("Required FIA tables are absent: ", paste(missing_tables, collapse = ", "), call. = FALSE)
}

sugar_maple <- find_reference_matches(con, "REF_SPECIES", c("sugar maple", "acer saccharum"))
if (nrow(sugar_maple) != 1L) {
  stop("Expected one sugar-maple reference match; found ", nrow(sugar_maple), call. = FALSE)
}
write_csv_atomic(sugar_maple, project_path("data", "interim", "sugar-maple-reference.csv"))

forest_candidates <- find_reference_matches(
  con,
  "REF_FOREST_TYPE",
  c("northern hardwood", "maple.*beech.*birch", "sugar maple")
)
if (!nrow(forest_candidates)) stop("No northern-hardwood forest-type candidates found.", call. = FALSE)
write_csv_atomic(
  forest_candidates,
  project_path("data", "interim", "northern-hardwood-forest-type-candidates.csv")
)

manual_fields <- intersect(c("CN", "INVYR", "MEASYEAR", "MANUAL", "MANUAL_NATIONAL", "DESIGNCD", "KINDCD"), DBI::dbListFields(con, "PLOT"))
manual_sql <- paste0(
  "SELECT ", paste(DBI::dbQuoteIdentifier(con, manual_fields), collapse = ", "),
  " FROM PLOT WHERE STATECD = 26"
)
manuals <- standardize_names(DBI::dbGetQuery(con, manual_sql))
manual_summary <- manuals |>
  dplyr::count(dplyr::across(-dplyr::any_of(c("cn"))), name = "plot_visits", .drop = FALSE) |>
  dplyr::arrange(dplyr::across(dplyr::everything()))
write_csv_atomic(manual_summary, project_path("outputs", "audits", "plot-protocol-summary.csv"))

log_step("FIA schema audit complete")
