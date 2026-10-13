# Data scripts

These scripts make the data that njord uses. They are in two folders, by
where their output goes:

- [`data-raw/`](data-raw/Readme.md) downloads the raw hazard data, the UK
  asset exposure and the region boundaries used to pick out the UK, puts the
  UK regions on the footprint grid and summarises each storm's footprint
  over the UK. All its output goes to `data-raw/`, which git ignores.
- [`extdata/`](extdata/Readme.md) writes the small extracts in
  `inst/extdata/` that the package's articles and demos read, so that they
  run without `data-raw/`. Its scripts read their inputs from `data-raw/`.

The demonstrations of the package functions, such as Storm Ciara from
footprint to loss, are in [`inst/demos/`](../demos/Readme.md).

The storm data come from the Copernicus Climate Data Store (CDS) dataset
[`sis-european-wind-storm-reanalysis`](https://cds.climate.copernicus.eu/datasets/sis-european-wind-storm-reanalysis)
(Hodges tracking, 1940–2026). The scripts download it, check that the download
is complete and unpack it. A CDS account is required.

The daily maximum gusts come from another CDS dataset,
[`derived-era5-single-levels-daily-statistics`](https://cds.climate.copernicus.eu/datasets/derived-era5-single-levels-daily-statistics),
with the same account.

The region boundaries are the NUTS 2021 regions from
[Eurostat GISCO](https://ec.europa.eu/eurostat/web/gisco). No account is
needed.

The asset exposure is CLIMADA's
[LitPop](https://climada-python.readthedocs.io/en/stable/user-guide/climada_entity_LitPop.html)
for the UK, from the [CLIMADA data API](https://climada.ethz.ch/data-api/v2/docs).
No account is needed.

**Run every script from the project root.** All paths in the scripts are
relative to it, for example:

    Rscript inst/scripts/data-raw/download_tracks.R

Every script behaves the same way when run:

- If its output already exists, it says so and does nothing. Delete the
  output to make it again.
- If an input is missing, it names the input and the script that makes it,
  and does nothing.
- It creates directories only when it has something to write.
- It writes each output to a `.part` file and renames it only when complete,
  so a failed or interrupted run leaves nothing that a later run would
  mistake for finished output.
- It ends with a short report of what it did, or why it didn't.

The R scripts report with `message()`, so the report goes to stderr. The shell
and Python scripts end with a line starting `OK` (exit status 0) or
`PROBLEMS FOUND` (exit status 1), and exit 1 if an input is missing.
