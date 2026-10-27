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

#' Calibrate the trigger at the weakest wind the layer pays on
#'
#' Sets the attachment at the weakest wind among the storms the layer pays
#' on, so the cover reaches all of them apart from the storm that sets the
#' attachment, which receives a payout of zero; it also pays on many weaker
#' storms the layer does not pay on. The layer pays on the storms whose loss
#' exceeds the retention, the loss with return period `attach_rp`, so the
#' attachment is the lowest index among them. The exhaustion is likewise the
#' lowest index among the storms whose loss exceeds the loss with return
#' period `exhaust_rp`. The trigger is tied to loss exceedances, not to
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
#' @family calibration methods
#' @export
min_index_calibration <- function(index_vec, loss_vec, attach_rp = 5,
                                  exhaust_rp = 20, events_per_year) {
  loss <- loss_vec[names(index_vec)]
  level <- function(rp)
    min(index_vec[loss > loss_level(loss, rp, events_per_year)])
  list(attachment = level(attach_rp), exhaustion = level(exhaust_rp),
       attach_rp = attach_rp, exhaust_rp = exhaust_rp)
}

# The loss with return period `rp` years: the 1 - 1 / (rp * events_per_year)
# quantile of the losses (type 7).
loss_level <- function(loss, rp, events_per_year)
  unname(stats::quantile(loss, 1 - 1 / (rp * events_per_year)))

#' Calibrate the trigger by matching frequencies
#'
#' Sets the attachment so that as many storms receive a payout as the layer
#' pays on, and the exhaustion so that as many are paid in full as the layer
#' pays its limit on, counting down from the storm with the highest index. It
#' uses only the ranking of the storms, so any increasing transformation of
#' the index gives the same cover. The result is the frequency-matched cover.
#'
#' The layer pays on the storms whose loss is above the retention, the loss
#' with return period `attach_rp`, and pays its limit on those whose loss is
#' above the loss with return period `exhaust_rp`. With `k` storms whose loss
#' is strictly above the first loss and `m` strictly above the second, the
#' attachment is the (k+1)-th largest index, so the `k` storms with the
#' largest index lie above it, and the exhaustion is the m-th largest, so the
#' `m` storms with the largest index lie at or above it. The losses with
#' return period `rp` are as in [min_index_calibration()].
#'
#' Indices are ranked with ties counted separately (the k-th and (k+1)-th
#' largest of 30, 30 are both 30). If the (k+1)-th largest index equals the
#' k-th, fewer than `k` storms lie strictly above the attachment and so
#' fewer are paid; if the m-th largest equals the (m+1)-th, more than `m`
#' storms receive the full limit. It stops with an error if no storm's loss
#' is above either loss level (`k` or `m` is 0), or if tied indices leave the
#' attachment not below the exhaustion. The (k+1)-th largest index always
#' exists: a loss level is a quantile of the losses, so the smallest loss is
#' never strictly above it and `k` is at most one less than the number of
#' storms.
#'
#' @inheritParams min_index_calibration
#' @return A list: `attachment`, `exhaustion`, `attach_rp`, `exhaust_rp` as
#'   in [min_index_calibration()], and `k`, `m`, `attachment_events` and
#'   `exhaustion_events`, the names of the storms whose index equals the
#'   attachment and the exhaustion.
#' @family calibration methods
#' @export
frequency_matching_calibration <- function(index_vec, loss_vec,
                                           attach_rp = 5, exhaust_rp = 20,
                                           events_per_year) {
  loss <- loss_vec[names(index_vec)]
  k <- sum(loss > loss_level(loss, attach_rp, events_per_year))
  m <- sum(loss > loss_level(loss, exhaust_rp, events_per_year))
  if (k == 0 || m == 0)
    stop("No storm has a loss above the ", if (k == 0) attach_rp
         else exhaust_rp, "-year loss, so the level can't be matched.")
  ranked <- sort(unname(index_vec), decreasing = TRUE)
  attachment <- ranked[k + 1]
  exhaustion <- ranked[m]
  if (attachment >= exhaustion)
    stop("Tied indices put the attachment (", attachment, ") at or above ",
         "the exhaustion (", exhaustion, ").")
  list(attachment = attachment, exhaustion = exhaustion,
       attach_rp = attach_rp, exhaust_rp = exhaust_rp, k = k, m = m,
       attachment_events = names(index_vec)[index_vec == attachment],
       exhaustion_events = names(index_vec)[index_vec == exhaustion])
}

#' Calibrate the trigger by fitting the ramp
#'
#' Chooses the attachment and exhaustion that bring the cover's payouts as
#' close as possible to the layer's recoveries over all storms. The layer
#' pays the loss above the retention, the loss with return period
#' `attach_rp`, up to the loss with return period `exhaust_rp`, so the limit
#' is the difference. A storm's recovery is what the layer would have paid
#' on it: its loss above the retention, capped at the limit. Its basis risk
#' is the payout of [payout()] with that limit minus the recovery. The
#' attachment and exhaustion minimise the sum over all storms of the squared
#' basis risk (`loss = "squared"`) or of its absolute value
#' (`loss = "absolute"`).
#'
#' Every pair of distinct storm indices with the attachment below the
#' exhaustion is tried, so the result is exact over those candidates; the
#' work grows with the cube of the number of storms (about 2 seconds for 600
#' storms and 15 to 20 for 1,300). Pairs whose sum is within a relative 1e-12
#' of the minimum count as
#' optimal; if there are several, the one with the lowest attachment, then
#' the lowest exhaustion, is returned. It stops with an error if the layer's
#' limit is not positive or there are fewer than two distinct indices.
#'
#' @inheritParams min_index_calibration
#' @param loss What to minimise: `"squared"` for the sum of squared basis
#'   risk, `"absolute"` for the sum of absolute basis risk.
#' @param near Relative margin for the near-optimal pairs: those whose sum is
#'   within `near` of the minimum (0.01 for 1%).
#' @return A list: `attachment`, `exhaustion`, `attach_rp`, `exhaust_rp` as
#'   in [min_index_calibration()], and `loss`, `objective` (the minimum sum),
#'   `unique` (whether one pair alone reaches it), `optima` (the number of
#'   pairs that do), `near_attachment` and `near_exhaustion` (the range of
#'   each over the near-optimal pairs), and `attachment_events` and
#'   `exhaustion_events`, the names of the storms whose index equals the
#'   attachment and the exhaustion.
#' @family calibration methods
#' @export
fitted_ramp_calibration <- function(index_vec, loss_vec, attach_rp = 5,
                                    exhaust_rp = 20, events_per_year,
                                    loss = c("squared", "absolute"),
                                    near = 0.01) {
  loss <- match.arg(loss)
  storm_loss <- loss_vec[names(index_vec)]
  retention <- loss_level(storm_loss, attach_rp, events_per_year)
  limit <- loss_level(storm_loss, exhaust_rp, events_per_year) - retention
  if (limit <= 0)
    stop("The layer's limit is not positive: the ", exhaust_rp, "-year ",
         "loss is not above the ", attach_rp, "-year loss.")
  recovery <- unname(pmin(pmax(storm_loss - retention, 0), limit))
  x <- unname(index_vec)
  cand <- sort(unique(x))
  n <- length(cand)
  if (n < 2) stop("Fewer than two distinct indices to choose from.")
  penalty <- if (loss == "squared") function(d) d^2 else abs
  # objective[i, j]: attachment cand[i], exhaustion cand[j], j > i.
  objective <- matrix(NA_real_, n, n)
  for (i in seq_len(n - 1)) {
    e <- cand[(i + 1):n]
    paid <- limit * pmin(outer(pmax(x - cand[i], 0), 1 / (e - cand[i])), 1)
    objective[i, (i + 1):n] <- colSums(penalty(paid - recovery))
  }
  best <- min(objective, na.rm = TRUE)
  tol <- 1e-12 * max(best, sum(penalty(recovery)))
  at_best <- which(objective <= best + tol, arr.ind = TRUE)
  at_best <- at_best[order(at_best[, 1], at_best[, 2]), , drop = FALSE]
  near_pairs <- which(objective <= best * (1 + near) + tol, arr.ind = TRUE)
  attachment <- cand[at_best[1, 1]]
  exhaustion <- cand[at_best[1, 2]]
  list(attachment = attachment, exhaustion = exhaustion,
       attach_rp = attach_rp, exhaust_rp = exhaust_rp, loss = loss,
       objective = best, unique = nrow(at_best) == 1,
       optima = nrow(at_best),
       near_attachment = range(cand[near_pairs[, 1]]),
       near_exhaustion = range(cand[near_pairs[, 2]]),
       attachment_events = names(index_vec)[index_vec == attachment],
       exhaustion_events = names(index_vec)[index_vec == exhaustion])
}

#' Basis risk per storm
#'
#' The payout of the linear ramp against `loss_vec`, storm by storm. A
#' cover's basis risk on a storm is its payout minus the recovery, what the
#' layer would have paid on the storm: its modelled loss above the retention,
#' capped at the limit. Pass the recoveries as `loss_vec` to get it; the
#' function does not apply the retention itself. Losses are matched to
#' `index_vec` by name. The limit is in the units of the losses, a fraction
#' of the total insured value.
#'
#' @inheritParams min_index_calibration
#' @inheritParams payout
#' @return A data frame with one row per storm: `event` (the names of
#'   `index_vec`), `index`, `loss`, `payout`, and `basis_risk`, payout minus
#'   loss (positive is an overpayment).
#' @export
basis_risk <- function(index_vec, loss_vec, attachment, exhaustion,
                       limit = 1) {
  loss <- unname(loss_vec[names(index_vec)])
  paid <- payout(unname(index_vec), attachment, exhaustion, limit)
  data.frame(event = names(index_vec), index = unname(index_vec),
             loss = loss, payout = paid, basis_risk = paid - loss)
}
