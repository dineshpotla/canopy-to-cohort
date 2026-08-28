source("R/utils.R")

targets <- c(
  list.files(project_path("data", "interim"), full.names = TRUE, all.files = FALSE),
  list.files(project_path("data", "processed"), full.names = TRUE, all.files = FALSE),
  list.files(project_path("outputs", "figures"), full.names = TRUE, all.files = FALSE),
  list.files(project_path("outputs", "tables"), full.names = TRUE, all.files = FALSE),
  list.files(project_path("outputs", "models"), full.names = TRUE, all.files = FALSE),
  list.files(project_path("outputs", "audits"), full.names = TRUE, all.files = FALSE)
)
targets <- targets[basename(targets) != ".gitkeep"]
if (length(targets)) unlink(targets, recursive = TRUE, force = TRUE)
log_step(paste("Removed", length(targets), "derived artifacts; raw data preserved."))
