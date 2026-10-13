# prepare_extdata.R
#
# Writes the small rasters that the Storm Ciara article
# (vignettes/articles/ciara.Rmd) reads from inst/extdata, so that it runs
# without data-raw/. All three are cropped to the extent of the LitPop
# exposure summed to 0.25 degrees, lon -8.875 to 1.875, lat 49.625 to 60.875,
# so they share one grid and the cell numbers from uk_weights() match the
# footprint.
#
#   ciara_footprint_uk.tif  Ciara (track 1758) footprint, maximum gust (m/s)
#   uk_nuts1_cover.tif      UK land fraction per cell, from rasterize_uk.R
#   uk_litpop_025deg.tif    LitPop assets (USD), 6 x 6 cells summed to 0.25
#
# Needs these scripts in inst/scripts/data-raw to have been run:
# unzip_footprints.sh, rasterize_uk.R, download_litpop.sh and
# convert_litpop.py. Writes nothing if any output exists.
# Uses the package functions through devtools::load_all().
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

footprint_file <- paste0("data-raw/footprints/nc/storm_footprint-hodges-raw-",
                         "20200209-1758-original-decontaminated-v1_0.nc")
cover_file <- "data-raw/nuts/uk_nuts1_cover.tif"
litpop_file <- "data-raw/litpop/LitPop_150arcsec_GBR.csv"
out_dir <- "inst/extdata"
data_raw_scripts <- "inst/scripts/data-raw"
out <- file.path(out_dir, c("ciara_footprint_uk.tif", "uk_nuts1_cover.tif",
                            "uk_litpop_025deg.tif"))
names(out) <- c("footprint", "cover", "assets")

if (any(file.exists(out))) {
  message("Already there, so nothing written: ",
          paste(out[file.exists(out)], collapse = ", "),
          ". Delete them to rebuild.")
} else if (!file.exists(footprint_file)) {
  message(footprint_file, " not found; run ",
          file.path(data_raw_scripts, "unzip_footprints.sh"), " first.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run ",
          file.path(data_raw_scripts, "rasterize_uk.R"), " first.")
} else if (!file.exists(litpop_file)) {
  message(litpop_file, " not found; run ",
          file.path(data_raw_scripts, "download_litpop.sh"), ", then ",
          file.path(data_raw_scripts, "convert_litpop.py"), ".")
} else {
  assets <- aggregate(load_litpop_uk(litpop_file), 6, sum, na.rm = TRUE)
  dir.create(out_dir, showWarnings = FALSE)
  write_part(assets, out[["assets"]])
  write_part(crop(rast(footprint_file), assets), out[["footprint"]])
  write_part(crop(rast(cover_file), assets), out[["cover"]])
  wts <- uk_weights(out[["cover"]])
  index <- uk_mean_gust_index(out[["footprint"]], wts)
  message("Written:\n",
          paste(sprintf("  %-24s %5.1f kB", basename(out),
                        file.size(out) / 1e3), collapse = "\n"),
          "\nIndex from these files: ", round(index, 2), " m/s over ",
          length(wts$idx), " cells (the full footprint gives 31.34 over ",
          "750).")
}
