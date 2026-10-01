# uk_storm_values.R
#
# One row per storm with the footprint summarised over UK land: the highest
# gust, the land area with gusts above 25 m/s, the mean gust over that area,
# and a storm severity index (SSI) defined as in the CDS summary indicators,
# mean gust cubed times area. Cells count in proportion to their UK land
# cover, and by their area in km², which shrinks with latitude.
#
# Footprint cells that are NaN (more than 1000 km from the track) are left
# out. n_valid counts the UK cells with a value; a storm with none has
# max_gust NA and area_25 zero.
#
# Needs unzip_footprints.sh and rasterize_uk.R to have been run. An existing
# output file is not made again. Run from the project root.

library(terra)

target <- "data-raw/uk_storm_values.csv"
threshold <- 25

if (!file.exists(target)) {
  cover <- rast("data-raw/nuts/uk_nuts1_cover.tif")[["UK"]]
  uk <- which(!is.na(values(cover, mat = FALSE)))
  weight <- values(cover, mat = FALSE)[uk] *
    values(cellSize(cover, unit = "km"), mat = FALSE)[uk]

  files <- list.files("data-raw/footprints/nc", pattern = "\\.nc$",
                      full.names = TRUE)
  parts <- regmatches(basename(files),
                      regexec("-raw-([0-9]{8})-([0-9]+)-", basename(files)))

  columns <- c("n_valid", "max_gust", "area_25", "mean_gust_25", "ssi")

  storm <- function(file) {
    gust <- values(rast(file), mat = FALSE)[uk]
    valid <- !is.na(gust)
    above <- valid & gust > threshold
    area <- sum(weight[above])
    mean_gust <- if (area > 0) sum(gust[above] * weight[above]) / area else NA
    c(sum(valid),
      if (any(valid)) max(gust[valid]) else NA,
      area,
      mean_gust,
      if (area > 0) mean_gust^3 * area else 0)
  }

  values <- t(vapply(files, storm, numeric(5), USE.NAMES = FALSE))
  colnames(values) <- columns

  out <- data.frame(
    track_id = as.integer(vapply(parts, `[`, "", 3)),
    start_date = as.Date(vapply(parts, `[`, "", 2), format = "%Y%m%d"),
    values
  )
  out <- out[order(out$track_id), ]

  write.csv(out, target, row.names = FALSE)
}
