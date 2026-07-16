#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
INPUT_DIR="./input_art"
OUTPUT_DIR="./normalized_art"
REFERENCE_IMAGE="" # Optional: e.g., "./reference.png"

# Print Adjustment: 1.0 is neutral. 
# 1.08 to 1.12 is the sweet spot for correcting the screen-to-print darkness gap.
PRINT_LIGHTNESS_BUMP="1.40" 

# Check if tools are installed
if ! command -v magick &> /dev/null || ! command -v gmic &> /dev/null; then
    echo "Error: Both ImageMagick ('magick') and G'MIC ('gmic') must be installed."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Process images recursively
find "$INPUT_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.tiff" \) -print0 | while IFS= read -r -d '' img; do
    # Calculate relative path and target output path
    rel_path="${img#$INPUT_DIR/}"
    target_out="$OUTPUT_DIR/$rel_path"
    
    # Ensure target subdirectory exists
    mkdir -p "$(dirname "$target_out")"
    
    filename=$(basename "$img")
    
    echo "----------------------------------------"
    echo "Processing: $rel_path"

    if [ -n "$REFERENCE_IMAGE" ] && [ -f "$REFERENCE_IMAGE" ]; then
        echo "-> Applying Color Palette Matching & Print Lightness..."
        # 1. Match the palette of the reference image
        # 2. Boost artistic colors
        # 3. Output to a temp file, then use ImageMagick to apply the precise print gamma correction
        gmic "$img" "$REFERENCE_IMAGE" \
             -transfer_colors[0] [1],1 \
             -remove[1] \
             -fx_enhance_color 1.1,0,0,0,0,0,0,0,0,0,0 \
             -output "$target_out"
             
        # Apply the lightness/gamma bump to the G'MIC output
        magick "$target_out" -gamma "$PRINT_LIGHTNESS_BUMP" "$target_out"
    else
        echo "-> Applying Standard Enhancements & Print Lightness..."
        # Integrated ImageMagick pipeline:
        # -level 1%,99%: Maximum clean contrast
        # -gamma: Safely raises midtones for printing without clipping highlights
        # -modulate: Boosts saturation slightly to prevent a washed-out print
        # -sharpen: Keeps edges crisp through the printing ink-absorption process
        magick "$img" \
            -colorspace sRGB \
            -level 1%,99% \
            -gamma "$PRINT_LIGHTNESS_BUMP" \
            -modulate 100,130,100 \
            -sharpen 0x0.8 \
            "$target_out"
    fi

    echo "✓ Saved to: $target_out"
done

echo "========================================"
echo "Batch processing complete! Check '$OUTPUT_DIR'"
