# download_tracks.R
#
# All storm tracks (Hodges tracking) from the CDS dataset
# sis-european-wind-storm-reanalysis, in one request. Run from the project root.
# Requires a CDS key in the keyring (ecmwfr::wf_set_key).
#
# An existing file is not downloaded again. The download is requested as a
# .part file and renamed to the target only when complete, so a failed or
# timed-out request leaves nothing behind. Says whether the file was written, with the number of storms
# and their date range, or why not.

library(ecmwfr)

dir <- "data-raw"
target <- file.path(dir, "reanalysis_tracks_hodges.zip")
part <- paste0(target, ".part")

request_tracks <- list(
  dataset_short_name = "sis-european-wind-storm-reanalysis",
  product = "windstorm_track",
  variable = "all",
  tracking_algorithm = "hodges",
  event_aggregation = "all_events",
  target = basename(part)
)

if (file.exists(target)) {
  message(target, " already exists; delete it to download it again.")
} else {
  dir.create(dir, showWarnings = FALSE)
  # wf_request() returns the path it wrote to. ecmwfr 2 replaces the
  # target's extension with the downloaded file's type (".part" becomes
  # ".zip", giving "...zip.zip"), so the file is renamed from that path.
  got <- tryCatch(wf_request(request_tracks, path = dir),
                  error = function(e) {
                    message("Request failed: ", conditionMessage(e))
                    NULL
                  })
  if (length(got) == 1 && is.character(got) && file.exists(got)) {
    file.rename(got, target)
    csv <- grep("\\.csv$", unzip(target, list = TRUE)$Name, value = TRUE)
    tracks <- read.csv(unz(target, csv))
    days <- as.Date(range(tracks$time))
    message("Wrote ", target, " (", csv, "): ", length(unique(tracks$id)),
            " storms, ", days[1], " to ", days[2], ".")
  } else {
    unlink(c(part, if (is.character(got)) got))
    message("Nothing written. If the request timed out, it may still be ",
            "on the CDS requests page.")
  }
}
