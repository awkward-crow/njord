#' Folds of consecutive storm seasons
#'
#' Splits the storm seasons of a catalogue into blocks of `block`
#' consecutive seasons, for [holdout_calibration()]. A season runs from July
#' to June and is named by the year it starts in. The catalogue covers the
#' calendar years `first_year` to `last_year`, so its first season (starting
#' in July of `first_year - 1`) and its last (starting in July of
#' `last_year`) lie only half inside it and count as half a year each; every
#' other season counts as a year, and the seasons' years add up to the
#' catalogue's length. The last block takes the seasons left over, so it
#' holds between `block` and `2 * block - 1` seasons (fewer only if there are
#' fewer than `block` seasons in all, when there is one block).
#'
#' @param first_year,last_year First and last calendar years of the catalogue.
#' @param block Number of consecutive seasons in a fold.
#' @return A data frame with one row per season: `season` (the year it
#'   starts in), `years` (the part of a year it adds to the catalogue, 0.5 or
#'   1) and `fold` (1, 2, ...).
#' @export
season_folds <- function(first_year, last_year, block = 5) {
  season <- (first_year - 1):last_year
  in_period <- function(y) as.numeric(y >= first_year & y <= last_year)
  n_folds <- max(1, length(season) %/% block)
  data.frame(season = season,
             years = 0.5 * in_period(season) + 0.5 * in_period(season + 1),
             fold = pmin((seq_along(season) - 1) %/% block + 1, n_folds))
}

# The season (July to June) of each time, named by the year it starts in.
storm_season <- function(time) {
  lt <- as.POSIXlt(as.POSIXct(time, tz = "UTC"))
  lt$year + 1900L - (lt$mon < 6)
}

#' Hold-out scoring of a calibration method
#'
#' Calibrates a trigger on all but one fold of storm seasons and scores it on
#' the storms of the fold left out, for each fold in turn. Each storm falls
#' in the season of its central time and so in one fold of `scheme`. For each
#' fold, the training storms are those of the other folds and the training
#' years the catalogue's years less the fold's, so the training storms a year
#' are their number over the training years. The layer is set from the
#' training losses as in [fitted_ramp_calibration()]: the retention is the
#' loss with return period `attach_rp` and the limit the loss with return
#' period `exhaust_rp` less the retention. `method` is then called on the
#' training storms with those storms a year, and the held-out storms are
#' scored with the training attachment, exhaustion, retention and limit: the
#' payout is that of [payout()] and the recovery is the loss above the
#' retention, between 0 and the limit, as in [basis_risk()].
#'
#' A fold fails if `method` stops or warns, if it returns an attachment or
#' exhaustion that is not finite, or if the attachment is not below the
#' exhaustion ([min_index_calibration()] returns `Inf` with a warning when no
#' storm is above a loss level, and equal levels when one storm sets both).
#' If `method` stops or warns, the reason is its message, prefixed `"error:"`
#' or `"warning:"`.
#' The fold's storms are still returned, with the reason in `failure` and
#' the attachment, exhaustion and payout `NA`; the layer does not depend on
#' the method, so the retention, limit and recovery are kept.
#'
#' @param events A data frame with one row per storm and columns `event`
#'   (its name), `central_time` (POSIXct, or text that `as.POSIXct()` reads,
#'   in UTC), `index` and `loss` (a fraction of the total insured value).
#' @param region A label for the region, copied to the result.
#' @param method A calibration function, such as [min_index_calibration()],
#'   [frequency_matching_calibration()] or [fitted_ramp_calibration()].
#' @param ... Further arguments to `method`, such as `loss = "squared"`.
#' @param scheme The folds, as from [season_folds()]. Every storm's season
#'   must be in it.
#' @inheritParams min_index_calibration
#' @param fold_apply A function like [lapply()], used to run the folds: for
#'   example `function(x, f) parallel::mclapply(x, f, mc.cores = 4)` to run
#'   them in parallel.
#' @return A data frame with one row per storm: `region`, `fold`, `season`,
#'   `event`, `index`, `loss`, then the fold's `training_years`,
#'   `events_per_year`, `retention`, `limit`, `training_mean_recovery` (the
#'   mean recovery of the training storms), `attachment` and `exhaustion`,
#'   then the storm's `payout` and `recovery`. Last comes `failure`: `NA`,
#'   or the reason the fold failed.
#' @export
holdout_calibration <- function(events, region, method, ..., scheme,
                                attach_rp = 5, exhaust_rp = 20,
                                fold_apply = lapply) {
  season <- storm_season(events$central_time)
  fold <- scheme$fold[match(season, scheme$season)]
  if (anyNA(fold))
    stop(sum(is.na(fold)), " storms fall in no season of the scheme.")
  total_years <- sum(scheme$years)
  one_fold <- function(f) {
    train <- fold != f
    held <- !train
    training_years <- total_years - sum(scheme$years[scheme$fold == f])
    events_per_year <- sum(train) / training_years
    index_vec <- stats::setNames(events$index[train], events$event[train])
    loss_vec <- stats::setNames(events$loss[train], events$event[train])
    retention <- loss_level(loss_vec, attach_rp, events_per_year)
    limit <- loss_level(loss_vec, exhaust_rp, events_per_year) - retention
    fit <- tryCatch(method(index_vec, loss_vec, attach_rp = attach_rp,
                           exhaust_rp = exhaust_rp,
                           events_per_year = events_per_year, ...),
                    error = function(e) paste("error:", conditionMessage(e)),
                    warning = function(w)
                      paste("warning:", conditionMessage(w)))
    failure <- if (is.character(fit)) fit
      else if (!all(is.finite(c(fit$attachment, fit$exhaustion))))
        "The attachment or exhaustion is not finite."
      else if (fit$attachment >= fit$exhaustion)
        "The attachment is not below the exhaustion."
      else NA_character_
    attachment <- if (is.na(failure)) fit$attachment else NA_real_
    exhaustion <- if (is.na(failure)) fit$exhaustion else NA_real_
    data.frame(region = rep(region, sum(held)), fold = f,
               season = season[held], event = events$event[held],
               index = events$index[held], loss = events$loss[held],
               training_years = training_years,
               events_per_year = events_per_year, retention = retention,
               limit = limit,
               training_mean_recovery =
                 mean(pmin(pmax(loss_vec - retention, 0), limit)),
               attachment = attachment,
               exhaustion = exhaustion,
               payout = payout(events$index[held], attachment, exhaustion,
                               limit),
               recovery = pmin(pmax(events$loss[held] - retention, 0), limit),
               failure = failure)
  }
  do.call(rbind, fold_apply(sort(unique(scheme$fold)), one_fold))
}

#' Add the hold-out results of several regional covers
#'
#' Treats covers on several regions as one cover whose payout and recovery
#' are the regional ones added storm by storm, rule by rule. A failed
#' fold's payout counts as nothing, so the other regions' payouts stand. A
#' storm's failure lists those of its regions, each prefixed with the region.
#'
#' @param results Hold-out results of [holdout_calibration()] for the
#'   regions, bound together with a `rule` column naming the rule. Every
#'   storm must appear once for each region under each rule.
#' @param region The label of the combined cover.
#' @return A data frame with one row per rule and storm: `region`, `rule`,
#'   `fold`, `season`, `event`, `payout`, `recovery`,
#'   `training_mean_recovery` (each the sum over the regions) and `failure`.
#' @export
combine_holdout <- function(results, region = "combined") {
  failed <- !is.na(results$failure)
  key <- paste(results$rule, results$event, sep = "\r")
  counts <- table(key)
  if (any(counts != length(unique(results$region))))
    stop(sum(counts != length(unique(results$region))),
         " storms are not in every region under their rule.")
  sums <- rowsum(cbind(payout = ifelse(failed, 0, results$payout),
                       recovery = results$recovery,
                       training_mean_recovery =
                         results$training_mean_recovery), key)
  reasons <- ifelse(failed, paste0(results$region, ": ", results$failure),
                    NA_character_)
  failure <- tapply(reasons, key, function(x)
    if (all(is.na(x))) NA_character_ else paste(stats::na.omit(x),
                                                collapse = "; "))
  first <- results[match(rownames(sums), key), ]
  data.frame(region = region, rule = first$rule, fold = first$fold,
             season = first$season, event = first$event,
             payout = sums[, "payout"], recovery = sums[, "recovery"],
             training_mean_recovery = sums[, "training_mean_recovery"],
             failure = unname(failure[rownames(sums)]), row.names = NULL)
}

#' Summarise pooled hold-out results
#'
#' Pools the held-out storms of every fold and gives, for each region and
#' rule, how well the payouts match the recoveries. A storm in a fold whose
#' rule failed counts as paid nothing (no cover); the number of such folds
#' and storms is given too.
#'
#' The statistics are: `events`, the held-out storms; `recovering`, those
#' with a recovery; `paid`, those with a payout; `false_payments`, those
#' paid with no recovery; `misses`, those with a recovery paid nothing;
#' `rms_basis_risk`, the root mean square of payout less recovery;
#' `paid_to_recovery`, total payout over total recovery; `correlation`, of
#' payout with recovery; `annual_payout` and `annual_recovery`, the totals
#' over the catalogue's years; `rms_to_baseline`, the RMS basis risk over
#' that of a cover with no index, which pays every held-out storm its
#' fold's training mean recovery; `failed_folds` and `failed_events`.
#'
#' The same RMS statistics are also given over the fitted folds only,
#' leaving out the storms of failed folds: `fitted_folds`,
#' `fitted_events`, `rms_basis_risk_fitted` and `rms_to_baseline_fitted`.
#' A combined cover's storm is left out if any of its regions failed.
#'
#' The interval of each statistic comes from a bootstrap over seasons: the
#' seasons of `scheme` are drawn with replacement `n_boot` times, every
#' held-out storm of a drawn season counts once for each draw, and the
#' years are those of the drawn seasons. The same draws serve every region
#' and rule. The rules are not refitted, so the interval reflects only the
#' sampling of the storms they are scored on, not the uncertainty in the
#' fitted attachment and exhaustion. The random number state is restored
#' afterwards. The counts of failed and fitted folds and of failed storms
#' have no interval.
#'
#' @param results Hold-out results, as from [holdout_calibration()] or
#'   [combine_holdout()], bound together with a `rule` column naming the
#'   rule. Payouts may be missing only in failed folds.
#' @param scheme The folds the results were made with, as from
#'   [season_folds()].
#' @param n_boot Number of bootstrap resamples.
#' @param level Coverage of the intervals.
#' @param seed Seed for the bootstrap draws.
#' @return A data frame with one row per region, rule and statistic:
#'   `region`, `rule`, `statistic`, `estimate`, `lower` and `upper`.
#' @export
holdout_summary <- function(results, scheme, n_boot = 5000, level = 0.9,
                            seed = 1) {
  failed <- !is.na(results$failure)
  results$payout[failed & is.na(results$payout)] <- 0
  if (anyNA(results$payout))
    stop(sum(is.na(results$payout)), " payouts are missing outside the ",
         "failed folds.")
  n_seasons <- nrow(scheme)
  draws <- with_seed(seed, t(replicate(n_boot, tabulate(
    sample.int(n_seasons, n_seasons, replace = TRUE), n_seasons))))
  probs <- c((1 - level) / 2, 1 - (1 - level) / 2)
  groups <- split(results, list(results$region, results$rule), drop = TRUE)
  do.call(rbind, lapply(unname(groups), function(g) {
    by_season <- season_sums(g, scheme)
    estimate <- summary_statistics(t(colSums(by_season)))
    boot <- summary_statistics(draws %*% by_season)
    g_failed <- !is.na(g$failure)
    data.frame(region = g$region[1], rule = g$rule[1],
               statistic = c(colnames(estimate), "failed_folds",
                             "failed_events", "fitted_folds"),
               estimate = c(estimate[1, ],
                            length(unique(g$fold[g_failed])),
                            sum(g_failed),
                            length(unique(g$fold[!g_failed]))),
               lower = c(apply(boot, 2, stats::quantile, probs[1],
                               na.rm = TRUE), NA, NA, NA),
               upper = c(apply(boot, 2, stats::quantile, probs[2],
                               na.rm = TRUE), NA, NA, NA),
               row.names = NULL)
  }))
}

# Per season of `scheme`, the sums the summary statistics are made from.
season_sums <- function(g, scheme) {
  p <- g$payout
  r <- g$recovery
  b <- g$training_mean_recovery
  fitted <- is.na(g$failure)
  parts <- cbind(events = 1, recovering = r > 0, paid = p > 0,
                 false_payments = p > 0 & r == 0,
                 misses = r > 0 & p == 0, p = p, r = r, pp = p^2, rr = r^2,
                 pr = p * r, dd = (p - r)^2, bb = (b - r)^2,
                 fitted_events = fitted, dd_fitted = fitted * (p - r)^2,
                 bb_fitted = fitted * (b - r)^2)
  season <- factor(g$season, scheme$season)
  cbind(apply(parts, 2, function(x) tapply(x, season, sum, default = 0)),
        years = scheme$years)
}

# The summary statistics from rows of season sums.
summary_statistics <- function(s) {
  n <- s[, "events"]
  cbind(s[, c("events", "recovering", "paid", "false_payments", "misses"),
          drop = FALSE],
        rms_basis_risk = sqrt(s[, "dd"] / n),
        paid_to_recovery = s[, "p"] / s[, "r"],
        correlation = (n * s[, "pr"] - s[, "p"] * s[, "r"]) /
          sqrt((n * s[, "pp"] - s[, "p"]^2) * (n * s[, "rr"] - s[, "r"]^2)),
        annual_payout = s[, "p"] / s[, "years"],
        annual_recovery = s[, "r"] / s[, "years"],
        rms_to_baseline = sqrt(s[, "dd"] / s[, "bb"]),
        s[, "fitted_events", drop = FALSE],
        rms_basis_risk_fitted = sqrt(s[, "dd_fitted"] / s[, "fitted_events"]),
        rms_to_baseline_fitted = sqrt(s[, "dd_fitted"] / s[, "bb_fitted"]))
}

# Evaluates `expr` after set.seed(seed), then restores the random number
# state.
with_seed <- function(seed, expr) {
  env <- globalenv()
  old <- if (exists(".Random.seed", env, inherits = FALSE))
    get(".Random.seed", env)
  on.exit(if (is.null(old)) rm(".Random.seed", envir = env)
          else assign(".Random.seed", old, envir = env))
  set.seed(seed)
  expr
}

#' The failed folds of hold-out results
#'
#' One row for each region, rule and fold whose rule could not be fitted,
#' to explain the failures that [holdout_summary()] counts.
#'
#' @inheritParams holdout_summary
#' @return A data frame with one row per failed fold: `region`, `rule`,
#'   `fold`, `first_season` and `last_season` (the fold's seasons in
#'   `scheme`, named by the year they start in), `events` (its held-out
#'   storms) and `failure` (its distinct reasons, separated by `"; "`).
#'   No rows if no fold failed.
#' @export
holdout_failures <- function(results, scheme) {
  failed <- results[!is.na(results$failure), ]
  key <- paste(failed$region, failed$rule, failed$fold, sep = "\r")
  rows <- lapply(unname(split(failed, key)), function(g) {
    seasons <- scheme$season[scheme$fold == g$fold[1]]
    data.frame(region = g$region[1], rule = g$rule[1], fold = g$fold[1],
               first_season = min(seasons), last_season = max(seasons),
               events = nrow(g),
               failure = paste(unique(g$failure), collapse = "; "))
  })
  out <- do.call(rbind, c(list(data.frame(
    region = character(), rule = character(), fold = numeric(),
    first_season = numeric(), last_season = numeric(), events = integer(),
    failure = character())), rows))
  out <- out[order(out$region, out$rule, out$fold), , drop = FALSE]
  rownames(out) <- NULL
  out
}
