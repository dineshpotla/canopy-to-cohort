source("R/recruitment_submission.R")

input <- "outputs/models/recruitment-analysis.rds"
before <- unname(tools::md5sum(input))
result <- submission_verify_bundle(readRDS(input))
stopifnot(identical(before, unname(tools::md5sum(input))))
result$checked_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
result$r_version <- as.character(getRversion())
result$source_model_md5 <- before
result$source_model_unchanged <- TRUE
jsonlite::write_json(result, "outputs/audits/recruitment-submission-checks.json",
  pretty = TRUE, auto_unbox = TRUE, digits = 16, na = "null")
print(result$fits[, c("population", "assessment", "fold", "model", "max_prediction_difference", "passed")])
if (!result$passed) stop("Second-implementation verification failed; inspect the JSON audit")
cat(nrow(result$fits), "optimizer fits and", nrow(result$metrics), "metric comparisons passed.\n")
