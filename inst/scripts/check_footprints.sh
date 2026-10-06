#!/usr/bin/env bash
# Check that every monthly footprint zip is intact, that every storm in the
# Hodges tracks CSV has exactly one footprint .nc in those zips, and that
# footprint dates match track start dates. Reads the zips only; nothing is
# extracted or written outside a temporary directory, which is removed on exit.
#
# Run from the project root, after download_tracks.R and download_footprints.R.
# Says so and exits 1 if an input is missing. Each check prints a count and
# lists any problems; the last line is OK (exit 0) or PROBLEMS FOUND (exit 1).
set -euo pipefail

if [ ! -d data-raw ]; then
  echo "No data-raw directory; run from the project root."; exit 1
fi
cd data-raw

tracks=reanalysis_tracks_hodges.zip
if [ ! -f "$tracks" ]; then
  echo "data-raw/$tracks not found; run download_tracks.R first."; exit 1
fi
zips=(footprints/*.zip)
if [ ! -f "${zips[0]}" ]; then
  echo "No zips in data-raw/footprints; run download_footprints.R first."; exit 1
fi

tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT

# Print a count and the items (one per line) under a label; add to problems.
problems=0
report() {
  local n
  n=$(grep -c . <<< "$2" || true)
  echo "$1: $n"
  if [ "$n" -gt 0 ]; then sed 's/^/  /' <<< "$2"; fi
  problems=$((problems + n))
}

# 1. Integrity of every monthly zip (unzip -t checks each member's CRC)
echo "zips tested: ${#zips[@]}"
report "bad zips" "$(for z in "${zips[@]}"; do
  unzip -tq "$z" >/dev/null 2>&1 || echo "$z"; done)"

# 2. Every .nc inside the zips (reads the zip index only)
#    Filename: storm_footprint-hodges-raw-YYYYMMDD-<trackid>-original-decontaminated-v1_0.nc
for z in "${zips[@]}"; do unzip -Z1 "$z" 2>/dev/null || true; done |
  { grep '\.nc$' || true; } > "$tmp/fp_files.txt"
echo "footprint files: $(wc -l < "$tmp/fp_files.txt")"

# 3. Track ids from the footprint filenames (5th '-'-separated field)
awk -F- '{print $5}' "$tmp/fp_files.txt" | sort -n > "$tmp/fp_ids.txt"
echo "distinct footprint ids: $(uniq "$tmp/fp_ids.txt" | wc -l)"
report "duplicate footprint ids" "$(uniq -d "$tmp/fp_ids.txt")"

# 4. Track ids from the tracks CSV (column 1, skip header)
unzip -p "$tracks" | awk -F, 'NR>1 {print $1}' | sort -un > "$tmp/tr_ids.txt"
echo "track ids: $(wc -l < "$tmp/tr_ids.txt")"

# 5. Set differences
report "tracks without footprint" "$(comm -23 "$tmp/tr_ids.txt" <(uniq "$tmp/fp_ids.txt"))"
report "footprints without track" "$(comm -13 "$tmp/tr_ids.txt" <(uniq "$tmp/fp_ids.txt"))"

# 6. Footprint filename date vs earliest track time, for ids in both;
#    a mismatch prints as: id footprint_date track_date
awk -F- '{print $5, $4}' "$tmp/fp_files.txt" | sort > "$tmp/fp_iddate.txt"
unzip -p "$tracks" |
  awk -F, 'NR>1 { d = substr($2, 1, 10); gsub("-", "", d)
                  if (!($1 in m) || d < m[$1]) m[$1] = d }
           END  { for (i in m) print i, m[i] }' |
  sort > "$tmp/tr_iddate.txt"
report "date mismatches" "$(join "$tmp/fp_iddate.txt" "$tmp/tr_iddate.txt" |
  awk '$2 != $3')"

if [ "$problems" -eq 0 ]; then
  echo "OK: every storm has exactly one footprint, dated by its track start."
else
  echo "PROBLEMS FOUND: $problems, listed above."; exit 1
fi
