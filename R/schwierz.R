#' Schwierz windstorm vulnerability curve
#'
#' Mean damage ratio (MDR) of residential buildings as a function of the
#' maximum gust speed, after Schwierz et al. (2010),
#' \doi{10.1007/s10584-009-9712-1}. The curve nodes are those of CLIMADA's
#' `ImpfStormEurope.from_schwierz()`; between nodes the mean damage degree
#' (MDD) and the percentage of affected assets (PAA) are interpolated
#' linearly, and held constant beyond 0 and 100 m/s. MDR = MDD x PAA.
#'
#' Only the MDD is scaled, as in the country calibrations of Mishra et al.
#' (2026), \doi{10.5194/egusphere-2026-3099}.
#'
#' @param v Maximum gust speed (m/s).
#' @param mdd_scale Factor applied to the mean damage degree (1 for the
#'   original curve).
#' @return Mean damage ratio, one value per element of `v`.
#' @export
schwierz_mdr <- function(v, mdd_scale) {
  intensity <- c(0, 20, 25, 30, 35, 40, 45, 50, 55, 60, 80, 100)
  mdd <- c(0, 0, 0.001, 0.00177515, 0.00367253, 0.00749977, 0.01263556,
           0.01849639, 0.02370487, 0.037253, 0.037253, 0.037253)
  paa <- c(0, 0, 0.001, 0.00676, 0.03921, 0.10707, 0.25357, 0.48869,
           0.82907, 1, 1, 1)
  node <- function(y) stats::approx(intensity, y, xout = v, rule = 2)$y
  mdd_scale * node(mdd) * node(paa)
}

#' Plot the vulnerability curve
#'
#' Plots [schwierz_mdr()] for gusts of 0 to 80 m/s.
#'
#' @inheritParams schwierz_mdr
#' @return A data frame of `v` and `mdr`, invisibly.
#' @export
plot_vulnerability_curve <- function(mdd_scale) {
  v <- seq(0, 80, by = 0.5)
  mdr <- schwierz_mdr(v, mdd_scale = mdd_scale)
  graphics::plot(v, mdr, type = "l",
                 xlab = "Maximum gust (m/s)", ylab = "Mean damage ratio")
  invisible(data.frame(v, mdr))
}
