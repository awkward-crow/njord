# Extdata scripts

These scripts write the small extracts in `inst/extdata/` that the package's
articles and demos read, so that they run without `data-raw/`. They read
their inputs from `data-raw/`, so the [data-raw scripts](../data-raw/Readme.md)
have to have been run first. See the [scripts Readme](../Readme.md) for how
every script behaves when run.

| Script                     | Output in `inst/extdata/`                                              |
|----------------------------|------------------------------------------------------------------------|
| `uk_litpop_025deg.R`       | `uk_litpop_025deg.tif`, the LitPop assets on the 0.25° grid            |
| `uk_nuts1_cover.R`         | `uk_nuts1_cover.tif`, the NUTS1 land cover on that grid                |
| `ciara_footprint_uk.R`     | `ciara_footprint_uk.tif`, the Storm Ciara footprint on that grid       |
| `burns_day_footprint.R`    | `burns_day_footprint.tif`, the Burns' Day footprint on the full grid   |
| `uk_storm_values.R`        | `uk_storm_values.csv`, one row per storm                               |
| `uk_storm_losses.R`        | `uk_storm_losses.csv`, one row per storm                               |
| `uk_exposure_gust.R`       | `uk_exposure_gust.csv`, one row per storm                              |
| `ew_exposure_gust.R`       | `ew_exposure_gust.csv`, one row per storm                              |
| `sco_exposure_gust.R`      | `sco_exposure_gust.csv`, one row per storm                             |
| `ew_storm_losses.R`        | `ew_storm_losses.csv`, one row per storm                               |
| `sco_storm_losses.R`       | `sco_storm_losses.csv`, one row per storm                              |

## uk_litpop_025deg.R

Writes `uk_litpop_025deg.tif`, the LitPop assets of the UK in USD summed
from LitPop's 150-arcsecond cells to the 0.25° footprint grid, 6 × 6 LitPop
cells to each footprint cell (`load_litpop_uk()`, then `aggregate()`). The
extent is that of `load_litpop_uk()`, longitude −8.875 to 1.875 and latitude
49.625 to 60.875, 43 × 45 cells. Its edges are footprint cell edges, so the
sum keeps the total exactly. This grid is the grid of every raster in
`inst/extdata/` but `burns_day_footprint.tif`: `uk_nuts1_cover.R` crops the
cover to it, and `ciara_footprint_uk.R` crops the footprint to the cover.

It needs `download_litpop.sh` and `convert_litpop.py` from
`inst/scripts/data-raw/` to have been run. An existing output file is not
made again. On success it reports the grid, the number of cells with
assets, the total and how far that total is from the total of the LitPop
cells. For the LitPop file downloaded on 2026-10-09 it gave:

```
Wrote inst/extdata/uk_litpop_025deg.tif (5.3 kB): 45 x 43 cells, 728 with assets, USD 9471.9 bn in all; the LitPop cells differ from that by USD 0.00977.
```

## uk_nuts1_cover.R

Writes `uk_nuts1_cover.tif`, the NUTS1 land cover raster from
`rasterize_uk.R` cropped to the grid of `uk_litpop_025deg.tif`. It keeps all
13 layers, one per NUTS1 region (`UKC` to `UKN`) and one for the whole UK
(`UK`), each the fraction of every cell that is land in that region.
`area_weights()` and `exposure_weights()` read it, and the cell numbers they
return are on its grid.

It needs `rasterize_uk.R` from `inst/scripts/data-raw/` and
`uk_litpop_025deg.R` to have been run. It writes nothing if the cropped
cover is not on the grid of the assets raster, or if cropping loses any cell
with UK land. An existing output file is not made again. It gave:

```
Wrote inst/extdata/uk_nuts1_cover.tif (14.3 kB): 13 layers, 45 x 43 cells, 750 with UK land, as on the full grid.
```

## ciara_footprint_uk.R

Writes `ciara_footprint_uk.tif`, the footprint of Storm Ciara (February
2020, track 1758), cropped to the grid of `uk_nuts1_cover.tif`.
`inst/demos/ciara_demo.R` and `vignettes/articles/ciara.Rmd` read it.

It needs `unzip_footprints.sh` and `rasterize_uk.R` from
`inst/scripts/data-raw/` and `uk_nuts1_cover.R` to have been run. It writes
nothing if the cropped footprint is not on the grid of the cover, or if its
values at the cells with UK land differ from those of the full footprint at
the cells with UK land in the full cover from `rasterize_uk.R`; that second
check also catches a cover in `inst/extdata/` that isn't the crop of the one
in `data-raw/`. An existing output file is not made again. It gave:

```
Wrote inst/extdata/ciara_footprint_uk.tif (11.9 kB): 45 x 43 cells, the 750 with UK land unchanged from the full footprint. Highest gust there 38.4 m/s.
```

## burns_day_footprint.R

Writes `burns_day_footprint.tif`, the footprint of the Burns' Day storm
(January 1990, track 1070) on the full footprint grid, 0.25° cells from 25°W
to 35°E and 30°N to 70°N, 161 × 241 cells, uncropped. It is the only raster
in `inst/extdata/` not on the UK grid. `vignettes/articles/storm-footprints.Rmd`
reads it, to show a whole footprint, with the cells more than 1000 km from
the track left without values.

It needs `unzip_footprints.sh` from `inst/scripts/data-raw/` to have been
run. It writes nothing if the footprint is not 161 × 241 cells, or if the
values written differ from the footprint's. An existing output file is not
made again. It gave:

```
Wrote inst/extdata/burns_day_footprint.tif (77.1 kB): 161 x 241 cells, 18531 with a value. Highest gust 43.6 m/s.
```

The highest gust is over the whole grid, sea included; the storm's
`max_gust` in `uk_storm_values.csv`, over cells at least half UK land, is
43.5 m/s.

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

It needs `unzip_footprints.sh` from `inst/scripts/data-raw/`, and
`uk_litpop_025deg.R` and `uk_nuts1_cover.R`, to have been run. It checks
that the first footprint, cropped, is on the grid of the rasters. An existing output file is not made
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

## uk_exposure_gust.R

Computes each storm's UK exposure-weighted mean gust, the trigger index of
`inst/demos/calibration_demo.R`. The output is a CSV with one row per storm:

| Column             | Meaning                                                |
|--------------------|--------------------------------------------------------|
| `track_id`         | the storm's track id, from the footprint filename      |
| `uk_exposure_gust` | the UK exposure-weighted mean gust (m/s)               |

The index is the footprint gust averaged over the cells with UK assets, each
weighted by the value of its LitPop assets in `uk_litpop_025deg.tif`
(`exposure_weights()`, then `weighted_mean_index()`). The asset value is
already a total for the cell, counting UK assets only, so there is no land
fraction or area factor as in `area_weights()`. 728 of the 750
cells with UK land hold assets; the other 22 drop out. Each footprint is
cropped to the grid of the rasters in `inst/extdata/`.

Footprint cells that are `NaN` are left out. A storm with no values in the
cells with assets has no index; the script counts these as `NaN`, and
`write.csv()` writes them as `NA`.

It needs `unzip_footprints.sh` from `inst/scripts/data-raw/`, and
`uk_litpop_025deg.R` and `uk_nuts1_cover.R`, to have been run. It checks
that the assets raster and the first footprint, cropped, are on the grid of
the cover raster. An
existing output file is not made again. On success it reports the number of
storms, how many have no values, the highest index with its track id and
Ciara's index. It takes about 20 seconds.

For the footprints downloaded on 2026-09-28 it gave:

```
Wrote inst/extdata/uk_exposure_gust.csv: 1905 storms, 27 with no values (NaN). The highest is 33.23 m/s (track 1070); Ciara (track 1758) 31.94 m/s, which should be 31.94.
```

The highest is the Burns' Day storm, which is also the storm with the
largest loss. Weighting by assets moves the index towards the gusts where
the assets are: Ciara's is 31.94 m/s here and 31.34 m/s by area.

## ew_exposure_gust.R

Computes each storm's England and Wales exposure-weighted mean gust, the
trigger index of the England and Wales cover in
`inst/demos/calibration_demo.R`. The output is a CSV with one row per storm:

| Column             | Meaning                                                 |
|--------------------|---------------------------------------------------------|
| `track_id`         | the storm's track id, from the footprint filename       |
| `ew_exposure_gust` | the England and Wales exposure-weighted mean gust (m/s) |

It is `uk_exposure_gust.R` with the weights for NUTS1 regions UKC to UKL,
`exposure_weights(cover, assets, paste0("UK", LETTERS[3:12]))`. A cell on
the border with Scotland holds assets of both, and LitPop doesn't say which,
so its assets are split by each region's share of its UK land, from the
region layers of `uk_nuts1_cover.tif`, as if spread evenly over that land.
Assigning each LitPop point to its region from the NUTS polygons instead
moves less than 0.3% of Scotland's assets and changes the index of any
storm above 25 m/s by at most 0.2 m/s. 398 cells hold assets in England and
Wales, 8,654 USD bn in all.

It needs the same scripts, makes the same checks and reports the same things
as `uk_exposure_gust.R`, and takes about 20 seconds. For the footprints
downloaded on 2026-09-28 it gave:

```
Wrote inst/extdata/ew_exposure_gust.csv: 1905 storms, 158 with no values (NaN), over 398 cells with assets in England and Wales. The highest is 35.30 m/s (track 1412); Ciara (track 1758) 32.18 m/s.
```

Track 1412 has its central time on 7 January 2005. Of the 158 storms with
no values, 27 have no UK values at all and the rest reach only Scotland or
Northern Ireland.

## sco_exposure_gust.R

Computes each storm's Scotland exposure-weighted mean gust, the trigger
index of the Scotland cover in `inst/demos/calibration_demo.R`. The output
is a CSV with one row per storm:

| Column              | Meaning                                                |
|---------------------|--------------------------------------------------------|
| `track_id`          | the storm's track id, from the footprint filename      |
| `sco_exposure_gust` | the Scotland exposure-weighted mean gust (m/s)         |

It is `uk_exposure_gust.R` with the weights for NUTS1 region UKM,
`exposure_weights(cover, assets, "UKM")`; border cells are split as in
`ew_exposure_gust.R`. 288 cells hold assets in Scotland, 658 USD bn in all.

It needs the same scripts, makes the same checks and reports the same things
as `uk_exposure_gust.R`, and takes about 20 seconds. For the footprints
downloaded on 2026-09-28 it gave:

```
Wrote inst/extdata/sco_exposure_gust.csv: 1905 storms, 52 with no values (NaN), over 288 cells with assets in Scotland. The highest is 38.98 m/s (track 1346); Ciara (track 1758) 29.72 m/s.
```

Track 1346 has its central time on 28 January 2002. It has the largest loss
in Scotland, but only 25.81 m/s on the UK index, because Scotland holds 7%
of UK assets.

## ew_storm_losses.R

Models each storm's loss to assets in England and Wales. The output is a
CSV with one row per storm:

| Column          | Meaning                                                              |
|-----------------|----------------------------------------------------------------------|
| `track_id`      | the storm's track id, from the footprint filename                    |
| `loss_usd_mdd1` | the modelled loss to England and Wales assets (USD), `mdd_scale = 1` |

It is the calculation of `uk_storm_losses.R` on the assets of
`exposure_weights()` for NUTS1 regions UKC to UKL, so a border cell's loss
is split between the regions as its weight is in `ew_exposure_gust.R`. With
the `UK` layer the same calculation gives `uk_storm_losses.csv` exactly, and
the losses of England and Wales, Scotland and Northern Ireland (UKN, not
written) add up to the UK loss of every storm to within 6 USD.

It needs `unzip_footprints.sh` from `inst/scripts/data-raw/`, and
`uk_litpop_025deg.R` and `uk_nuts1_cover.R`, to have been run. It checks
that the assets raster and the first footprint, cropped, are on the grid of
the cover raster. An
existing output file is not made again. On success it reports the number of
storms, how many have a loss, the number of cells and value of the assets,
the largest loss with its track id and Ciara's loss. It takes about 20
seconds.

For the footprints downloaded on 2026-09-28 it gave:

```
Wrote inst/extdata/ew_storm_losses.csv: 1905 storms, 1596 with a loss, over 398 cells with assets in England and Wales (USD 8654 bn). The largest is 1.675 USD bn (track 1070); Ciara (track 1758) 0.562 USD bn.
```

All of the Burns' Day loss is in England and Wales, and 0.562 of Ciara's
0.575 USD bn.

## sco_storm_losses.R

Models each storm's loss to assets in Scotland. The output is a CSV with one
row per storm:

| Column          | Meaning                                                     |
|-----------------|-------------------------------------------------------------|
| `track_id`      | the storm's track id, from the footprint filename           |
| `loss_usd_mdd1` | the modelled loss to Scotland assets (USD), `mdd_scale = 1` |

It is `ew_storm_losses.R` for NUTS1 region UKM, with the same inputs,
checks and report, and takes about 20 seconds. For the footprints downloaded
on 2026-09-28 it gave:

```
Wrote inst/extdata/sco_storm_losses.csv: 1905 storms, 1728 with a loss, over 288 cells with assets in Scotland (USD 658 bn). The largest is 0.493 USD bn (track 1346); Ciara (track 1758) 0.012 USD bn.
```
