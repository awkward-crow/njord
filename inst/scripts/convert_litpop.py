# Write the LitPop points (latitude, longitude, value in USD) from
# data-raw/litpop/LitPop_150arcsec_GBR.hdf5 to a CSV next to it.
#
# The coordinates are in degrees on WGS 84, the usual latitude/longitude
# system (EPSG:4326 in the EPSG registry of coordinate reference systems,
# or CRS). The HDF5 records this CRS in the exposures node's metadata;
# the CSV does not, so code reading it must assume EPSG:4326.
#
# The HDF5 file is a pandas table under the key "exposures", with a pickled
# geometry column. Only the block holding value, latitude and longitude is
# read, with PyTables, so neither pandas nor shapely is needed. The block's
# column names and row count are checked first.
#
# Run from the project root, after download_litpop.sh. Says so and does
# nothing if the CSV already exists. Writes to a .part file and renames it
# when complete. Ends with the number of points, the value total and the
# coordinate ranges; the last line is OK (exit 0) or PROBLEMS FOUND (exit 1).
import csv
import os
import sys

import tables

SOURCE = "data-raw/litpop/LitPop_150arcsec_GBR.hdf5"
TARGET = "data-raw/litpop/LitPop_150arcsec_GBR.csv"
COLUMNS = ["latitude", "longitude", "value"]


def read_block(path):
    """Column names, values and row count of the table's float block."""
    with tables.open_file(path) as h5:
        table = h5.root.exposures
        names = [s.decode() for s in table.block0_items.read()]
        return names, table.block0_values.read(), table.axis1.shape[0]


def write_csv(path, points):
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(COLUMNS)
        writer.writerows(points.tolist())


def main():
    if not os.path.isdir("data-raw"):
        print("No data-raw directory; run from the project root.")
        return 1
    if os.path.exists(TARGET):
        print(f"OK: {TARGET} already exists; delete it to make it again.")
        return 0
    if not os.path.exists(SOURCE):
        print(f"No {SOURCE}; run download_litpop.sh first.")
        return 1

    try:
        names, values, rows = read_block(SOURCE)
    except Exception as e:
        print(f"can't read {SOURCE}: {type(e).__name__}: {e}".strip())
        print("PROBLEMS FOUND.")
        return 1
    if sorted(names) != sorted(COLUMNS) or values.shape != (rows, 3):
        print(f"unexpected layout: columns {names}, shape {values.shape}, "
              f"{rows} rows")
        print("PROBLEMS FOUND.")
        return 1
    points = values[:, [names.index(c) for c in COLUMNS]]

    part = TARGET + ".part"
    try:
        write_csv(part, points)
        os.replace(part, TARGET)
    finally:
        if os.path.exists(part):
            os.remove(part)

    lat, lon, value = points.T
    print(f"points: {rows}")
    print(f"value total: {value.sum():,.0f} USD")
    print(f"zero values: {(value == 0).sum()}")
    print(f"latitude: {lat.min()} to {lat.max()}")
    print(f"longitude: {lon.min()} to {lon.max()}")
    print(f"OK: {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
