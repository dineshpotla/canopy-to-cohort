source("R/utils.R")
source("R/recruitment_models.R")
source("R/recruitment_paper.R")

read_output <- function(name, folder = "tables") readr::read_csv(
  project_path("outputs", folder, paste0(name, ".csv")), show_col_types = FALSE)
d <- read_required_rds(project_path("data", "processed", "recruitment_condition_pairs.rds"))
m <- read_required_rds(project_path("outputs", "models", "recruitment-analysis.rds"))
f <- read_required_rds(project_path("data", "processed", "recruitment_sapling_fates.rds"))
support <- recruitment_paper_support(d)
audit <- recruitment_paper_audit(d, m,
  read_output("recruitment-model-validation"), read_output("recruitment-model-paired-differences"),
  read_output("recruitment-model-temporal"), read_output("recruitment-model-bootstrap-audit"),
  read_output("recruitment-survey-bootstrap-audit"), f,
  read_output("recruitment-sapling-fates", "audits"), read_output("recruitment-sapling-growth", "audits"))
audit <- dplyr::bind_rows(audit, recruitment_paper_detail_audit(m,
  read_output("recruitment-model-coefficients"), read_output("recruitment-model-fold-diagnostics"),
  read_output("recruitment-model-joint-strata"), read_output("recruitment-model-intervals")))
write_csv_atomic(audit, project_path("outputs", "audits", "recruitment-paper-checks.csv"))
if (!all(audit$passed)) stop("Manuscript reconciliation failed: ",
  paste(audit$check[!audit$passed], collapse = "; "), call. = FALSE)
write_csv_atomic(support, project_path("outputs", "tables", "recruitment-paper-support.csv"))
print(support[, 1:6])
log_step(paste(nrow(audit), "manuscript evidence checks passed. No models fitted."))
