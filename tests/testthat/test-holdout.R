test_that("season folds count the half seasons at the ends as half a year", {
  # 2000-2019: seasons 1999 to 2019, 21 in all, so four blocks of five and
  # one season left over, which joins the last block.
  scheme <- season_folds(2000, 2019, block = 5)
  expect_equal(scheme$season, 1999:2019)
  expect_equal(scheme$years, c(0.5, rep(1, 19), 0.5))
  expect_equal(sum(scheme$years), 20)
  expect_equal(as.vector(table(scheme$fold)), c(5, 5, 5, 6))
  expect_equal(season_folds(2000, 2001, block = 5)$fold, c(1, 1, 1))
})

test_that("the catalogue's folds are 17, the last of seven seasons", {
  scheme <- season_folds(1940, 2025, block = 5)
  expect_equal(nrow(scheme), 87)
  expect_equal(range(scheme$season), c(1939, 2025))
  expect_equal(max(scheme$fold), 17)
  expect_equal(sum(scheme$fold == 17), 7)
  expect_equal(scheme$years[scheme$season %in% c(1939, 2025)], c(0.5, 0.5))
  expect_true(all(scheme$years[!scheme$season %in% c(1939, 2025)] == 1))
  expect_equal(sum(scheme$years), 86)
})

test_that("a storm's season starts in July", {
  expect_equal(storm_season(c("2000-06-30 23:00", "2000-07-01 00:00",
                              "2001-01-15 12:00")),
               c(1999, 2000, 2000))
})

# Eight storms over 2000-2019 in blocks of ten seasons: fold 1 is seasons
# 1999-2008 (9.5 years), fold 2 seasons 2009-2019 (10.5 years, the season
# left over joining it).
toy_events <- data.frame(
  event = letters[1:8],
  central_time = c("2000-01-15 00:00", "2002-12-01 00:00",
                   "2005-02-01 00:00", "2008-11-01 00:00",
                   "2010-01-15 00:00", "2012-12-01 00:00",
                   "2015-02-01 00:00", "2019-11-01 00:00"),
  index = c(10, 20, 30, 40, 15, 25, 35, 45),
  loss = c(0, 0, 2, 6, 0, 1, 3, 8))
toy_scheme <- season_folds(2000, 2019, block = 10)

test_that("the hold-out matches a hand computation over two folds", {
  # Fold 1 held out: training e-h, 4 storms in 10.5 years. The 1-in-5 loss
  # is the 1 - 10.5 / 20 = 0.475 quantile of 0, 1, 3, 8: position 2.425,
  # so 1 + 0.425 * 2 = 1.85. The 1-in-20 loss is the 1 - 10.5 / 80 =
  # 0.86875 quantile: position 3.60625, 3 + 0.60625 * 5 = 6.03125, so the
  # limit is 4.18125. The minimum index above 1.85 is 35 (g) and above
  # 6.03125 is 45 (h). Held out: d pays (40 - 35) / 10 of the limit and
  # recovers 6 - 1.85; c pays nothing and recovers 0.15.
  # Fold 2 held out: training a-d, 4 storms in 9.5 years. The 1-in-5 loss
  # is the 0.525 quantile of 0, 0, 2, 6: position 2.575, 0.575 * 2 = 1.15.
  # The 1-in-20 loss is the 0.88125 quantile: position 3.64375,
  # 2 + 0.64375 * 4 = 4.575, so the limit is 3.425. The levels are 30 (c)
  # and 40 (d). Held out: g pays half the limit and recovers 3 - 1.15; h
  # pays the limit and recovers it.
  out <- holdout_calibration(toy_events, "toy", min_index_calibration,
                             scheme = toy_scheme)
  expect_equal(out$event, letters[1:8])
  expect_equal(out$fold, rep(1:2, each = 4))
  expect_equal(out$region, rep("toy", 8))
  expect_equal(out$training_years, rep(c(10.5, 9.5), each = 4))
  expect_equal(out$retention, rep(c(1.85, 1.15), each = 4))
  expect_equal(out$limit, rep(c(4.18125, 3.425), each = 4))
  expect_equal(out$attachment, rep(c(35, 30), each = 4))
  expect_equal(out$exhaustion, rep(c(45, 40), each = 4))
  expect_equal(out$payout, c(0, 0, 0, 0.5 * 4.18125, 0, 0, 0.5 * 3.425,
                             3.425))
  expect_equal(out$recovery, c(0, 0, 0.15, 4.15, 0, 0, 1.85, 3.425))
  expect_true(all(is.na(out$failure)))
})

test_that("a fold that fails keeps its storms and its layer", {
  # With f, g and h tied at 45, frequency matching on training e-h (k = 2,
  # m = 1) puts the attachment, the 3rd largest index, at the exhaustion,
  # the largest, so fold 1 fails; fold 2's training storms are untied.
  tied <- toy_events
  tied$index[6:8] <- 45
  out <- holdout_calibration(tied, "toy", frequency_matching_calibration,
                             scheme = toy_scheme)
  f1 <- out$fold == 1
  expect_equal(nrow(out), 8)
  expect_match(unique(out$failure[f1]), "^error: Tied indices")
  expect_true(all(is.na(out$attachment[f1]) & is.na(out$exhaustion[f1]) &
                    is.na(out$payout[f1])))
  expect_equal(out$retention[f1], rep(1.85, 4))
  expect_equal(out$recovery[f1], c(0, 0, 0.15, 4.15))
  expect_true(all(is.na(out$failure[!f1])))
  expect_false(anyNA(out$payout[!f1]))
})

test_that("a method's warning or equal levels fail the fold", {
  # One storm above both loss levels: the minimum index sets both at its
  # index.
  one_big <- toy_events
  one_big$loss <- c(0, 0, 0, 6, 0, 0, 0, 8)
  out <- holdout_calibration(one_big, "toy", min_index_calibration,
                             scheme = toy_scheme)
  expect_equal(unique(out$failure),
               "The attachment is not below the exhaustion.")
})

test_that("a method's own message is the failure, prefixed", {
  warns <- function(...) { warning("no storm, here"); list() }
  out <- holdout_calibration(toy_events, "toy", warns, scheme = toy_scheme)
  expect_equal(unique(out$failure), "warning: no storm, here")
  stops <- function(...) stop("bad fit: 3 of 4")
  out <- holdout_calibration(toy_events, "toy", stops, scheme = toy_scheme)
  expect_equal(unique(out$failure), "error: bad fit: 3 of 4")
  # The minimum index with no storm above a level: min() warns, verbatim.
  no_loss <- toy_events
  no_loss$loss <- 0
  out <- holdout_calibration(no_loss, "toy", min_index_calibration,
                             scheme = toy_scheme)
  expect_match(unique(out$failure), "^warning: no non-missing arguments to min")
})

set.seed(5)
many <- data.frame(event = paste0("s", 1:300),
                   central_time = as.POSIXct("1980-01-01", tz = "UTC") +
                     runif(300, 0, 40 * 365.25 * 86400),
                   index = runif(300, 15, 45))
many$loss <- pmax(0, many$index - 30)^2 * runif(300, 0.5, 1.5)
many_scheme <- season_folds(1980, 2019)

test_that("a fold's training storms never include a held-out storm", {
  seen <- list()
  spy <- function(index_vec, loss_vec, ...) {
    seen[[length(seen) + 1]] <<- names(index_vec)
    min_index_calibration(index_vec, loss_vec, ...)
  }
  out <- holdout_calibration(many, "many", spy, scheme = many_scheme)
  folds <- sort(unique(many_scheme$fold))
  expect_length(seen, length(folds))
  for (f in folds) {
    held <- out$event[out$fold == f]
    expect_length(intersect(seen[[f]], held), 0)
    expect_setequal(c(seen[[f]], held), many$event)
  }
})

test_that("training and held-out years add up to the catalogue", {
  out <- holdout_calibration(many, "many", min_index_calibration,
                             scheme = many_scheme)
  held_years <- tapply(many_scheme$years, many_scheme$fold, sum)
  training_years <- tapply(out$training_years, out$fold, unique)
  expect_equal(as.vector(training_years + held_years[names(training_years)]),
               rep(40, length(training_years)))
  expect_equal(sort(out$event), sort(many$event))
})

test_that("storms outside the scheme's seasons stop the hold-out", {
  expect_error(holdout_calibration(toy_events, "toy", min_index_calibration,
                                   scheme = season_folds(2001, 2019)),
               "1 storms fall in no season")
})

test_that("storms with index 0 are paid nothing, under every rule", {
  zeros <- toy_events
  zeros$index[c(1, 2, 5, 6)] <- 0
  rules <- list(min_index_calibration, frequency_matching_calibration,
                fitted_ramp_calibration)
  for (method in rules) {
    out <- holdout_calibration(zeros, "toy", method, scheme = toy_scheme)
    expect_true(all(is.na(out$failure)))
    expect_equal(out$payout[out$index == 0], rep(0, 4))
  }
})

test_that("the hold-out gives each fold's training mean recovery", {
  # Fold 1's training recoveries are 0, 0, 3 - 1.85 and the limit 4.18125;
  # fold 2's 0, 0, 2 - 1.15 and 3.425.
  out <- holdout_calibration(toy_events, "toy", min_index_calibration,
                             scheme = toy_scheme)
  expect_equal(out$training_mean_recovery,
               rep(c((1.15 + 4.18125) / 4, (0.85 + 3.425) / 4), each = 4))
})

# Four held-out storms in two half seasons (one year): one paid what it
# recovers, one paid with no recovery, one missed (all fold 1) and one in a
# failed fold (fold 2). Every storm's training mean recovery is 1.
toy_results <- data.frame(
  region = "toy", rule = "R", fold = c(1, 1, 1, 2),
  season = c(1999, 1999, 2000, 2000),
  event = c("e1", "e2", "e3", "e4"), payout = c(2, 1, 0, NA),
  recovery = c(2, 0, 3, 0), training_mean_recovery = 1,
  failure = c(NA, NA, NA, "error: no fit"))
toy_results_scheme <- season_folds(2000, 2000)

test_that("the summary matches a hand computation", {
  # Basis risk 0, 1, -3, 0: RMS sqrt(10 / 4). Against the flat payout of 1,
  # -1, 1, -2, 1: sum of squares 7. Paid 3 against 5 recovered, in a year.
  out <- holdout_summary(toy_results, toy_results_scheme, n_boot = 10)
  est <- setNames(out$estimate, out$statistic)
  expect_equal(est[["events"]], 4)
  expect_equal(est[["recovering"]], 2)
  expect_equal(est[["paid"]], 2)
  expect_equal(est[["false_payments"]], 1)
  expect_equal(est[["misses"]], 1)
  expect_equal(est[["rms_basis_risk"]], sqrt(10 / 4))
  expect_equal(est[["paid_to_recovery"]], 3 / 5)
  expect_equal(est[["correlation"]], cor(c(2, 1, 0, 0), c(2, 0, 3, 0)))
  expect_equal(est[["annual_payout"]], 3)
  expect_equal(est[["annual_recovery"]], 5)
  expect_equal(est[["rms_to_baseline"]], sqrt(10 / 7))
  expect_equal(est[["failed_folds"]], 1)
  expect_equal(est[["failed_events"]], 1)
})

test_that("the summary also scores the fitted folds alone", {
  # Leaving out e4: basis risk 0, 1, -3 (sum of squares 10) over three
  # storms, and against the flat payout -1, 1, -2 (6).
  out <- holdout_summary(toy_results, toy_results_scheme, n_boot = 10)
  est <- setNames(out$estimate, out$statistic)
  expect_equal(est[["fitted_folds"]], 1)
  expect_equal(est[["fitted_events"]], 3)
  expect_equal(est[["rms_basis_risk_fitted"]], sqrt(10 / 3))
  expect_equal(est[["rms_to_baseline_fitted"]], sqrt(10 / 6))
  # With no failure the fitted statistics are the headline ones.
  all_fit <- transform(toy_results, payout = c(2, 1, 0, 0), failure = NA)
  s <- holdout_summary(all_fit, toy_results_scheme, n_boot = 50)
  st <- function(x) s[s$statistic == x, c("estimate", "lower", "upper")]
  expect_equal(st("rms_basis_risk_fitted"), st("rms_basis_risk"),
               ignore_attr = TRUE)
  expect_equal(st("rms_to_baseline_fitted"), st("rms_to_baseline"),
               ignore_attr = TRUE)
})

test_that("each failed fold is listed with its seasons and reason", {
  out <- holdout_failures(toy_results, season_folds(2000, 2009, block = 5))
  expect_equal(out, data.frame(region = "toy", rule = "R", fold = 2,
                               first_season = 2004, last_season = 2009,
                               events = 1L, failure = "error: no fit"))
  none <- holdout_failures(transform(toy_results, failure = NA),
                           toy_results_scheme)
  expect_equal(nrow(none), 0)
  tied <- toy_events
  tied$index[6:8] <- 45
  real <- holdout_failures(
    transform(holdout_calibration(tied, "toy",
                                  frequency_matching_calibration,
                                  scheme = toy_scheme), rule = "R2"),
    toy_scheme)
  expect_equal(real[c("fold", "first_season", "last_season", "events")],
               data.frame(fold = 1, first_season = 1999,
                          last_season = 2008, events = 4L))
  expect_match(real$failure, "^error: Tied indices")
})

test_that("the summary refuses payouts missing outside failed folds", {
  bad <- toy_results
  bad$payout[1] <- NA
  expect_error(holdout_summary(bad, toy_results_scheme, n_boot = 10),
               "1 payouts are missing")
})

test_that("the bootstrap is fixed by its seed and leaves the RNG alone", {
  res <- transform(holdout_calibration(many, "many", min_index_calibration,
                                       scheme = many_scheme), rule = "R1")
  set.seed(99)
  before <- runif(1)
  set.seed(99)
  a <- holdout_summary(res, many_scheme, n_boot = 200, seed = 3)
  expect_equal(runif(1), before)
  b <- holdout_summary(res, many_scheme, n_boot = 200, seed = 3)
  expect_identical(a, b)
  c <- holdout_summary(res, many_scheme, n_boot = 200, seed = 4)
  expect_false(identical(a$lower, c$lower))
  ok <- !is.na(a$lower)
  expect_true(all(a$lower[ok] <= a$upper[ok]))
})

test_that("two identical seasons give intervals with no width", {
  same <- toy_results[c(1:3, 1:3), ]
  same$season <- rep(c(1999, 2000), each = 3)
  out <- holdout_summary(same, toy_results_scheme, n_boot = 100)
  ok <- !out$statistic %in% c("failed_folds", "failed_events",
                              "fitted_folds")
  expect_equal(out$lower[ok], out$estimate[ok])
  expect_equal(out$upper[ok], out$estimate[ok])
})

test_that("combined covers add payouts and recoveries storm by storm", {
  a <- toy_results
  b <- transform(toy_results, region = "other", payout = c(1, 0, 1, 1),
                 recovery = c(1, 1, 0, 0), failure = NA)
  out <- combine_holdout(rbind(a, b), region = "both")
  out <- out[order(out$event), ]
  expect_equal(out$payout, c(3, 1, 1, 1))
  expect_equal(out$recovery, c(3, 1, 3, 0))
  expect_equal(out$training_mean_recovery, rep(2, 4))
  expect_equal(out$failure, c(NA, NA, NA, "toy: error: no fit"))
  expect_equal(unique(out$region), "both")
  s <- holdout_summary(out, toy_results_scheme, n_boot = 10)
  expect_equal(s$estimate[s$statistic == "failed_events"], 1)
  expect_error(combine_holdout(rbind(a, b[-1, ])), "1 storms are not")
})

test_that("the folds can be run by another lapply", {
  backwards <- function(x, f) rev(lapply(rev(x), f))
  expect_equal(holdout_calibration(toy_events, "toy", min_index_calibration,
                                   scheme = toy_scheme,
                                   fold_apply = backwards),
               holdout_calibration(toy_events, "toy", min_index_calibration,
                                   scheme = toy_scheme))
})
