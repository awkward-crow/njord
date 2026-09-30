# Download scripts

These scripts download the raw hazard data used by njord from the Copernicus
Climate Data Store (CDS) dataset
[`sis-european-wind-storm-reanalysis`](https://cds.climate.copernicus.eu/datasets/sis-european-wind-storm-reanalysis)
(Hodges tracking, 1940–2026), check that the download is complete, and unpack
it. A CDS account is required.

**Run every script from the project root.** All paths in the scripts are
relative to it, and all output goes to `data-raw/`.

| Script                  | Output in `data-raw/`                                              |
|-------------------------|--------------------------------------------------------------------|
| `download_tracks.R`     | `reanalysis_tracks_hodges.zip`                                     |
| `download_footprints.R` | `footprints/footprints_hodges_YYYYMM.zip`, one per year-month      |
| `check_footprints.sh`   | nothing; prints a report                                           |
| `unzip_footprints.sh`   | `footprints/nc/*.nc`, one per storm                                |

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
