# calibration_demo.R
#
# Calibrates a trigger on the UK exposure-weighted mean gust to modelled
# losses over the storm catalogue, then shows the basis risk storm by storm.
# The index is the footprint gust averaged over the UK, each cell weighted
# by the value of its LitPop assets (exposure_weights()). The event set is
# the storms of 1940-2025 with a UK maximum gust above 25 m/s, less those
# that share a maximum gust with a nearby storm (shared_max_within_72h()).
# Losses are under the Schwierz curve with the MDD scaled by mdd_scale (0.8,
# as in ciara_demo.R), as a fraction of the total assets in the regions. The
# attachment and exhaustion are the index levels of the 1-in-attach_rp and
# 1-in-exhaust_rp year losses (calibrate_trigger()). The cover is a layer:
# it should pay the loss above the 1-in-attach_rp year loss (the retention)
# up to the 1-in-exhaust_rp year loss, so the limit is the difference, and
# the basis risk is the payout minus what the layer would pay.
#
# Reads only inst/extdata, so it runs without data-raw/.
# Uses the package functions through devtools::load_all().
#
# Run from the project root.

devtools::load_all(quiet = TRUE)

extdata <- function(f) system.file("extdata", f, package = "njord")
values_file <- extdata("uk_storm_values.csv")
index_file <- extdata("uk_exposure_gust.csv")
losses_file <- extdata("uk_storm_losses.csv")
cover_file <- extdata("uk_nuts1_cover.tif")
assets_file <- extdata("uk_litpop_025deg.tif")
regions <- "UK"
first_year <- 1940
last_year <- 2025
gust_threshold <- 25
mdd_scale <- 0.8
attach_rp <- 5
exhaust_rp <- 20

if (any(c(values_file, index_file, losses_file, cover_file,
          assets_file) == "")) {
  message("Files missing from inst/extdata; see ",
          "inst/scripts/extdata/Readme.md.")
} else {
  storms <- read.csv(values_file)
  storms$central_time <- as.POSIXct(storms$central_time, tz = "UTC")
  storms <- merge(merge(storms, read.csv(index_file)), read.csv(losses_file))

  year <- lubridate::year(storms$central_time)
  events <- subset(storms, !shared_max_within_72h(storms) &
                     max_gust > gust_threshold &
                     year >= first_year & year <= last_year)
  events_per_year <- nrow(events) / (last_year - first_year + 1)

  total_assets <- sum(exposure_weights(cover_file, assets_file,
                                       regions = regions)$weight)

  index_vec <- setNames(events$uk_exposure_gust, events$track_id)
  loss_vec <- setNames(mdd_scale * events$loss_usd_mdd1 / total_assets,
                       events$track_id)
  attach_loss <- unname(quantile(loss_vec,
                                 1 - 1 / (attach_rp * events_per_year)))
  exhaust_loss <- unname(quantile(loss_vec,
                                  1 - 1 / (exhaust_rp * events_per_year)))
  limit <- exhaust_loss - attach_loss
  layer_vec <- pmin(pmax(loss_vec - attach_loss, 0), limit)

  trigger <- calibrate_trigger(index_vec, loss_vec, attach_rp = attach_rp,
                               exhaust_rp = exhaust_rp,
                               events_per_year = events_per_year)
  br <- basis_risk(index_vec, layer_vec, trigger$attachment,
                   trigger$exhaustion, limit = limit)
  names(br)[names(br) == "loss"] <- "layer_loss"
  br$storm_loss <- unname(loss_vec[br$event])

  missed <- sum(br$payout == 0 & br$layer_loss > 0)
  paid_small <- sum(br$payout > 0 & br$layer_loss == 0)
  years <- last_year - first_year + 1
  bn <- function(x) round(x * total_assets / 1e9, 3)

  message(nrow(events), " storms, ", round(events_per_year, 2), " a year.\n",
          "Attachment ", round(trigger$attachment, 2), " m/s (1-in-",
          attach_rp, "), exhaustion ", round(trigger$exhaustion, 2),
          " m/s (1-in-", exhaust_rp, ").\n",
          "Layer: USD ", bn(limit), " bn in excess of USD ", bn(attach_loss),
          " bn (limit ", signif(limit, 3), " of total assets).\n",
          sum(br$payout > 0), " storms pay out, ", sum(br$layer_loss > 0),
          " would recover from the layer. ", missed, " of those pay ",
          "nothing; ", paid_small, " with no recovery pay something.\n",
          "Paid a year: trigger USD ", bn(sum(br$payout) / years),
          " bn, layer USD ", bn(sum(br$layer_loss) / years), " bn.")
  print(head(br[order(-br$storm_loss), ], 10), digits = 3)
}
