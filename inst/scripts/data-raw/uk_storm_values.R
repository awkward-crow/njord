# uk_storm_values.R
#
# One row per storm with the footprint summarised over UK land: the highest
# gust, the land area with gusts above 25 m/s, the mean gust over that area,
# and a storm severity index (SSI) defined as in the CDS summary indicators,
# mean gust cubed times area. Cells count in proportion to their UK land
# cover, and by their area in km², which shrinks with latitude.
#
# The highest gust is taken only over cells that are at least half UK land.
# Cells that are mostly sea are often the windiest, and would otherwise set
# the maximum for most storms. Area, mean gust and SSI use every cell with
# some UK land, weighted by its cover.
#
# Footprint cells that are NaN (more than 1000 km from the track) are left
# out. n_valid counts the UK cells with a value; a storm with none has
# area_25 zero, and a storm with no value in a cell at least half land has
# max_gust NA.
#
# The track start time and the footprint central time (the centre of the 72h
# window the gusts are taken over) are read from each file's header with
# ncdump, as GDAL doesn't show them. Both are UTC, written as "YYYY-MM-DD HH:MM".
#
# Needs unzip_footprints.sh and rasterize_uk.R to have been run; says so and
# does nothing if the footprints or the cover file are missing. An existing
# output file is not made again. Otherwise prints a brief summary of what was
# written. The CSV is written to a .part file and renamed when complete. Run
# from the project root.

library(terra)

# Start date (part 2) or track id (part 3) from footprint file names.
name_part <- function(files, part) {
  parts <- regmatches(basename(files),
                      regexec("-raw-([0-9]{8})-([0-9]+)-", basename(files)))
  vapply(parts, `[`, "", part)
}

ncdump_header <- function(file)
  system2("ncdump", c("-h", shQuote(file)), stdout = TRUE)

# Each time is stored as zero "days since" the time itself.
header_time <- function(header, variable) {
  units <- grep(paste0("\\b", variable, ":units"), header, value = TRUE)
  as.POSIXct(sub('.*since ([^"]+)".*', "\\1", units),
             format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
}

header_times <- function(headers, variable)
  do.call(c, lapply(headers, header_time, variable))

# Summaries of one storm's gusts over the UK cells.
gust_summary <- function(gust, weight, land, threshold) {
  valid <- !is.na(gust)
  above <- valid & gust > threshold
  area <- sum(weight[above])
  mean_gust <- if (area > 0) sum(gust[above] * weight[above]) / area else NA
  setNames(c(sum(valid),
             if (any(valid & land)) max(gust[valid & land]) else NA,
             area,
             mean_gust,
             if (area > 0) mean_gust^3 * area else 0),
           c("n_valid", "max_gust", paste0(c("area_", "mean_gust_"), threshold),
             "ssi"))
}

uk_storm_values <- function(files, cover, threshold, min_cover) {
  share <- values(cover, mat = FALSE)
  uk <- which(!is.na(share))
  weight <- share[uk] * values(cellSize(cover, unit = "km"), mat = FALSE)[uk]
  land <- share[uk] >= min_cover
  headers <- lapply(files, ncdump_header)
  data.frame(
    track_id = as.integer(name_part(files, 3)),
    start_date = as.Date(name_part(files, 2), format = "%Y%m%d"),
    start_time = header_times(headers, "track_start_time"),
    central_time = header_times(headers, "footprint_central_time"),
    do.call(rbind, lapply(files, function(file)
      gust_summary(values(rast(file), mat = FALSE)[uk], weight, land,
                   threshold)))
  )
}

target <- "data-raw/uk_storm_values.csv"
cover_file <- "data-raw/nuts/uk_nuts1_cover.tif"
files <- list.files("data-raw/footprints/nc", pattern = "\\.nc$",
                    full.names = TRUE)

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(cover_file)) {
  message(cover_file, " not found; run rasterize_uk.R first.")
} else if (length(files) == 0) {
  message("No footprint files in data-raw/footprints/nc; ",
          "run unzip_footprints.sh first.")
} else {
  files <- files[order(as.integer(name_part(files, 3)))]
  cover <- rast(cover_file)[["UK"]]
  threshold <- 25
  min_cover <- 0.5
  out <- uk_storm_values(files, cover, threshold, min_cover)
  out$start_time <- format(out$start_time, "%Y-%m-%d %H:%M")
  out$central_time <- format(out$central_time, "%Y-%m-%d %H:%M")
  part <- paste0(target, ".part")
  write.csv(out, part, row.names = FALSE)
  file.rename(part, target)
  top <- which.max(out$max_gust)
  message("Wrote ", target, ": ", nrow(out), " storms starting ",
          min(out$start_date), " to ", max(out$start_date), ".\n",
          sum(out$n_valid > 0), " have UK values; ",
          sum(out$max_gust > threshold, na.rm = TRUE),
          " have a max gust above ", threshold, " m/s; the highest is ",
          round(out$max_gust[top], 1), " m/s (track ", out$track_id[top], ").")
}
