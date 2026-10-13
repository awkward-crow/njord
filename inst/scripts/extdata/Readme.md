# Extdata scripts

These scripts write the small extracts in `inst/extdata/` that the package's
articles and demos read, so that they run without `data-raw/`. They read
their inputs from `data-raw/`, so the [data-raw scripts](../data-raw/Readme.md)
have to have been run first. See the [scripts Readme](../Readme.md) for how
every script behaves when run.

| Script              | Output in `inst/extdata/`                                         |
|---------------------|-------------------------------------------------------------------|
| `prepare_extdata.R` | `ciara_footprint_uk.tif`, `uk_nuts1_cover.tif`, `uk_litpop_025deg.tif` |
| `uk_storm_values.R` | `uk_storm_values.csv`, one row per storm                           |
| `uk_storm_losses.R` | `uk_storm_losses.csv`, one row per storm                           |

## prepare_extdata.R

Writes the three small rasters that the Storm Ciara article
(`vignettes/articles/ciara.Rmd`) reads to `inst/extdata/`, so that the
article runs from the package alone, without `data-raw/`:

- `ciara_footprint_uk.tif` — the Ciara footprint (track 1758), maximum gust
  in m/s.
- `uk_nuts1_cover.tif` — the UK land fraction of each cell, the layers of the
  cover raster from `rasterize_uk.R`.
- `uk_litpop_025deg.tif` — the LitPop assets in USD, 6 × 6 LitPop cells
  summed to each 0.25° cell.

All three are cropped to the extent of the summed LitPop raster, longitude
−8.875 to 1.875 and latitude 49.625 to 60.875, which is 43 × 45 cells. The
footprint and the cover have to be cropped together, because `uk_weights()`
returns cell numbers on the cover's grid and `uk_mean_gust_index()` uses them on
the footprint's.

It needs `unzip_footprints.sh`, `rasterize_uk.R`, `download_litpop.sh` and
`convert_litpop.py` from `inst/scripts/data-raw/` to have been run. As a
check, it ends by computing the trigger index from the new files, which
should match the index from the full footprint in `data-raw/`. For the files
above it gave:

```
Written:
  ciara_footprint_uk.tif    11.9 kB
  uk_nuts1_cover.tif        14.3 kB
  uk_litpop_025deg.tif       5.3 kB
Index from these files: 31.34 m/s over 750 cells (the full footprint gives 31.34 over 750).
```

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

It needs `unzip_footprints.sh` and `rasterize_uk.R` from
`inst/scripts/data-raw/` to have been run. An existing output file is not
made again. On success it reports the number of storms and their start
dates, how many have UK values and how many have a `max_gust` above the
threshold, and the highest `max_gust` with its track id.
It takes about 30 seconds.

For the footprints downloaded on 2026-09-28 it gave 1,905 storms. 27 have
no UK cell values and 29 have no `max_gust`. 1,482 have a `max_gust` above
25 m/s, and 1,563 have some UK land above 25 m/s; the difference is storms
whose gusts pass 25 m/s only in cells that are mostly sea.

## uk_storm_losses.R

Models each storm's loss to UK assets. The output is a CSV with one row per
storm:

| Column          | Meaning                                                     |
|-----------------|-------------------------------------------------------------|
| `track_id`      | the storm's track id, from the footprint filename           |
| `loss_usd_mdd1` | the modelled loss to UK assets (USD), with `mdd_scale = 1`  |

The loss is the Schwierz vulnerability curve (`schwierz_mdr()`) applied to
the footprint gust in each cell with UK land, times the LitPop assets in that
cell, summed. It is the same calculation as `inst/demos/ciara_demo.R`, on the
same grid and assets: each footprint is cropped to the grid of the rasters
in `inst/extdata/`, and the assets are `uk_litpop_025deg.tif`.

The loss is proportional to `mdd_scale`, so the file holds it at 1 and a
demo multiplies by its own scale; Ciara's 0.575 USD bn here is 0.460 at the
demo's 0.8. Footprint cells that are `NaN` add no loss. The curve is above
zero from 20 m/s, so most storms have some loss, if only a small one.

It needs `unzip_footprints.sh` from `inst/scripts/data-raw/` and
`prepare_extdata.R` to have been run. It checks that the first footprint,
cropped, is on the grid of the rasters. An existing output file is not made
again. On success it reports the number of storms, how many have a loss, the
largest loss with its track id and Ciara's loss, which should match the
demo at `mdd_scale = 1`. It takes about 20 seconds.

For the footprints downloaded on 2026-09-28 it gave:

```
Wrote inst/extdata/uk_storm_losses.csv: 1905 storms, 1828 with a loss. The largest is 1.675 USD bn (track 1070); Ciara (track 1758) 0.575 USD bn, which should be 0.575.
```

Of the 1,828 storms with a loss, 800 lose more than 1 million USD, 70 more
than 100 million and 4 more than 1 billion. The largest, track 1070, is the
Burns' Day storm of 25 January 1990.
