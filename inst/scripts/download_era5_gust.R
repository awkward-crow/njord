# download_era5_gust.R
#
# Downloads the ERA5 daily maximum gust files whose CDS jobs, submitted by
# submit_era5_gust.R and listed in data-raw/era5_gust/jobs.csv, have
# finished. Run it from time to time until every year has arrived; each
# year can take hours in the CDS queue. Run from the project root. Requires
# a CDS key in the keyring (ecmwfr::wf_set_key); ecmwfr asks to unlock the
# keyring when needed.
#
# For each job in jobs.csv whose year has no file yet, asks the CDS for its
# status. A finished job is downloaded to a .part file, renamed when
# complete and deleted from the CDS. A job the CDS reports as failed, or no
# longer knows (expired, or deleted by hand), is dropped from jobs.csv so
# submit_era5_gust.R will send that year again; a failed job is left on the
# CDS so its reason can be read on the requests page. A year whose file is
# already there (e.g. downloaded by hand) has its job deleted from the CDS
# and dropped. Jobs still queued or running, and any that couldn't be
# checked or downloaded, stay in jobs.csv for the next run. Ends with a
# count of years present, downloaded now, waiting, failed, unknown and not
# submitted.

library(ecmwfr)

years <- 1991:2020
dir <- "data-raw/era5_gust"
jobs_file <- file.path(dir, "jobs.csv")

file_name <- function(k) sprintf("era5_fg10_daymax_%s.nc", k)

# The CDS status of a job ("accepted", "running", "successful", "failed",
# ...), "unknown" if the CDS doesn't know it, or "unchecked" if the check
# itself failed (e.g. no network).
job_status <- function(url, k) tryCatch({
    response <- httr::GET(url,
                          httr::add_headers(`PRIVATE-TOKEN` = wf_get_key()))
    status <- if (httr::http_error(response)) NULL
              else httr::content(response)$status
    if (httr::status_code(response) == 404) "unknown"
    else if (is.null(status)) {
        message(k, " not checked: HTTP ", httr::status_code(response))
        "unchecked"
    } else status
}, error = function(e) {
    message(k, " not checked: ", conditionMessage(e))
    "unchecked"
})

# Download a finished job to target via a .part file: TRUE if it arrived.
fetch <- function(url, k, target) {
    part <- paste0(target, ".part")
    ok <- tryCatch({
        wf_transfer(url, path = dirname(part), filename = basename(part),
                    verbose = FALSE)
        file.rename(part, target)
    }, error = function(e) {
        message(k, " not downloaded: ", conditionMessage(e))
        FALSE
    })
    unlink(part)
    ok
}

# Delete a job from the CDS: TRUE if deleted.
remove_job <- function(url, k) tryCatch({
    wf_delete(url, verbose = FALSE)
    TRUE
}, error = function(e) {
    message(k, " not deleted from the CDS: ", conditionMessage(e))
    FALSE
})

write_jobs <- function(jobs, path) {
    part <- paste0(path, ".part")
    write.csv(jobs, part, row.names = FALSE)
    file.rename(part, path)
}

if (!file.exists(jobs_file) &&
    all(file.exists(file.path(dir, file_name(years))))) {
    message("All ", length(years), " years already exist in ", dir, ".")
} else if (!file.exists(jobs_file)) {
    message("No ", jobs_file, "; run submit_era5_gust.R first.")
} else {
    jobs <- read.csv(jobs_file)
    target <- file.path(dir, file_name(jobs$year))
    status <- rep("present", nrow(jobs))
    open <- which(!file.exists(target))
    status[open] <- vapply(open, function(i)
        job_status(jobs$url[i], jobs$year[i]), "")
    for (i in which(status == "successful"))
        if (fetch(jobs$url[i], jobs$year[i], target[i]))
            status[i] <- "downloaded"
    for (i in which(status %in% c("present", "downloaded")))
        remove_job(jobs$url[i], jobs$year[i])
    for (i in which(status == "failed"))
        message(jobs$year[i], " failed on the CDS; see its requests page ",
                "for the reason.")
    keep <- !status %in% c("present", "downloaded", "failed", "unknown")
    if (!all(keep)) write_jobs(jobs[keep, ], jobs_file)

    present <- years[file.exists(file.path(dir, file_name(years)))]
    waiting <- jobs[keep, ]
    resubmit <- setdiff(years, c(present, waiting$year))
    message(length(years), " years: ", length(present), " present (",
            sum(status == "downloaded"), " downloaded now), ",
            nrow(waiting), " waiting, ", sum(status == "failed"),
            " failed, ", sum(status == "unknown"), " unknown to the CDS, ",
            length(resubmit), " to submit.")
    if (nrow(waiting) > 0)
        message("Waiting: ", paste0(waiting$year, " (", status[keep],
                                    ", submitted ", waiting$submitted, ")",
                                    collapse = ", "))
    if (length(resubmit) > 0)
        message("Run submit_era5_gust.R to submit ",
                paste(resubmit, collapse = " "), ".")
}
