# ciara_demo.R
#
# Storm Ciara (February 2020, track 1758) from footprint to modelled loss:
# the UK mean gust trigger index, then the loss to UK assets under the
# Schwierz vulnerability curve with the MDD scaled by mdd_scale (0.8, the UK
# RMSE calibration read from Fig. 3n of Mishra et al. 2026). Gusts are the
# footprint on the 0.25 degree grid; assets are the LitPop exposure summed to
# that grid, 6 x 6 LitPop cells to each footprint cell which keeps the total
# exactly. Both are restricted to the cells with some UK land in the cover
# raster, so the curve is not applied to sea cells. Losses are in USD.
#
# Needs these scripts in inst/scripts/data-raw to have been run:
# unzip_footprints.sh and rasterize_uk.R, and for the losses,
# download_litpop.sh and convert_litpop.py.
# Uses the package functions through devtools::load_all(). 
#
# Run from the project root.

library(terra)
devtools::load_all(quiet = TRUE)

footprint_file <- paste0("data-raw/footprints/nc/storm_footprint-hodges-raw-",
                         "20200209-1758-original-decontaminated-v1_0.nc")
cover_file <- "data-raw/nuts/uk_nuts1_cover.tif"
litpop_file <- "data-raw/litpop/LitPop_150arcsec_GBR.csv"
data_raw_scripts <- "inst/scripts/data-raw"
mdd_scale <- 0.8

if (!file.exists(footprint_file)) {
  message(footprint_file, " not found; run ",
          file.path(data_raw_scripts, "unzip_footprints.sh"), " first.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run ",
          file.path(data_raw_scripts, "rasterize_uk.R"), " first.")
} else {
  wts <- uk_weights(cover_file)
  index <- uk_mean_gust_index(footprint_file, wts)
  message("Storm Ciara (track 1758): UK mean gust index ", round(index, 2),
          " m/s, over ", length(wts$idx), " cells with UK land.")
  if (!file.exists(litpop_file)) {
    message(litpop_file, " not found, so no losses; run ",
            file.path(data_raw_scripts, "download_litpop.sh"), ", then ",
            file.path(data_raw_scripts, "convert_litpop.py"), ".")
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
    mdr <- app(gust, function(v) schwierz_mdr(v, mdd_scale = mdd_scale))
    loss <- global(mdr * assets, "sum", na.rm = TRUE)[[1]]
    message("Modelled loss ", sprintf("%.3f", loss / 1e9),
            " USD bn (Schwierz, mdd_scale ", mdd_scale, ").")
  }
}
