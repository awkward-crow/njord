# uk_mean_gust_catalogue.R
#
# One row per storm with the UK mean gust trigger index
# (weighted_mean_index()): the footprint gust averaged over the UK, weighted
# by UK land cover and cell area. Gusts are taken on the grid of the rasters
# in inst/extdata, so every index uses the same UK cells and weights as the
# demos. A storm with no UK values gives NaN.
#
# Needs inst/scripts/data-raw/unzip_footprints.sh and
# inst/scripts/extdata/prepare_extdata.R to have been run; says so and does
# nothing if the footprints or the cover raster are missing, or if the first
# footprint, cropped, is not on the cover raster's grid. An existing output
# file is not made again. The CSV is written to a .part file and renamed
# when complete. Uses the package functions through devtools::load_all().
#
# Run from the project root.

library(terra)
devtools::load_all(quiet = TRUE)

# Track ids from footprint file names.
track_id <- function(files)
  as.integer(sub(".*-raw-[0-9]{8}-([0-9]+)-.*", "\\1", basename(files)))

# Index of each storm: its gusts cropped to the cover's grid.
storm_index <- function(files, cover, wts)
  vapply(files, function(f)
    weighted_mean_index(values(crop(rast(f), cover), mat = FALSE), wts),
    numeric(1), USE.NAMES = FALSE)

target <- "inst/extdata/uk_mean_gust_catalogue.csv"
cover_file <- "inst/extdata/uk_nuts1_cover.tif"
files <- list.files("data-raw/footprints/nc", pattern = "\\.nc$",
                    full.names = TRUE)

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run ",
          "inst/scripts/extdata/prepare_extdata.R first.")
} else if (length(files) == 0) {
  message("No footprint files in data-raw/footprints/nc; run ",
          "inst/scripts/data-raw/unzip_footprints.sh first.")
} else if (!compareGeom(crop(rast(files[1]), rast(cover_file)),
                        rast(cover_file), stopOnError = FALSE)) {
  message(files[1], ", cropped, is not on the grid of ", cover_file,
          "; nothing written.")
} else {
  files <- files[order(track_id(files))]
  wts <- area_weights(cover_file, regions = "UK")
  out <- data.frame(track_id = track_id(files),
                    uk_mean_gust = storm_index(files, rast(cover_file), wts))
  part <- paste0(target, ".part")
  write.csv(out, part, row.names = FALSE)
  file.rename(part, target)
  top <- which.max(out$uk_mean_gust)
  message("Wrote ", target, ": ", nrow(out), " storms, ",
          sum(is.nan(out$uk_mean_gust)), " with no UK values (NaN). ",
          "The highest is ", sprintf("%.2f", out$uk_mean_gust[top]),
          " m/s (track ", out$track_id[top], "); Ciara (track 1758) ",
          sprintf("%.2f", out$uk_mean_gust[out$track_id == 1758]),
          " m/s, which should be 31.34.")
}
