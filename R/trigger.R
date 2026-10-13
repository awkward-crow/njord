#' UK cell weights for the trigger index
#'
#' Cells of the footprint grid that cover some UK land, and their weights
#' for an area-weighted mean: the UK land cover fraction times the cosine of
#' the cell's latitude, which is proportional to the cell's area. Computed
#' once, before a loop over storms with [compute_index()].
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
compute_index <- function(nc_path, wts) {
  v <- terra::values(terra::rast(nc_path), mat = FALSE)[wts$idx]
  sum(v * wts$weight, na.rm = TRUE) / sum(wts$weight[!is.na(v)])
}

#' Linear ramp payout
#'
#' Nothing below the attachment, the full limit above the exhaustion, and a
#' straight line between them. All arguments are recycled.
#'
#' @param index Trigger index value(s).
#' @param attachment Index value at which the payout starts.
#' @param exhaustion Index value at which the payout reaches the limit.
#' @param limit Maximum payout.
#' @return The payout, one value per element of `index`.
#' @export
payout <- function(index, attachment, exhaustion, limit) {
  limit * pmin(1, pmax(0, (index - attachment) / (exhaustion - attachment)))
}

#' Calibrate the trigger to loss return periods
#'
#' Sets the attachment to the lowest index among the storms whose loss
#' exceeds the loss with return period `attach_rp`, and the exhaustion
#' likewise for `exhaust_rp`. The trigger is tied to loss exceedances, not to
#' quantiles of the index. With `events_per_year` storms a year, the loss with
#' return period `rp` years is the `1 - 1 / (rp * events_per_year)` quantile
#' of the storm losses.
#'
#' @param index_vec Named vector of trigger index values, one per storm.
#' @param loss_vec Named vector of modelled losses as a fraction of the total
#'   insured value, matched to `index_vec` by name.
#' @param attach_rp Return period (years) of the loss at attachment.
#' @param exhaust_rp Return period (years) of the loss at exhaustion.
#' @param events_per_year Mean number of storms a year in the catalogue.
#' @return A list: `attachment`, `exhaustion`, `attach_rp`, `exhaust_rp`.
#' @export
calibrate_trigger <- function(index_vec, loss_vec, attach_rp = 5,
                              exhaust_rp = 20, events_per_year) {
  loss <- loss_vec[names(index_vec)]
  level <- function(rp)
    min(index_vec[loss > stats::quantile(loss, 1 - 1 / (rp * events_per_year))])
  list(attachment = level(attach_rp), exhaustion = level(exhaust_rp),
       attach_rp = attach_rp, exhaust_rp = exhaust_rp)
}

#' Basis risk per storm
#'
#' The payout of the linear ramp against the modelled loss, storm by storm.
#' Losses are matched to `index_vec` by name. The limit is in the units of
#' the losses, a fraction of the total insured value.
#'
#' @inheritParams calibrate_trigger
#' @inheritParams payout
#' @return A data frame with one row per storm: `event` (the names of
#'   `index_vec`), `index`, `loss`, `payout`, and `basis_risk`, payout minus
#'   loss (positive when the payout exceeds the loss).
#' @export
basis_risk <- function(index_vec, loss_vec, attachment, exhaustion,
                       limit = 1) {
  loss <- unname(loss_vec[names(index_vec)])
  paid <- payout(unname(index_vec), attachment, exhaustion, limit)
  data.frame(event = names(index_vec), index = unname(index_vec),
             loss = loss, payout = paid, basis_risk = paid - loss)
}
