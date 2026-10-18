# Demos

These scripts demonstrate the package functions. They write nothing; each
prints a short report with `message()`, so it goes to stderr, and
`calibration_demo.R` also prints a table to stdout. They load the
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
the cosine of its latitude (`area_weights()`, `weighted_mean_index()`). It
then gives the loss to UK assets under the Schwierz vulnerability curve
(`schwierz_mdr()`) with the mean damage degree scaled by `mdd_scale = 0.8`,
the UK calibration against PERILS losses with the RMSE cost function, read
from Fig. 3n of Mishra et al. (2026). The LitPop exposure is summed to the
footprint grid, 6 × 6 LitPop cells to each footprint cell, which keeps the
total exactly, and both gusts and assets are restricted to the cells with UK
land, so the curve is not applied to sea cells. Losses are in USD.

It reads the three rasters in `inst/extdata/` written by
`uk_litpop_025deg.R`, `uk_nuts1_cover.R` and `ciara_footprint_uk.R` in
`inst/scripts/extdata/`, so it runs from a checkout without `data-raw/` or a
CDS account.

It gives:

```
Storm Ciara (track 1758): UK mean gust index 31.34 m/s, over 750 cells with UK land.
UK assets 9472 USD bn; highest UK gust 38.4 m/s.
Modelled loss 0.460 USD bn (Schwierz, mdd_scale 0.8).
```

The loss is proportional to `mdd_scale`: the unscaled curve gives 0.575 USD
bn.

## calibration_demo.R

Calibrates parametric triggers to modelled losses over the storm catalogue
and shows their basis risk: first one cover for the whole UK, then two
covers, one for England and Wales and one for Scotland, whose payouts are
added.

Each trigger index is the exposure-weighted mean gust over its region: the
footprint gust averaged over the cells with assets there, each weighted by
the value of its LitPop assets (`exposure_weights()`,
`weighted_mean_index()`). A storm with no gust values in a region has index
0 there. Losses are under the Schwierz curve with `mdd_scale = 0.8`, as in
`ciara_demo.R`, as fractions of the total UK assets, so the covers' amounts
can be added; the report gives them in USD bn.

The event set is the storms of 1940–2025 with a UK maximum gust above
25 m/s, less those that share their maximum gust with a storm less than
72 hours away (`shared_max_within_72h()`): 1,323 storms, 15.38 a year. The
same storms are used for every cover.

Each cover is a layer on its own region's losses: it should pay the loss
above the 1-in-5 year loss (the retention), up to the 1-in-20 year loss, so
its limit is the difference. `calibrate_trigger()` sets the attachment and
exhaustion at the index levels of those two losses: each is the lowest
index among the storms with a loss above the level. The payout is a straight
line from nothing at the attachment to the limit at the exhaustion
(`payout()`), and the basis risk of a storm is its payout minus what the
layer would pay (`basis_risk()`). The return periods are `attach_rp` and
`exhaust_rp` at the top of the script.

It reads `uk_storm_values.csv`, the three `*_exposure_gust.csv` and three
`*_storm_losses.csv` files, `uk_nuts1_cover.tif` and `uk_litpop_025deg.tif`
from `inst/extdata/`, so it runs from a checkout without `data-raw/` or a
CDS account. If any are missing it names them and does nothing else. It
takes about 3 seconds.

It gives:

```
1323 storms, 15.38 a year.
UK: attachment 25.81 m/s, exhaustion 31.08 m/s; layer USD 0.243 bn xs USD 0.203 bn.
  120 storms pay out, 18 would recover; 1 of those pay nothing, 103 with no recovery pay something. Paid a year: trigger USD 0.114 bn, layer USD 0.028 bn; correlation 0.52.
England and Wales: attachment 26.63 m/s, exhaustion 30.82 m/s; layer USD 0.241 bn xs USD 0.183 bn.
  65 storms pay out, 18 would recover; 1 of those pay nothing, 48 with no recovery pay something. Paid a year: trigger USD 0.081 bn, layer USD 0.026 bn; correlation 0.636.
Scotland: attachment 32.37 m/s, exhaustion 34.8 m/s; layer USD 0.073 bn xs USD 0.054 bn.
  22 storms pay out, 18 would recover; 1 of those pay nothing, 5 with no recovery pay something. Paid a year: trigger USD 0.011 bn, layer USD 0.01 bn; correlation 0.972.
England and Wales plus Scotland: 82 storms pay out, 35 would recover; 2 of those pay nothing, 49 with no recovery pay something. Paid a year: trigger USD 0.092 bn, layer USD 0.036 bn; correlation 0.663.
```

and then the ten storms with the largest UK loss: their three indices, the
UK cover's payout and layer recovery, the same for the two regional covers
added, and the storm's loss, in USD bn:

```
   event uk_index ew_index sco_index uk_payout uk_layer regional_payout
1   1070     33.2     34.3      21.8     0.243    0.243           0.241
2    926     31.1     30.8      33.8     0.243    0.243           0.284
3   1079     32.9     33.4      27.2     0.243    0.243           0.241
4   1470     31.6     32.0      28.0     0.243    0.243           0.241
5   1758     31.9     32.2      29.7     0.243    0.243           0.241
6   1346     25.8     24.8      39.0     0.000    0.210           0.073
7   1014     26.2     26.6      21.8     0.016    0.159           0.000
8   1804     31.0     31.3      28.8     0.239    0.157           0.241
9   1224     28.2     28.6      24.3     0.112    0.098           0.114
10  1239     27.5     27.8      23.1     0.076    0.093           0.066
   regional_layer storm_loss
1           0.241      1.340
2           0.256      0.990
3           0.241      0.888
4           0.241      0.528
5           0.241      0.460
6           0.073      0.413
7           0.180      0.362
8           0.160      0.361
9           0.118      0.302
10          0.112      0.297
```

The largest storms are paid in full. Most of the basis risk is the other
way: storms whose index passes the attachment but whose loss stays below
the retention, so the trigger pays about four times what the UK layer
would. Splitting the UK into two covers halves the number of such storms.
Track 1346, which hit Scotland hardest, gets nothing from the UK cover but
the full Scotland limit from the regional covers.

The storm a cover misses is the one that sets its attachment, because its
index equals the attachment and the payout there is nothing: track 1346 for
the UK cover, track 1014 (the Great Storm of October 1987) for England and
Wales and track 344 for Scotland. The two regional layers together are also
a bigger cover than the UK layer: their limits add up to 0.314 USD bn
against 0.243, and they would pay 0.036 USD bn a year against 0.028. So the
two sets of figures compare covers of different size.
