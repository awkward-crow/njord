# submit_era5_gust.R
#
# Submits the CDS requests for the daily maximum 10 m gust over the UK, one
# per year from 1991 to 2020, from the dataset
# derived-era5-single-levels-daily-statistics. The variable is the one the
# storm footprints are made from (ERA5 "maximum 10 metre wind gust since
# previous post-processing", an hourly maximum), and the daily maximum is
# taken over the 24 hourly values of each UTC day. The area is the UK box on
# the footprint grid: cell centres 8.75W to 1.75E, 49.75N to 60.75N. These
# files are for the local 98th percentile of daily maximum gust (v98), so
# the years are a 30-year reference period, not the storm record.
#
# Only submits; download_era5_gust.R fetches the finished years. Each year
# can take hours in the CDS queue, so run that from time to time until all
# have arrived. Each submitted job (year, CDS job URL, time submitted) is
# added to data-raw/era5_gust/jobs.csv as soon as the CDS accepts it. Years
# that already have a file or a job in jobs.csv are skipped, so re-running
# never sends a duplicate. A year the CDS refuses is reported; re-run to
# try again. Run from the project root. Requires a CDS key in the keyring
# (ecmwfr::wf_set_key); ecmwfr asks to unlock the keyring when needed. Ends
# with a count of years present, already submitted, submitted now and
# refused.

library(ecmwfr)

years <- 1991:2020
dir <- "data-raw/era5_gust"
jobs_file <- file.path(dir, "jobs.csv")

file_name <- function(k) sprintf("era5_fg10_daymax_%s.nc", k)

request <- function(k) list(
    dataset_short_name = "derived-era5-single-levels-daily-statistics",
    product_type = "reanalysis",
    variable = "10m_wind_gust_since_previous_post_processing",
    year = as.character(k),
    month = sprintf("%02d", 1:12),
    day = sprintf("%02d", 1:31),
    daily_statistic = "daily_maximum",
    time_zone = "utc+00:00",
    frequency = "1_hourly",
    area = c(60.75, -8.75, 49.75, 1.75),
    target = file_name(k)
)

# The CDS job URL for year k, or NA if the CDS refuses the request.
submit <- function(k, dir) tryCatch(
    wf_request(request(k), path = dir, transfer = FALSE,
               verbose = FALSE)$get_url(),
    error = function(e) {
        message(k, " not submitted: ", conditionMessage(e))
        NA_character_
    })

write_jobs <- function(jobs, path) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    part <- paste0(path, ".part")
    write.csv(jobs, part, row.names = FALSE)
    file.rename(part, path)
}

jobs <- if (file.exists(jobs_file)) read.csv(jobs_file) else
    data.frame(year = integer(), url = character(), submitted = character())
present <- years[file.exists(file.path(dir, file_name(years)))]
waiting <- setdiff(jobs$year, present)
todo <- setdiff(years, c(present, waiting))

if (length(todo) == 0) {
    message("Nothing to submit: ", length(present), " of ", length(years),
            " years present, ", length(waiting), " waiting in ", jobs_file,
            ".")
} else {
    # One at a time, saving jobs.csv after each, so an interruption never
    # loses the URL of a job the CDS has accepted.
    for (k in todo) {
        url <- submit(k, dir)
        if (!is.na(url)) {
            jobs <- rbind(jobs, data.frame(
                year = k, url = url,
                submitted = format(Sys.time(), "%Y-%m-%d %H:%M")))
            write_jobs(jobs, jobs_file)
        }
    }
    refused <- setdiff(todo, jobs$year)
    message(length(years), " years: ", length(present), " present, ",
            length(waiting), " already submitted, ",
            length(todo) - length(refused), " submitted now, ",
            length(refused), " refused.")
    if (length(refused) > 0)
        message("Refused: ", paste(refused, collapse = " "),
                "; re-run to try again.")
    message("Run download_era5_gust.R from time to time to fetch finished ",
            "years.")
}
