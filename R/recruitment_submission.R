# A second implementation of the declared model, for computational verification.
# Does not call the production scaler, design builder, optimizer, or metrics.
# Uses the already selected rows and folds; not independent scientific validation.
submission_design <- function(training, testing) {
  transform <- function(x) cbind(
    coverage = x$baseline_micrprop_unadj,
    interval = x$interval_years,
    count = log1p(x$baseline_seedling_count),
    saplings = log1p(x$baseline_maple_sapling_tpa),
    established = log1p(x$baseline_established_maple_ba_ft2_ac))
  train <- transform(training)
  test <- transform(testing)
  if (any(!is.finite(train)) || any(!is.finite(test))) stop("Nonfinite audit predictors")
  center <- colMeans(train)
  spread <- apply(train, 2, stats::sd)
  spread[!is.finite(spread) | spread < 1e-12] <- 1
  standardize <- function(x) cbind(intercept = 1,
    sweep(sweep(x, 2, center, "-"), 2, spread, "/"))
  list(training = standardize(train), testing = standardize(test))
}

submission_fit <- function(x, y, lambda = 1) {
  stopifnot(nrow(x) == length(y), all(y %in% 0:1), length(unique(y)) == 2)
  penalty <- c(0, rep(lambda, ncol(x) - 1L))
  objective <- function(beta) {
    eta <- drop(x %*% beta)
    sum(pmax(eta, 0) + log1p(exp(-abs(eta))) - y * eta) + sum(penalty * beta^2) / 2
  }
  gradient <- function(beta) drop(crossprod(x, stats::plogis(x %*% beta) - y)) + penalty * beta
  fit <- stats::optim(c(stats::qlogis(mean(y)), rep(0, ncol(x) - 1L)),
    objective, gradient, method = "BFGS", control = list(maxit = 10000, reltol = 1e-13))
  list(coefficients = fit$par, converged = fit$convergence == 0,
    max_gradient = max(abs(gradient(fit$par))))
}

submission_metrics <- function(y, p, prevalence = FALSE) {
  stopifnot(length(y) == length(p), all(is.finite(p)), all(p >= 0 & p <= 1))
  p <- pmin(1 - 1e-12, pmax(1e-12, p))
  positive <- sum(y)
  negative <- length(y) - positive
  auc <- if (prevalence || !positive || !negative) NA_real_ else
    (sum(rank(p, ties.method = "average")[y == 1]) - positive * (positive + 1) / 2) /
      (positive * negative)
  c(brier_score = mean((y - p)^2), log_loss = -mean(y * log(p) + (1 - y) * log1p(-p)), roc_auc = auc)
}

submission_verify_bundle <- function(bundle, tolerance = 1e-5) {
  specifications <- list("Prevalence" = 1L, "Observation design" = 1:3,
    "Seedling count and design" = 1:4, "Maple stages and design" = 1:6)
  fits <- metrics <- list()
  for (population in names(bundle)) {
    item <- bundle[[population]]
    d <- item$data
    for (assessment in c("County held out", "Temporal")) {
      if (assessment == "County held out") {
        parts <- lapply(sort(unique(item$crossfit$fold)), function(f) {
          list(label = as.character(f), train = which(item$crossfit$fold != f),
            test = which(item$crossfit$fold == f))
        })
        expected <- item$crossfit$predictions
        scoring_rows <- seq_len(nrow(d))
      } else {
        test <- which(d$followup_measyear >= 2023)
        stopifnot(identical(as.integer(test), as.integer(item$temporal$test_rows)))
        parts <- list(list(label = "2023 onward", train = which(d$followup_measyear < 2023), test = test))
        expected <- item$temporal$predictions
        scoring_rows <- test
      }
      prediction <- matrix(NA_real_, nrow(d), 4, dimnames = list(NULL, names(specifications)))
      for (part in parts) {
        train <- d[part$train, , drop = FALSE]
        test <- d[part$test, , drop = FALSE]
        stopifnot(!length(intersect(train$physical_plot_key, test$physical_plot_key)))
        if (assessment == "County held out") stopifnot(!length(intersect(train$geoid, test$geoid)))
        design <- submission_design(train, test)
        for (model in names(specifications)) {
          columns <- specifications[[model]]
          fit <- submission_fit(design$training[, columns, drop = FALSE], train$outcome_recruitment)
          predicted <- drop(stats::plogis(design$testing[, columns, drop = FALSE] %*% fit$coefficients))
          prediction[part$test, model] <- predicted
          delta <- max(abs(predicted - expected[match(part$test, scoring_rows), model]))
          fits[[length(fits) + 1L]] <- data.frame(population, assessment, fold = part$label, model,
            training_n = nrow(train), testing_n = nrow(test), converged = fit$converged,
            max_gradient = fit$max_gradient, max_prediction_difference = delta,
            passed = fit$converged && fit$max_gradient < 1e-3 && delta <= tolerance)
        }
      }
      for (model in names(specifications)) {
        y <- d$outcome_recruitment[scoring_rows]
        actual <- submission_metrics(y, prediction[scoring_rows, model], model == "Prevalence")
        reference <- submission_metrics(y, expected[, model], model == "Prevalence")
        # Recompute metrics from stored probabilities using rank-based AUC.
        stored <- if (assessment == "County held out") item$crossfit$summary else item$temporal$summary
        old <- unlist(stored[stored$model == model, names(reference)], use.names = TRUE)
        nonmissing <- is.finite(reference)
        delta <- max(abs(actual[nonmissing] - reference[nonmissing]))
        stored_delta <- max(abs(reference[nonmissing] - as.numeric(old)[nonmissing]))
        # AUC has discrete jumps if a second optimizer reverses near ties.
        # Probability/loss agreement is checked continuously; rank agreement
        # on the identical stored predictions is checked to tight precision.
        loss_delta <- max(abs(actual[1:2] - reference[1:2]))
        metrics[[length(metrics) + 1L]] <- data.frame(population, assessment, model,
          max_refit_metric_difference = delta, max_refit_loss_difference = loss_delta,
          max_stored_metric_difference = stored_delta,
          passed = loss_delta <= tolerance && stored_delta <= 1e-10)
      }
    }
  }
  fits <- do.call(rbind, fits)
  metrics <- do.call(rbind, metrics)
  list(passed = all(fits$passed) && all(metrics$passed), fits = fits, metrics = metrics,
    probability_tolerance = tolerance,
    scope = "Second computational implementation on existing data and splits; no new predictors, bootstrap intervals, external validation, or independent peer review")
}
