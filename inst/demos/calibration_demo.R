# calibration_demo.R
#
# Calibrates a parametric cover for Scotland with
# frequency_matching_calibration() and measures its basis risk over the
# storm catalogue, in sample. The index is the exposure-weighted mean gust
# over Scotland: the footprint gust averaged over the cells with assets
# there, each weighted by the value of its LitPop assets (exposure_weights()).
# The event set is the package's current definition: the storms of
# 1940-2025 with a UK maximum gust above 25 m/s, less those that share a
# maximum gust with a nearby storm (shared_max_within_72h()); a storm with
# no gust values in Scotland (NA in the CSV) has index 0 there. Losses are
# under the Schwierz curve with the MDD scaled by mdd_scale (0.8, as in
# ciara_demo.R).
#
# The cover is a layer on Scotland's losses: it should pay the loss above
# the 1-in-attach_rp year loss (the retention) up to the 1-in-exhaust_rp
# year loss, so its limit is the difference; what it should pay a storm is
# the storm's recovery. It prints the layer, the attachment and exhaustion
# and the storms that set them, storms paid against storms recovering,
# false payments, missed storms, RMS basis risk, RMS against a flat payout
# of the mean recovery, paid over the layer's recoveries, the correlation of
# payout with recovery and the storms with the largest losses.
#
# It plots each storm's recovery and payout against its index, with the
# payout ramp; the January 2002 storm (track 1346) is marked, as its
# modelled Scottish loss is not supported by observed gusts. Storms with an
# index below plot_min_index, none of which is paid or recovers, are left
# out. Base graphics only. The plot is
# drawn in an interactive session only.
#
# The other regions, the other rules and the out-of-sample test are in the
# vignette (vignettes/njord-method.Rmd).
#
# Reads only inst/extdata, so it runs without data-raw/ or a CDS account.
# Takes a few seconds. Uses the package functions through
# devtools::load_all(). Run from the project root.

devtools::load_all(quiet = TRUE)

file_names <- c(values = "uk_storm_values.csv",
                index = "sco_exposure_gust.csv",
                loss = "sco_storm_losses.csv",
                cover = "uk_nuts1_cover.tif",
                assets = "uk_litpop_025deg.tif")
files <- vapply(file_names, function(f)
  system.file("extdata", f, package = "njord"), character(1))
first_year <- 1940
last_year <- 2025
gust_threshold <- 25
mdd_scale <- 0.8
attach_rp <- 5
exhaust_rp <- 20
jennifer <- 1346
n_largest <- 5
plot_min_index <- 25

# One column of a per-storm CSV, keyed by track id, under a new name.
read_column <- function(file, name)
  setNames(read.csv(file), c("track_id", name))

# The loss with return period rp years, as in the calibration functions.
loss_at <- function(loss, rp, events_per_year)
  unname(quantile(loss, 1 - 1 / (rp * events_per_year)))

fmt <- function(x, digits = 2) formatC(x, format = "f", digits = digits)
month_year <- function(t) format(t, "%b %Y")

# Recovery (points) and payout (on the ramp) of each storm against its
# index, in USD m, with the gap between them, the attachment and exhaustion
# marked, the largest storms labelled above the limit, in order of index,
# and track `marked` set apart.
plot_cover <- function(d, attachment, exhaustion, limit, largest, marked,
                       min_index) {
  d <- d[d$index >= min_index, ]
  blue <- "#1f5fa8"
  grey <- "grey35"
  red <- "#c0392b"
  l <- d[d$event %in% largest & d$event != marked, ]
  l <- l[order(l$index), ]
  label_y <- limit * (1.1 + 0.09 * (seq_len(nrow(l)) - 1))
  op <- par(mar = c(4.2, 4.2, 2.6, 1), mgp = c(2.6, 0.7, 0), las = 1)
  on.exit(par(op))
  plot(d$index, d$recovery, type = "n", xlab = "Storm's index (m/s)",
       ylab = "USD m", ylim = c(0, max(label_y, limit) + 0.08 * limit),
       main = "Scotland cover: what it pays and what the layer recovers",
       font.main = 1, cex.main = 1.05, bty = "l")
  abline(v = c(attachment, exhaustion), lty = 2, col = "grey70")
  text(c(attachment, exhaustion), 0.5 * limit,
       c("attachment", "exhaustion"), pos = c(2, 4), cex = 0.8, col = grey)
  gap <- d$payout != d$recovery
  segments(d$index[gap], d$recovery[gap], d$index[gap], d$payout[gap],
           col = "grey75")
  x <- c(min_index, attachment, exhaustion, max(d$index))
  lines(x, payout(x, attachment, exhaustion, limit), col = blue, lwd = 2)
  points(d$index[d$payout > 0], d$payout[d$payout > 0], pch = 16, cex = 0.8,
         col = blue)
  other <- d$event != marked
  points(d$index[other], d$recovery[other], pch = 1, cex = 0.8, col = grey)
  segments(l$index, l$recovery, l$index, label_y, col = "grey75", lty = 3)
  text(l$index, label_y, month_year(l$central_time), pos = 4, offset = 0.2,
       cex = 0.75, col = grey)
  m <- d[d$event == marked, ]
  points(m$index, m$recovery, pch = 23, cex = 1.4, bg = red, col = red)
  text(m$index, m$recovery - 0.06 * limit,
       paste0(month_year(m$central_time), "\nmodelled loss not\n",
              "supported by\nobserved gusts"),
       adj = c(1, 1), cex = 0.75, col = red)
  legend("topleft", c("payout (on the ramp)", "layer's recovery"),
         pch = c(16, 1), col = c(blue, grey), lty = c(1, NA), lwd = c(2, NA),
         bty = "n", cex = 0.8)
}

if (any(files == "")) {
  message("Files missing from inst/extdata: ",
          paste(file_names[files == ""], collapse = ", "),
          "; see inst/scripts/extdata/Readme.md.")
} else {
  storms <- read.csv(files[["values"]])
  storms$central_time <- as.POSIXct(storms$central_time, tz = "UTC")
  storms <- merge(merge(storms, read_column(files[["index"]], "index")),
                  read_column(files[["loss"]], "loss"))
  year <- as.POSIXlt(storms$central_time)$year + 1900
  events <- subset(storms, !shared_max_within_72h(storms) &
                     max_gust > gust_threshold &
                     year >= first_year & year <= last_year)
  years <- sum(season_folds(first_year, last_year)$years)
  events_per_year <- nrow(events) / years
  total_assets <- sum(exposure_weights(files[["cover"]], files[["assets"]],
                                       regions = "UK")$weight)
  usd_m <- function(x) x * total_assets / 1e6

  index <- ifelse(is.na(events$index), 0, events$index)
  loss <- mdd_scale * events$loss / total_assets
  retention <- loss_at(loss, attach_rp, events_per_year)
  limit <- loss_at(loss, exhaust_rp, events_per_year) - retention
  levels <- frequency_matching_calibration(
    setNames(index, events$track_id), setNames(loss, events$track_id),
    attach_rp = attach_rp, exhaust_rp = exhaust_rp,
    events_per_year = events_per_year)
  p <- payout(index, levels$attachment, levels$exhaustion, limit)
  r <- pmin(pmax(loss - retention, 0), limit)
  setter <- function(level) {
    k <- index == level
    paste0("track ", paste(events$track_id[k], collapse = " "), " (",
           paste(month_year(events$central_time[k]), collapse = ", "), ")")
  }

  message(
    "Basis risk here is measured against a modelled loss from the same ",
    "ERA5 gust field as the index, not against real losses.\n",
    "Scotland cover, frequency_matching_calibration(), on ", nrow(events),
    " storms of ", first_year, "-", last_year, " (", fmt(events_per_year),
    " a year); amounts in USD.\n",
    "Layer:        USD ", fmt(usd_m(limit), 1), " m xs USD ",
    fmt(usd_m(retention), 1), " m (the 1-in-", attach_rp, " to 1-in-",
    exhaust_rp, " year Scottish loss)\n",
    "Attachment:   ", fmt(levels$attachment), " m/s, set by ",
    setter(levels$attachment), "\n",
    "Exhaustion:   ", fmt(levels$exhaustion), " m/s, set by ",
    setter(levels$exhaustion), "\n",
    "Storms paid / storms recovering:      ", sum(p > 0), " / ", sum(r > 0),
    "\n",
    "False payments (paid, no recovery):   ", sum(p > 0 & r == 0), "\n",
    "Missed storms (recovery, not paid):   ", sum(r > 0 & p == 0), "\n",
    "RMS basis risk:                       USD ",
    fmt(usd_m(sqrt(mean((p - r)^2))), 1), " m a storm\n",
    "RMS against a flat payout:            ",
    fmt(sqrt(sum((p - r)^2) / sum((mean(r) - r)^2))), "\n",
    "Paid / layer:                         ", fmt(sum(p) / sum(r)), "\n",
    "Correlation of payout with recovery:  ", fmt(cor(p, r)), "\n",
    "(A flat payout pays every storm the mean recovery.)")

  largest <- order(-loss)[seq_len(n_largest)]
  message("\nThe ", n_largest, " storms with the largest Scottish loss, in USD m:")
  show <- data.frame(track = events$track_id[largest],
                     date = month_year(events$central_time[largest]),
                     index = fmt(index[largest]),
                     loss = fmt(usd_m(loss[largest]), 1),
                     recovery = fmt(usd_m(r[largest]), 1),
                     payout = fmt(usd_m(p[largest]), 1))
  message(paste(capture.output(print(show, row.names = FALSE)),
                collapse = "\n"))
  if (jennifer %in% events$track_id[largest])
    message("Track ", jennifer, " (January 2002): its modelled Scottish ",
            "loss is not supported by observed gusts.")

  d <- data.frame(event = events$track_id, central_time = events$central_time,
                  index = index, recovery = usd_m(r), payout = usd_m(p))
  if (interactive())
    plot_cover(d, levels$attachment, levels$exhaustion, usd_m(limit),
               events$track_id[largest], jennifer, plot_min_index)
}
