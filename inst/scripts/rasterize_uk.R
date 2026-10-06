# rasterize_uk.R
#
# The UK NUTS 2021 level 1 regions on the footprint grid. For every grid cell,
# the fraction of the cell covered by each of the 12 UK regions (UKC to UKN),
# plus a layer for the whole UK. Cells with no land in a region are NA in its
# layer. Small islands are kept; a cell counts in proportion to its land.
#
# The grid is taken from a footprint file rather than built from scratch: the
# footprint cell centres are on quarter degrees, so the cell edges are at
# .125 and .375. Run from the project root.
#
# Needs download_nuts.R and unzip_footprints.sh to have been run; says so and
# does nothing if either input is missing. An existing output file is not
# made again. The raster is written to a .part file and renamed when
# complete. Says what was written: the layers, the number of cells with UK
# land and the UK area.
#
# Administrative boundaries: © EuroGeographics.

library(terra)

target <- "data-raw/nuts/uk_nuts1_cover.tif"
nuts_file <- "data-raw/nuts/NUTS_RG_01M_2021_4326_LEVL_1.geojson"
footprints <- list.files("data-raw/footprints/nc", pattern = "\\.nc$",
                         full.names = TRUE)

# Fraction of each grid cell covered by each UK region, and by the whole UK.
uk_cover <- function(nuts, grid) {
  uk <- nuts[nuts$CNTR_CODE == "UK", ]
  uk <- project(uk[order(uk$NUTS_ID), ], crs(grid))
  regions <- lapply(seq_len(nrow(uk)),
                    function(i) rasterize(uk[i], grid, cover = TRUE))
  cover <- c(rast(regions), rasterize(aggregate(uk), grid, cover = TRUE))
  names(cover) <- c(uk$NUTS_ID, "UK")
  cover
}

if (file.exists(target)) {
  message(target, " already exists; delete it to make it again.")
} else if (!file.exists(nuts_file)) {
  message(nuts_file, " not found; run download_nuts.R first.")
} else if (length(footprints) == 0) {
  message("No footprint files in data-raw/footprints/nc; ",
          "run unzip_footprints.sh first.")
} else {
  cover <- uk_cover(vect(nuts_file), rast(rast(footprints[1])))
  part <- paste0(target, ".part")
  writeRaster(cover, part, filetype = "GTiff")
  file.rename(part, target)
  share <- values(cover[["UK"]], mat = FALSE)
  km2 <- values(cellSize(cover, unit = "km"), mat = FALSE)
  message("Wrote ", target, ": ", nlyr(cover), " layers (",
          paste(names(cover), collapse = " "), "); ",
          sum(!is.na(share)), " cells with UK land, ",
          round(sum(share * km2, na.rm = TRUE)), " km².")
}
