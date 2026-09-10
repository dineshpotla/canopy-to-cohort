source("R/utils.R")
source("R/regional_sources.R")

sources <- regional_fia_sources()
attempted <- format(Sys.time(), tz = "UTC", usetz = TRUE)
results <- lapply(seq_len(nrow(sources)), function(i) {
  tryCatch(regional_acquire_one(sources[i, , drop = FALSE]), error = function(e)
    data.frame(state = sources$state[i], statecd = sources$statecd[i],
      source_url = sources$source_url[i], retrieved_at_utc = NA_character_,
      status = "acquisition_incomplete", archive_path = NA_character_, database_path = NA_character_,
      archive_member = NA_character_, archive_bytes = NA_real_, database_bytes = NA_real_,
      archive_sha256 = NA_character_, database_sha256 = NA_character_, sqlite_quick_check = NA_character_,
      error_message = conditionMessage(e), stringsAsFactors = FALSE))
})
audit <- dplyr::bind_rows(results)
audit$attempted_at_utc <- attempted
write_csv_atomic(audit, project_path("outputs", "audits", "recruitment-regional-acquisition.csv"))
print(audit[, c("state", "status", "archive_bytes", "error_message")], row.names = FALSE)
if (any(audit$status == "acquisition_incomplete")) {
  stop("Regional acquisition incomplete; no regional feasibility or validation result is available. See the acquisition audit.", call. = FALSE)
}
log_step("Both regional sources pinned; scientific frame/count screening remains a separate, outcome-blinded step")
