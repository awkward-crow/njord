# download_footprints.R
#
# One footprint per storm (Hodges tracking, original 0.25 deg resolution,
# footprint area) from the CDS dataset sis-european-wind-storm-reanalysis.
# Footprints are requested by storm start date, one request per year-month,
# with the dates taken from the tracks. Existing zips are skipped, so the
# script can be re-run after an interruption. Run from the project root,
# after download_tracks.R. Requires a CDS key in the keyring
# (ecmwfr::wf_set_key).

library(ecmwfr)

tracks <- read.csv(unz("data-raw/reanalysis_tracks_hodges.zip",
        "storm_track-hodges-raw-194001_202607-all-v1_0.csv"))
starts <- aggregate(time ~ id, tracks, min)
starts$date <- as.Date(starts$time)
dates <- unique(starts$date)
ym <- split(dates, format(dates, "%Y%m"))

dir.create("data-raw/footprints", showWarnings = FALSE)

for (k in names(ym)) {
    target <- paste0("footprints_hodges_", k, ".zip")
    if (file.exists(file.path("data-raw/footprints", target))) next
    req <- list(
        dataset_short_name = "sis-european-wind-storm-reanalysis",
        product = "windstorm_footprint",
        variable = "all",
        tracking_algorithm = "hodges",
        event_aggregation = "single_event",
        windstorm_footprint_resolution = "original",
        spatial_extent = "windstorm_footprint_area",
        year = substr(k, 1, 4),
        month = substr(k, 5, 6),
        day = format(ym[[k]], "%d"),
        target = target
    )
    wf_request(req, path = "data-raw/footprints")
}
