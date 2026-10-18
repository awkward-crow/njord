# ciara_demo.R
#
# Storm Ciara (February 2020, track 1758) from footprint to modelled loss:
# the UK mean gust trigger index, then the loss to UK assets under the
# Schwierz vulnerability curve with the MDD scaled by mdd_scale (0.8, the UK
# RMSE calibration read from Fig. 3n of Mishra et al. 2026). Losses are in
# USD.
#
# Reads the rasters in inst/extdata written by
# inst/scripts/extdata/prepare_extdata.R, so it runs without data-raw/. The
# footprint, the UK cover and the LitPop assets summed to 0.25 degrees share
# one grid, so the gusts and assets are taken at the cells with UK land, and
# the curve is not applied to sea cells.
# Uses the package functions through devtools::load_all().
#
# Run from the project root.

library(terra)
devtools::load_all(quiet = TRUE)

extdata <- function(f) system.file("extdata", f, package = "njord")
footprint_file <- extdata("ciara_footprint_uk.tif")
cover_file <- extdata("uk_nuts1_cover.tif")
assets_file <- extdata("uk_litpop_025deg.tif")
mdd_scale <- 0.8

if (any(c(footprint_file, cover_file, assets_file) == "")) {
  message("Rasters missing from inst/extdata; run ",
          "inst/scripts/extdata/prepare_extdata.R.")
} else {
  wts <- area_weights(cover_file, regions = "UK")
  footprint <- values(rast(footprint_file), mat = FALSE)
  index <- weighted_mean_index(footprint, wts)
  gust <- footprint[wts$idx]
  assets <- values(rast(assets_file), mat = FALSE)[wts$idx]
  loss <- sum(schwierz_mdr(gust, mdd_scale = mdd_scale) * assets, na.rm = TRUE)
  message("Storm Ciara (track 1758): UK mean gust index ", round(index, 2),
          " m/s, over ", length(wts$idx), " cells with UK land.\n",
          "UK assets ", round(sum(assets, na.rm = TRUE) / 1e9),
          " USD bn; highest UK gust ", round(max(gust, na.rm = TRUE), 1),
          " m/s.\nModelled loss ", sprintf("%.3f", loss / 1e9),
          " USD bn (Schwierz, mdd_scale ", mdd_scale, ").")
}
