#' Area weights for a weighted mean index
#'
#' Cells of the footprint grid that cover some land in the given NUTS1
#' regions, and their weights for an area-weighted mean: the fraction of the
#' cell that is land in those regions times the cosine of the cell's
#' latitude, which is proportional to the cell's area. A cell on a border
#' counts in each region by its own land fraction. Computed once, before a
#' loop over storms with [weighted_mean_index()].
#'
#' @param cover_path Path to a cover raster, as written by
#'   `inst/scripts/data-raw/rasterize_uk.R` or its crop in `inst/extdata`:
#'   one layer per NUTS1 region (`UKC` to `UKN`) and one for the whole UK
#'   (`UK`), each the fraction of every 0.25 degree footprint cell that is
#'   land in that region, NA where there is none.
#' @param regions Names of the cover layers to sum, e.g. `"UK"`, `"UKM"`
#'   (Scotland) or `paste0("UK", LETTERS[3:12])` (England and Wales).
#' @return A list: `idx`, the cell numbers with land in the regions, and
#'   `weight`, the weight of each of those cells.
#' @export
area_weights <- function(cover_path, regions) {
  cover <- terra::rast(cover_path)
  share <- region_share(cover, regions)
  idx <- which(share > 0)
  list(idx = idx,
       weight = cos(terra::yFromCell(cover, idx) * pi / 180) * share[idx])
}

#' Exposure weights for a weighted mean index
#'
#' Cells of the footprint grid that hold assets in the given NUTS1 regions,
#' and their weights for an exposure-weighted mean: the value of the assets
#' in the regions. A cell's assets are split between regions by their shares
#' of its UK land, as if spread evenly over that land, so a cell on a border
#' counts in each region by its share. Computed once, before a loop over
#' storms with [weighted_mean_index()].
#'
#' @param assets_path Path to an asset raster on the same grid as the cover
#'   raster, e.g. `uk_litpop_025deg.tif` in `inst/extdata`: the value of the
#'   UK assets in each cell, NA where there are none.
#' @inheritParams area_weights
#' @return A list: `idx`, the cell numbers with assets in the regions, and
#'   `weight`, the value of those assets in each of those cells.
#' @export
exposure_weights <- function(cover_path, assets_path, regions) {
  cover <- terra::rast(cover_path)
  # The assets are UK assets only, so a cell's assets lie on its UK land (the
  # "UK" layer); the regions' share of that land is their share of the
  # assets. Outside the UK this is 0/0, NaN, and the cell drops out below.
  share <- region_share(cover, regions) / region_share(cover, "UK")
  w <- terra::values(terra::rast(assets_path), mat = FALSE) * share
  idx <- which(w > 0)
  list(idx = idx, weight = w[idx])
}

# Fraction of each cell that is land in any of the regions (0 if none).
region_share <- function(cover, regions)
  rowSums(terra::values(cover[[regions]], mat = TRUE), na.rm = TRUE)

#' Weighted mean index
#'
#' The trigger index: gusts averaged over the cells of `wts`, with its
#' weights, e.g. from [area_weights()]. Cells with no gust value (more than
#' 1000 km from the track) are left out, so a storm with no values in those
#' cells gives NaN.
#'
#' @param gust Gust values (m/s) of every cell of the grid `wts` was made
#'   on, in cell order.
#' @param wts A list: `idx`, cell numbers, and `weight`, the weight of each
#'   of those cells, as returned by [area_weights()].
#' @return The weighted mean gust (m/s).
#' @export
weighted_mean_index <- function(gust, wts) {
  v <- gust[wts$idx]
  sum(v * wts$weight, na.rm = TRUE) / sum(wts$weight[!is.na(v)])
}
