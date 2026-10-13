#' Storms that share a maximum gust with a nearby storm
#'
#' Picks out storms that are really one event counted more than once.
#' Storms whose footprint central times are less than 72 hours apart and
#' whose UK maximum gusts are identical are one event; all but the storm with
#' the largest SSI (the lowest track id on a tie) are TRUE. Pairs chain: if A
#' and B qualify, and B and C, all three are one event. Storms with no UK
#' maximum gust are FALSE. Use it as `subset(df, !shared_max_within_72h(df))`.
#'
#' @param df A data frame with one row per storm and columns `central_time`
#'   (POSIXct, or text that `as.POSIXct()` reads, in UTC), `max_gust`, `ssi`
#'   and `track_id`, as in the per-storm UK values.
#' @return A logical vector, one element per row of `df`.
#' @export
shared_max_within_72h <- function(df) {
  time <- as.numeric(as.POSIXct(df$central_time, tz = "UTC"))
  o <- order(df$max_gust, time)
  new_event <- c(TRUE, diff(df$max_gust[o]) != 0 |
                         diff(time[o]) >= 72 * 3600)
  new_event[is.na(new_event)] <- TRUE
  event <- integer(nrow(df))
  event[o] <- cumsum(new_event)

  o <- order(event, -df$ssi, df$track_id)
  shared <- logical(nrow(df))
  shared[o] <- duplicated(event[o])
  shared
}
