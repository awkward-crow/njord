#!/usr/bin/env bash
# Download CLIMADA's LitPop exposure for the UK (v3, exponents (1,1),
# fin_mode pc, 150 arcsec) into data-raw/litpop/. The file is listed by
# CLIMADA's data API:
# https://climada.ethz.ch/data-api/v2/dataset/?data_type=litpop&country_iso3alpha=GBR&status=active
#
# Run from the project root. Says so and does nothing if the file is already
# there. Downloads to a .part file, checks its size against the API's, and
# renames it only if the sizes match. The last line is OK (exit 0) or
# PROBLEMS FOUND (exit 1).
set -euo pipefail

if [ ! -d data-raw ]; then
  echo "No data-raw directory; run from the project root."; exit 1
fi
url=https://data.iac.ethz.ch/climada/e750f52b-c3d2-49aa-be40-8ccc35a260a7/LitPop_150arcsec_GBR.hdf5
size=2571888
dir=data-raw/litpop
file="$dir/LitPop_150arcsec_GBR.hdf5"

if [ -f "$file" ]; then
  echo "OK: $file already exists; delete it to download again."; exit 0
fi

mkdir -p "$dir"
trap 'rm -f "$file.part"' EXIT
if ! curl -fsS -o "$file.part" "$url"; then
  echo "download failed: $url"
  echo "PROBLEMS FOUND."; exit 1
fi
got=$(stat -c %s "$file.part")
if [ "$got" -ne "$size" ]; then
  echo "wrong size: $got bytes, expected $size"
  echo "PROBLEMS FOUND."; exit 1
fi
mv "$file.part" "$file"
echo "OK: $file, $size bytes."
