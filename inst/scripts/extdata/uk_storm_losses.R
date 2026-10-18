# uk_storm_losses.R
#
# One row per storm with the modelled loss to UK assets in USD, under the
# Schwierz vulnerability curve with mdd_scale = 1. The loss is proportional
# to mdd_scale, so a demo multiplies by its own scale rather than this file
# fixing one. Gusts and assets are taken at the cells with UK land, on the
# grid of the rasters in inst/extdata, so every loss uses the same assets as
# the demos. Footprint cells that are NaN (more than 1000 km from the track)
# add no loss, so a storm with no UK values has loss zero.
#
# Needs inst/scripts/data-raw/unzip_footprints.sh, then
# inst/scripts/extdata/uk_litpop_025deg.R and uk_nuts1_cover.R, to have been
# run; says so and does nothing if the footprints or the rasters are missing,
# or if the first footprint, cropped, is not on the rasters' grid. An existing
# output file is not made again. The CSV is written to a .part file and
# renamed when complete. Uses the package functions through
# devtools::load_all().
#
# Run from the project root.

library(terra)
devtools::load_all(quiet = TRUE)

# Track ids from footprint file names.
track_id <- function(files)
  as.integer(sub(".*-raw-[0-9]{8}-([0-9]+)-.*", "\\1", basename(files)))

# Loss of each storm: its gusts cropped to the assets' grid, at the UK cells.
storm_losses <- function(files, assets, wts, mdd_scale) {
  value <- values(assets, mat = FALSE)[wts$idx]
  vapply(files, function(f) {
    gust <- values(crop(rast(f), assets), mat = FALSE)[wts$idx]
    sum(schwierz_mdr(gust, mdd_scale = mdd_scale) * value, na.rm = TRUE)
  }, numeric(1), USE.NAMES = FALSE)
}

target <- "inst/extdata/uk_storm_losses.csv"
cover_file <- "inst/extdata/uk_nuts1_cover.tif"
assets_file <- "inst/extdata/uk_litpop_025deg.tif"
files <- list.files("data-raw/footprints/nc", pattern = "\\.nc$",
                    full.names = TRUE)

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!all(file.exists(c(cover_file, assets_file)))) {
  message(cover_file, " or ", assets_file, " not found; run ",
          "inst/scripts/extdata/uk_litpop_025deg.R, then uk_nuts1_cover.R.")
} else if (length(files) == 0) {
  message("No footprint files in data-raw/footprints/nc; run ",
          "inst/scripts/data-raw/unzip_footprints.sh first.")
} else if (!compareGeom(crop(rast(files[1]), rast(assets_file)),
                        rast(assets_file), stopOnError = FALSE)) {
  message(files[1], ", cropped, is not on the grid of ", assets_file,
          "; nothing written.")
} else {
  files <- files[order(track_id(files))]
  wts <- area_weights(cover_file, regions = "UK")
  mdd_scale <- 1
  out <- data.frame(
    track_id = track_id(files),
    loss_usd_mdd1 = storm_losses(files, rast(assets_file), wts, mdd_scale))
  part <- paste0(target, ".part")
  write.csv(out, part, row.names = FALSE)
  file.rename(part, target)
  top <- which.max(out$loss_usd_mdd1)
  bn <- function(x) sprintf("%.3f", x / 1e9)
  message("Wrote ", target, ": ", nrow(out), " storms, ",
          sum(out$loss_usd_mdd1 > 0), " with a loss. The largest is ",
          bn(out$loss_usd_mdd1[top]), " USD bn (track ", out$track_id[top],
          "); Ciara (track 1758) ",
          bn(out$loss_usd_mdd1[out$track_id == 1758]),
          " USD bn, which should be 0.575.")
}
