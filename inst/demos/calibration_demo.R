# calibration_demo.R
#
# Calibrates triggers on exposure-weighted mean gust indices to modelled
# losses over the storm catalogue, then shows the basis risk storm by storm:
# first one cover for the whole UK, then two covers, one for England and
# Wales and one for Scotland, whose payouts are added. Each index is the
# footprint gust averaged over the region, each cell weighted by the value
# of its LitPop assets there (exposure_weights()). The event set is the
# storms of 1940-2025 with a UK maximum gust above 25 m/s, less those that
# share a maximum gust with a nearby storm (shared_max_within_72h()); a
# storm with no gust values in a region (NA in the CSV) has index 0 there.
# Losses are under the Schwierz curve with the MDD scaled by mdd_scale (0.8,
# as in ciara_demo.R), as a fraction of the total UK assets, so the covers'
# amounts can be added. Each cover is a layer on its own region's losses:
# it should pay the loss above the 1-in-attach_rp year loss (the retention)
# up to the 1-in-exhaust_rp year loss, so its limit is the difference. The
# attachment and exhaustion are the index levels of those two losses
# (calibrate_trigger()), and the basis risk is the payout minus what the
# layer would pay.
#
# Reads only inst/extdata, so it runs without data-raw/.
# Uses the package functions through devtools::load_all().
#
# Run from the project root.

devtools::load_all(quiet = TRUE)

# One column of a per-storm CSV, keyed by track id, under a new name.
read_column <- function(file, name)
  setNames(read.csv(file), c("track_id", name))

# A layer cover on one region: the trigger calibrated on the region's
# losses, and storm by storm the payout and what the layer would pay.
layer_cover <- function(index_vec, loss_vec, attach_rp, exhaust_rp,
                        events_per_year) {
  loss_at <- function(rp)
    unname(quantile(loss_vec, 1 - 1 / (rp * events_per_year)))
  retention <- loss_at(attach_rp)
  limit <- loss_at(exhaust_rp) - retention
  trigger <- calibrate_trigger(index_vec, loss_vec, attach_rp = attach_rp,
                               exhaust_rp = exhaust_rp,
                               events_per_year = events_per_year)
  br <- basis_risk(index_vec, pmin(pmax(loss_vec - retention, 0), limit),
                   trigger$attachment, trigger$exhaustion, limit = limit)
  names(br)[names(br) == "loss"] <- "layer_loss"
  list(attachment = trigger$attachment, exhaustion = trigger$exhaustion,
       retention = retention, limit = limit, table = br)
}

# Counts and amounts a year of a cover's table (amounts as fractions).
cover_summary <- function(br, years)
  c(pay = sum(br$payout > 0), recover = sum(br$layer_loss > 0),
    missed = sum(br$payout == 0 & br$layer_loss > 0),
    paid_small = sum(br$payout > 0 & br$layer_loss == 0),
    paid = sum(br$payout) / years, layer = sum(br$layer_loss) / years,
    cor = cor(br$payout, br$layer_loss))

file_names <- c(values = "uk_storm_values.csv",
                uk_index = "uk_exposure_gust.csv",
                uk_loss = "uk_storm_losses.csv",
                ew_index = "ew_exposure_gust.csv",
                ew_loss = "ew_storm_losses.csv",
                sco_index = "sco_exposure_gust.csv",
                sco_loss = "sco_storm_losses.csv",
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

if (any(files == "")) {
  message("Files missing from inst/extdata: ",
          paste(file_names[files == ""], collapse = ", "),
          "; see inst/scripts/extdata/Readme.md.")
} else {
  storms <- read.csv(files[["values"]])
  storms$central_time <- as.POSIXct(storms$central_time, tz = "UTC")
  for (k in c("uk_index", "uk_loss", "ew_index", "ew_loss", "sco_index",
              "sco_loss"))
    storms <- merge(storms, read_column(files[[k]], k))

  year <- lubridate::year(storms$central_time)
  events <- subset(storms, !shared_max_within_72h(storms) &
                     max_gust > gust_threshold &
                     year >= first_year & year <= last_year)
  years <- last_year - first_year + 1
  events_per_year <- nrow(events) / years
  total_assets <- sum(exposure_weights(files[["cover"]], files[["assets"]],
                                       regions = "UK")$weight)
  bn <- function(x) round(x * total_assets / 1e9, 3)

  cover <- function(region) {
    index_vec <- setNames(events[[paste0(region, "_index")]], events$track_id)
    index_vec[is.na(index_vec)] <- 0
    loss_vec <- setNames(mdd_scale * events[[paste0(region, "_loss")]] /
                           total_assets, events$track_id)
    layer_cover(index_vec, loss_vec, attach_rp, exhaust_rp, events_per_year)
  }
  covers <- lapply(c(uk = "uk", ew = "ew", sco = "sco"), cover)
  regional <- covers$ew$table
  regional$index <- NULL
  regional$payout <- covers$ew$table$payout + covers$sco$table$payout
  regional$layer_loss <- covers$ew$table$layer_loss +
    covers$sco$table$layer_loss
  regional$basis_risk <- regional$payout - regional$layer_loss

  describe_trigger <- function(cv)
    paste0("attachment ", round(cv$attachment, 2), " m/s, exhaustion ",
           round(cv$exhaustion, 2), " m/s; layer USD ", bn(cv$limit),
           " bn xs USD ", bn(cv$retention), " bn.")
  describe_basis <- function(s)
    paste0(s[["pay"]], " storms pay out, ", s[["recover"]],
           " would recover; ", s[["missed"]], " of those pay nothing, ",
           s[["paid_small"]], " with no recovery pay something. Paid a ",
           "year: trigger USD ", bn(s[["paid"]]), " bn, layer USD ",
           bn(s[["layer"]]), " bn; correlation ", round(s[["cor"]], 3), ".")
  s <- lapply(covers, function(cv) cover_summary(cv$table, years))
  message(nrow(events), " storms, ", round(events_per_year, 2), " a year.\n",
          "UK: ", describe_trigger(covers$uk), "\n  ", describe_basis(s$uk),
          "\nEngland and Wales: ", describe_trigger(covers$ew), "\n  ",
          describe_basis(s$ew),
          "\nScotland: ", describe_trigger(covers$sco), "\n  ",
          describe_basis(s$sco),
          "\nEngland and Wales plus Scotland: ",
          describe_basis(cover_summary(regional, years)))

  top <- order(-events$uk_loss)[1:10]
  print(data.frame(event = events$track_id[top],
                   uk_index = covers$uk$table$index[top],
                   ew_index = covers$ew$table$index[top],
                   sco_index = covers$sco$table$index[top],
                   uk_payout = bn(covers$uk$table$payout[top]),
                   uk_layer = bn(covers$uk$table$layer_loss[top]),
                   regional_payout = bn(regional$payout[top]),
                   regional_layer = bn(regional$layer_loss[top]),
                   storm_loss = bn(mdd_scale * events$uk_loss[top] /
                                     total_assets)), digits = 3)
}
