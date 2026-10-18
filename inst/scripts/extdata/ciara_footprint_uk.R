# ciara_footprint_uk.R
#
# Writes inst/extdata/ciara_footprint_uk.tif: the footprint of Storm Ciara
# (February 2020, track 1758), the maximum 10 m gust in m/s over its 72-hour
# window, cropped to the grid of inst/extdata/uk_nuts1_cover.tif, so that
# its cells match the cell numbers of area_weights() and exposure_weights().
# inst/demos/ciara_demo.R and vignettes/articles/ciara.Rmd read it.
#
# Needs inst/scripts/data-raw/unzip_footprints.sh, rasterize_uk.R and
# inst/scripts/extdata/uk_nuts1_cover.R to have been run; says so and does
# nothing if the footprint or either cover raster is missing. Writes nothing
# if the cropped footprint is not on the cover's grid, or if its values at
# the cells with UK land differ from those of the full footprint at the full
# cover's. An existing output file is not made again. The raster is written
# to a .part file and renamed when complete.
#
# Run from the project root.

library(terra)

# Write a GeoTIFF through a .part file, so a failed write leaves nothing.
write_part <- function(x, path) {
  part <- paste0(path, ".part")
  writeRaster(x, part, filetype = "GTiff")
  file.rename(part, path)
}

# Footprint values at the cells with UK land, in cell order.
uk_values <- function(footprint, cover)
  values(footprint, mat = FALSE)[which(values(cover[["UK"]], mat = FALSE) > 0)]

target <- "inst/extdata/ciara_footprint_uk.tif"
footprint_file <- paste0("data-raw/footprints/nc/storm_footprint-hodges-raw-",
                         "20200209-1758-original-decontaminated-v1_0.nc")
full_cover_file <- "data-raw/nuts/uk_nuts1_cover.tif"
cover_file <- "inst/extdata/uk_nuts1_cover.tif"
data_raw_scripts <- "inst/scripts/data-raw"

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(footprint_file)) {
  message(footprint_file, " not found; run ",
          file.path(data_raw_scripts, "unzip_footprints.sh"), " first.")
} else if (!file.exists(full_cover_file)) {
  message(full_cover_file, " not found; run ",
          file.path(data_raw_scripts, "rasterize_uk.R"), " first.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run ",
          "inst/scripts/extdata/uk_nuts1_cover.R first.")
} else {
  footprint <- rast(footprint_file)
  cropped <- crop(footprint, rast(cover_file))
  uk <- uk_values(cropped, rast(cover_file))
  if (!compareGeom(cropped, rast(cover_file), stopOnError = FALSE)) {
    message(footprint_file, ", cropped, is not on the grid of ", cover_file,
            "; nothing written.")
  } else if (!identical(uk, uk_values(footprint, rast(full_cover_file)))) {
    message("The cropped footprint's values at the cells with UK land ",
            "differ from the full footprint's; nothing written.")
  } else {
    write_part(cropped, target)
    message("Wrote ", target, " (", sprintf("%.1f", file.size(target) / 1e3),
            " kB): ", nrow(cropped), " x ", ncol(cropped), " cells, the ",
            length(uk), " with UK land unchanged from the full footprint. ",
            "Highest gust there ", round(max(uk, na.rm = TRUE), 1), " m/s.")
  }
}
