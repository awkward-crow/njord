#' Schwierz windstorm vulnerability curve
#'
#' Mean damage ratio (MDR) of residential buildings as a function of the
#' maximum gust speed, after Schwierz et al. (2010),
#' \doi{10.1007/s10584-009-9712-1}. The curve nodes are those of CLIMADA's
#' `ImpfStormEurope.from_schwierz()`; between nodes the mean damage degree
#' (MDD) and the percentage of affected assets (PAA) are interpolated
#' linearly, and held constant beyond 0 and 100 m/s. MDR = MDD x PAA.
#'
#' The scaled PAA is clipped at 1, as in CLIMADA's calibration. CLIMADA first
#' resamples the curve to 131 evenly spaced points, which smooths the bends
#' at 25, 35, 45 and 55 m/s; here the nodes are scaled directly, so the two
#' differ by up to about 1.4% within 0.4 m/s of those bends. See Welker et
#' al. (2021) for details of the calibration.
#'
#' @param v Maximum gust speed (m/s).
#' @param mdd_scale Factor applied to the mean damage degree (1 for the
#'   original curve).
#' @param paa_scale Factor applied to the percentage of affected assets (1
#'   for the original curve).
#' @return Mean damage ratio, one value per element of `v`.
#' @export
schwierz_mdr <- function(v, mdd_scale, paa_scale) {
  intensity <- c(0, 20, 25, 30, 35, 40, 45, 50, 55, 60, 80, 100)
  mdd <- c(0, 0, 0.001, 0.00177515, 0.00367253, 0.00749977, 0.01263556,
           0.01849639, 0.02370487, 0.037253, 0.037253, 0.037253)
  paa <- c(0, 0, 0.001, 0.00676, 0.03921, 0.10707, 0.25357, 0.48869,
           0.82907, 1, 1, 1)
  node <- function(y) stats::approx(intensity, y, xout = v, rule = 2)$y
  mdd_scale * node(mdd) * pmin(1, paa_scale * node(paa))
}

#' Welker windstorm vulnerability curve
#'
#' The Schwierz curve calibrated for Switzerland by Welker et al. (2021),
#' \doi{10.5194/nhess-21-279-2021}: MDD and PAA both scaled by 1.332518, as
#' in CLIMADA's `ImpfStormEurope.from_welker()`. See [schwierz_mdr()].
#'
#' The scaled PAA reaches its clip at 1 at about 53.9 m/s, which gives a
#' visible kink in the curve there.
#'
#' @inheritParams schwierz_mdr
#' @return Mean damage ratio, one value per element of `v`.
#' @export
welker_mdr <- function(v) {
  schwierz_mdr(v, mdd_scale = 1.332518, paa_scale = 1.332518)
}

#' UK windstorm vulnerability curve
#'
#' The Schwierz curve with the MDD scaled by 1.07 for the UK.
#'
#' Source: Mishra et al. (2026), preprint egusphere-2026-3099,
#' https://doi.org/10.5194/egusphere-2026-3099 (DOI not yet checked). The
#' factor and whether it applies to the PAA as well are still to be checked
#' against the paper's results table.
#'
#' @inheritParams schwierz_mdr
#' @return Mean damage ratio, one value per element of `v`.
#' @export
uk_mdr <- function(v) {
  schwierz_mdr(v, mdd_scale = 1.07, paa_scale = 1)
}

#' Plot the vulnerability curves
#'
#' Plots [schwierz_mdr()], [welker_mdr()] and [uk_mdr()] for gusts of 0 to
#' 80 m/s.
#'
#' @return A data frame of `v` and the three curves, invisibly.
#' @export
plot_vulnerability_curves <- function() {
  v <- seq(0, 80, by = 0.5)
  curves <- cbind(schwierz = schwierz_mdr(v, mdd_scale = 1, paa_scale = 1),
                  welker = welker_mdr(v),
                  uk = uk_mdr(v))
  old <- graphics::par(mar = c(5.1, 4.1, 4.1, 8.1))
  on.exit(graphics::par(old))
  graphics::matplot(v, curves, type = "l", lty = 1, col = 1:3,
                    xlab = "Maximum gust (m/s)", ylab = "Mean damage ratio")
  usr <- graphics::par("usr")
  graphics::legend(usr[2], usr[4], legend = colnames(curves), lty = 1,
                   col = 1:3, xpd = TRUE, bty = "n")
  invisible(data.frame(v, curves))
}
