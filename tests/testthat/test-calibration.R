# Five storms, one a year: the 1-in-5 loss is the 0.8 quantile of 0, 0, 1,
# 2, 3, which is 2.2, and the 1-in-20 loss the 0.95 quantile, 2.8. So one
# storm (e) is above each.
toy_index <- c(a = 10, b = 20, c = 30, d = 40, e = 50)
toy_loss <- c(a = 0, b = 0, c = 1, d = 2, e = 3)

test_that("frequency matching attaches below the k largest indices", {
  out <- frequency_matching_calibration(toy_index, toy_loss,
                                        events_per_year = 1)
  expect_equal(out[c("attachment", "exhaustion", "k", "m")],
               list(attachment = 40, exhaustion = 50, k = 1L, m = 1L))
  expect_equal(out$attachment_events, "d")
  expect_equal(out$exhaustion_events, "e")
})

test_that("frequency matching depends only on the order of the indices", {
  set.seed(2)
  storms <- paste0("s", 1:200)
  index_vec <- setNames(runif(200, 15, 45), storms)
  loss_vec <- setNames(pmax(0, index_vec - 25)^3 * runif(200, 0.5, 1.5),
                       storms)
  events_per_year <- 4
  base <- frequency_matching_calibration(index_vec, loss_vec,
                                         events_per_year = events_per_year)
  f <- function(x) exp(x / 10) + x^3
  moved <- frequency_matching_calibration(f(index_vec), loss_vec,
                                          events_per_year = events_per_year)
  expect_equal(moved$attachment, f(base$attachment))
  expect_equal(moved$exhaustion, f(base$exhaustion))
  expect_equal(moved$attachment_events, base$attachment_events)
  scaled <- frequency_matching_calibration(index_vec, 1e6 * loss_vec,
                                           events_per_year = events_per_year)
  expect_equal(scaled[c("attachment", "exhaustion", "k", "m")],
               base[c("attachment", "exhaustion", "k", "m")])
})

test_that("frequency matching stops on degenerate inputs", {
  expect_error(frequency_matching_calibration(toy_index, toy_loss * 0,
                                              events_per_year = 1),
               "No storm")
  tied <- c(a = 10, b = 20, c = 30, d = 50, e = 50)
  expect_error(frequency_matching_calibration(tied, toy_loss,
                                              events_per_year = 1),
               "Tied indices")
})

test_that("frequency matching never has every storm above the retention", {
  # Even at the lowest possible level, the 0 quantile, the smallest loss is
  # not strictly above it, so k is at most n - 1.
  out <- frequency_matching_calibration(c(a = 1, b = 2), c(a = 1, b = 2),
                                        attach_rp = 1, exhaust_rp = 2,
                                        events_per_year = 1)
  expect_equal(out[c("attachment", "exhaustion", "k", "m")],
               list(attachment = 1, exhaustion = 2, k = 1L, m = 1L))
})

# 100 storms whose loss is exactly a ramp of the index from 40 to 60. At 0.2
# storms a year the 1-in-5 loss is the 0 quantile (0) and the 1-in-20 loss
# the 0.75 quantile (1), so the layer is the whole loss and the limit is 1.
ramp_index <- setNames(1:100, paste0("s", 1:100))
ramp_loss <- setNames(pmin(1, pmax(0, (ramp_index - 40) / 20)),
                      names(ramp_index))

test_that("the fitted ramp recovers an exact ramp with no basis risk", {
  for (loss in c("squared", "absolute")) {
    out <- fitted_ramp_calibration(ramp_index, ramp_loss,
                                   events_per_year = 0.2, loss = loss)
    expect_equal(c(out$attachment, out$exhaustion), c(40, 60))
    expect_true(out$unique)
    br <- basis_risk(ramp_index, ramp_loss, out$attachment, out$exhaustion,
                     limit = 1)
    expect_equal(max(abs(br$basis_risk)), 0, tolerance = 1e-12)
  }
})

# Ten storms over 15 years (2/3 a year). The 1-in-5 loss is the 0.7
# quantile of the sorted losses 0, 0, 0, 1, 1, 2, 3, 4, 5, 9: position 7.3,
# so 3 + 0.3 * (4 - 3) = 3.3, with three storms above it (h, i, j). The
# 1-in-20 loss is the 0.925 quantile: position 9.325, 5 + 0.325 * 4 = 6.3,
# with one storm above it (j). Storms f, g and h tie at index 50.
tie_index <- c(a = 10, b = 20, c = 30, d = 30, e = 40, f = 50, g = 50,
               h = 50, i = 70, j = 80)
tie_loss <- c(a = 0, b = 0, c = 1, d = 0, e = 2, f = 3, g = 1, h = 5, i = 4,
              j = 9)
tie_epy <- 2 / 3

test_that("minimum index takes the lowest index above each loss level", {
  out <- min_index_calibration(tie_index, tie_loss,
                               events_per_year = tie_epy)
  expect_equal(c(out$attachment, out$exhaustion), c(50, 80))
})

test_that("frequency matching counts tied indices separately", {
  # Ranked: 80, 70, 50, 50, 50, ... k = 3, so the attachment is the 4th
  # largest, 50; the 3rd is also 50, so only two storms lie above it.
  out <- frequency_matching_calibration(tie_index, tie_loss,
                                        events_per_year = tie_epy)
  expect_equal(out[c("attachment", "exhaustion", "k", "m")],
               list(attachment = 50, exhaustion = 80, k = 3L, m = 1L))
  expect_equal(out$attachment_events, c("f", "g", "h"))
  expect_equal(sum(tie_index > out$attachment), 2)
})

# Four storms over 16 years (1/4 a year): the 1-in-5 loss is the 0.2
# quantile of 0, 0, 0.5, 1, which is 0, and the 1-in-20 loss the 0.8
# quantile, 0.7, so the limit is 0.7 and the recoveries are 0, 0, 0.5, 0.7.
# Over the six pairs the sums of squared basis risk are (1, 2) 0.53,
# (1, 3) 0.1625, (1, 4) 0.0556, (2, 3) 0.04, (2, 4) 0.0225, (3, 4) 0.25,
# and of absolute basis risk 0.9, 0.55, 0.2667, 0.2, 0.15, 0.5.
small_index <- c(a = 1, b = 2, c = 3, d = 4)
small_loss <- c(a = 0, b = 0, c = 0.5, d = 1)

test_that("the fitted ramp finds the hand-computed optimum", {
  sq <- fitted_ramp_calibration(small_index, small_loss,
                                events_per_year = 0.25)
  expect_equal(c(sq$attachment, sq$exhaustion), c(2, 4))
  expect_equal(sq$objective, 0.0225)
  expect_true(sq$unique)
  ab <- fitted_ramp_calibration(small_index, small_loss,
                                events_per_year = 0.25, loss = "absolute")
  expect_equal(c(ab$attachment, ab$exhaustion), c(2, 4))
  expect_equal(ab$objective, 0.15)
  # Within 10% of 0.0225 lies only (2, 4); within 100%, (2, 3) as well.
  wide <- fitted_ramp_calibration(small_index, small_loss,
                                  events_per_year = 0.25, near = 1)
  expect_equal(wide$near_attachment, c(2, 2))
  expect_equal(wide$near_exhaustion, c(3, 4))
})

test_that("the fitted ramp stops on degenerate inputs", {
  expect_error(fitted_ramp_calibration(small_index, small_loss * 0,
                                       events_per_year = 0.25),
               "limit is not positive")
  expect_error(fitted_ramp_calibration(c(a = 5, b = 5), c(a = 0, b = 1),
                                       attach_rp = 1, exhaust_rp = 2,
                                       events_per_year = 1),
               "Fewer than two")
})

test_that("losses are matched to the indices by name", {
  shuffled <- rev(tie_loss)
  for (f in list(min_index_calibration, frequency_matching_calibration))
    expect_equal(f(tie_index, shuffled, events_per_year = tie_epy)[1:2],
                 f(tie_index, tie_loss, events_per_year = tie_epy)[1:2])
  expect_equal(fitted_ramp_calibration(small_index, rev(small_loss),
                                       events_per_year = 0.25)[1:2],
               fitted_ramp_calibration(small_index, small_loss,
                                       events_per_year = 0.25)[1:2])
})

# The UK, England and Wales and Scotland covers of the vignette
# (vignettes/njord-method.Rmd): storms of 1940-2025 with a UK maximum gust
# above 25 m/s, less those shared_max_within_72h() drops; losses at
# mdd_scale 0.8 as fractions of UK assets; a missing index is 0. The expected
# levels are those calibrate_trigger() gave before it was renamed
# min_index_calibration(), so the test shows the rename changed no result.
stored_covers <- function() {
  ex <- function(f) system.file("extdata", f, package = "njord")
  storms <- utils::read.csv(ex("uk_storm_values.csv"))
  storms$central_time <- as.POSIXct(storms$central_time, tz = "UTC")
  for (r in c("uk", "ew", "sco")) {
    storms <- merge(storms, stats::setNames(
      utils::read.csv(ex(paste0(r, "_exposure_gust.csv"))),
      c("track_id", paste0(r, "_index"))))
    storms <- merge(storms, stats::setNames(
      utils::read.csv(ex(paste0(r, "_storm_losses.csv"))),
      c("track_id", paste0(r, "_loss"))))
  }
  year <- as.integer(format(storms$central_time, "%Y"))
  events <- subset(storms, !shared_max_within_72h(storms) &
                     max_gust > 25 & year >= 1940 & year <= 2025)
  assets <- sum(exposure_weights(ex("uk_nuts1_cover.tif"),
                                 ex("uk_litpop_025deg.tif"), "UK")$weight)
  lapply(c(uk = "uk", ew = "ew", sco = "sco"), function(r) {
    index_vec <- stats::setNames(events[[paste0(r, "_index")]],
                                 events$track_id)
    index_vec[is.na(index_vec)] <- 0
    list(index_vec = index_vec,
         loss_vec = stats::setNames(0.8 * events[[paste0(r, "_loss")]] /
                                      assets, events$track_id),
         events_per_year = nrow(events) / 86)
  })
}

test_that("minimum index reproduces the three stored covers", {
  skip_if(system.file("extdata", "uk_storm_values.csv",
                      package = "njord") == "")
  covers <- stored_covers()
  expected <- list(uk = c(25.8110058322931, 31.0787221781675),
                   ew = c(26.6306837386137, 30.8237389621747),
                   sco = c(32.3656081197466, 34.7971579049992))
  for (r in names(expected)) {
    out <- with(covers[[r]],
                min_index_calibration(index_vec, loss_vec, attach_rp = 5,
                                      exhaust_rp = 20,
                                      events_per_year = events_per_year))
    expect_equal(c(out$attachment, out$exhaustion), expected[[r]],
                 tolerance = 1e-12)
  }
})

test_that("every method's result works with basis_risk() and the vignette's scoring", {
  set.seed(3)
  storms <- paste0("s", 1:150)
  index_vec <- setNames(runif(150, 15, 45), storms)
  loss_vec <- setNames(pmax(0, index_vec - 25)^3 * runif(150, 0.5, 1.5),
                       storms)
  events_per_year <- 5
  methods <- list(min_index_calibration, frequency_matching_calibration,
                  fitted_ramp_calibration)
  # The layer as in the vignette and holdout_calibration(): the retention is
  # the 1-in-5 year loss and the limit the 1-in-20 year loss less it.
  retention <- unname(quantile(loss_vec, 1 - 1 / (5 * events_per_year)))
  limit <- unname(quantile(loss_vec, 1 - 1 / (20 * events_per_year))) -
    retention
  for (f in methods) {
    trigger <- f(index_vec, loss_vec, attach_rp = 5, exhaust_rp = 20,
                 events_per_year = events_per_year)
    expect_true(all(c("attachment", "exhaustion", "attach_rp",
                      "exhaust_rp") %in% names(trigger)))
    br <- basis_risk(index_vec, pmin(pmax(loss_vec - retention, 0), limit),
                     trigger$attachment, trigger$exhaustion, limit = limit)
    names(br)[names(br) == "loss"] <- "layer_loss"
    expect_equal(nrow(br), 150)
    summary <- c(pay = sum(br$payout > 0), recover = sum(br$layer_loss > 0),
                 cor = cor(br$payout, br$layer_loss))
    expect_true(all(is.finite(summary)))
    expect_true(all(br$payout >= 0 & br$payout <= limit))
  }
})
