# download_nuts.R
#
# NUTS 2021 level 1 region boundaries (1:1 million, lon/lat WGS 84) from
# Eurostat GISCO. The CDS summary indicators use the NUTS 2021 regions, and
# 2021 is the latest NUTS version that includes the UK. The file covers all of
# Europe; the UK regions are picked out later. An existing file is not
# downloaded again. Run from the project root. No account is needed.
#
# Administrative boundaries: © EuroGeographics.

url <- paste0("https://gisco-services.ec.europa.eu/distribution/v2/nuts/",
              "geojson/NUTS_RG_01M_2021_4326_LEVL_1.geojson")
target <- file.path("data-raw/nuts", basename(url))

dir.create("data-raw/nuts", showWarnings = FALSE)

if (!file.exists(target)) download.file(url, target, mode = "wb")
