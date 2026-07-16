#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# CONFIGURATION
# ==========================================
INPUT_DIR="./input_art"
OUTPUT_DIR="./normalized_art"
PREVIEW_DIR="./store_previews"

# Print Adjustment: 1.0 is neutral. 
# 1.08 to 1.12 corrects the screen-to-print darkness gap.
PRINT_LIGHTNESS_BUMP="1.10" 

# Store Preview Config
PREVIEW_WIDTH="1200"
WATERMARK_TEXT="© 2026 James Dyer | Shop Preview"
# Using hex for better compatibility (#RRGGBBAA)
# White with ~60% opacity
WATERMARK_COLOR="#FFFFFF99" 
# Black with ~40% opacity
WATERMARK_SHADOW_COLOR="#00000066"


# Metadata Details
ARTIST_NAME="James Dyer"
SHOP_URL="https://yourshop.com"
COPYRIGHT_NOTICE="© 2026 $ARTIST_NAME. All rights reserved."

# Optional G'MIC color transfer reference image (leave empty to bypass)
REFERENCE_IMAGE="" # e.g., "./reference.png"

# ==========================================
# SYSTEM CHECKS
# ==========================================
if ! command -v magick &> /dev/null || ! command -v gmic &> /dev/null || ! command -v exiftool &> /dev/null; then
    echo "Error: ImageMagick ('magick'), G'MIC ('gmic'), and ExifTool ('exiftool') must be installed."
    exit 1
fi

# Create target directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$PREVIEW_DIR"

echo "========================================"
echo "Starting Digital Art Processing Pipeline"
echo "========================================"
echo "Input:   $INPUT_DIR"
echo "Prints:  $OUTPUT_DIR (with brightness lift)"
echo "Web:     $PREVIEW_DIR (${PREVIEW_WIDTH}px with Watermark)"
echo "----------------------------------------"

# Process images recursively
find "$INPUT_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.tiff" \) -print0 | while IFS= read -r -d '' img; do
    # Calculate relative path and target output paths
    rel_path="${img#$INPUT_DIR/}"
    target_out="$OUTPUT_DIR/$rel_path"
    target_preview="$PREVIEW_DIR/$rel_path"
    
    # Ensure target subdirectories exist
    mkdir -p "$(dirname "$target_out")"
    mkdir -p "$(dirname "$target_preview")"
    
    filename=$(basename "$img")
    
    echo "Processing: $rel_path"

    # ----------------------------------------------------
    # STEP 1: CREATE HIGH-RES PRINT FILE (Color Normalization & Gamma Lift)
    # ----------------------------------------------------
    if [ -n "$REFERENCE_IMAGE" ] && [ -f "$REFERENCE_IMAGE" ]; then
        echo "  [Print] Applying G'MIC Palette Matching..."
        # Match palette, boost details
        gmic "$img" "$REFERENCE_IMAGE" \
             -transfer_colors[0] [1],1 \
             -remove[1] \
             -fx_enhance_color 1.1,0,0,0,0,0,0,0,0,0,0 \
             -output "$target_out"
             
        # Apply print-lift
        magick "$target_out" -gamma "$PRINT_LIGHTNESS_BUMP" "$target_out"

        # Inject professional metadata using exiftool
        exiftool \
            -Artist="$ARTIST_NAME" \
            -Copyright="$COPYRIGHT_NOTICE" \
            -CopyrightNotice="$COPYRIGHT_NOTICE" \
            -Comment="Purchased from $SHOP_URL" \
            -overwrite_original \
            "$target_out"
    else
        echo "  [Print] Applying ImageMagick Enhancements..."
        magick "$img" \
            -colorspace sRGB \
            -level 1%,99% \
            -gamma "$PRINT_LIGHTNESS_BUMP" \
            -modulate 100,112,100 \
            -sharpen 0x0.8 \
            "$target_out"

        # Inject professional metadata using exiftool
        exiftool \
            -Artist="$ARTIST_NAME" \
            -Copyright="$COPYRIGHT_NOTICE" \
            -CopyrightNotice="$COPYRIGHT_NOTICE" \
            -Comment="Purchased from $SHOP_URL" \
            -overwrite_original \
            "$target_out"
    fi
    echo "  ✓ Saved Print File: $target_out"

    # ----------------------------------------------------
    # STEP 2: CREATE LOW-RES WATERMARKED STORE PREVIEW
    # ----------------------------------------------------
    echo "  [Web]   Generating Watermarked Preview..."
    # Resize the print-ready image, then draw a clean shadow-backed watermark
    magick "$target_out" \
        -resize "${PREVIEW_WIDTH}x" \
        -gravity Center \
        -pointsize 60 \
        -fill "$WATERMARK_SHADOW_COLOR" -annotate +2+2 "$WATERMARK_TEXT" \
        -fill "$WATERMARK_COLOR"        -annotate +0+0 "$WATERMARK_TEXT" \
        -quality 82 \
        "$target_preview"
        
    echo "  ✓ Saved Preview File: $target_preview"
    echo "----------------------------------------"
done

echo "========================================"
echo "Batch processing complete!"
echo "Print-Ready files:   $OUTPUT_DIR"
echo "Watermarked Web:     $PREVIEW_DIR"
echo "========================================"
