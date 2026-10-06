#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Digital Art → Print-on-Demand Export Pipeline
# Refreshed October 2026 for Redbubble (specs verified 2026-08-04).
#
# Redbubble upload rules:
#   - File types accepted: JPEG and PNG only (TIFF/PDF rejected)
#   - Colour: upload RGB (design in CMYK if you like, convert to RGB to upload)
#   - Hard limits: 300 MB per file, 13500 x 13500 pixels
#   - DPI/PPI metadata is ignored by Redbubble, but 300 DPI is set anyway so
#     the same print file is correct for other print services
#
# Official product minimums (both dimensions must be met, either orientation):
#   Art Prints (all sizes to XL) .... 3840 x 3840
#   XL Framed / Canvas .............. 4800 x 4800
#   Duvets / Tapestries / Blankets .. 7632 x 6480
#   Desk Mats ....................... 8268 x 4331
#   Photographic Prints XL .......... 9144 x 6096
#   Jigsaw Puzzles .................. 9075 x 6201
#   Posters (Large) ................. 8310 x 11790
#   Stickers (XL) ................... 2800 x 2800  (PNG for transparency)
#
# Target presets for TARGET_LONG_EDGE below:
#   3840  = wall art only
#   4800  = wall art incl. XL canvas
#   7632  = DEFAULT: large home decor (duvets/tapestries/blankets) + most else
#   9144  = adds photographic prints XL and jigsaws
#   11790 = full coverage incl. large posters (check the 300 MB cap!)
#   0     = never upscale, only normalise/convert what you feed it
#
# USAGE
#   ./normalize_art.sh [input_dir] [output_dir] [preview_dir]
#   ./normalize_art.sh --check <dir>     validate existing files against specs
#
# Defaults: ./input_art  ./normalized_art  ./store_previews
# ============================================================================

# ==========================================
# CONFIGURATION
# ==========================================
INPUT_DIR="${1:-./input_art}"
OUTPUT_DIR="${2:-./normalized_art}"
PREVIEW_DIR="${3:-./store_previews}"

# ----- Redbubble export target --------------------------------------------
TARGET_LONG_EDGE=7632       # see presets above; 0 disables upscaling
ALLOW_LANCZOS_UPSCALE=1     # 1 = fall back to Lanczos if art is too small.
                            # Quality is much better if you re-run Upscayl
                            # (Digital Art 4x) at TARGET_LONG_EDGE first.
MAX_LONG_EDGE=13500         # Redbubble hard cap
MAX_FILE_MB=300             # Redbubble hard cap
UPLOAD_FORMAT="jpg"         # jpg or png (png if you need transparency)
JPEG_QUALITY=95             # Redbubble recommend 95%+
DPI=300                     # metadata only; RB ignore it, other printers may not

# ----- Print adjustment ----------------------------------------------------
# 1.0 is neutral. 1.08 to 1.12 corrects the screen-to-print darkness gap.
PRINT_LIGHTNESS_BUMP="1.20"
SATURATION=120              # 100 = neutral
LEVEL_CLIP="1%,99%"         # trim extreme shadows/highlights before gamma lift
SHARPEN_AMOUNT="0x0.8"

# ----- Store preview config ------------------------------------------------
MAKE_PREVIEWS=1             # NOTE: previews are watermarked — never upload
PREVIEW_WIDTH="1200"        #  these to Redbubble, only the print files
WATERMARK_TEXT="© 2026 James Dyer | Shop Preview"
# Using hex for better compatibility (#RRGGBBAA)
WATERMARK_COLOR="#FFFFFF99"       # white, ~60% opacity
WATERMARK_SHADOW_COLOR="#00000066" # black, ~40% opacity
PREVIEW_QUALITY=82

# ----- Metadata ------------------------------------------------------------
ARTIST_NAME="James Dyer"
SHOP_URL="https://yourshop.com"     # <-- update me
COPYRIGHT_NOTICE="© 2026 $ARTIST_NAME. All rights reserved."

# ----- Optional G'MIC colour matching --------------------------------------
# Point at a single "hero" piece to make the whole collection share its
# palette, or leave empty to enhance each image independently.
REFERENCE_IMAGE=""          # e.g. "./reference.png"

# ==========================================
# SYSTEM CHECKS
# ==========================================
MAGICK_OK=0; GMIC_OK=0; EXIF_OK=0
command -v magick  >/dev/null && MAGICK_OK=1
command -v gmic    >/dev/null && GMIC_OK=1
command -v exiftool >/dev/null && EXIF_OK=1

if (( ! MAGICK_OK || ! EXIF_OK )); then
    echo "Error: ImageMagick ('magick') and ExifTool ('exiftool') must be installed." >&2
    echo "  sudo apt install imagemagick libimage-exiftool-perl" >&2
    exit 1
fi
if [[ -n "$REFERENCE_IMAGE" ]] && (( ! GMIC_OK )); then
    echo "Error: REFERENCE_IMAGE is set but G'MIC ('gmic') is not installed." >&2
    exit 1
fi

human_size() { # bytes -> "12.3 MB"
    awk -v b="$1" 'BEGIN { printf "%.1f MB", b/1048576 }'
}

dimensions() { # file -> "W H"
    magick identify -format '%w %h\n' "$1"
}

# Print which Redbubble product tiers this pixel size unlocks
report_tiers() {
    local w=$1 h=$2 long short
    if (( w >= h )); then long=$w; short=$h; else long=$h; short=$w; fi
    local tiers=()
    (( short >= 3840 )) && tiers+=("Art Prints")
    (( short >= 4800 )) && tiers+=("XL Canvas")
    (( (w >= 7632 && h >= 6480) || (w >= 6480 && h >= 7632) )) && tiers+=("Duvets/Tapestries")
    (( (w >= 8268 && h >= 4331) || (w >= 4331 && h >= 8268) )) && tiers+=("Desk Mats")
    (( (w >= 9075 && h >= 6201) || (w >= 6201 && h >= 9075) )) && tiers+=("Jigsaws")
    (( (w >= 9144 && h >= 6096) || (w >= 6096 && h >= 9144) )) && tiers+=("Photographic XL")
    (( (w >= 8310 && h >= 11790) || (w >= 11790 && h >= 8310) )) && tiers+=("Posters Large")
    if (( ${#tiers[@]} == 0 )); then
        echo "    Tiers: apparel/accessories only (wall art needs >= 3840px)"
    else
        echo "    Tiers: ${tiers[*]}"
    fi
}

# ==========================================
# CHECK MODE — validate files against Redbubble specs
# ==========================================
if [[ "${1:-}" == "--check" ]]; then
    CHECK_DIR="${2:-.}"
    [[ -d "$CHECK_DIR" ]] || { echo "Not a directory: $CHECK_DIR" >&2; exit 1; }
    echo "Redbubble spec check: $CHECK_DIR"
    echo "----------------------------------------------------------------------"
    FOUND=0; BAD=0
    while IFS= read -r -d '' f; do
        FOUND=$((FOUND + 1))
        read -r w h < <(dimensions "$f")
        size=$(stat -c %s "$f")
        mb=$(human_size "$size")
        status="OK"
        (( size > MAX_FILE_MB * 1048576 )) && status="TOO BIG (>${MAX_FILE_MB}MB)"
        (( w > 13500 || h > 13500 )) && status="TOO BIG (>13500px)"
        (( w < 2400 || h < 2400 )) && [[ "$status" == OK ]] && status="WARN: small"
        [[ "$status" != OK ]] && BAD=$((BAD + 1))
        echo "$(basename "$(dirname "$f")")/$(basename "$f") — ${w}x${h}, $mb [$status]"
        report_tiers "$w" "$h"
    done < <(find "$CHECK_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0)
    echo "----------------------------------------------------------------------"
    echo "$FOUND file(s) checked, $BAD with warnings."
    exit 0
fi

# ==========================================
# PROCESSING
# ==========================================
mkdir -p "$OUTPUT_DIR" "$PREVIEW_DIR"

echo "========================================"
echo "Digital Art → Redbubble Pipeline"
echo "========================================"
echo "Input:      $INPUT_DIR"
echo "Prints:     $OUTPUT_DIR (target long edge ${TARGET_LONG_EDGE}px, ${UPLOAD_FORMAT^^}, ${DPI} DPI)"
(( MAKE_PREVIEWS )) && echo "Previews:   $PREVIEW_DIR (${PREVIEW_WIDTH}px watermarked)"
if [[ -n "$REFERENCE_IMAGE" && -f "$REFERENCE_IMAGE" ]]; then
    echo "Palette:    matching to $(basename "$REFERENCE_IMAGE") via G'MIC"
else
    echo "Palette:    independent enhancement per image"
fi
echo "----------------------------------------"

TOTAL=0
while IFS= read -r -d '' img; do
    TOTAL=$((TOTAL + 1))
    rel_path="${img#"$INPUT_DIR"/}"
    name="${rel_path%.*}"
    target_out="$OUTPUT_DIR/${name}.${UPLOAD_FORMAT}"
    target_preview="$PREVIEW_DIR/${name}.jpg"

    mkdir -p "$(dirname "$target_out")" "$(dirname "$target_preview")"
    echo "Processing: $rel_path"

    # ---- optional G'MIC palette match against a reference -----------------
    process_src="$img"
    tmp_matched=""
    if [[ -n "$REFERENCE_IMAGE" && -f "$REFERENCE_IMAGE" ]]; then
        echo "  [Match]  matching palette to $(basename "$REFERENCE_IMAGE")"
        tmp_matched="$(mktemp --suffix=.png)"
        if gmic "$img" "$REFERENCE_IMAGE" \
                -transfer_histogram[0] [1],256 \
                -remove[1] -o "$tmp_matched" >/dev/null 2>&1 && [[ -s "$tmp_matched" ]]; then
            process_src="$tmp_matched"
        else
            echo "  ! G'MIC palette match failed; using standard enhancement instead." >&2
            rm -f "$tmp_matched"
            tmp_matched=""
        fi
    fi

    # ---- work out resize geometry (long edge, aspect preserved) -----------
    read -r w h < <(dimensions "$process_src")
    geom=""
    if (( w >= h )); then long=$w; else long=$h; fi
    if (( long > MAX_LONG_EDGE )); then
        if (( w >= h )); then geom="${MAX_LONG_EDGE}x"; else geom="x${MAX_LONG_EDGE}"; fi
        echo "  [Size]   downscaling ${w}x${h} → ${MAX_LONG_EDGE}px long edge (Redbubble cap)"
    elif (( TARGET_LONG_EDGE > 0 && long < TARGET_LONG_EDGE )); then
        if (( ALLOW_LANCZOS_UPSCALE )); then
            if (( w >= h )); then geom="${TARGET_LONG_EDGE}x"; else geom="x${TARGET_LONG_EDGE}"; fi
            echo "  [Size]   upscaling ${w}x${h} → ${TARGET_LONG_EDGE}px long edge (Lanczos fallback)"
            echo "           ! For best print quality, re-run Upscayl (Digital Art 4x) at ${TARGET_LONG_EDGE}px and process that."
        else
            echo "  [Size]   WARNING: ${long}px long edge is below ${TARGET_LONG_EDGE}px target; passing through unchanged."
        fi
    fi

    # ---- print file: normalise colour, lift for print, set metadata -------
    magick_args=( "$process_src" -colorspace sRGB )
    [[ -n "$geom" ]] && magick_args+=( -filter Lanczos -resize "$geom" )
    magick_args+=(
        -level "$LEVEL_CLIP"
        -gamma "$PRINT_LIGHTNESS_BUMP"
        -modulate 100,"$SATURATION",100
        -sharpen "$SHARPEN_AMOUNT"
        -strip
        -units PixelsPerInch -density "$DPI"
    )
    if [[ "$UPLOAD_FORMAT" == "jpg" ]]; then
        magick_args+=( -quality "$JPEG_QUALITY" "$target_out" )
    else
        magick_args+=( "$target_out" )
    fi
    magick "${magick_args[@]}"

    exiftool -q -m \
        -Artist="$ARTIST_NAME" \
        -Copyright="$COPYRIGHT_NOTICE" \
        -CopyrightNotice="$COPYRIGHT_NOTICE" \
        -Comment="Purchased from $SHOP_URL" \
        -XResolution="$DPI" -YResolution="$DPI" -ResolutionUnit=inches \
        -overwrite_original \
        "$target_out"

    [[ -n "$tmp_matched" ]] && rm -f "$tmp_matched"

    # ---- post-write validation --------------------------------------------
    read -r out_w out_h < <(dimensions "$target_out")
    out_size=$(stat -c %s "$target_out")
    out_mb=$(human_size "$out_size")
    echo "  ✓ Print: $target_out (${out_w}x${out_h}, $out_mb)"
    report_tiers "$out_w" "$out_h"
    if (( out_size > MAX_FILE_MB * 1048576 )); then
        echo "    ! WARNING: over Redbubble's ${MAX_FILE_MB}MB limit — lower JPEG_QUALITY or use jpg."
    fi
    if (( out_w > 13500 || out_h > 13500 )); then
        echo "    ! WARNING: over Redbubble's 13500px limit."
    fi

    # ---- watermarked store preview (do NOT upload to Redbubble) -----------
    if (( MAKE_PREVIEWS )); then
        magick "$target_out" \
            -resize "${PREVIEW_WIDTH}x" \
            -gravity Center \
            -pointsize 60 \
            -fill "$WATERMARK_SHADOW_COLOR" -annotate +2+2 "$WATERMARK_TEXT" \
            -fill "$WATERMARK_COLOR"        -annotate +0+0 "$WATERMARK_TEXT" \
            -quality "$PREVIEW_QUALITY" \
            "$target_preview"
        echo "  ✓ Preview: $target_preview"
    fi
    echo "----------------------------------------"
done < <(find "$INPUT_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.tiff' \) -print0)

if (( TOTAL == 0 )); then
    echo "No images found in $INPUT_DIR"
    exit 1
fi

echo "========================================"
echo "Complete: $TOTAL image(s) processed."
echo "Print-ready uploads: $OUTPUT_DIR  (upload these to Redbubble)"
echo "Watermarked web:     $PREVIEW_DIR  (for your own shop, not Redbubble)"
echo "Validate any folder: $0 --check <dir>"
echo "========================================"
