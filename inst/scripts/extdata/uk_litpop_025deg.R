# uk_litpop_025deg.R
#
# Writes inst/extdata/uk_litpop_025deg.tif: the CLIMADA LitPop assets of the
# UK in USD, summed from LitPop's 150 arcsecond cells to the 0.25 degree
# footprint grid, 6 x 6 LitPop cells to each footprint cell. The extent is
# that of load_litpop_uk(), lon -8.875 to 1.875, lat 49.625 to 60.875, whose
# edges are footprint cell edges, so the sum keeps the total exactly. This is
# the grid of every raster in inst/extdata: uk_nuts1_cover.R crops the cover
# to it, and ciara_footprint_uk.R crops the footprint to the cover.
#
# Needs inst/scripts/data-raw/download_litpop.sh and convert_litpop.py to
# have been run; says so and does nothing if the LitPop CSV is missing. An
# existing output file is not made again. The raster is written to a .part
# file and renamed when complete. Uses load_litpop_uk() through
# devtools::load_all().
#
# Run from the project root.

library(terra)
devtools::load_all(quiet = TRUE)

# Write a GeoTIFF through a .part file, so a failed write leaves nothing.
write_part <- function(x, path) {
  part <- paste0(path, ".part")
  writeRaster(x, part, filetype = "GTiff")
  file.rename(part, path)
}

# Sum of a raster's cells.
total <- function(r) global(r, "sum", na.rm = TRUE)[[1]]

target <- "inst/extdata/uk_litpop_025deg.tif"
litpop_file <- "data-raw/litpop/LitPop_150arcsec_GBR.csv"
data_raw_scripts <- "inst/scripts/data-raw"
fact <- 6  # 150 arcsec LitPop cells to each 0.25 degree footprint cell

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(litpop_file)) {
  message(litpop_file, " not found; run ",
          file.path(data_raw_scripts, "download_litpop.sh"), ", then ",
          file.path(data_raw_scripts, "convert_litpop.py"), ".")
} else {
  litpop <- load_litpop_uk(litpop_file)
  assets <- aggregate(litpop, fact, sum, na.rm = TRUE)
  dir.create(dirname(target), showWarnings = FALSE)
  write_part(assets, target)
  v <- values(assets, mat = FALSE)
  message("Wrote ", target, " (", sprintf("%.1f", file.size(target) / 1e3),
          " kB): ", nrow(assets), " x ", ncol(assets), " cells, ",
          sum(v > 0, na.rm = TRUE), " with assets, USD ",
          sprintf("%.1f", total(assets) / 1e9), " bn in all; the LitPop ",
          "cells differ from that by USD ",
          signif(total(assets) - total(litpop), 3), ".")
}
