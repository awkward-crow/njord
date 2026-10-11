# ciara_demo.R
#
# Storm Ciara (February 2020, track 1758) from footprint to modelled loss:
# the UK mean gust trigger index, then the loss to UK assets under the three
# vulnerability curves (Schwierz, Welker, UK). Gusts are the footprint on the
# 0.25 degree grid; assets are the LitPop exposure summed to that grid, 6 x 6
# LitPop cells to each footprint cell, which keeps the total exactly. Both
# are restricted to the cells with some UK land in the cover raster, so the
# curves are not applied to sea cells. Losses are in USD.
#
# Needs unzip_footprints.sh and rasterize_uk.R to have been run, and for the
# losses download_litpop.sh and convert_litpop.py; says what is missing.
# Without the LitPop CSV, gives the index only. Writes nothing. Uses the
# package functions through devtools::load_all(). Run from the project root.

library(terra)
devtools::load_all(quiet = TRUE)

# Total loss (USD) under each vulnerability curve.
losses <- function(gust, assets, curves)
  vapply(curves, function(curve)
    global(app(gust, curve) * assets, "sum", na.rm = TRUE)[[1]], 0)

footprint_file <- paste0("data-raw/footprints/nc/storm_footprint-hodges-raw-",
                         "20200209-1758-original-decontaminated-v1_0.nc")
cover_file <- "data-raw/nuts/uk_nuts1_cover.tif"
litpop_file <- "data-raw/litpop/LitPop_150arcsec_GBR.csv"

if (!file.exists(footprint_file)) {
  message(footprint_file, " not found; run unzip_footprints.sh first.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run rasterize_uk.R first.")
} else {
  wts <- uk_weights(cover_file)
  index <- compute_index(footprint_file, wts)
  message("Storm Ciara (track 1758): UK mean gust index ", round(index, 2),
          " m/s, over ", length(wts$idx), " cells with UK land.")
  if (!file.exists(litpop_file)) {
    message(litpop_file, " not found, so no losses; run ",
            "inst/scripts/download_litpop.sh, then ",
            "inst/scripts/convert_litpop.py.")
  } else {
    assets <- aggregate(load_litpop_uk(litpop_file), 6, sum, na.rm = TRUE)
    fp <- rast(footprint_file)
    uk <- rast(fp)
    uk[wts$idx] <- 1
    uk <- crop(uk, assets)
    gust <- mask(crop(fp, assets), uk)
    assets <- mask(assets, uk)
    message("UK assets ", round(global(assets, "sum", na.rm = TRUE)[[1]] / 1e9),
            " USD bn; highest UK gust ",
            round(global(gust, "max", na.rm = TRUE)[[1]], 1), " m/s.")
    curves <- list(Schwierz = function(v) schwierz_mdr(v, mdd_scale = 1,
                                                       paa_scale = 1),
                   Welker = welker_mdr,
                   UK = uk_mdr)
    loss <- losses(gust, assets, curves)
    message("Modelled loss (USD bn):\n",
            paste(sprintf("  %-9s %6.3f", names(loss), loss / 1e9),
                  collapse = "\n"))
  }
}
