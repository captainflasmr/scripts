#!/bin/bash
# Verify that generated photos exist for every eligible source image,
# and optionally report generated files that the current images.sh
# selection would not produce.
#
# Mirrors the selection logic in images.sh:
#   - years under $PHOTOS_SRC (default ~/nas/Photos)
#   - every immediate subdirectory of a year (e.g. 201006-CricketSt,
#     2012-Misc, 2020-All), skipping private/.nomedia directories
#   - JPEGs recursively below each selected directory
#
# Usage:
#   verify_photos.sh [START_YEAR [END_YEAR [START_MONTH]]]
#
# With no arguments it checks the whole collection. START_MONTH filters
# YYYYMM-style directories for the "process from month" mode in images.sh;
# non-month directories are always included.

set -u

SRC="${PHOTOS_SRC:-/home/jdyer/nas/Photos}"
DST="${PHOTOS_DST:-$HOME/DCIM/content/static/photos}"
REPORT="${VERIFY_PHOTOS_REPORT:-$HOME/DCIM/content/verify-photos-missing.txt}"
EXTRA_REPORT="${VERIFY_PHOTOS_EXTRA_REPORT:-$HOME/DCIM/content/verify-photos-extra.txt}"

if [ -n "${1:-}" ]; then
    START_YEAR="$1"
    END_YEAR="${2:-$1}"
else
    START_YEAR=0
    END_YEAR=9999
fi
START_MONTH="${3:-}"

missing_tmp=$(mktemp)
expected_tmp=$(mktemp)
expected_sorted=$(mktemp)
actual_tmp=$(mktemp)
extra_tmp=$(mktemp)
trap 'rm -f "$missing_tmp" "$expected_tmp" "$expected_sorted" "$actual_tmp" "$extra_tmp"' EXIT

expected=0
present=0
missing=0

echo "Source: $SRC"
echo "Output: $DST"
if [ "$START_YEAR" -gt 0 ]; then
    if [ -n "$START_MONTH" ]; then
        echo "Range:  $START_YEAR (from month $START_MONTH)"
    else
        echo "Range:  $START_YEAR-$END_YEAR"
    fi
fi
echo

for year_dir in "$SRC"/[0-9][0-9][0-9][0-9]; do
    [ -d "$year_dir" ] || continue
    year=$(basename "$year_dir")
    [ "$year" -ge "$START_YEAR" ] || continue
    [ "$year" -le "$END_YEAR" ] || continue

    year_expected=0
    year_present=0
    year_missing=0

    while IFS= read -r month_dir; do
        folder=$(basename "$month_dir")
        [ "$folder" = "private" ] && continue
        [ -f "$month_dir/.nomedia" ] && continue
        # In from-month mode only YYYYMM-style dirs are filtered;
        # non-month dirs such as 2012-Misc are always included.
        if [ -n "$START_MONTH" ] && [[ "$folder" =~ ^[0-9]{6} ]] \
           && [ "$folder" \< "$START_MONTH" ]; then
            continue
        fi
        while IFS= read -r -d '' src; do
            base=${src##*/}
            rel_out="$year/${base%.*}.jpg"
            out="$DST/$rel_out"
            year_expected=$((year_expected + 1))
            printf '%s\n' "$out" >> "$expected_tmp"
            if [ -f "$out" ]; then
                year_present=$((year_present + 1))
            else
                year_missing=$((year_missing + 1))
                printf '%s\n' "$out" >> "$missing_tmp"
            fi
        done < <(find "$month_dir" \
            \( -name private -type d -prune \) -o \
            \( -exec [ -f {}/.nomedia ] \; -prune \) -o \
            -iname '*.jpg' -print0)
    done < <(find "$year_dir" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' \
                 | sort)

    expected=$((expected + year_expected))
    present=$((present + year_present))
    missing=$((missing + year_missing))

    if [ "$year_expected" -gt 0 ]; then
        printf '%s  expected=%-5d present=%-5d missing=%-5d\n' \
               "$year" "$year_expected" "$year_present" "$year_missing"
    fi
done

# Report outputs that the current images.sh selection would not create.
# These are usually leftovers from older additive builds in source year
# directories that do not follow the YYYYMM naming convention.
extra=0
if [ -z "$START_MONTH" ]; then
    sort -u "$expected_tmp" > "$expected_sorted"
    find "$DST" -mindepth 2 -maxdepth 2 -type f -iname '*.jpg' -print \
        | awk -F/ -v s="$START_YEAR" -v e="$END_YEAR" \
               '{ y=$(NF-1); if (y ~ /^[0-9][0-9][0-9][0-9]$/ && y+0 >= s && y+0 <= e) print }' \
        | sort -u > "$actual_tmp"
    comm -13 "$expected_sorted" "$actual_tmp" > "$extra_tmp"
    extra=$(wc -l < "$extra_tmp")
fi

echo
echo "Expected: $expected  Present: $present  Missing: $missing"
if [ "$extra" -gt 0 ]; then
    echo "Extra:    $extra (not selected by the current images.sh rules)"
fi

mkdir -p "$(dirname "$REPORT")" "$(dirname "$EXTRA_REPORT")"
cp "$missing_tmp" "$REPORT"
cp "$extra_tmp" "$EXTRA_REPORT"

if [ "$missing" -gt 0 ]; then
    echo
    echo "Missing outputs (first 40):"
    head -40 "$REPORT" | sed 's/^/  /'
    if [ "$missing" -gt 40 ]; then
        echo "  ... and $((missing - 40)) more"
    fi
    echo
    echo "Full list: $REPORT"
fi

if [ "$extra" -gt 0 ]; then
    echo
    echo "Extra outputs (first 20):"
    head -20 "$EXTRA_REPORT" | sed 's/^/  /'
    if [ "$extra" -gt 20 ]; then
        echo "  ... and $((extra - 20)) more"
    fi
    echo
    echo "Full list: $EXTRA_REPORT"
    echo "These outputs have no matching source image under the current"
    echo "images.sh selection; they are stale or manually added files."
fi

if [ "$missing" -gt 0 ]; then
    exit 1
fi

echo "All expected images are present."
exit 0
