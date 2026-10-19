# ciara_demo.R
#
# Storm Ciara (February 2020, track 1758) from footprint to modelled loss:
# the exposure-weighted UK mean gust trigger index, then the loss to UK
# assets under the Schwierz vulnerability curve with the MDD scaled by
# mdd_scale (0.8, the UK RMSE calibration read from Fig. 3n of Mishra et al.
# 2026). Losses are in USD. In an interactive session it also plots the
# footprint with the UK coastline (ggplot2, tidyterra, rnaturalearth).
#
# Reads the rasters in inst/extdata written by
# inst/scripts/extdata/uk_litpop_025deg.R, uk_nuts1_cover.R and
# ciara_footprint_uk.R, so it runs without data-raw/. The
# footprint, the UK cover and the LitPop assets summed to 0.25 degrees share
# one grid, so the gusts and assets are taken at the cells with UK assets
# (exposure_weights()), and the curve is not applied to sea cells.
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
  message("Rasters missing from inst/extdata; run uk_litpop_025deg.R, ",
          "uk_nuts1_cover.R and ciara_footprint_uk.R in inst/scripts/extdata.")
} else {
  wts <- exposure_weights(cover_file, assets_file, regions = "UK")
  footprint_rast <- rast(footprint_file)
  footprint <- values(footprint_rast, mat = FALSE)
  index <- weighted_mean_index(footprint, wts)
  gust <- footprint[wts$idx]
  loss <- sum(schwierz_mdr(gust, mdd_scale = mdd_scale) * wts$weight,
              na.rm = TRUE)
  message("Storm Ciara (track 1758): exposure-weighted UK mean gust index ",
          round(index, 2), " m/s, over ", length(wts$idx),
          " cells with UK assets.\n",
          "UK assets ", round(sum(wts$weight) / 1e9),
          " USD bn; highest UK gust ", round(max(gust, na.rm = TRUE), 1),
          " m/s.\nModelled loss ", sprintf("%.3f", loss / 1e9),
          " USD bn (Schwierz, mdd_scale ", mdd_scale, ").")
  if (interactive()) {
    uk <- rnaturalearth::ne_countries(country = "United Kingdom",
                                      scale = "medium", returnclass = "sf")
    print(ggplot2::ggplot() +
            tidyterra::geom_spatraster(data = footprint_rast) +
            ggplot2::geom_sf(data = uk, fill = NA, colour = "white",
                             linewidth = 0.3) +
            ggplot2::scale_fill_viridis_c(name = "Gust (m/s)",
                                          na.value = "transparent") +
            ggplot2::labs(title = "Storm Ciara footprint, max gust") +
            ggplot2::theme_minimal())
  }
}
