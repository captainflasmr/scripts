#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
INPUT_DIR="./input_art"
OUTPUT_DIR="./normalized_art"
# Optional: Set a path to a "style" reference image for palette matching
REFERENCE_IMAGE="" # e.g., "./reference.png"

# Check if tools are installed
if ! command -v magick &> /dev/null || ! command -v gmic &> /dev/null; then
    echo "Error: Both ImageMagick ('magick') and G'MIC ('gmic') must be installed."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Processing images from '$INPUT_DIR'..."

for img in "$INPUT_DIR"/*.{png,jpg,jpeg,tiff,PNG,JPG,JPEG,TIFF}; do
    # Skip if no matching files
    [ -f "$img" ] || continue
    
    filename=$(basename "$img")
    target_out="$OUTPUT_DIR/$filename"
    
    echo "----------------------------------------"
    echo "Processing: $filename"

    if [ -n "$REFERENCE_IMAGE" ] && [ -f "$REFERENCE_IMAGE" ]; then
        echo "-> Applying Color Palette Matching using G'MIC..."
        # 1. Match the color palette of the reference image
        # 2. Sharpen and enhance local details
        gmic "$img" "$REFERENCE_IMAGE" \
             -transfer_colors[0] [1],1 \
             -remove[1] \
             -fx_enhance_color 1.1,0,0,0,0,0,0,0,0,0,0 \
             -output "$target_out"
    else
        echo "-> Applying Standard Digital Art Enhancements..."
        # No reference image? Use a safe, high-pop ImageMagick pipeline:
        # -colorspace sRGB: Ensures consistent profile
        # -level 1%,99%: Clips noisy extremes while maximizing contrast
        # -modulate 100,112,100: Boosts saturation by 12% without altering hue
        # -sharpen: Crisp up details for digital display
        magick "$img" \
            -colorspace sRGB \
            -level 1%,99% \
            -modulate 100,112,100 \
            -sharpen 0x0.8 \
            "$target_out"
    fi

    echo "✓ Saved to: $target_out"
done

echo "========================================"
echo "Batch processing complete! Check '$OUTPUT_DIR'"
