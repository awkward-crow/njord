# rasterize_uk.R
#
# The UK NUTS 2021 level 1 regions on the footprint grid. For every grid cell,
# the fraction of the cell covered by each of the 12 UK regions (UKC to UKN),
# plus a layer for the whole UK. Cells with no land in a region are NA in its
# layer. Small islands are kept; a cell counts in proportion to its land.
#
# The grid is taken from a footprint file rather than built from scratch: the
# footprint cell centres are on quarter degrees, so the cell edges are at
# .125 and .375. Needs download_nuts.R and unzip_footprints.sh to have been
# run. An existing output file is not made again. Run from the project root.
#
# Administrative boundaries: © EuroGeographics.

library(terra)

target <- "data-raw/nuts/uk_nuts1_cover.tif"

if (!file.exists(target)) {
  footprint <- list.files("data-raw/footprints/nc", full.names = TRUE)[1]
  grid <- rast(rast(footprint))

  nuts <- vect("data-raw/nuts/NUTS_RG_01M_2021_4326_LEVL_1.geojson")
  uk <- nuts[nuts$CNTR_CODE == "UK", ]
  uk <- project(uk[order(uk$NUTS_ID), ], crs(grid))

  regions <- lapply(seq_len(nrow(uk)),
                    function(i) rasterize(uk[i], grid, cover = TRUE))
  cover <- c(rast(regions), rasterize(aggregate(uk), grid, cover = TRUE))
  names(cover) <- c(uk$NUTS_ID, "UK")

  writeRaster(cover, target)
}
