#!/usr/bin/env bash
# Extract the footprint .nc files from every monthly zip into
# data-raw/footprints/nc/, one file per storm. The zips are left in place.
# Only files not already in nc/ are extracted, so the script can be re-run.
# Files are extracted into a staging directory, removed on exit, and moved
# into nc/ only when unzip succeeds, so an interrupted run or a bad zip
# leaves no partial files in nc/.
#
# Run from the project root, after download_footprints.R and
# check_footprints.sh. Says so and exits 1 if there are no zips. Ends with
# the number of files expected, already present and extracted; the last line
# is OK (exit 0) or PROBLEMS FOUND (exit 1), listing failed zips and files
# still missing.
set -euo pipefail
export LC_ALL=C

if [ ! -d data-raw ]; then
  echo "No data-raw directory; run from the project root."; exit 1
fi
dir=data-raw/footprints
zips=("$dir"/footprints_hodges_*.zip)
if [ ! -f "${zips[0]}" ]; then
  echo "No zips in $dir; run download_footprints.R first."; exit 1
fi

tmp=$(mktemp -d)
stage="$dir/nc.part"
trap 'rm -rf "$tmp" "$stage"' EXIT

# "zip member" for every .nc in the zips (zips that can't be read go in
# failed.txt); the files already in nc/; the members not yet in nc/
: > "$tmp/failed.txt"
for z in "${zips[@]}"; do
  if list=$(unzip -Z1 "$z" 2>/dev/null); then
    sed "s|^|$z |" <<< "$list"
  else
    echo "$z" >> "$tmp/failed.txt"
  fi
done | { grep '\.nc$' || true; } | sort -k2 > "$tmp/members.txt"
{ ls "$dir/nc" 2>/dev/null || true; } | sort > "$tmp/present.txt"
join -1 2 -2 1 -v 1 -o 1.1,1.2 "$tmp/members.txt" "$tmp/present.txt" \
  > "$tmp/missing.txt"

expected=$(wc -l < "$tmp/members.txt")
missing=$(wc -l < "$tmp/missing.txt")
echo "zips: ${#zips[@]}"
echo "footprint files in zips: $expected"
echo "already in nc/: $((expected - missing))"

# Extract the missing files zip by zip, each into its own staging directory,
# dropped if unzip fails
if [ "$missing" -gt 0 ]; then
  mkdir -p "$dir/nc" "$stage"
  for z in $(cut -d' ' -f1 "$tmp/missing.txt" | sort -u); do
    mapfile -t members < <(awk -v z="$z" '$1 == z {print $2}' "$tmp/missing.txt")
    out="$stage/$(basename "$z" .zip)"
    if ! unzip -qo -d "$out" "$z" "${members[@]}" 2>/dev/null; then
      echo "$z" >> "$tmp/failed.txt"
      rm -rf "$out"
    fi
  done
  echo "extracted: $(find "$stage" -name '*.nc' | wc -l)"
  find "$stage" -name '*.nc' -exec mv -n {} "$dir/nc/" \;
fi

{ ls "$dir/nc" 2>/dev/null || true; } | sort > "$tmp/present.txt"
still=$(join -1 2 -2 1 -v 1 -o 1.2 "$tmp/members.txt" "$tmp/present.txt")
if [ ! -s "$tmp/failed.txt" ] && [ -z "$still" ]; then
  echo "OK: all $expected footprint files in nc/."
else
  if [ -s "$tmp/failed.txt" ]; then
    echo "failed zips:"; sed 's/^/  /' "$tmp/failed.txt"
  fi
  if [ -n "$still" ]; then
    echo "still missing:"; sed 's/^/  /' <<< "$still"
  fi
  echo "PROBLEMS FOUND."; exit 1
fi
