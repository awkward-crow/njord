#!/usr/bin/env bash
# Extract the footprint .nc files from every monthly zip into
# data-raw/footprints/nc/, one file per storm. The zips are left in place, and
# a file that already exists is not overwritten, so the script can be re-run.
# Run from the project root, after download_footprints.R and check_footprints.sh.
set -euo pipefail

cd data-raw/footprints

mkdir -p nc

echo "failed zips:"
for z in footprints_hodges_*.zip; do unzip -qn "$z" -d nc || echo "$z"; done

echo "zips: $(ls footprints_hodges_*.zip | wc -l)"
echo "footprint files: $(ls nc | grep -c '\.nc$')"
