# Data scripts

These scripts download the raw hazard data used by njord and the region
boundaries used to pick out the UK, put the UK regions on the footprint
grid, and summarise each storm's footprint over the UK.

The storm data come from the Copernicus Climate Data Store (CDS) dataset
[`sis-european-wind-storm-reanalysis`](https://cds.climate.copernicus.eu/datasets/sis-european-wind-storm-reanalysis)
(Hodges tracking, 1940–2026). The scripts download it, check that the download
is complete, and unpack it. A CDS account is required.

The region boundaries are the NUTS 2021 regions from
[Eurostat GISCO](https://ec.europa.eu/eurostat/web/gisco). No account is
needed.

**Run every script from the project root.** All paths in the scripts are
relative to it, and all output goes to `data-raw/`.

| Script                  | Output in `data-raw/`                                              |
|-------------------------|--------------------------------------------------------------------|
| `download_tracks.R`     | `reanalysis_tracks_hodges.zip`                                     |
| `download_footprints.R` | `footprints/footprints_hodges_YYYYMM.zip`, one per year-month      |
| `check_footprints.sh`   | nothing; prints a report                                           |
| `unzip_footprints.sh`   | `footprints/nc/*.nc`, one per storm                                |
| `download_nuts.R`       | `nuts/NUTS_RG_01M_2021_4326_LEVL_1.geojson`                        |
| `rasterize_uk.R`        | `nuts/uk_nuts1_cover.tif`                                          |
| `uk_storm_values.R`     | `uk_storm_values.csv`, one row per storm                           |

## download_tracks.R

Downloads all the storm tracks in one request. The tracks are a single CSV
with one row per storm per 6-hour time step.

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
on where it stopped.

## check_footprints.sh

Checks the footprint download against the tracks, so run it after
`download_tracks.R` and `download_footprints.R`. It doesn't extract
anything. It:

1. tests every footprint zip with `unzip -t` and lists any bad ones;
2. lists the `.nc` files inside the zips;
3. counts the distinct track ids in the footprint filenames and lists duplicates;
4. counts the track ids in the tracks CSV;
5. lists tracks without a footprint and footprints without a track;
6. compares each footprint's filename date with its track's start date.

For the download on 2026-09-28, a complete download gave:

```
zips tested: 721
bad zips:
footprint files: 1905
distinct footprint ids: 1905
duplicate footprint ids:
track ids: 1905
tracks without footprint:
footprints without track:
date mismatches: 0
```

## unzip_footprints.sh

Extracts the `.nc` files from every footprint zip into
`data-raw/footprints/nc/`, one file per storm. Run it last, once
`check_footprints.sh` shows the download is complete.

The zips are left in place. A file that already exists is not overwritten, so
the script can be run again. It lists any zip that fails to extract.

For the download on 2026-09-28 it gave:

```
failed zips:
zips: 721
footprint files: 1905
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
again.

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
existing output file is not made again.

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
is `max_cover` at the top of the script. Area, mean gust and SSI still use
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
existing output file is not made again.

For the footprints downloaded on 2026-09-28 it gave 1,905 storms. 27 have
no UK cell values and 29 have no `max_gust`. 1,482 have a `max_gust` above
25 m/s, and 1,563 have some UK land above 25 m/s; the difference is storms
whose gusts pass 25 m/s only in cells that are mostly sea.
