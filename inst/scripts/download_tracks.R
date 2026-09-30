# download_tracks.R
#
# All storm tracks (Hodges tracking) from the CDS dataset
# sis-european-wind-storm-reanalysis, in one request. Run from the project root.
# Requires a CDS key in the keyring (ecmwfr::wf_set_key).

library(ecmwfr)

request_tracks <- list(
  dataset_short_name = "sis-european-wind-storm-reanalysis",
  product = "windstorm_track",
  variable = "all",
  tracking_algorithm = "hodges",
  event_aggregation = "all_events",
  target = "reanalysis_tracks_hodges.zip"
)

wf_request(request_tracks, path = "data-raw")
