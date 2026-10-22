# Checks the fitted ramp results stored by inst/scripts/holdout_fitted_ramp.R
# against the package function, so the two can't drift apart. Slow (about a
# minute), so it runs only when NJORD_SLOW_TESTS is "true":
#   NJORD_SLOW_TESTS=true Rscript -e 'devtools::test(filter = "precomputed")'

# The vignette's event set for one region, as in holdout_fitted_ramp.R.
catalogue_events <- function(region, first_year = 1940, last_year = 2025,
                             gust_threshold = 25, mdd_scale = 0.8) {
  extdata <- function(f) system.file("extdata", f, package = "njord")
  storms <- read.csv(extdata("uk_storm_values.csv"))
  storms$central_time <- as.POSIXct(storms$central_time, tz = "UTC")
  for (k in c("exposure_gust", "storm_losses"))
    storms <- merge(storms, setNames(
      read.csv(extdata(paste0(region, "_", k, ".csv"))),
      c("track_id", k)))
  year <- as.integer(format(storms$central_time, "%Y"))
  events <- subset(storms, !shared_max_within_72h(storms) &
                     max_gust > gust_threshold &
                     year >= first_year & year <= last_year)
  total_assets <- sum(exposure_weights(extdata("uk_nuts1_cover.tif"),
                                       extdata("uk_litpop_025deg.tif"),
                                       regions = "UK")$weight)
  data.frame(event = events$track_id, central_time = events$central_time,
             index = ifelse(is.na(events$exposure_gust), 0,
                            events$exposure_gust),
             loss = mdd_scale * events$storm_losses / total_assets)
}

read_stored <- function(f, ...)
  read.csv(system.file("extdata", f, package = "njord"), comment.char = "#",
           ...)

test_that("the stored in-sample fit matches a fresh one (Scotland)", {
  skip_on_cran()
  skip_if_not(Sys.getenv("NJORD_SLOW_TESTS") == "true",
              "NJORD_SLOW_TESTS is not \"true\"")
  ev <- catalogue_events("sco")
  fit <- fitted_ramp_calibration(setNames(ev$index, ev$event),
                                 setNames(ev$loss, ev$event),
                                 events_per_year = nrow(ev) / 86,
                                 loss = "squared")
  stored <- subset(read_stored("insample_fitted_ramp.csv"),
                   region == "sco" & loss == "squared")
  expect_equal(c(fit$attachment, fit$exhaustion, fit$objective,
                 fit$optima),
               c(stored$attachment, stored$exhaustion, stored$objective,
                 stored$optima), tolerance = 1e-8)
  expect_equal(paste(fit$attachment_events, collapse = " "),
               as.character(stored$attachment_events))
})

test_that("a stored hold-out fold matches a fresh one (England and Wales)", {
  skip_on_cran()
  skip_if_not(Sys.getenv("NJORD_SLOW_TESTS") == "true",
              "NJORD_SLOW_TESTS is not \"true\"")
  fold <- 9
  fresh <- holdout_calibration(catalogue_events("ew"), "ew",
                               fitted_ramp_calibration, loss = "squared",
                               scheme = season_folds(1940, 2025),
                               fold_apply = function(x, f)
                                 lapply(x[x == fold], f))
  stored <- subset(read_stored("holdout_fitted_ramp.csv",
                               colClasses = c(failure = "character")),
                   region == "ew" & fold == 9)
  expect_equal(fresh$event, stored$event)
  expect_equal(fresh[names(stored)], stored, tolerance = 1e-8,
               ignore_attr = TRUE)
})
