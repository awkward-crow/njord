# Extdata scripts

These scripts write the small extracts in `inst/extdata/` that the package's
articles and demos read, so that they run without `data-raw/`. They read
their inputs from `data-raw/`, so the [data-raw scripts](../data-raw/Readme.md)
have to have been run first. See the [scripts Readme](../Readme.md) for how
every script behaves when run.

| Script              | Output in `inst/extdata/`                                         |
|---------------------|-------------------------------------------------------------------|
| `prepare_extdata.R` | `ciara_footprint_uk.tif`, `uk_nuts1_cover.tif`, `uk_litpop_025deg.tif` |

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
should match `inst/demos/ciara_demo.R`. For the files above it gave:

```
Written:
  ciara_footprint_uk.tif    11.9 kB
  uk_nuts1_cover.tif        14.3 kB
  uk_litpop_025deg.tif       5.3 kB
Index from these files: 31.34 m/s over 750 cells (inst/demos/ciara_demo.R gives 31.34 over 750).
```
