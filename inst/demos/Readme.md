# Demos

These two scripts demonstrate the package functions. Each prints a short
report with `message()`, so it goes to stderr; neither writes a file.
Run in an interactive session, each also draws a plot. They load the
package with `devtools::load_all()`, so they run without njord being
installed.

**Run every demo from the project root**, for example:

    Rscript inst/demos/ciara_demo.R

The data they read are made by the [data scripts](../scripts/Readme.md).

## ciara_demo.R

Runs Storm Ciara (February 2020, track 1758) through from footprint to
modelled loss.

It first gives the trigger index, the exposure-weighted UK mean gust: the
footprint gust averaged over the 728 cells with UK assets, each weighted by
the value of its LitPop assets (`exposure_weights()`,
`weighted_mean_index()`). It
then gives the loss to UK assets under the Schwierz vulnerability curve
(`schwierz_mdr()`) with the mean damage degree scaled by `mdd_scale = 0.8`,
the UK calibration against PERILS losses with the RMSE cost function, read
from Fig. 3n of Mishra et al. (2026). The LitPop exposure is summed to the
footprint grid, 6 × 6 LitPop cells to each footprint cell, which keeps the
total exactly, and both gusts and assets are restricted to the cells with UK
assets, so the curve is not applied to sea cells. Losses are in USD. In an
interactive session it also plots the footprint with the UK coastline from
rnaturalearth.

It reads the three rasters in `inst/extdata/` written by
`uk_litpop_025deg.R`, `uk_nuts1_cover.R` and `ciara_footprint_uk.R` in
`inst/scripts/extdata/`, so it runs from a checkout without `data-raw/` or a
CDS account.

It gives:

```
Storm Ciara (track 1758): exposure-weighted UK mean gust index 31.94 m/s, over 728 cells with UK assets.
UK assets 9472 USD bn; highest UK gust 38.4 m/s.
Modelled loss 0.460 USD bn (Schwierz, mdd_scale 0.8).
```

The loss is proportional to `mdd_scale`: the unscaled curve gives 0.575 USD
bn.

## calibration_demo.R

Calibrates a parametric cover for Scotland with
`frequency_matching_calibration()` and measures its basis risk over the
storm catalogue, in sample. The comparison with the other two rules, the
England and Wales, combined and UK covers, the out-of-sample test and the
limits of the method are in the vignette,
[`docs/njord-method.md`](../../docs/njord-method.md)
(source `vignettes/njord-method.Rmd`).

The index is the exposure-weighted mean gust over Scotland: the footprint
gust averaged over the cells with assets there, each weighted by the value
of its LitPop assets (`exposure_weights()`). The event set is the
package's current definition: the storms of 1940–2025 with a UK maximum
gust above 25 m/s, less those that share their maximum gust with a storm
less than 72 hours away (`shared_max_within_72h()`): 1,323 storms, 15.38 a
year. Losses are under the Schwierz curve with `mdd_scale = 0.8`, as in
`ciara_demo.R`.

The cover is compared with a layer on Scotland's losses, which pays the
loss above the *retention* (the loss exceeded about once in five years) up
to the loss exceeded about once in twenty, so its *limit* is the
difference. A storm's *recovery* is what the layer would have paid on it,
and the cover's *basis risk* on the storm is its payout minus the recovery
(positive is an overpayment). The payout is a straight line from nothing at
the *attachment* to the limit at the *exhaustion* (`payout()`). The
frequency-matched cover ranks the storms by wind index and pays on as many
of the windiest as the layer pays on, and in full on as many as the layer
pays its limit on, so it pays about as often as the layer would. The basis
risk is measured against the modelled loss, which is built from the same
ERA5 gust field as the index, so errors in that field are not part of it.

It gives:

```
Basis risk here is measured against a modelled loss from the same ERA5 gust field as the index, not against real losses.
Frequency-matched Scotland cover (frequency_matching_calibration()), on 1323 storms of 1940-2025 (15.38 a year); amounts in USD.
Layer:        USD 73.1 m xs USD 53.8 m (the 1-in-5 to 1-in-20 year Scottish loss)
Attachment:   32.62 m/s, set by track 1642 (Jan 2015)
Exhaustion:   35.05 m/s, set by track 1266 (Dec 1998)
Storms paid / storms recovering:      18 / 18
False payments (paid, no recovery):   2
Missed storms (recovery, not paid):   2
Typical basis risk (RMS):             USD 1.2 m a storm
Typical basis risk / reference cover: 0.20
Paid / layer:                         1.03
Correlation of payout with recovery:  0.98
(The reference cover ignores the wind and pays every storm the mean recovery.)

The 5 storms with the largest Scottish loss, in USD m:
 track     date index  loss recovery payout
  1346 Jan 2002 38.98 394.5     73.1   73.1
  1618 Dec 2013 36.23 174.9     73.1   73.1
  1266 Dec 1998 35.05 163.1     73.1   73.1
  1045 Feb 1989 35.31 151.5     73.1   73.1
  1578 Dec 2011 34.80 127.4     73.1   65.5
Track 1346 (January 2002): its modelled Scottish loss is not supported by observed gusts.
```

*False payments* are storms the cover pays on where the layer pays
nothing, and *missed storms* are storms the layer pays on that the cover
does not. The typical basis risk is the root-mean-square of payout minus
recovery. The *reference cover* ignores the wind and pays every storm the
same amount, the mean recovery. The cover's typical basis risk as a
fraction of the reference cover's is below 1 when the index helps.

In an interactive session it also draws the plot behind the figure in the
main README: for
each storm with an index of at least 25 m/s, the layer's recovery (circle)
and the cover's payout (dot, on the ramp) against the storm's index, joined
where they differ, with the attachment and exhaustion marked, the largest
storms labelled and the January 2002 storm (track 1346) set apart in red, as
its modelled loss is not supported by observed gusts.
It reads `uk_storm_values.csv`, `sco_exposure_gust.csv`,
`sco_storm_losses.csv`, `uk_nuts1_cover.tif` and `uk_litpop_025deg.tif`
from `inst/extdata/`, so it runs from a checkout without `data-raw/` or a
CDS account. If any are missing it names them and does nothing else. It
takes a few seconds and uses base graphics only.
