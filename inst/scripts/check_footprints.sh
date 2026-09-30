#!/usr/bin/env bash
# Check that every monthly footprint zip is intact, that every storm in the
# Hodges tracks CSV has exactly one footprint .nc in those zips, and that
# footprint dates match track start dates.
# Run from the project root, after download_tracks.R and download_footprints.R.
set -euo pipefail

cd data-raw

tmp=$(mktemp -d)

# 1. Integrity of every monthly zip (unzip -t checks each member's CRC; nothing is extracted)
echo "zips tested: $(ls footprints/*.zip | wc -l)"
echo "bad zips:"
for z in footprints/*.zip; do unzip -tq "$z" >/dev/null 2>&1 || echo "$z"; done

# 2. List every .nc inside the 721 monthly zips (reads the zip index; nothing is extracted)
#    Filename: storm_footprint-hodges-raw-YYYYMMDD-<trackid>-original-decontaminated-v1_0.nc
for z in footprints/*.zip; do unzip -Z1 "$z"; done | grep '\.nc$' > "$tmp/fp_files.txt"
echo "footprint files: $(wc -l < "$tmp/fp_files.txt")"

# 3. Track ids from the footprint filenames (5th '-'-separated field)
awk -F- '{print $5}' "$tmp/fp_files.txt" | sort -n > "$tmp/fp_ids.txt"
echo "distinct footprint ids: $(uniq "$tmp/fp_ids.txt" | wc -l)"
echo "duplicate footprint ids:"; uniq -d "$tmp/fp_ids.txt"

# 4. Track ids from the tracks CSV (column 1, skip header)
unzip -p reanalysis_tracks_hodges.zip | awk -F, 'NR>1 {print $1}' | sort -un > "$tmp/tr_ids.txt"
echo "track ids: $(wc -l < "$tmp/tr_ids.txt")"

# 5. Set differences
echo "tracks without footprint:";  comm -23 "$tmp/tr_ids.txt" <(uniq "$tmp/fp_ids.txt")
echo "footprints without track:";  comm -13 "$tmp/tr_ids.txt" <(uniq "$tmp/fp_ids.txt")

# 6. Footprint filename date vs earliest track time for each id
awk -F- '{print $5, $4}' "$tmp/fp_files.txt" | sort > "$tmp/fp_iddate.txt"
unzip -p reanalysis_tracks_hodges.zip |
  awk -F, 'NR>1 { d = substr($2, 1, 10); gsub("-", "", d)
                  if (!($1 in m) || d < m[$1]) m[$1] = d }
           END  { for (i in m) print i, m[i] }' |
  sort > "$tmp/tr_iddate.txt"
echo "date mismatches: $(comm -3 "$tmp/fp_iddate.txt" "$tmp/tr_iddate.txt" | wc -l)"
comm -3 "$tmp/fp_iddate.txt" "$tmp/tr_iddate.txt"

rm -r "$tmp"
