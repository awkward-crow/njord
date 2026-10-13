#' UK cell weights for the trigger index
#'
#' Cells of the footprint grid that cover some UK land, and their weights
#' for an area-weighted mean: the UK land cover fraction times the cosine of
#' the cell's latitude, which is proportional to the cell's area. Computed
#' once, before a loop over storms with [uk_mean_gust_index()].
#'
#' @param cover_path Path to the cover raster written by
#'   `inst/scripts/data-raw/rasterize_uk.R`; its layer `UK` is the fraction
#'   of each 0.25 degree footprint cell that is UK land, NA outside the UK.
#' @return A list: `idx`, the cell numbers with UK cover, and `weight`, the
#'   weight of each of those cells.
#' @export
uk_weights <- function(cover_path = "data-raw/nuts/uk_nuts1_cover.tif") {
  cover <- terra::rast(cover_path)[["UK"]]
  share <- terra::values(cover, mat = FALSE)
  idx <- which(share > 0)
  list(idx = idx,
       weight = cos(terra::yFromCell(cover, idx) * pi / 180) * share[idx])
}

#' UK-wide mean gust of one storm
#'
#' The trigger index: the footprint gust averaged over the UK, weighted by
#' [uk_weights()]. Cells with no gust value (more than 1000 km from the
#' track) are left out, so a storm with no UK values gives NaN.
#'
#' @param nc_path Path to one storm's footprint NetCDF file.
#' @param wts The list returned by [uk_weights()].
#' @return The weighted mean gust (m/s).
#' @export
uk_mean_gust_index <- function(nc_path, wts) {
  v <- terra::values(terra::rast(nc_path), mat = FALSE)[wts$idx]
  sum(v * wts$weight, na.rm = TRUE) / sum(wts$weight[!is.na(v)])
}
