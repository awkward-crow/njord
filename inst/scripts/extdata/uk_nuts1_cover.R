# uk_nuts1_cover.R
#
# Writes inst/extdata/uk_nuts1_cover.tif: the NUTS1 land cover raster from
# inst/scripts/data-raw/rasterize_uk.R, cropped to the grid of
# inst/extdata/uk_litpop_025deg.tif. It keeps all 13 layers, one per NUTS1
# region (UKC to UKN) and one for the whole UK (UK), each the fraction of
# every 0.25 degree cell that is land in that region, NA where there is none.
# area_weights() and exposure_weights() read it, and their cell numbers are
# on its grid, which is the grid of every raster in inst/extdata.
#
# Needs inst/scripts/data-raw/rasterize_uk.R and
# inst/scripts/extdata/uk_litpop_025deg.R to have been run; says so and does
# nothing if either input is missing. Writes nothing if the cropped cover is
# not on the assets raster's grid, or if it has fewer cells with UK land than
# the full cover. An existing output file is not made again. The raster is
# written to a .part file and renamed when complete.
#
# Run from the project root.

library(terra)

# Write a GeoTIFF through a .part file, so a failed write leaves nothing.
write_part <- function(x, path) {
  part <- paste0(path, ".part")
  writeRaster(x, part, filetype = "GTiff")
  file.rename(part, path)
}

# Number of cells with some UK land.
uk_cells <- function(cover) sum(values(cover[["UK"]], mat = FALSE) > 0,
                                na.rm = TRUE)

target <- "inst/extdata/uk_nuts1_cover.tif"
cover_file <- "data-raw/nuts/uk_nuts1_cover.tif"
assets_file <- "inst/extdata/uk_litpop_025deg.tif"

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run ",
          "inst/scripts/data-raw/rasterize_uk.R first.")
} else if (!file.exists(assets_file)) {
  message(assets_file, " not found; run ",
          "inst/scripts/extdata/uk_litpop_025deg.R first.")
} else {
  cover <- rast(cover_file)
  cropped <- crop(cover, rast(assets_file))
  if (!compareGeom(cropped, rast(assets_file), stopOnError = FALSE)) {
    message(cover_file, ", cropped, is not on the grid of ", assets_file,
            "; nothing written.")
  } else if (uk_cells(cropped) < uk_cells(cover)) {
    message("Cropping to ", assets_file, " leaves ", uk_cells(cropped),
            " of the ", uk_cells(cover), " cells with UK land; ",
            "nothing written.")
  } else {
    write_part(cropped, target)
    message("Wrote ", target, " (", sprintf("%.1f", file.size(target) / 1e3),
            " kB): ", nlyr(cropped), " layers, ", nrow(cropped), " x ",
            ncol(cropped), " cells, ", uk_cells(cropped),
            " with UK land, as on the full grid.")
  }
}
