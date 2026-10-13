# Demos

These scripts demonstrate the package functions. They write nothing; each
prints a short report with `message()`, so it goes to stderr. They load the
package with `devtools::load_all()`, so they run without njord being
installed.

**Run every demo from the project root**, for example:

    Rscript inst/demos/ciara_demo.R

The data they read are made by the [data scripts](../scripts/Readme.md).

## ciara_demo.R

Runs Storm Ciara (February 2020, track 1758) through from footprint to
modelled loss.

It first gives the trigger index, the UK mean gust: the footprint gust
averaged over the 750 cells with UK land, each weighted by its land cover and
the cosine of its latitude (`uk_weights()`, `compute_index()`). It then
gives the loss to UK assets under the Schwierz vulnerability curve
(`schwierz_mdr()`) with the mean damage degree scaled by `mdd_scale = 0.8`,
the UK calibration against PERILS losses with the RMSE cost function, read
from Fig. 3n of Mishra et al. (2026). The LitPop exposure is summed to the
footprint grid, 6 × 6 LitPop cells to each footprint cell, which keeps the
total exactly, and both gusts and assets are restricted to the cells with UK
land, so the curve is not applied to sea cells. Losses are in USD.

It needs `unzip_footprints.sh` and `rasterize_uk.R` from
`inst/scripts/data-raw/` to have been run, and for the losses
`download_litpop.sh` and `convert_litpop.py`. Without the LitPop CSV it gives
the index only.

With the data from the data-raw scripts, it gave:

```
Storm Ciara (track 1758): UK mean gust index 31.34 m/s, over 750 cells with UK land.
UK assets 9472 USD bn; highest UK gust 38.4 m/s.
Modelled loss 0.460 USD bn (Schwierz, mdd_scale 0.8).
```

The loss is proportional to `mdd_scale`: the unscaled curve gives 0.575 USD
bn.
