#' Load the UK LitPop exposure
#'
#' Reads the CLIMADA LitPop exposure for the UK (v3, exponents (1, 1),
#' produced capital, 150 arcsec) from the CSV written by
#' `inst/scripts/convert_litpop.py`, and places it on a 150 arcsec grid
#' covering the outer edges of the ERA5 UK box (longitude -8.875 to 1.875,
#' latitude 49.625 to 60.875). Each 0.25 degree hazard cell holds exactly
#' 6 x 6 LitPop cells. Cells without a LitPop point are NA.
#'
#' @param path Path to the LitPop CSV (columns `latitude`, `longitude`,
#'   `value`).
#' @return A one-layer SpatRaster `asset_value_usd`, asset value in USD.
#' @export
load_litpop_uk <- function(path) {
  points <- utils::read.csv(path)
  # EPSG:4326 = WGS 84 latitude/longitude in degrees, the CRS of the LitPop
  # data; the CSV doesn't record it (see inst/scripts/convert_litpop.py).
  template <- terra::rast(xmin = -8.875, xmax = 1.875, ymin = 49.625,
                          ymax = 60.875, resolution = 1 / 24,
                          crs = "EPSG:4326")
  litpop <- terra::rasterize(as.matrix(points[c("longitude", "latitude")]),
                             template, values = points$value, fun = "sum")
  names(litpop) <- "asset_value_usd"
  litpop
}
