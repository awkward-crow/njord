# burns_day_footprint.R
#
# Writes inst/extdata/burns_day_footprint.tif: the footprint of the Burns'
# Day storm (January 1990, track 1070), the maximum 10 m gust in m/s over its
# 72-hour window, on the full footprint grid, 0.25 degree cells from 25W to
# 35E and 30N to 70N, uncropped. vignettes/articles/storm-footprints.Rmd
# reads it. Unlike the other rasters in inst/extdata it is not on the UK
# grid.
#
# Needs inst/scripts/data-raw/unzip_footprints.sh to have been run; says so
# and does nothing if the footprint is missing. Writes nothing if the
# footprint is not 161 x 241 cells, or if the written values differ from the
# footprint's. An existing output file is not made again. The raster is
# written to a .part file and renamed when complete.
#
# Run from the project root.

library(terra)

target <- "inst/extdata/burns_day_footprint.tif"
footprint_file <- paste0("data-raw/footprints/nc/storm_footprint-hodges-raw-",
                         "19900124-1070-original-decontaminated-v1_0.nc")
grid_dim <- c(161, 241)
data_raw_scripts <- "inst/scripts/data-raw"

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(footprint_file)) {
  message(footprint_file, " not found; run ",
          file.path(data_raw_scripts, "unzip_footprints.sh"), " first.")
} else {
  footprint <- rast(footprint_file)
  part <- paste0(target, ".part")
  if (!identical(dim(footprint)[1:2], grid_dim)) {
    message(footprint_file, " is ", nrow(footprint), " x ", ncol(footprint),
            " cells, not ", grid_dim[1], " x ", grid_dim[2],
            "; nothing written.")
  } else {
    writeRaster(footprint, part, filetype = "GTiff")
    v <- values(footprint, mat = FALSE)
    if (!identical(values(rast(part), mat = FALSE), v)) {
      file.remove(part)
      message("The written values differ from those of ", footprint_file,
              "; nothing written.")
    } else {
      file.rename(part, target)
      message("Wrote ", target, " (", sprintf("%.1f", file.size(target) / 1e3),
              " kB): ", nrow(footprint), " x ", ncol(footprint), " cells, ",
              sum(!is.na(v)), " with a value. Highest gust ",
              round(max(v, na.rm = TRUE), 1), " m/s.")
    }
  }
}
