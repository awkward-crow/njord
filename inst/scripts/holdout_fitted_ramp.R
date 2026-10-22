# holdout_fitted_ramp.R
#
# The fitted ramp (fitted_ramp_calibration()) results that the vignette
# (vignettes/njord-method.Rmd) reads rather than computes, as the ramp
# takes 15 to 20 seconds to fit to the full catalogue. It writes two files
# to inst/extdata:
#
# - holdout_fitted_ramp.csv: the hold-out results with loss = "squared"
#   for the Scotland and the England and Wales covers, every column of
#   holdout_calibration(), one row per region and storm. The folds are
#   blocks of five storm seasons (season_folds()).
# - insample_fitted_ramp.csv: the fits to all storms with loss = "squared"
#   and "absolute" for the UK, Scotland and England and Wales covers, one
#   row per region and loss: the attachment and exhaustion, the storms whose
#   index equals each (space-separated track ids), the objective, the number
#   of pairs reaching it (optima), the ranges of attachment and exhaustion
#   over the pairs within 1% of it and the layer's retention and limit.
#
# The event set, indices, losses and layers are the vignette's: the storms of
# 1940-2025 with a UK maximum gust above 25 m/s, less those that share a
# maximum gust with a nearby storm (shared_max_within_72h()); a storm with
# no gust values in a region has index 0 there; losses under the Schwierz
# curve with mdd_scale 0.8, as fractions of the total UK assets; layers from
# the 1-in-5 to the 1-in-20 year loss. Numbers are written to 10
# significant digits.
#
# Each CSV starts with comment lines: how to make it again, then
# "# key: value" lines with the event set, fold scheme and rule, which the
# vignette checks against its own before using the file. The event ids are the
# `event` column of the hold-out file and the `event_ids` line of the
# in-sample file.
#
# Reads only inst/extdata. Runs the hold-out folds in parallel with
# parallel::mclapply() on one core fewer than are available (serially on
# Windows). The hold-out took about 9 minutes on a 4-core laptop
# (i7-1165G7) with 7 workers, about what its 34 fits take one after another
# (12 seconds each with one BLAS thread): concurrent fits contend for memory
# and cache, so extra workers help little. A single fit also spreads over
# every core through a multithreaded BLAS (outer() is a matrix product),
# which only slows it; running with OPENBLAS_NUM_THREADS=1 avoids that. The
# in-sample fits run serially and take about 100 seconds. An existing output file is not made
# again; delete it to make it again. Each CSV is written to a .part file and
# renamed when complete. Uses the package functions through
# devtools::load_all().
#
# Run from the project root.

devtools::load_all(quiet = TRUE)

# One column of a per-storm CSV, keyed by track id, under a new name.
read_column <- function(file, name)
  setNames(read.csv(file), c("track_id", name))

# Writes comment lines, then the data frame, to target via a .part file,
# numbers to 10 significant digits.
write_with_header <- function(df, header, target) {
  numeric_cols <- vapply(df, is.double, logical(1))
  df[numeric_cols] <- lapply(df[numeric_cols], signif, digits = 10)
  part <- paste0(target, ".part")
  con <- file(part, "w")
  writeLines(header, con)
  write.csv(df, con, row.names = FALSE)
  close(con)
  file.rename(part, target)
}

holdout_target <- "inst/extdata/holdout_fitted_ramp.csv"
insample_target <- "inst/extdata/insample_fitted_ramp.csv"
file_names <- c(values = "uk_storm_values.csv",
                uk_index = "uk_exposure_gust.csv",
                uk_loss = "uk_storm_losses.csv",
                ew_index = "ew_exposure_gust.csv",
                ew_loss = "ew_storm_losses.csv",
                sco_index = "sco_exposure_gust.csv",
                sco_loss = "sco_storm_losses.csv",
                cover = "uk_nuts1_cover.tif",
                assets = "uk_litpop_025deg.tif")
files <- file.path("inst/extdata", file_names)
names(files) <- names(file_names)
first_year <- 1940
last_year <- 2025
block <- 5
gust_threshold <- 25
mdd_scale <- 0.8
attach_rp <- 5
exhaust_rp <- 20
holdout_loss <- "squared"
holdout_regions <- c("ew", "sco")
insample_losses <- c("squared", "absolute")
insample_regions <- c("uk", "ew", "sco")
cores <- max(1, parallel::detectCores() - 1)

if (file.exists(holdout_target) && file.exists(insample_target)) {
  message(holdout_target, " and ", insample_target, " already exist; ",
          "delete one to make it again.")
} else if (any(!file.exists(files))) {
  message("Files missing from inst/extdata: ",
          paste(file_names[!file.exists(files)], collapse = ", "),
          "; see inst/scripts/extdata/Readme.md.")
} else {
  storms <- read.csv(files[["values"]])
  storms$central_time <- as.POSIXct(storms$central_time, tz = "UTC")
  for (k in c("uk_index", "uk_loss", "ew_index", "ew_loss", "sco_index",
              "sco_loss"))
    storms <- merge(storms, read_column(files[[k]], k))
  year <- as.integer(format(storms$central_time, "%Y"))
  events <- subset(storms, !shared_max_within_72h(storms) &
                     max_gust > gust_threshold &
                     year >= first_year & year <= last_year)
  total_assets <- sum(exposure_weights(files[["cover"]], files[["assets"]],
                                       regions = "UK")$weight)
  scheme <- season_folds(first_year, last_year, block = block)
  region_events <- function(region) {
    index <- events[[paste0(region, "_index")]]
    data.frame(event = events$track_id, central_time = events$central_time,
               index = ifelse(is.na(index), 0, index),
               loss = mdd_scale * events[[paste0(region, "_loss")]] /
                 total_assets)
  }
  header <- function(what, rule_loss, regions)
    c(paste0("# ", what, " of fitted_ramp_calibration() for ",
             "vignettes/njord-method.Rmd."),
      paste("# To make again: delete this file and run",
            "Rscript inst/scripts/holdout_fitted_ramp.R from the project",
            "root."),
      paste0("# ", c("rule", "loss", "regions", "first_year", "last_year",
                     "block", "folds", "events", "gust_threshold",
                     "mdd_scale", "attach_rp", "exhaust_rp"), ": ",
             c("fitted_ramp_calibration", paste(rule_loss, collapse = " "),
               paste(regions, collapse = " "), first_year, last_year, block,
               max(scheme$fold), nrow(events), gust_threshold, mdd_scale,
               attach_rp, exhaust_rp)))

  if (file.exists(holdout_target)) {
    message(holdout_target, " already exists; delete it to make it again.")
  } else {
    started <- Sys.time()
    # A worker that dies returns a try-error; stop rather than bind it.
    fold_apply <- function(x, f) {
      res <- parallel::mclapply(x, f, mc.cores = cores)
      crashed <- vapply(res, inherits, logical(1), "try-error")
      if (any(crashed)) stop("Folds ", paste(x[crashed], collapse = ", "),
                             " crashed: ", res[crashed][[1]])
      res
    }
    out <- do.call(rbind, lapply(holdout_regions, function(region)
      holdout_calibration(region_events(region), region,
                          fitted_ramp_calibration, loss = holdout_loss,
                          scheme = scheme, attach_rp = attach_rp,
                          exhaust_rp = exhaust_rp, fold_apply = fold_apply)))
    write_with_header(out, header("Hold-out results", holdout_loss,
                                  holdout_regions), holdout_target)
    failures <- holdout_failures(transform(out, rule = "R3"), scheme)
    message("Wrote ", holdout_target, ": ", nrow(out), " rows (",
            nrow(events), " storms in each of ", length(holdout_regions),
            " regions, ", max(scheme$fold), " folds), ",
            round(file.size(holdout_target) / 1024), " KB, in ",
            round(as.numeric(Sys.time() - started, units = "secs")),
            " s on ", cores, " cores. ",
            if (nrow(failures) == 0) "No fold failed."
            else paste0(nrow(failures), " folds failed: ",
                        paste0(failures$region, " fold ", failures$fold,
                               " (", failures$failure, ")",
                               collapse = "; "), "."))
  }

  if (file.exists(insample_target)) {
    message(insample_target, " already exists; delete it to make it again.")
  } else {
    started <- Sys.time()
    events_per_year <- nrow(events) / sum(scheme$years)
    fits <- expand.grid(region = insample_regions, loss = insample_losses,
                        stringsAsFactors = FALSE)
    out <- do.call(rbind, Map(function(region, loss) {
      ev <- region_events(region)
      index_vec <- setNames(ev$index, ev$event)
      loss_vec <- setNames(ev$loss, ev$event)
      fit <- fitted_ramp_calibration(index_vec, loss_vec,
                                     attach_rp = attach_rp,
                                     exhaust_rp = exhaust_rp,
                                     events_per_year = events_per_year,
                                     loss = loss)
      retention <- loss_level(loss_vec, attach_rp, events_per_year)
      data.frame(region = region, loss = loss,
                 attachment = fit$attachment, exhaustion = fit$exhaustion,
                 attachment_events = paste(fit$attachment_events,
                                           collapse = " "),
                 exhaustion_events = paste(fit$exhaustion_events,
                                           collapse = " "),
                 objective = fit$objective, optima = fit$optima,
                 near_attachment_low = fit$near_attachment[1],
                 near_attachment_high = fit$near_attachment[2],
                 near_exhaustion_low = fit$near_exhaustion[1],
                 near_exhaustion_high = fit$near_exhaustion[2],
                 retention = retention,
                 limit = loss_level(loss_vec, exhaust_rp, events_per_year) -
                   retention)
    }, fits$region, fits$loss))
    write_with_header(out, c(header("In-sample fits", insample_losses,
                                    insample_regions),
                             paste("# event_ids:",
                                   paste(events$track_id, collapse = " "))),
                      insample_target)
    message("Wrote ", insample_target, ": ", nrow(out), " fits (",
            paste(insample_regions, collapse = ", "), " by ",
            paste(insample_losses, collapse = " and "), "), ",
            round(file.size(insample_target) / 1024), " KB, in ",
            round(as.numeric(Sys.time() - started, units = "secs")), " s.")
  }
}
