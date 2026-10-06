# download_nuts.R
#
# NUTS 2021 level 1 region boundaries (1:1 million, lon/lat WGS 84) from
# Eurostat GISCO. The CDS summary indicators use the NUTS 2021 regions, and
# 2021 is the latest NUTS version that includes the UK. The file covers all of
# Europe; the UK regions are picked out later. No account is needed. Run from
# the project root.
#
# An existing file is not downloaded again. The download goes to a .part file
# that is renamed only when complete, so a failed download leaves nothing
# behind. Says whether the file was written, with its size and number of
# regions, or why not.
#
# Administrative boundaries: © EuroGeographics.

url <- paste0("https://gisco-services.ec.europa.eu/distribution/v2/nuts/",
              "geojson/NUTS_RG_01M_2021_4326_LEVL_1.geojson")
dir <- "data-raw/nuts"
target <- file.path(dir, basename(url))

if (file.exists(target)) {
  message(target, " already exists; delete it to download it again.")
} else {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  part <- paste0(target, ".part")
  failed <- function(e) {
    message("Download of ", url, " failed: ", conditionMessage(e),
            "\nNothing written.")
    FALSE
  }
  ok <- tryCatch(download.file(url, part, mode = "wb") == 0,
                 error = failed, warning = failed)
  if (ok) {
    file.rename(part, target)
    message("Wrote ", target, ": ", round(file.size(target) / 2^20, 1),
            " MB, ", nrow(terra::vect(target)), " regions.")
  } else {
    unlink(part)
  }
}
