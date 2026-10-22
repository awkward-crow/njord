# download_footprints.R
#
# One footprint per storm (Hodges tracking, original 0.25 deg resolution,
# footprint area) from the CDS dataset sis-european-wind-storm-reanalysis.
# Footprints are requested by storm start date, one request per year-month,
# with the dates taken from the tracks. Run from the project root, after
# download_tracks.R. Requires a CDS key in the keyring (ecmwfr::wf_set_key).
#
# Existing zips are skipped, so the script can be re-run after an
# interruption. Each download is requested as a .part file and renamed to
# its zip only when complete. A month that fails or times out is reported and skipped; re-run
# the script to try it again. Ends with a count of the months downloaded,
# already present, failed and timed out.

library(ecmwfr)

tracks_zip <- "data-raw/reanalysis_tracks_hodges.zip"
dir <- "data-raw/footprints"

zip_name <- function(k) paste0("footprints_hodges_", k, ".zip")

request <- function(k, days, target) list(
    dataset_short_name = "sis-european-wind-storm-reanalysis",
    product = "windstorm_footprint",
    variable = "all",
    tracking_algorithm = "hodges",
    event_aggregation = "single_event",
    windstorm_footprint_resolution = "original",
    spatial_extent = "windstorm_footprint_area",
    year = substr(k, 1, 4),
    month = substr(k, 5, 6),
    day = format(days, "%d"),
    target = target
)

# Download one year-month: "downloaded", "failed" or "timed out".
# wf_request() returns the path it wrote to, or the request itself if it
# timed out. ecmwfr 2 replaces the target's extension with the downloaded
# file's type (".part" becomes ".zip", giving "...zip.zip"), so the file is
# renamed from that path.
download_month <- function(k, days, dir) {
    target <- file.path(dir, zip_name(k))
    part <- paste0(target, ".part")
    got <- tryCatch(wf_request(request(k, days, basename(part)), path = dir),
                    error = function(e) {
                        message("request for ", k, " failed: ",
                                conditionMessage(e))
                        NULL
                    })
    if (length(got) == 1 && is.character(got) && file.exists(got)) {
        file.rename(got, target)
        "downloaded"
    } else {
        unlink(c(part, if (is.character(got)) got))
        if (is.null(got)) "failed" else "timed out"
    }
}

if (!file.exists(tracks_zip)) {
    message(tracks_zip, " not found; run download_tracks.R first.")
} else {
    csv <- grep("\\.csv$", unzip(tracks_zip, list = TRUE)$Name, value = TRUE)
    tracks <- read.csv(unz(tracks_zip, csv))
    starts <- aggregate(time ~ id, tracks, min)
    dates <- unique(as.Date(starts$time))
    ym <- split(dates, format(dates, "%Y%m"))
    todo <- names(ym)[!file.exists(file.path(dir, zip_name(names(ym))))]
    if (length(todo) == 0) {
        message("All ", length(ym), " monthly zips already exist in ", dir, ".")
    } else {
        dir.create(dir, showWarnings = FALSE, recursive = TRUE)
        status <- vapply(todo, function(k) download_month(k, ym[[k]], dir), "")
        missing <- names(status)[status != "downloaded"]
        message(length(ym), " months with storms: ",
                length(ym) - length(todo), " already present, ",
                sum(status == "downloaded"), " downloaded, ",
                sum(status == "failed"), " failed, ",
                sum(status == "timed out"), " timed out.")
        if (length(missing) > 0)
            message("Missing: ", paste(missing, collapse = " "),
                    "\nRe-run to try again. A timed-out request may still be ",
                    "on the CDS requests page; download it from there by hand ",
                    "or delete it before re-running, to avoid a duplicate.")
    }
}
