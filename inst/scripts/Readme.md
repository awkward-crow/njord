# Data scripts

These scripts download the raw hazard data used by njord, the UK asset
exposure and the region boundaries used to pick out the UK, put the UK
regions on the footprint grid, and summarise each storm's footprint over the
UK.

The storm data come from the Copernicus Climate Data Store (CDS) dataset
[`sis-european-wind-storm-reanalysis`](https://cds.climate.copernicus.eu/datasets/sis-european-wind-storm-reanalysis)
(Hodges tracking, 1940–2026). The scripts download it, check that the download
is complete, and unpack it. A CDS account is required.

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
relative to it, and all output goes to `data-raw/`.

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

| Script                  | Output in `data-raw/`                                              |
|-------------------------|--------------------------------------------------------------------|
| `download_tracks.R`     | `reanalysis_tracks_hodges.zip`                                     |
| `download_footprints.R` | `footprints/footprints_hodges_YYYYMM.zip`, one per year-month      |
| `check_footprints.sh`   | nothing; prints a report                                           |
| `unzip_footprints.sh`   | `footprints/nc/*.nc`, one per storm                                |
| `download_nuts.R`       | `nuts/NUTS_RG_01M_2021_4326_LEVL_1.geojson`                        |
| `rasterize_uk.R`        | `nuts/uk_nuts1_cover.tif`                                          |
| `uk_storm_values.R`     | `uk_storm_values.csv`, one row per storm                           |
| `submit_era5_gust.R`    | `era5_gust/jobs.csv`, the CDS requests waiting to be downloaded    |
| `download_era5_gust.R`  | `era5_gust/era5_fg10_daymax_YYYY.nc`, one per year 1991–2020       |
| `download_litpop.sh`    | `litpop/LitPop_150arcsec_GBR.hdf5`                                 |
| `convert_litpop.py`     | `litpop/LitPop_150arcsec_GBR.csv`                                  |

## download_tracks.R

Downloads all the storm tracks in one request. The tracks are a single CSV
with one row per storm per 6-hour time step.

It doesn't depend on the other scripts. On success it reports the name of
the CSV in the zip (the name gives the period covered, e.g.
`storm_track-hodges-raw-194001_202607-all-v1_0.csv`), the number of storms
and the range of track dates. For the download on 2026-09-28 that was 1,905
storms, 1940-02-22 to 2026-04-06.

If the request fails, the error is reported. If it times out (ecmwfr gives
up after an hour without an error), the script says nothing was written; the
request may still be on the CDS requests page.

## download_footprints.R

Downloads one footprint per storm: the maximum 10 m gust over a 72-hour
window, at the original 0.25° resolution, covering the storm's footprint area.
Grid cells more than 1000 km from the track are `NaN`. The CDS
serves footprints by storm start date, so the script reads the start dates from
the tracks zip and sends one request per year-month that has storms. The zip
for each request holds one `.nc` file per storm. For the download on
2026-09-28 that made 721 requests.

It needs the tracks zip, so run `download_tracks.R` first. A zip that already
exists is skipped, so if the script is interrupted, running it again carries
on where it stopped. If every zip exists, it says so and sends no requests.

A month whose request fails or times out is reported and skipped, and the
other months carry on. The script ends with a count of the months already
present, downloaded, failed and timed out, and lists the missing months.
Running it again tries them again, but a timed-out request may still be
queued on the CDS: download it from the requests page by hand, or delete it,
before running the script again, so it isn't requested twice.

## check_footprints.sh

Checks the footprint download against the tracks, so run it after
`download_tracks.R` and `download_footprints.R`. It doesn't extract
anything. It:

1. tests every footprint zip with `unzip -t` and lists any bad ones;
2. lists the `.nc` files inside the zips;
3. counts the distinct track ids in the footprint filenames and lists duplicates;
4. counts the track ids in the tracks CSV;
5. lists tracks without a footprint and footprints without a track;
6. compares each footprint's filename date with its track's start date, for
   the storms that have both.

Each check that can find a problem prints a count and then lists the
problems, indented; a date mismatch is listed as track id, footprint date,
track start date. The last line is `OK` or `PROBLEMS FOUND` with the total.

For the download on 2026-09-28, a complete download gave:

```
zips tested: 721
bad zips: 0
footprint files: 1905
distinct footprint ids: 1905
duplicate footprint ids: 0
track ids: 1905
tracks without footprint: 0
footprints without track: 0
date mismatches: 0
OK: every storm has exactly one footprint, dated by its track start.
```

## unzip_footprints.sh

Extracts the `.nc` files from every footprint zip into
`data-raw/footprints/nc/`, one file per storm. Run it last, once
`check_footprints.sh` shows the download is complete.

The zips are left in place. Only the files not already in `nc/` are
extracted, so the script can be run again. Each zip is extracted into its
own directory under `data-raw/footprints/nc.part/`, and its files are moved
into `nc/` only if the whole zip extracts cleanly; the staging directory is
removed when the script ends. A zip that can't be read or extracted is listed
under "failed zips" and its storms under "still missing". The script checks
file names only, not the contents of files already in `nc/`.

Run again once all the files were extracted, it gives:

```
zips: 721
footprint files in zips: 1905
already in nc/: 1905
OK: all 1905 footprint files in nc/.
```

## download_nuts.R

Downloads the boundaries of the NUTS level 1 regions of Europe, from the 2021
NUTS version, at 1:1 million scale, in longitude and latitude (WGS 84), the
same coordinates as the footprints. The file is a single GeoJSON of 13.8 MB.

The CDS summary indicators use exactly the NUTS 2021 regions, for every year
from 1940 to 2025, so the footprints are aggregated to the same regions. 2021
is also the latest NUTS version that includes the UK. The UK has 12 level 1
regions, `UKC` to `UKN`.

It doesn't depend on the other scripts. An existing file is not downloaded
again. On success it reports the file's size and number of regions (125 for
the file downloaded on 2026-09-30); on failure it reports the error, e.g. an
HTTP 404.

## rasterize_uk.R

Puts the 12 UK NUTS level 1 regions on the footprint grid. For every grid
cell it records the fraction of the cell covered by each region, so a coastal
cell that is 30% land counts as 0.3. The output is a GeoTIFF with 13 layers:
one per region, `UKC` to `UKN`, and a last layer, `UK`, for the whole
country. A cell with no land in a region is `NA` in that region's layer.
Small islands are kept.

The grid is taken from a footprint file, not built from scratch: the
footprint cell centres are on quarter degrees, so the cell edges fall at .125
and .375.

It needs `download_nuts.R` and `unzip_footprints.sh` to have been run. An
existing output file is not made again. On success it reports the layers,
the number of cells with UK land and the UK area.

For the NUTS file downloaded on 2026-09-30 it gave 750 cells with some UK
land, adding up to 538.8 whole cells. That is 244,671 km², against 244,545 km²
from the region boundaries.

Administrative boundaries: © EuroGeographics.

## uk_storm_values.R

Summarises each storm's footprint over UK land. The output is a CSV with
one row per storm:

| Column         | Meaning                                                         |
|----------------|-----------------------------------------------------------------|
| `track_id`     | the storm's track id, from the footprint filename               |
| `start_date`   | the storm's start date, from the footprint filename             |
| `start_time`   | the time of the track's first point (UTC)                       |
| `central_time` | the centre of the 72-hour window the gusts are taken over (UTC) |
| `n_valid`      | UK cells with a gust value, out of 750                          |
| `max_gust`     | the highest gust in any cell at least half UK land (m/s)        |
| `area_25`      | UK land area with gusts above 25 m/s (km²)                      |
| `mean_gust_25` | the mean gust over that area (m/s)                              |
| `ssi`          | storm severity index, `mean_gust_25`³ × `area_25`               |

Cells are weighted by their UK land fraction, from the `UK` layer of
`uk_nuts1_cover.tif`, and by their area in km², which shrinks with latitude.
"Above 25 m/s" means strictly greater. The SSI follows the definition in the
CDS summary indicators: the mean gust over the area above the threshold,
cubed, times that area.

The highest gust is taken only over cells that are at least half UK land
(533 of the 750 cells). Cells that are mostly sea are often the windiest,
and including them would let sea gusts set the UK maximum for most storms.
With this rule, counts of storms above 15.6, 20 and 25 m/s match the CDS
summary indicators' UK `storms_number` closely, year by year. The cut-off
is `min_cover` near the end of the script. Area, mean gust and SSI still use
every cell with some UK land, weighted by its land fraction.

Footprint cells that are `NaN` are left out. A storm with no UK cell values
has `area_25` and `ssi` zero. A storm with no value in a cell at least half
land has `max_gust` `NA`.

`start_time` and `central_time` are read from each footprint file's header
and written as `YYYY-MM-DD HH:MM`, in UTC. GDAL doesn't read these header
values, so the script runs `ncdump` (from the netCDF tools in the dev shell)
on every file. The central time is the better guide to when a storm's
strongest gusts occurred: the start time can be days earlier, as some
tracks last two weeks or more.

It needs `unzip_footprints.sh` and `rasterize_uk.R` to have been run. An
existing output file is not made again. On success it reports the number of
storms and their start dates, how many have UK values and how many have a
`max_gust` above the threshold, and the highest `max_gust` with its track id.
It takes about 30 seconds.

For the footprints downloaded on 2026-09-28 it gave 1,905 storms. 27 have
no UK cell values and 29 have no `max_gust`. 1,482 have a `max_gust` above
25 m/s, and 1,563 have some UK land above 25 m/s; the difference is storms
whose gusts pass 25 m/s only in cells that are mostly sea.

## submit_era5_gust.R

Submits the CDS requests for the daily maximum 10 m gust over the UK for
every day from 1991 to 2020, one request per year. These are not storm
data: they are a 30-year reference period for working out how windy each
grid cell normally is (the 98th percentile of daily maximum gust in each
cell), which some storm severity indices and damage functions need.

The gust is the same ERA5 variable the footprints are made from, the
maximum 10 m gust since the previous post-processing step, which is hourly.
The daily maximum is taken over the 24 hours of each UTC day. The area is the
UK box on the footprint grid, cell centres 8.75°W to 1.75°E and 49.75°N to
60.75°N, and the files are on exactly the same grid as the footprints. Each
file has one layer per day, 365 or 366. terra reads the time as a depth
(days since 1 January), not as a time.

The script only submits the requests; `download_era5_gust.R` fetches them
when they are ready. The CDS runs one request per user at a time, and in
October 2026 each year took hours, mostly waiting in the queue, so the whole
set took several days. Nobody needs to keep R open for that: submit once,
then run the download script now and then until every year has arrived.

Each request the CDS accepts is added to `era5_gust/jobs.csv` straight away,
with its year, its CDS job URL and the time it was submitted. Years that
already have a file, or a request in `jobs.csv`, are skipped, so running the
script again never sends a duplicate. A year the CDS refuses is reported;
run the script again to retry it. It ends with a count of the years present,
already submitted, submitted now and refused. It doesn't depend on the
other scripts.

## download_era5_gust.R

Downloads the years whose requests in `era5_gust/jobs.csv` have finished,
as `era5_gust/era5_fg10_daymax_YYYY.nc`. Run it after `submit_era5_gust.R`,
as often as you like.

For each request in `jobs.csv` whose year has no file yet, it asks the CDS
for the request's status:

- finished: downloads the file (via a `.part` file), deletes the request
  from the CDS and removes it from `jobs.csv`;
- failed, or no longer known to the CDS (expired, or deleted by hand):
  reports it and removes it from `jobs.csv`, so `submit_era5_gust.R` will
  send that year again. A failed request is left on the CDS, so the reason
  can be read on its requests page;
- queued or running, or the check or download failed (e.g. no network):
  keeps it in `jobs.csv` for the next run.

A year whose file is already there, e.g. downloaded by hand from the CDS
website, has its request deleted from the CDS and removed from `jobs.csv`.
When everything has arrived, `jobs.csv` holds only its header line.

It ends with a count of the years present (and how many were downloaded
now), waiting, failed, unknown to the CDS and still to submit, then lists
the waiting years with their CDS status and submission time, and the years
to give to `submit_era5_gust.R`. For example:

    30 years: 6 present (3 downloaded now), 1 waiting, 0 failed, 0 unknown to the CDS, 23 to submit.
    Waiting: 1998 (running, submitted 2026-10-10 12:00)
    Run submit_era5_gust.R to submit 1995 1996 2000 ...

## download_litpop.sh

Downloads CLIMADA's LitPop asset exposure for the UK: LitPop v3 with
exponents (1,1), i.e. nightlights × population, scaled to produced capital
(`fin_mode` pc) in USD, at 150 arcsec (about 0.042°; about 4.6 km north–south
by 2.7–3.0 km east–west over the UK), made with CLIMADA v4.1.1 in June 2022.
The file is 2.5 MB.

CLIMADA lists its files through its data API, not as a directory that can be
browsed; this one was found with

    https://climada.ethz.ch/data-api/v2/dataset/?data_type=litpop&country_iso3alpha=GBR&status=active

The file is a pandas table in HDF5, one row per point, not a raster;
`convert_litpop.py` turns it into a CSV.

It doesn't depend on the other scripts. The download is checked against the
size the API gives, 2,571,888 bytes; a file of the wrong size is not kept.

## convert_litpop.py

Writes the LitPop points to a CSV with three columns: `latitude`,
`longitude` (the cell centre, in degrees) and `value` (USD). It needs
`download_litpop.sh` to have been run.

The HDF5 file is a pandas table stored under the key `exposures`. Besides
`value`, `latitude` and `longitude` it has `region_id`, `impf_` and a
`geometry` column of pickled shapely points. Reading it with
`pandas.read_hdf()` would unpickle the geometry, which needs shapely, so the
script uses PyTables alone and reads only the block of the table that holds
the three numeric columns. It first checks that the block holds exactly
`value`, `latitude` and `longitude`, with one row per point, and stops if
not.

The coordinates in the file are rounded to 8 decimal places; they are the
centres of a 150 arcsec grid whose cell edges fall on multiples of 1/24°, so
each 0.25° footprint cell holds exactly 6 × 6 LitPop cells. They are
WGS 84 latitude/longitude (coordinate reference system EPSG:4326), as
recorded in the HDF5 file; the CSV doesn't record it. A file that can't
be read, or has no `exposures` table, is reported with the error.

For the file of 2022-06-26 it gave:

```
points: 19349
value total: 9,471,908,198,426 USD
zero values: 4
latitude: 49.97916667 to 60.8125
longitude: -8.60416667 to 1.72916667
OK: data-raw/litpop/LitPop_150arcsec_GBR.csv
```

The westernmost points are St Kilda; the westernmost in Northern Ireland are
at 8.15°W, in Fermanagh.

### Python packages

Python is not in the project's Nix flake. The script needs Python 3 with:

- `tables` (PyTables), which also installs `numpy`

It was tested with Python 3.14, tables 3.11.1 and numpy 2.5.3.

How to install it is up to you. One way is a virtual environment in
`data-raw/litpop/`, which git ignores:

```sh
python3 -m venv data-raw/litpop/.venv
data-raw/litpop/.venv/bin/pip install tables
```

Then run the script with that Python, from the project root; the
environment doesn't need activating:

```sh
data-raw/litpop/.venv/bin/python inst/scripts/convert_litpop.py
```
